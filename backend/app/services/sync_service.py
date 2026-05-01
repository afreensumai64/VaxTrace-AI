"""
VaxTrace AI — Offline sync service
Handles bulk upsert of children + vaccination records from Flutter devices.
"""

import logging
from datetime import datetime
from typing import List

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.models import (
    ChildORM, VaccinationRecordORM, ChildCreate,
    VaccinationRecordCreate, SyncResult, RiskLevel, SyncStatus
)
from app.services.risk_engine import compute_risk_score, days_since

logger = logging.getLogger(__name__)


async def bulk_sync(
    db: AsyncSession,
    children: List[ChildCreate],
    records: List[VaccinationRecordCreate],
    firebase_uid: str,
) -> SyncResult:
    errors: List[str] = []
    synced_children = 0
    synced_records = 0

    # Upsert children
    for child_data in children:
        try:
            data = child_data.model_dump()
            # Compute risk score from available data
            d_since = days_since(child_data.last_dose_date)
            risk = compute_risk_score(
                distance_from_clinic_km=child_data.distance_from_clinic_km,
                days_since_last_dose=d_since,
            )
            data.update({
                "risk_score": risk["score"],
                "risk_level": RiskLevel(risk["risk_level"]),
                "is_high_risk": risk["score"] >= 40,
                "is_synced": True,
                "sync_status": SyncStatus.SYNCED,
                "created_by_uid": firebase_uid,
            })

            stmt = pg_insert(ChildORM).values(**data)
            stmt = stmt.on_conflict_do_update(
                index_elements=["client_id"],
                set_={k: v for k, v in data.items() if k != "id"},
            )
            await db.execute(stmt)
            synced_children += 1
        except Exception as e:
            logger.error("Sync child error: %s", e)
            errors.append(f"Child '{child_data.name}': {str(e)}")

    # Upsert vaccination records
    for rec_data in records:
        try:
            data = rec_data.model_dump()
            data.update({
                "is_synced": True,
                "sync_status": SyncStatus.SYNCED,
                "created_by_uid": firebase_uid,
            })
            stmt = pg_insert(VaccinationRecordORM).values(**data)
            stmt = stmt.on_conflict_do_update(
                index_elements=["client_id"],
                set_={k: v for k, v in data.items() if k != "id"},
            )
            await db.execute(stmt)
            synced_records += 1
        except Exception as e:
            logger.error("Sync record error: %s", e)
            errors.append(f"Record '{rec_data.vaccine_name}': {str(e)}")

    await db.commit()

    return SyncResult(
        synced_children=synced_children,
        synced_records=synced_records,
        errors=errors,
        server_time=datetime.utcnow(),
    )
