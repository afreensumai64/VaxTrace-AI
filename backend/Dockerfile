# ─────────────────────────────────────────────────────────────────────────────
# VaxTrace AI — FastAPI Backend Dockerfile
# Optimised for Render.com Free Web Service (512 MB RAM, shared CPU)
#
# KEY DIFFERENCES from Cloud Run version:
#   - Uses $PORT env var set by Render (not hardcoded 8080)
#   - Single uvicorn worker to stay inside 512 MB RAM budget
#   - model.pkl is baked into the image (no volume mount needed)
#   - gunicorn removed — uvicorn handles signals cleanly on Render
# ─────────────────────────────────────────────────────────────────────────────

FROM python:3.11-slim AS builder

WORKDIR /build

# Build deps for asyncpg + cryptography (for JWT)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev libffi-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ─────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

# Runtime deps for asyncpg
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 && \
    rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY app/ ./app/
# Bake the trained model.pkl directly into the image (≈ 2-5 MB)
# If model.pkl doesn't exist yet, the COPY is skipped gracefully via wildcard
COPY ml/model.pk[l] ./ml/

# Render.com sets PORT dynamically — do NOT hardcode a port number here
ENV PORT=10000
EXPOSE 10000

# Health check (Render pings / to confirm service is up)
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT}/')" || exit 1

# Start: read $PORT at runtime so Render can assign any port
CMD sh -c "uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers 1"
