"""VaxTrace AI — Vaccination records router"""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import (
    VaccinationRecordORM, VaccinationRecordCreate,
    VaccinationRecordOut, ChildORM, SyncStatus
)
from app.services.firebase_auth import get_current_user

router = APIRouter(prefix="/vaccines", tags=["vaccines"])


@router.get("/{child_id}", response_model=list[VaccinationRecordOut])
async def get_records_for_child(
    child_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    stmt = (
        select(VaccinationRecordORM)
        .where(VaccinationRecordORM.child_id == child_id)
        .order_by(VaccinationRecordORM.date_administered.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("", response_model=VaccinationRecordOut, status_code=status.HTTP_201_CREATED)
async def create_record(
    record_in: VaccinationRecordCreate,
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    # Verify child exists
    child_result = await db.execute(
        select(ChildORM).where(ChildORM.id == UUID(record_in.child_id))
    )
    if not child_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Child not found")

    record = VaccinationRecordORM(
        **record_in.model_dump(),
        is_synced=True,
        sync_status=SyncStatus.SYNCED,
        created_by_uid=user["uid"],
    )
    db.add(record)

    # Update child's last_dose_date + last_vaccine_name
    child = child_result.scalar_one_or_none()
    if child:
        if child.last_dose_date is None or record_in.date_administered > child.last_dose_date:
            child.last_dose_date = record_in.date_administered
            child.last_vaccine_name = record_in.vaccine_name

    await db.commit()
    await db.refresh(record)
    return record
