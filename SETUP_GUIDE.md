# VaxTrace AI — Zero-Cost Setup Guide
# All services below have free tiers with NO credit card required.

---

## Stack at a Glance

| Component | Service | Cost | Card Required? |
|---|---|---|---|
| **Backend Hosting** | Render.com Free Web Service | $0 | ❌ No |
| **Database** | Supabase (500MB PostgreSQL) | $0 | ❌ No |
| **Auth** | JWT (built into FastAPI) | $0 | ❌ No |
| **Maps** | OpenStreetMap + flutter_map | $0 | ❌ No |
| **OCR** | Google ML Kit (on-device) | $0 | ❌ No |
| **TTS** | flutter_tts (on-device) | $0 | ❌ No |

---

## 1. 🗄️ Supabase — Free PostgreSQL Database

No credit card. No billing info. Just an email.

### Step 1: Create account
1. Go to [supabase.com](https://supabase.com) → **Start for Free**
2. Sign up with GitHub or email
3. Click **New Project** → fill in name (`vaxtrace-ai`) and database password
4. Select region: **Southeast Asia (Singapore)** for low latency

### Step 2: Get connection string
1. In your project → **Settings → Database**
2. Scroll to **Connection string → URI**
3. Select **"Transaction pooler"** mode (required for Render free tier)
4. Copy the string, replace `[YOUR-PASSWORD]` with your DB password

The string will look like:
```
postgresql://postgres.xxxx:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres
```

### Step 3: Set as environment variable on Render
In Render dashboard → your service → **Environment**:
```
DATABASE_URL=postgresql+asyncpg://postgres.xxxx:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres
```

> **Free limits**: 500 MB storage, 2 GB data transfer/month. Enough for thousands of child records.

---

## 2. 🔐 JWT Auth (Built-in FastAPI — Zero External Deps)

No Firebase, no Supabase Auth, no credit card. Pure server-side JWT.

### Step 1: Generate a secure secret key
```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

### Step 2: Set as Render environment variable
```
JWT_SECRET_KEY=your-generated-64-char-hex-string
JWT_EXPIRE_MINUTES=1440
```

### Step 3: Register a health worker account
After deployment, call:
```bash
curl -X POST https://your-app.onrender.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "worker@clinic.org", "password": "securepass123", "display_name": "Field Worker"}'
```

### Step 4: Flutter — update auth service
Open `flutter_app/lib/services/firebase_auth_service.dart` and note there's a
**TODO** comment to swap `firebase_auth` for direct JWT calls.
A pre-built `JwtAuthService` file is available as an alternative (see below).

---

## 3. 🗺️ OpenStreetMap (Zero Config)

**No API key. No account. Just works.**

`flutter_map` reads tiles from `https://tile.openstreetmap.org/{z}/{x}/{y}.png` —
this is free under the [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).

> For production with > 100 users, self-host tiles using:
> - **Protomaps** (free self-hosted PMTiles format)
> - **Stadia Maps** (free tier 200K requests/month, no card)

---

## 4. 🤖 XGBoost Model — Bake into Docker Image

Run the trainer once before deploying to Render:

```bash
cd backend
pip install -r requirements.txt
python ml/train_model.py
# Creates: backend/ml/model.pkl (~2-5 MB)
```

The `Dockerfile` bakes `model.pkl` directly into the image:
```dockerfile
COPY ml/model.pk[l] ./ml/
```

This means:
- ✅ No volume mounts needed
- ✅ Works on Render free tier (no persistent disk)
- ✅ Model loads in < 0.5 seconds on startup
- ✅ Memory usage: ~30 MB for 200-estimator XGBoost

### Memory Budget for Render Free Tier (512 MB)
| Component | RAM Usage |
|---|---|
| Python interpreter | ~60 MB |
| FastAPI + SQLAlchemy | ~80 MB |
| XGBoost model loaded | ~30 MB |
| XGBoost inference | ~10 MB peak |
| asyncpg connection pool (5) | ~15 MB |
| **Total** | **~195 MB ✅ well within 512 MB** |

---

## 5. ☁️ Render.com Deployment — Step by Step

### Step 1: Create account
Go to [render.com](https://render.com) → Sign Up with GitHub (no card required)

### Step 2: Push code to GitHub
```bash
git init
git add .
git commit -m "Initial VaxTrace AI commit"
git remote add origin https://github.com/yourusername/vaxtrace-ai.git
git push -u origin main
```

### Step 3: Create Web Service on Render
1. Render dashboard → **New → Web Service**
2. Connect your GitHub repo
3. Settings:
   - **Name**: `vaxtrace-api`
   - **Root Directory**: `backend`
   - **Environment**: Docker
   - **Instance Type**: Free
4. Add Environment Variables (click **Add Environment Variable**):

| Key | Value |
|---|---|
| `DATABASE_URL` | your Supabase connection string |
| `JWT_SECRET_KEY` | your generated secret |
| `JWT_EXPIRE_MINUTES` | `1440` |
| `SQL_ECHO` | `false` |

5. Click **Create Web Service** → Render builds and deploys automatically.

### Step 4: Get your API URL
Your API will be at: `https://vaxtrace-api.onrender.com`

Update in `flutter_app/lib/providers/providers.dart`:
```dart
const String _kBaseUrl = 'https://vaxtrace-api.onrender.com';
```

> **Free tier note**: Render free services sleep after 15 minutes of inactivity.
> First request after sleep takes ~30s. Acceptable for a field pilot.
> Upgrade to Render Starter ($7/month) to avoid cold starts in production.

---

## 6. 📱 Flutter App Setup

```bash
cd flutter_app
flutter pub get
flutter run
```

> Maps (OpenStreetMap) and OCR (ML Kit) work with **zero configuration**.

For release APK:
```bash
flutter build apk --release
```

---

## 7. 🔄 (Optional) Switching to Supabase Auth

If you later want a richer auth UI, swap Firebase for Supabase:

### In `pubspec.yaml`, replace:
```yaml
# Remove:
firebase_core: ^3.1.0
firebase_auth: ^5.1.0

# Add:
supabase_flutter: ^2.3.0
```

### In `main.dart`, replace Firebase init:
```dart
await Supabase.initialize(
  url: 'https://xxxx.supabase.co',
  anonKey: 'your-anon-key',
);
```

Supabase anon key and URL are found in: **Supabase project → Settings → API**
Both are safe to include in client code (anon key has limited permissions by design).

---

## 8. 📁 `.gitignore`

```gitignore
# Secrets
backend/.env
backend/ml/model.pkl

# Never commit these
flutter_app/android/app/google-services.json
flutter_app/.dart_tool/
flutter_app/build/
__pycache__/
*.pyc
.env
```
