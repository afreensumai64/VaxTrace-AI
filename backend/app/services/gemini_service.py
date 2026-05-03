"""
VaxTrace AI — Gemini Flash Explanation Service
Converts XGBoost risk scores into plain-language, actionable field-worker explanations.
Only called for high-risk children (score >= 40) to stay within the free-tier quota.
Returns None on any failure — never raises.
"""

import os
import logging
import asyncio
from datetime import date
from typing import Optional

logger = logging.getLogger(__name__)

_GEMINI_TIMEOUT_SECONDS = 8
_HIGH_RISK_THRESHOLD = 40

_PROMPT_TEMPLATE = """\
You are a vaccine dropout prevention assistant for field health workers in remote areas.

A child has been flagged as high risk. Generate exactly 2 sentences.
Sentence 1: state the child's name, age in months, risk level, and the single biggest risk factor (missed dose or long distance).
Sentence 2: give one specific, actionable instruction with a time-urgency cue (e.g. "Visit before Friday").

Child details:
- Name: {name}
- Age: {age_months} months
- Risk level: {risk_level} (score {score}/100)
- Last vaccine: {last_vaccine_name}, given {days_since_last_dose} days ago
- Distance from clinic: {distance_km} km
- Next dose due: {next_due_date}

Rules: plain English, no medical jargon, no markdown, no bullet points, under 50 words total.\
"""


def _age_in_months(dob: Optional[date]) -> int:
    if dob is None:
        return 0
    today = date.today()
    return max(0, (today.year - dob.year) * 12 + (today.month - dob.month))


def _build_prompt(child, risk: dict) -> str:
    age = _age_in_months(child.date_of_birth)
    last_vaccine = child.last_vaccine_name or "unknown vaccine"
    days_since = risk.get("days_since_last_dose", 0)
    distance = risk.get("distance_from_clinic_km", 0.0)
    next_due = child.next_due_date.strftime("%B %d") if child.next_due_date else "not scheduled"

    return _PROMPT_TEMPLATE.format(
        name=child.name,
        age_months=age,
        risk_level=risk["risk_level"].upper(),
        score=int(risk["score"]),
        last_vaccine_name=last_vaccine,
        days_since_last_dose=days_since,
        distance_km=f"{distance:.1f}",
        next_due_date=next_due,
    )


async def generate_explanation(child, risk: dict) -> Optional[str]:
    """
    Generate a 2-sentence plain-language explanation for a high-risk child.
    Returns None silently on any error or if score < threshold.
    """
    if risk.get("score", 0) < _HIGH_RISK_THRESHOLD:
        return None

    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        logger.warning("GOOGLE_API_KEY not set — skipping Gemini explanation")
        return None

    try:
        import google.generativeai as genai

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-2.5-flash")
        prompt = _build_prompt(child, risk)

        loop = asyncio.get_event_loop()
        response = await asyncio.wait_for(
            loop.run_in_executor(None, lambda: model.generate_content(prompt)),
            timeout=_GEMINI_TIMEOUT_SECONDS,
        )

        text = response.text.strip()
        logger.info("Gemini explanation generated for child %s (%d chars)", child.id, len(text))
        return text

    except asyncio.TimeoutError:
        logger.warning("Gemini timed out for child %s", child.id)
        return None
    except Exception as exc:
        logger.warning("Gemini error for child %s: %s", child.id, exc)
        return None
