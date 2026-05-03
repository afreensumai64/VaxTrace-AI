"""
VaxTrace AI — Synthetic Seed Data Generator
Inserts directly into SQLite — no HTTP, no auth, instant.

Run from backend/ folder:
    python seed.py
"""

import asyncio
import random
import uuid
from datetime import date, timedelta

from dotenv import load_dotenv
load_dotenv()

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.models import ChildORM, RiskLevel, SyncStatus


def formula_risk(distance_km: float, days_since_dose: int, age_months: int) -> dict:
    """Graduated risk scoring — no XGBoost, deterministic distribution."""
    dist_score  = min(distance_km * 4.0, 40)
    days_score  = min(days_since_dose * 0.45, 45)
    age_penalty = 5 if age_months < 6 else 0
    score = round(min(dist_score + days_score + age_penalty, 100), 1)
    if score < 25:
        level = "low"
    elif score < 50:
        level = "medium"
    elif score < 70:
        level = "high"
    else:
        level = "critical"
    return {"score": score, "risk_level": level}

DATABASE_URL = "sqlite+aiosqlite:///./vaxtrace.db"

TOTAL = 1000

VILLAGES = [
    {"id": "chak-42-punjab",    "name": "Chak 42 (Punjab)",     "lat": 30.3753, "lng": 72.8656, "spread": 0.04, "km": 6.0,  "n": 220},
    {"id": "rahim-yar-khan",    "name": "Rahim Yar Khan",        "lat": 28.4212, "lng": 70.2989, "spread": 0.05, "km": 11.0, "n": 210},
    {"id": "muzaffargarh",      "name": "Muzaffargarh",          "lat": 30.0727, "lng": 71.1934, "spread": 0.03, "km": 4.5,  "n": 180},
    {"id": "kahama-tanzania",   "name": "Kahama (Tanzania)",     "lat": -3.8333, "lng": 31.6000, "spread": 0.06, "km": 14.0, "n": 210},
    {"id": "garissa-kenya",     "name": "Garissa (Kenya)",       "lat": -0.4532, "lng": 39.6461, "spread": 0.05, "km": 9.0,  "n": 180},
]

SA_NAMES = ["Aisha","Fatima","Zainab","Maryam","Noor","Sana","Khadija","Amina",
            "Hira","Rabia","Layla","Yasmin","Muhammad","Ali","Hassan","Omar",
            "Ibrahim","Yusuf","Bilal","Hamza","Abdullah","Tariq","Usman","Zaid"]
AF_NAMES = ["Amina","Fatuma","Zuhura","Halima","Jamila","Neema","Furaha","Salama",
            "Baraka","Rahma","Juma","Hassan","Saidi","Bakari","Kombo","Idris",
            "Musa","Rajabu","Hamisi","Rashid"]

SA_GUARDIANS = ["Fatima Bibi","Amina Khatun","Rukhsana Begum","Nasreen Akhtar",
                "Zarina Parveen","Muhammad Anwar","Abdul Rashid","Ghulam Mustafa",
                "Liaqat Ali","Muhammad Aslam","Riaz Ahmed","Bashir Ahmad"]
AF_GUARDIANS = ["Mama Fatuma","Mama Amina","Bi Zuhura","Mama Halima",
                "Baba Juma","Mzee Hassan","Baba Saidi","Mama Neema",
                "Bi Salama","Baba Kombo","Mzee Rashid"]

VACCINES = ["BCG","OPV-1","OPV-2","OPV-3",
            "Pentavalent-1","Pentavalent-2","Pentavalent-3",
            "Measles","Pneumococcal","Rotavirus"]

# (weight, days_since_min, days_since_max, extra_km_min, extra_km_max)
RISK_PROFILES = [
    (0.38,  7,  28,  0.0, 1.5),   # low
    (0.30, 30,  59,  1.0, 3.5),   # medium
    (0.20, 60, 119,  2.0, 6.0),   # high
    (0.12,120, 200,  4.0,11.0),   # critical
]

def pick_profile():
    r = random.random()
    cum = 0
    for w, d0, d1, k0, k1 in RISK_PROFILES:
        cum += w
        if r < cum:
            return d0, d1, k0, k1
    return RISK_PROFILES[-1][1:]

def phone(village_id):
    if "tanzania" in village_id or "kenya" in village_id:
        return f"+255{random.randint(700000000,799999999)}"
    return f"03{random.randint(10,49)}{random.randint(1000000,9999999)}"

def make_child(village):
    africa = "tanzania" in village["id"] or "kenya" in village["id"]
    name    = random.choice(AF_NAMES    if africa else SA_NAMES)
    guardian= random.choice(AF_GUARDIANS if africa else SA_GUARDIANS)

    age_months = random.choices(range(2, 37), weights=[
        *[4]*5, *[5]*6, *[4]*6, *[3]*6, *[2]*12], k=1)[0]
    dob = date.today() - timedelta(days=age_months * 30)

    d0, d1, k0, k1 = pick_profile()
    days = random.randint(d0, d1)
    last_dose = date.today() - timedelta(days=days)
    next_due  = last_dose + timedelta(days=random.randint(28, 56))
    vaccine   = random.choice(VACCINES)

    lat = village["lat"] + random.uniform(-village["spread"], village["spread"])
    lng = village["lng"] + random.uniform(-village["spread"], village["spread"])
    km  = max(0.5, round(village["km"] + random.uniform(k0, k1) - 3.0, 1))

    risk = formula_risk(
        distance_km=km,
        days_since_dose=days,
        age_months=age_months,
    )

    return ChildORM(
        id=uuid.uuid4(),
        name=name,
        date_of_birth=dob,
        guardian_name=guardian,
        guardian_phone=phone(village["id"]),
        village_id=village["id"],
        village_name=village["name"],
        latitude=round(lat, 6),
        longitude=round(lng, 6),
        distance_from_clinic_km=km,
        last_dose_date=last_dose,
        last_vaccine_name=vaccine,
        next_due_date=next_due,
        risk_score=risk["score"],
        risk_level=RiskLevel(risk["risk_level"]),
        is_high_risk=risk["score"] >= 40,
        is_synced=True,
        sync_status=SyncStatus.SYNCED,
        created_by_uid="seed-script",
    )


async def main():
    print("VaxTrace AI — Seed Data Generator")
    print(f"Target: {TOTAL} children across {len(VILLAGES)} villages\n")

    engine = create_async_engine(DATABASE_URL, echo=False)
    Session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    total_pop = sum(v["n"] for v in VILLAGES)
    children = []
    for village in VILLAGES:
        count = round(TOTAL * village["n"] / total_pop)
        for _ in range(count):
            children.append(make_child(village))

    while len(children) < TOTAL:
        children.append(make_child(random.choice(VILLAGES)))
    children = children[:TOTAL]
    random.shuffle(children)

    # Insert in batches of 100
    batch_size = 100
    inserted = 0
    async with Session() as session:
        for i in range(0, len(children), batch_size):
            batch = children[i:i + batch_size]
            session.add_all(batch)
            await session.commit()
            inserted += len(batch)
            print(f"  Inserted {inserted}/{TOTAL} children...")

    # Risk summary
    low      = sum(1 for c in children if c.risk_level == RiskLevel.LOW)
    medium   = sum(1 for c in children if c.risk_level == RiskLevel.MEDIUM)
    high     = sum(1 for c in children if c.risk_level == RiskLevel.HIGH)
    critical = sum(1 for c in children if c.risk_level == RiskLevel.CRITICAL)

    print(f"\nDone! {inserted} children inserted.")
    print(f"\nRisk distribution:")
    print(f"  Low:      {low:4d} ({low/TOTAL*100:.0f}%)")
    print(f"  Medium:   {medium:4d} ({medium/TOTAL*100:.0f}%)")
    print(f"  High:     {high:4d} ({high/TOTAL*100:.0f}%)")
    print(f"  Critical: {critical:4d} ({critical/TOTAL*100:.0f}%)")
    print(f"\nVillage breakdown:")
    for v in VILLAGES:
        n = sum(1 for c in children if c.village_id == v["id"])
        print(f"  {v['name']:30s} {n:3d} children")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
