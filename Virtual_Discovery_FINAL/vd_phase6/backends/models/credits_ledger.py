"""
models/credits_ledger.py
Discovery Credits ledger — Phase 6.

Every credit award and redemption is recorded here for:
  - Audit trail
  - Monthly cap enforcement (Rs 2,000/month per spec)
  - 90-day expiry enforcement
  - RBI prepaid instrument compliance (spec Section 09)

Credit types match spec Section 2.2:
  video_selected       → Rs 50 (quality score > 72%)
  views_500_48hrs      → Rs 25 bonus (500+ views in 48hrs)
  cart_adds_10         → Rs 100 bonus (10+ cart adds)
  brand_slot_featured  → Rs 250 (brand selects UGC)
  monthly_top_creator  → Rs 500 (leaderboard rank 1)
"""
from sqlalchemy import Column, String, Integer, Float, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid
from models.database import Base


class CreditsLedger(Base):
    __tablename__ = "credits_ledger"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id     = Column(String(100), nullable=False, index=True)
    video_id    = Column(String(100), nullable=True)               # Which video triggered this
    credit_type = Column(String(50), nullable=False)               # e.g. "video_selected"
    amount      = Column(Integer, nullable=False)                  # Rs amount (positive=award, negative=redeem)
    multiplier  = Column(Float, default=1.0)                       # CQS band multiplier applied
    base_amount = Column(Integer, nullable=False)                  # Pre-multiplier amount
    expires_at  = Column(DateTime, nullable=True)                  # 90 days from award
    redeemed_at = Column(DateTime, nullable=True)
    note        = Column(Text, nullable=True)
    created_at  = Column(DateTime, default=datetime.utcnow)
