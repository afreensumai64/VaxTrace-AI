"""
VaxTrace AI — Backend Data Models
SQLAlchemy ORM models + Pydantic schemas (schema contract with Flutter frontend)
"""

import uuid
from datetime import datetime, date
from typing import Optional, List
from enum import Enum as PyEnum

from sqlalchemy import (
    Column, String, Float, Boolean, DateTime, Date,
    ForeignKey, Text, Enum as SAEnum, Integer
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from pydantic import BaseModel, Field, validator

from app.database import Base


# ─────────────────────────────────────────────
# Enums
# ─────────────────────────────────────────────

class RiskLevel(str, PyEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class SyncStatus(str, PyEnum):
    PENDING = "pending"
    SYNCED = "synced"
    FAILED = "failed"


# ─────────────────────────────────────────────
# SQLAlchemy ORM Models
# ─────────────────────────────────────────────

class ChildORM(Base):
    """
    Core child record — mirrors Flutter models/child.dart exactly.
    Field names use snake_case (Python) matching camelCase (Dart via toJson).
    """
    __tablename__ = "children"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Identity
    name = Column(String(255), nullable=False, index=True)
    date_of_birth = Column(Date, nullable=False)
    guardian_name = Column(String(255), nullable=False)
    guardian_phone = Column(String(20), nullable=False)

    # Location
    village_id = Column(String(100), nullable=False, index=True)
    village_name = Column(String(255), nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    distance_from_clinic_km = Column(Float, nullable=False, default=0.0)

    # Vaccination state
    last_dose_date = Column(Date, nullable=True)
    last_vaccine_name = Column(String(100), nullable=True)
    next_due_date = Column(Date, nullable=True)

    # Risk engine output
    risk_score = Column(Float, nullable=False, default=0.0)
    risk_level = Column(SAEnum(RiskLevel), nullable=False, default=RiskLevel.LOW)
    is_high_risk = Column(Boolean, nullable=False, default=False)

    # Sync state
    is_synced = Column(Boolean, nullable=False, default=False)
    sync_status = Column(SAEnum(SyncStatus), nullable=False, default=SyncStatus.PENDING)
    client_id = Column(String(100), nullable=True)  # Flutter device UUID

    # Metadata
    created_by_uid = Column(String(128), nullable=True)  # Firebase UID
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    vaccination_records = relationship(
        "VaccinationRecordORM",
        back_populates="child",
        cascade="all, delete-orphan"
    )
    risk_scores = relationship(
        "RiskScoreORM",
        back_populates="child",
        cascade="all, delete-orphan"
    )


class VaccinationRecordORM(Base):
    """
    Vaccination event record — mirrors Flutter models/vaccination_record.dart.
    """
    __tablename__ = "vaccination_records"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    child_id = Column(UUID(as_uuid=True), ForeignKey("children.id", ondelete="CASCADE"), nullable=False, index=True)

    vaccine_name = Column(String(100), nullable=False)
    dose_number = Column(Integer, nullable=False, default=1)
    date_administered = Column(Date, nullable=False)
    administered_by = Column(String(255), nullable=False)
    batch_number = Column(String(100), nullable=True)
    clinic_name = Column(String(255), nullable=True)
    notes = Column(Text, nullable=True)

    # Sync state
    is_synced = Column(Boolean, nullable=False, default=False)
    client_id = Column(String(100), nullable=True)
    created_by_uid = Column(String(128), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    child = relationship("ChildORM", back_populates="vaccination_records")


class RiskScoreORM(Base):
    """
    Historical risk score snapshots for trend analysis.
    """
    __tablename__ = "risk_scores"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    child_id = Column(UUID(as_uuid=True), ForeignKey("children.id", ondelete="CASCADE"), nullable=False, index=True)

    score = Column(Float, nullable=False)
    risk_level = Column(SAEnum(RiskLevel), nullable=False)
    distance_from_clinic_km = Column(Float, nullable=False)
    days_since_last_dose = Column(Integer, nullable=False)
    model_version = Column(String(50), nullable=False, default="formula_v1")
    computed_at = Column(DateTime(timezone=True), server_default=func.now())

    child = relationship("ChildORM", back_populates="risk_scores")


# ─────────────────────────────────────────────
# Pydantic Schemas (API Request / Response)
# ─────────────────────────────────────────────

class VaccinationRecordBase(BaseModel):
    vaccine_name: str
    dose_number: int = 1
    date_administered: date
    administered_by: str
    batch_number: Optional[str] = None
    clinic_name: Optional[str] = None
    notes: Optional[str] = None
    client_id: Optional[str] = None


class VaccinationRecordCreate(VaccinationRecordBase):
    child_id: str


class VaccinationRecordOut(VaccinationRecordBase):
    id: str
    child_id: str
    is_synced: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

    @validator("id", "child_id", pre=True)
    def uuid_to_str(cls, v):
        return str(v) if v else v


class ChildBase(BaseModel):
    """Shared fields — mirrors Flutter Child model exactly."""
    name: str = Field(..., min_length=1, max_length=255)
    date_of_birth: date
    guardian_name: str = Field(..., min_length=1, max_length=255)
    guardian_phone: str = Field(..., max_length=20)
    village_id: str
    village_name: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_from_clinic_km: float = Field(default=0.0, ge=0)
    last_dose_date: Optional[date] = None
    last_vaccine_name: Optional[str] = None
    next_due_date: Optional[date] = None
    client_id: Optional[str] = None


class ChildCreate(ChildBase):
    pass


class ChildUpdate(BaseModel):
    name: Optional[str] = None
    guardian_name: Optional[str] = None
    guardian_phone: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_from_clinic_km: Optional[float] = None
    last_dose_date: Optional[date] = None
    last_vaccine_name: Optional[str] = None
    next_due_date: Optional[date] = None


class ChildOut(ChildBase):
    id: str
    risk_score: float
    risk_level: RiskLevel
    is_high_risk: bool
    is_synced: bool
    sync_status: SyncStatus
    created_at: datetime
    updated_at: datetime
    vaccination_records: List[VaccinationRecordOut] = []

    class Config:
        from_attributes = True

    @validator("id", pre=True)
    def uuid_to_str(cls, v):
        return str(v) if v else v


class RiskScoreOut(BaseModel):
    child_id: str
    score: float
    risk_level: RiskLevel
    distance_from_clinic_km: float
    days_since_last_dose: int
    model_version: str
    computed_at: datetime

    class Config:
        from_attributes = True

    @validator("child_id", pre=True)
    def uuid_to_str(cls, v):
        return str(v) if v else v


# ─────────────────────────────────────────────
# Sync Payload Schema (Offline-First Bulk Sync)
# ─────────────────────────────────────────────

class SyncPayload(BaseModel):
    """Bulk sync payload sent from Flutter when connectivity is restored."""
    device_id: str
    synced_at: datetime
    children: List[ChildCreate] = []
    vaccination_records: List[VaccinationRecordCreate] = []


class SyncResult(BaseModel):
    synced_children: int
    synced_records: int
    errors: List[str] = []
    server_time: datetime


# ─────────────────────────────────────────────
# Prediction Request Schema
# ─────────────────────────────────────────────

class RiskPredictionRequest(BaseModel):
    child_id: str
    distance_from_clinic_km: float = Field(..., ge=0)
    days_since_last_dose: int = Field(..., ge=0)

class HighRiskListResponse(BaseModel):
    total: int
    children: List[ChildOut]
