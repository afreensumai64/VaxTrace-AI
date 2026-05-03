"""
VaxTrace AI — Async database connection
Local dev: SQLite (zero network, zero setup)
Production: PostgreSQL on Supabase via DATABASE_URL env var
"""

import os
from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./vaxtrace.db")

# Auto-fix postgres:// prefixes for production deployments
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
elif DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)

_is_sqlite = DATABASE_URL.startswith("sqlite")

# SQLite doesn't support connection pooling options
_engine_kwargs = {"echo": os.getenv("SQL_ECHO", "false").lower() == "true"}
if not _is_sqlite:
    _engine_kwargs.update({"pool_pre_ping": True, "pool_size": 10, "max_overflow": 20})


class Base(DeclarativeBase):
    pass


engine = create_async_engine(DATABASE_URL, **_engine_kwargs)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def create_tables():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
