"""VaxTrace AI — Children router"""

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
from app.services.firebase_auth import get_current_user
from app.services.risk_engine import compute_risk_score, days_since

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
    await db.refresh(child)
    return child


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
    await db.refresh(child)
    return child


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
