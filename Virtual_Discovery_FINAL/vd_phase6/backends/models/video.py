"""
models/video.py
Extended Video model — Phase 6 adds:
  - caption (for moderation + personalisation)
  - quality_score (dedicated column, not piggybacked on ranking_score)
  - farmchain_price (for FarmChain transparency display in feed)
  - venture_category (grokly:produce, swadisht:biryani, etc.)
"""
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid
from models.database import Base


class Video(Base):
    __tablename__ = "videos"

    id                = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title             = Column(String(200), nullable=False)
    hls_url           = Column(String(500), nullable=True)
    thumbnail_url     = Column(String(500), nullable=True)
    duration_seconds  = Column(Integer, nullable=False, default=0)
    venture           = Column(String(20), nullable=False)           # grokly|swadisht|instastyle
    venture_category  = Column(String(100), nullable=True)          # produce|biryani|outfit etc.
    sku_id            = Column(String(100), nullable=True)
    product_name      = Column(String(200), nullable=True)
    price_current     = Column(Float, nullable=True)
    farmchain_price   = Column(Float, nullable=True)                # Farm-gate price
    units_available   = Column(Integer, default=0)
    delivery_eta_mins = Column(Integer, nullable=True)
    freshness_score   = Column(Float, nullable=True)
    caption           = Column(Text, nullable=True)                 # Creator's caption text
    creator_id        = Column(String(100), nullable=True)
    is_sponsored      = Column(Boolean, default=False)
    is_ugc            = Column(Boolean, default=False)
    moderation_status = Column(String(20), default="pending")       # pending|approved|rejected|review
    quality_score     = Column(Float, nullable=True)                # 0-100 from quality_check
    ranking_score     = Column(Float, default=0.0)
    view_count        = Column(Integer, default=0)
    cart_add_count    = Column(Integer, default=0)
    created_at        = Column(DateTime, default=datetime.utcnow)
    updated_at        = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
