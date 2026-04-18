from fastapi import APIRouter, Header
from services.cart import get_cart, add_to_cart, remove_from_cart
from services.inventory import get_live_inventory, is_in_stock
from pydantic import BaseModel

router = APIRouter(prefix="/api/v1/cart", tags=["LifeCart"])

class AddToCartRequest(BaseModel):
    sku_id: str
    product_name: str
    price: float
    quantity: int = 1

@router.get("/")
def view_cart(household_id: str = Header(...)):
    cart = get_cart(household_id)
    return cart

@router.post("/add")
def add_item(
    request: AddToCartRequest,
    household_id: str = Header(...)
):
    # Check stock before adding
    if not is_in_stock(request.sku_id):
        return {"error": "Product is out of stock or below minimum threshold"}

    cart = add_to_cart(
        household_id=household_id,
        sku_id=request.sku_id,
        product_name=request.product_name,
        price=request.price,
        quantity=request.quantity
    )
    return {"message": "Added to LifeCart", "cart": cart}

@router.delete("/remove/{sku_id}")
def remove_item(sku_id: str, household_id: str = Header(...)):
    cart = remove_from_cart(household_id, sku_id)
    return {"message": "Removed from LifeCart", "cart": cart}

@router.get("/inventory/{sku_id}")
def check_inventory(sku_id: str, dark_store_id: str = "store_001"):
    inventory = get_live_inventory(sku_id, dark_store_id)
    return inventory