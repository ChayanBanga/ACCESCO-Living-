from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid
from models.database import Base

class Inventory(Base):
    __tablename__ = "inventory"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sku_id = Column(String(100), nullable=False, unique=True)
    dark_store_id = Column(String(100), nullable=False)
    units_available = Column(Integer, default=0)
    price_current = Column(Float, nullable=False)
    farmchain_price = Column(Float, nullable=True)
    delivery_eta_mins = Column(Integer, default=30)
    freshness_score = Column(Float, default=1.0)
    last_synced_at = Column(DateTime, default=datetime.utcnow)
    is_surge_pricing = Column(Boolean, default=False)