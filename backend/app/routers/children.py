"""VaxTrace AI — Children router"""

import math
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import (
    ChildORM, ChildCreate, ChildOut, ChildUpdate,
    HighRiskListResponse, RiskLevel, SyncStatus
)
from app.routers.auth import get_current_user
from app.services.risk_engine import compute_risk_score, days_since


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in km."""
    R = 6371
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = math.sin(d_lat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lng / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _nearest_neighbor_sort(children: list, start_lat: float, start_lng: float) -> list:
    """Greedy nearest-neighbor route starting from clinic coordinates."""
    unmapped = [c for c in children if c.latitude is not None and c.longitude is not None]
    no_gps   = [c for c in children if c.latitude is None or c.longitude is None]

    visited, cur_lat, cur_lng = [], start_lat, start_lng
    remaining = list(unmapped)
    while remaining:
        nearest = min(remaining, key=lambda c: _haversine_km(cur_lat, cur_lng, c.latitude, c.longitude))
        visited.append(nearest)
        cur_lat, cur_lng = nearest.latitude, nearest.longitude
        remaining.remove(nearest)

    return visited + no_gps  # GPS children first, rest appended

router = APIRouter(prefix="/children", tags=["children"])


def _apply_risk(child: ChildORM) -> None:
    """Recompute and apply risk score to an ORM instance."""
    d_since = days_since(child.last_dose_date)
    result = compute_risk_score(
        distance_from_clinic_km=child.distance_from_clinic_km,
        days_since_last_dose=d_since,
    )
    child.risk_score = result["score"]
    child.risk_level = RiskLevel(result["risk_level"])
    child.is_high_risk = result["score"] >= 40


@router.get("", response_model=list[ChildOut])
async def list_children(
    village_id: Optional[str] = Query(None),
    risk_level: Optional[str] = Query(None),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    stmt = select(ChildORM).options(selectinload(ChildORM.vaccination_records))
    if village_id:
        stmt = stmt.where(ChildORM.village_id == village_id)
    if risk_level:
        stmt = stmt.where(ChildORM.risk_level == RiskLevel(risk_level))
    stmt = stmt.order_by(desc(ChildORM.risk_score)).offset(offset).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("", response_model=ChildOut, status_code=status.HTTP_201_CREATED)
async def create_child(
    child_in: ChildCreate,
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    child = ChildORM(**child_in.model_dump(), created_by_uid=user["uid"])
    _apply_risk(child)
    child.is_synced = True
    child.sync_status = SyncStatus.SYNCED
    db.add(child)
    await db.commit()
    # Re-query with eager load so vaccination_records is available for serialization
    result = await db.execute(
        select(ChildORM)
        .options(selectinload(ChildORM.vaccination_records))
        .where(ChildORM.id == child.id)
    )
    return result.scalar_one()


@router.get("/high-risk", response_model=HighRiskListResponse)
async def get_high_risk_children(
    limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    stmt = (
        select(ChildORM)
        .options(selectinload(ChildORM.vaccination_records))
        .where(ChildORM.is_high_risk == True)
        .order_by(desc(ChildORM.risk_score))
        .limit(limit)
    )
    result = await db.execute(stmt)
    children = result.scalars().all()
    return HighRiskListResponse(total=len(children), children=children)


@router.get("/village-stats")
async def get_village_stats(
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    """
    Returns per-village aggregate stats for the NGO dashboard.
    """
    from sqlalchemy import func as sqlfunc
    stmt = select(
        ChildORM.village_id,
        ChildORM.village_name,
        sqlfunc.count(ChildORM.id).label("total"),
        sqlfunc.sum(ChildORM.is_high_risk.cast(type_=type(True))).label("high_risk"),
        sqlfunc.avg(ChildORM.risk_score).label("avg_risk_score"),
    ).group_by(ChildORM.village_id, ChildORM.village_name)
    result = await db.execute(stmt)
    rows = result.fetchall()

    villages = []
    for row in rows:
        total = row.total or 0
        high_risk = int(row.high_risk or 0)
        avg_score = float(row.avg_risk_score or 0)
        coverage = round((total - high_risk) / total * 100, 1) if total > 0 else 0.0
        if avg_score >= 60:
            zone = "critical"
        elif avg_score >= 40:
            zone = "high"
        elif avg_score >= 20:
            zone = "medium"
        else:
            zone = "low"
        villages.append({
            "village_id": row.village_id,
            "village_name": row.village_name,
            "total_children": total,
            "high_risk_count": high_risk,
            "avg_risk_score": round(avg_score, 1),
            "coverage_pct": coverage,
            "zone": zone,
        })

    villages.sort(key=lambda v: v["avg_risk_score"], reverse=True)
    return {"villages": villages, "total_villages": len(villages)}


@router.get("/route", response_model=HighRiskListResponse)
async def get_daily_route(
    clinic_lat: float = Query(30.3753, description="Clinic latitude"),
    clinic_lng: float = Query(72.8656, description="Clinic longitude"),
    limit: int = Query(30, le=100),
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    """
    Returns today's high-risk children sorted into an optimized visit route
    using a greedy nearest-neighbor algorithm starting from the clinic.
    """
    stmt = (
        select(ChildORM)
        .options(selectinload(ChildORM.vaccination_records))
        .where(ChildORM.is_high_risk == True)
        .order_by(desc(ChildORM.risk_score))
        .limit(limit)
    )
    result = await db.execute(stmt)
    children = list(result.scalars().all())
    ordered = _nearest_neighbor_sort(children, clinic_lat, clinic_lng)
    return HighRiskListResponse(total=len(ordered), children=ordered)


@router.get("/{child_id}", response_model=ChildOut)
async def get_child(
    child_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    stmt = (
        select(ChildORM)
        .options(selectinload(ChildORM.vaccination_records))
        .where(ChildORM.id == child_id)
    )
    result = await db.execute(stmt)
    child = result.scalar_one_or_none()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")
    return child


@router.put("/{child_id}", response_model=ChildOut)
async def update_child(
    child_id: UUID,
    updates: ChildUpdate,
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    result = await db.execute(select(ChildORM).where(ChildORM.id == child_id))
    child = result.scalar_one_or_none()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")
    for field, value in updates.model_dump(exclude_none=True).items():
        setattr(child, field, value)
    _apply_risk(child)
    await db.commit()
    result = await db.execute(
        select(ChildORM)
        .options(selectinload(ChildORM.vaccination_records))
        .where(ChildORM.id == child_id)
    )
    return result.scalar_one()


@router.delete("/{child_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_child(
    child_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    result = await db.execute(select(ChildORM).where(ChildORM.id == child_id))
    child = result.scalar_one_or_none()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")
    await db.delete(child)
    await db.commit()
