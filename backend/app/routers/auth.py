"""
VaxTrace AI — JWT Auth Service
Zero-cost, no external service required.
Used when Firebase is not available or when running purely on Render.com.

Endpoints:
  POST /auth/register  — create user account (stored in PostgreSQL)
  POST /auth/login     — returns JWT access token
  GET  /auth/me        — returns current user (protected)
"""

import os
import logging
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.sql import func
from pydantic import BaseModel, EmailStr

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.database import Base, get_db

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "change-me-in-production-minimum-32-chars-long!!")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

router = APIRouter(prefix="/auth", tags=["auth"])


# ─────────────────────────────────────────────
# ORM Model
# ─────────────────────────────────────────────

class UserORM(Base):
    __tablename__ = "users"

    id = Column(String(128), primary_key=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    display_name = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


# ─────────────────────────────────────────────
# Pydantic schemas
# ─────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: str
    password: str
    display_name: Optional[str] = None


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    email: str
    display_name: Optional[str]


class UserOut(BaseModel):
    user_id: str
    email: str
    display_name: Optional[str]


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def _hash_password(password: str) -> str:
    return pwd_context.hash(password)


def _verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def _create_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode["exp"] = expire
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def _generate_user_id() -> str:
    import uuid
    return str(uuid.uuid4())


# ─────────────────────────────────────────────
# FastAPI dependency — mirrors firebase_auth.get_current_user signature
# Drop-in replacement: swap one line in routers to switch auth backends
# ─────────────────────────────────────────────

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """
    Decode JWT and return user dict with 'uid' and 'email'.
    Compatible with the same interface as firebase_auth.get_current_user.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(UserORM).where(UserORM.id == user_id))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise credentials_exception

    # Return dict compatible with firebase decoded token shape
    return {"uid": user.id, "email": user.email, "name": user.display_name}


# ─────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────

@router.post("/register", response_model=LoginResponse, status_code=status.HTTP_201_CREATED)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check email not already taken
    result = await db.execute(select(UserORM).where(UserORM.email == req.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    user_id = _generate_user_id()
    user = UserORM(
        id=user_id,
        email=req.email,
        hashed_password=_hash_password(req.password),
        display_name=req.display_name,
    )
    db.add(user)
    await db.commit()

    token = _create_token({"sub": user_id, "email": req.email})
    return LoginResponse(
        access_token=token,
        user_id=user_id,
        email=req.email,
        display_name=req.display_name,
    )


@router.post("/login", response_model=LoginResponse)
async def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(UserORM).where(UserORM.email == form.username))
    user = result.scalar_one_or_none()

    if not user or not _verify_password(form.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = _create_token({"sub": user.id, "email": user.email})
    return LoginResponse(
        access_token=token,
        user_id=user.id,
        email=user.email,
        display_name=user.display_name,
    )


@router.get("/me", response_model=UserOut)
async def get_me(current_user: dict = Depends(get_current_user)):
    return UserOut(
        user_id=current_user["uid"],
        email=current_user["email"],
        display_name=current_user.get("name"),
    )
