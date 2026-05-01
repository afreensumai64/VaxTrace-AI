"""VaxTrace AI — Offline sync router"""

from datetime import datetime
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import SyncPayload, SyncResult
from app.services.firebase_auth import get_current_user
from app.services.sync_service import bulk_sync

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("", response_model=SyncResult, status_code=status.HTTP_200_OK)
async def sync_offline_data(
    payload: SyncPayload,
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    """
    Bulk upsert endpoint for Flutter offline-first sync.
    Called when device regains internet connectivity.
    """
    result = await bulk_sync(
        db=db,
        children=payload.children,
        records=payload.vaccination_records,
        firebase_uid=user["uid"],
    )
    return result
