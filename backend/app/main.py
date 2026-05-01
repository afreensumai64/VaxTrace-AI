"""
VaxTrace AI — FastAPI Application Entry Point
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import create_tables
from app.routers import children, vaccines, predictions, sync, auth

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: create DB tables. Shutdown: cleanup."""
    logger.info("🚀 VaxTrace AI backend starting...")
    await create_tables()
    logger.info("✅ Database tables ready")
    yield
    logger.info("🛑 VaxTrace AI backend shutting down")


app = FastAPI(
    title="VaxTrace AI API",
    description="Predictive vaccine tracking and equity system for low-resource environments",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — restrict in production via env var
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth.router)        # JWT auth (zero-cost)
app.include_router(children.router)
app.include_router(vaccines.router)
app.include_router(predictions.router)
app.include_router(sync.router)


@app.get("/", tags=["health"])
async def root():
    return {"status": "healthy", "service": "VaxTrace AI", "version": "1.0.0"}


@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok"}
