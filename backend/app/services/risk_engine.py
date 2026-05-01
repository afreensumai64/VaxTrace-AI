"""
VaxTrace AI — NextChild Risk Engine
Primary: RiskScore = (distance_km * 0.3) + (days_since_dose * 0.7)
Advanced: XGBoost model (loaded from model.pkl if available)
"""

import os
import math
import logging
from datetime import date
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────
# Risk thresholds
# ─────────────────────────────────────────────
RISK_THRESHOLDS = {
    "low":      (0,   20),
    "medium":   (20,  40),
    "high":     (40,  60),
    "critical": (60,  math.inf),
}

MODEL_PATH = Path(__file__).parent.parent.parent / "ml" / "model.pkl"

# Attempt to load XGBoost model
_xgb_model = None
_model_version = "formula_v1"

try:
    import joblib
    if MODEL_PATH.exists():
        _xgb_model = joblib.load(MODEL_PATH)
        _model_version = "xgboost_v1"
        logger.info("✅ XGBoost model loaded from %s", MODEL_PATH)
    else:
        logger.info("ℹ️  No model.pkl found — using formula-based scoring")
except ImportError:
    logger.warning("joblib not installed — formula-based scoring only")


# ─────────────────────────────────────────────
# Core scoring logic
# ─────────────────────────────────────────────

def compute_risk_score(
    distance_from_clinic_km: float,
    days_since_last_dose: int,
    age_months: Optional[int] = None,
    missed_appointments: int = 0,
) -> dict:
    """
    Compute a risk score for a child.

    Formula (fallback):
        RiskScore = (distance_km * 0.3) + (days_since_dose * 0.7)

    XGBoost model (if available):
        Features: [distance_km, days_since_dose, age_months, missed_appointments]

    Returns:
        {score, risk_level, model_version}
    """
    if _xgb_model is not None:
        score = _xgb_score(distance_from_clinic_km, days_since_last_dose,
                           age_months or 0, missed_appointments)
    else:
        score = _formula_score(distance_from_clinic_km, days_since_last_dose)

    risk_level = _classify(score)
    return {
        "score": round(score, 2),
        "risk_level": risk_level,
        "model_version": _model_version,
    }


def _formula_score(distance_km: float, days_since_dose: int) -> float:
    """Deterministic formula as defined in product spec."""
    return (distance_km * 0.3) + (days_since_dose * 0.7)


def _xgb_score(distance_km: float, days_since_dose: int,
               age_months: int, missed_appointments: int) -> float:
    import numpy as np
    features = np.array([[distance_km, days_since_dose, age_months, missed_appointments]])
    raw = _xgb_model.predict(features)[0]
    # Scale 0-1 probability to 0-100 score
    return float(raw) * 100


def _classify(score: float) -> str:
    for level, (lo, hi) in RISK_THRESHOLDS.items():
        if lo <= score < hi:
            return level
    return "critical"


def days_since(d: Optional[date]) -> int:
    if d is None:
        return 9999
    return (date.today() - d).days
