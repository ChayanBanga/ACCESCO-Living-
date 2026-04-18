import redis
import json
import os
from dotenv import load_dotenv

load_dotenv()

r = redis.from_url(os.getenv("REDIS_URL"))

def get_cart(household_id: str):
    cart = r.get(f"cart:{household_id}")
    if cart:
        return json.loads(cart)
    return {"household_id": household_id, "items": [], "total": 0.0}

def add_to_cart(household_id: str, sku_id: str, product_name: str, price: float, quantity: int = 1):
    cart = get_cart(household_id)
    
    # Check if item already in cart
    for item in cart["items"]:
        if item["sku_id"] == sku_id:
            item["quantity"] += quantity
            item["subtotal"] = item["quantity"] * price
            _save_cart(household_id, cart)
            return cart

    # Add new item
    cart["items"].append({
        "sku_id": sku_id,
        "product_name": product_name,
        "price": price,
        "quantity": quantity,
        "subtotal": price * quantity
    })

    cart["total"] = sum(item["subtotal"] for item in cart["items"])
    _save_cart(household_id, cart)
    return cart

def remove_from_cart(household_id: str, sku_id: str):
    cart = get_cart(household_id)
    cart["items"] = [i for i in cart["items"] if i["sku_id"] != sku_id]
    cart["total"] = sum(item["subtotal"] for item in cart["items"])
    _save_cart(household_id, cart)
    return cart

def _save_cart(household_id: str, cart: dict):
    r.setex(f"cart:{household_id}", 86400, json.dumps(cart))  # 24hr expiry