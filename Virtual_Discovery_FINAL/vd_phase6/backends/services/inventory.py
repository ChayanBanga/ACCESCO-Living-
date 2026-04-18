import redis
import json
import os
from dotenv import load_dotenv

load_dotenv()

r = redis.from_url(os.getenv("REDIS_URL"))

def get_inventory(sku_id: str):
    # Check Redis cache first
    cached = r.get(f"inventory:{sku_id}")
    if cached:
        return json.loads(cached)
    return None

def update_inventory(sku_id: str, data: dict):
    # Cache in Redis for 60 seconds (per spec)
    r.setex(f"inventory:{sku_id}", 60, json.dumps(data))

def is_in_stock(sku_id: str) -> bool:
    inventory = get_inventory(sku_id)
    if not inventory:
        return False
    # Per spec: remove from feed if stock < 3
    return inventory.get("units_available", 0) >= 3

def get_live_inventory(sku_id: str, dark_store_id: str):
    # Try Redis first
    cached = get_inventory(sku_id)
    if cached:
        return cached

    # Fallback default (will be replaced by real dark store API later)
    default = {
        "sku_id": sku_id,
        "dark_store_id": dark_store_id,
        "units_available": 50,
        "price_current": 0.0,
        "farmchain_price": 0.0,
        "delivery_eta_mins": 30,
        "freshness_score": 0.9,
        "is_surge_pricing": False
    }
    update_inventory(sku_id, default)
    return default