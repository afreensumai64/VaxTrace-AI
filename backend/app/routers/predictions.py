"""VaxTrace AI — Risk prediction router"""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import (
    ChildORM, RiskPredictionRequest, RiskScoreOut, RiskScoreORM, RiskLevel
)
from app.services.firebase_auth import get_current_user
from app.services.risk_engine import compute_risk_score

router = APIRouter(prefix="/predict", tags=["predictions"])


@router.post("/risk", response_model=RiskScoreOut)
async def predict_risk(
    req: RiskPredictionRequest,
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    """
    Compute and persist a risk score for a child.
    Uses XGBoost if model.pkl is available, otherwise formula.
    """
    result = await db.execute(
        select(ChildORM).where(ChildORM.id == UUID(req.child_id))
    )
    child = result.scalar_one_or_none()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")

    risk = compute_risk_score(
        distance_from_clinic_km=req.distance_from_clinic_km,
        days_since_last_dose=req.days_since_last_dose,
        age_months=child.date_of_birth and
            ((child.date_of_birth.year - child.date_of_birth.year) * 12),
    )

    # Persist snapshot
    score_record = RiskScoreORM(
        child_id=child.id,
        score=risk["score"],
        risk_level=RiskLevel(risk["risk_level"]),
        distance_from_clinic_km=req.distance_from_clinic_km,
        days_since_last_dose=req.days_since_last_dose,
        model_version=risk["model_version"],
    )
    db.add(score_record)

    # Update child
    child.risk_score = risk["score"]
    child.risk_level = RiskLevel(risk["risk_level"])
    child.is_high_risk = risk["score"] >= 40

    await db.commit()
    await db.refresh(score_record)
    return score_record
