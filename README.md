# VaxTrace AI

**GNEC Hackathon 2026 Spring · UN SDG 3 — Good Health and Well-being**

> *"14.3 million children worldwide receive zero vaccine doses. VaxTrace AI tells field workers which child to visit next — and why — in their own language, offline."*

---

## The Problem

Childhood vaccine dropout is highest where it's hardest to track: remote villages, conflict zones, areas with no connectivity. Existing tools (UNICEF VaccTrace, Pakistan's Zindagi Mehfooz, India's U-WIN) record **what happened**. None predict **what will happen next**.

A field health worker in rural Punjab or coastal Kenya carries a paper list and walks door-to-door by memory. Children fall through the cracks.

---

## Our Solution

VaxTrace AI adds an **explainable AI reasoning layer** on top of standard vaccination records:

1. **Risk Prediction** — XGBoost model scores every child (distance from clinic + days overdue + age)
2. **Plain-language Explanation** — Gemini Flash converts each score into a 2-sentence human-readable alert
3. **Voice Output** — flutter_tts reads the explanation aloud in the worker's local language (offline)
4. **Smart Route** — Map screen shows today's high-risk visits in optimized order (nearest-neighbor routing)
5. **SnapCard OCR** — Scan a paper vaccination card with Google ML Kit, auto-fill the form
6. **NGO Dashboard** — Village-level red/yellow/green zones, risk distribution, sync status

**Example output:** *"Aisha, 8 months. HIGH RISK. Last dose missed and 6.2 km from clinic. Visit before Tuesday."*

---

## Key Differentiators

| Feature | VaxTrace AI | Existing Tools |
|---|---|---|
| Risk prediction | ✅ XGBoost + rule engine | ❌ Manual assessment |
| AI explanation | ✅ Gemini Flash, 2-sentence | ❌ None |
| Voice alerts | ✅ On-device TTS, offline | ❌ None |
| Offline-first | ✅ SQLite + sync | ⚠️ Partial |
| Zero cost | ✅ Free tier only | ⚠️ Varies |
| Paper card OCR | ✅ Google ML Kit | ❌ None |

---

## Tech Stack

```
Flutter (Android)          FastAPI (Python)
├── sqflite (offline DB)   ├── SQLAlchemy + asyncpg
├── flutter_map (OSM)      ├── XGBoost risk model
├── Google ML Kit (OCR)    ├── Gemini Flash 2.5 (AI)
├── flutter_tts (voice)    ├── JWT auth
└── Riverpod (state)       └── Supabase PostgreSQL
```

**Cost: $0.** Every component runs on a free tier. No credit card required.

---

## Architecture

```
Android Device (offline)          Backend (Render free)
┌─────────────────────┐          ┌────────────────────────┐
│  Flutter App        │  HTTPS   │  FastAPI               │
│  ├─ SQLite (local)  │◄────────►│  ├─ /predict/risk      │
│  ├─ OCR (ML Kit)    │          │  │    └─ XGBoost score  │
│  ├─ TTS (offline)   │          │  │    └─ Gemini explain │
│  └─ Map (OSM)       │          │  ├─ /children/route     │
└─────────────────────┘          │  ├─ /children/village-stats
                                 │  └─ Supabase PostgreSQL │
                                 └────────────────────────┘
```

Offline-first: all reads from local SQLite. Sync runs when connectivity returns.

---

## Quick Start (Local Dev)

### Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env: add GOOGLE_API_KEY from Google AI Studio (free)

# Start server
uvicorn app.main:app --reload

# Seed 1,000 synthetic children (5 villages, realistic risk distribution)
python seed.py
```

API runs at `http://localhost:8000`. Docs at `http://localhost:8000/docs`.

### Flutter App

```bash
cd flutter_app
flutter pub get

# Point to your backend (providers.dart line 20):
# const String _kBaseUrl = 'http://<YOUR_IP>:8000';

flutter run
```

---

## Demo Script (3 minutes)

| Time | Screen | What to show |
|---|---|---|
| 0:00–0:30 | Dashboard | 1,000 children, village zones (red/yellow/green), "Today's Route" |
| 0:30–1:00 | Route Map | Numbered markers, visit order, tap a child |
| 1:00–1:45 | Child Detail | Tap "Analyze Risk" → Gemini explanation loads → tap speaker icon → TTS reads aloud |
| 1:45–2:15 | SnapCard OCR | Scan a paper card → name + date auto-fill → confirm + save |
| 2:15–2:45 | Dashboard (refresh) | New child appears, risk score shown, offline indicator |
| 2:45–3:00 | Summary | Zero cost, works offline, 14.3M children problem |

---

## Seed Data

The `backend/seed.py` script inserts 1,000 synthetic children across 5 villages:

| Village | Country | Children | Avg Risk |
|---|---|---|---|
| Chak 42 (Punjab) | Pakistan | 220 | Medium |
| Rahim Yar Khan | Pakistan | 210 | High |
| Muzaffargarh | Pakistan | 180 | Medium |
| Kahama | Tanzania | 210 | Critical |
| Garissa | Kenya | 180 | High |

Risk distribution: ~14% Low · 33% Medium · 27% High · 26% Critical

Names, GPS coordinates, and dropout patterns based on WHO WUENIC field data.

---

## API Reference

| Endpoint | Description |
|---|---|
| `POST /auth/login` | JWT login |
| `GET /children` | List children (filter by village, risk level) |
| `POST /children` | Register new child |
| `GET /children/high-risk` | High-risk children sorted by score |
| `GET /children/route` | Today's route (nearest-neighbor optimized) |
| `GET /children/village-stats` | Village-level aggregate stats |
| `POST /predict/risk` | XGBoost score + Gemini explanation |
| `POST /sync` | Bulk offline sync |

Full docs: `http://localhost:8000/docs`

---

## Deployment

See `SETUP_GUIDE.md` for step-by-step Render + Supabase setup (both free tier, no credit card).

---

## Ethical Disclaimer

This is a prototype with **synthetic data only**. No real children, no real health records, no real medical validation. Intended for demonstration purposes at GNEC Hackathon 2026. Any production deployment would require ethics review, clinical validation, and compliance with local health data regulations.

---

## Team

Built for **GNEC Hackathon 2026 Spring** — Theme: UN SDG 3 (Good Health and Well-being)

**Hamza Atiq** · hamzaatiq34@gmail.com
