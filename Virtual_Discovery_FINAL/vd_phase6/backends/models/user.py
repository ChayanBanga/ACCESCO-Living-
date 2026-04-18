"""
models/user.py
Extended User model — Phase 6 adds columns needed for personalisation:
  - category_affinity (JSON)  : per-category engagement scores
  - cross_venture_signals (JSON) : signals from other ventures (spec 4.3)
  - last_active_at             : for consistency scoring
  - credits_last_reset_at      : monthly credit cap tracking
"""
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, JSON, Text
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid
from models.database import Base


class User(Base):
    __tablename__ = "users"

    id                    = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    household_id          = Column(String(100), unique=True, nullable=False)
    display_name          = Column(String(100), nullable=True)
    dietary_flags         = Column(JSON, default=list)
    budget_bracket        = Column(String(20), default="medium")
    preferred_ventures    = Column(JSON, default=list)

    # CQS
    cqs_score             = Column(Float, default=0.0)
    cqs_band              = Column(String(20), default="explorer")

    # Discovery Credits
    discovery_credits     = Column(Integer, default=0)
    credits_awarded_this_month = Column(Integer, default=0)
    credits_last_reset_at = Column(DateTime, nullable=True)

    # Upload stats (used in CQS community_trust component)
    total_videos_uploaded = Column(Integer, default=0)
    total_videos_approved = Column(Integer, default=0)

    # Phase 6 — Personalisation
    category_affinity     = Column(JSON, default=dict)     # {venture: {sku/category: score}}
    cross_venture_signals = Column(JSON, default=dict)     # biryani→spice, etc.
    last_active_at        = Column(DateTime, nullable=True)

    created_at            = Column(DateTime, default=datetime.utcnow)
    updated_at            = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
