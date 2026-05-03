"""VaxTrace AI — Risk prediction router with Gemini explanation layer"""

from datetime import date
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import (
    ChildORM, RiskPredictionRequest, RiskScoreOut, RiskScoreORM, RiskLevel
)
from app.routers.auth import get_current_user
from app.services.risk_engine import compute_risk_score
from app.services import gemini_service

router = APIRouter(prefix="/predict", tags=["predictions"])


def _age_in_months(dob: date | None) -> int:
    if dob is None:
        return 0
    today = date.today()
    return max(0, (today.year - dob.year) * 12 + (today.month - dob.month))


@router.post("/risk", response_model=RiskScoreOut)
async def predict_risk(
    req: RiskPredictionRequest,
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    """
    Compute and persist a risk score for a child.
    For high-risk children (score >= 40), also calls Gemini Flash to generate
    a plain-language explanation for the field worker.
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
        age_months=_age_in_months(child.date_of_birth),
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

    # Generate AI explanation for high-risk children (async, non-blocking on failure)
    risk_with_context = {
        **risk,
        "distance_from_clinic_km": req.distance_from_clinic_km,
        "days_since_last_dose": req.days_since_last_dose,
    }
    explanation = await gemini_service.generate_explanation(child, risk_with_context)

    return {
        "child_id": str(score_record.child_id),
        "score": score_record.score,
        "risk_level": score_record.risk_level,
        "distance_from_clinic_km": score_record.distance_from_clinic_km,
        "days_since_last_dose": score_record.days_since_last_dose,
        "model_version": score_record.model_version,
        "computed_at": score_record.computed_at,
        "explanation": explanation,
    }
