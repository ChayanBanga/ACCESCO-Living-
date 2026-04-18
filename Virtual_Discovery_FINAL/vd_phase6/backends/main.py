"""
main.py — Accesco Virtual Discovery API
All 6 phases complete.

Endpoints summary (24 total):
  Health:           GET /  GET /health
  Feed:             GET /api/v1/discovery/feed
  UGC:              POST /api/v1/discovery/upload
  Events:           POST /api/v1/discovery/event
  Cart:             GET/POST/DELETE /api/v1/cart/...
  Moderation:       GET/POST /api/v1/moderation/...
  Brand Dashboard:  GET/POST/DELETE /api/v1/brand/...
  Personalisation:  GET/PUT/DELETE /api/v1/personalisation/...
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os

from api.feed          import router as feed_router
from api.ugc           import router as ugc_router
from api.events        import router as events_router
from api.cart          import router as cart_router
from api.moderation    import router as moderation_router
from api.brand         import router as brand_router
from api.personalisation import router as personalisation_router

load_dotenv()

app = FastAPI(
    title="Accesco Virtual Discovery API",
    description=(
        "AI-powered real-time shoppable video discovery feed. "
        "All 6 phases complete. "
        "Flutter + Next.js ready."
    ),
    version="3.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Lock to Flutter app + Next.js domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", tags=["Health"])
def root():
    return {
        "status":          "running",
        "service":         "Accesco Virtual Discovery API",
        "version":         "3.0.0",
        "phases_complete": [
            "1-video-infra",
            "2-commerce-cart",
            "3-ugc-moderation",
            "4-ai-ranking",
            "5-brand-ads-auction",
            "6-personalisation-credits",
        ],
    }


@app.get("/health", tags=["Health"])
def health():
    return {
        "status":      "healthy",
        "database":    os.getenv("DATABASE_URL") is not None,
        "redis":       os.getenv("REDIS_URL") is not None,
        "kafka":       os.getenv("KAFKA_BOOTSTRAP_SERVERS") is not None,
        "environment": os.getenv("ENVIRONMENT", "development"),
    }


app.include_router(feed_router)
app.include_router(ugc_router)
app.include_router(events_router)
app.include_router(cart_router)
app.include_router(moderation_router)
app.include_router(brand_router)
app.include_router(personalisation_router)
