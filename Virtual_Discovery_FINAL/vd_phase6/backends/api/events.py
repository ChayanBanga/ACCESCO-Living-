"""
api/events.py — Phase 6 complete.
Every interaction now drives:
  1. DB counters (view_count, cart_add_count)
  2. Redis session context (for ranking diversity/suppression)
  3. Personalisation embeddings (interest vector, temporal, budget, farmchain, format)
  4. Kafka event stream

POST /api/v1/discovery/event
event_types: view_start | view_complete | skip | swipe_left |
             swipe_right | double_tap | share | unmute

Flutter/Next.js:
  - Fire on EVERY interaction — this is the signal that personalises the feed
  - Include session_id (same UUID used in X-Session-ID header on GET /feed)
  - Include completion_pct for view_complete events (0.0 to 1.0)
"""
import json
import logging
from datetime import datetime
import os

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from models.database import SessionLocal
from models.video import Video
from ranking.feature_store import update_session_context
from personalisation.embedding import (
    update_interest_vector,
    update_temporal_preference,
    update_budget_context,
    update_farmchain_affinity,
)

try:
    from kafka import KafkaProducer
    from kafka.errors import KafkaError
    _KAFKA_AVAILABLE = True
except ImportError:
    _KAFKA_AVAILABLE = False

logger = logging.getLogger(__name__)
router = APIRouter()

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
KAFKA_TOPIC = "discovery-events"
_producer = None


def _get_producer():
    global _producer
    if not _KAFKA_AVAILABLE:
        return None
    if _producer is not None:
        return _producer
    try:
        from kafka import KafkaProducer
        _producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            acks="all", retries=3, request_timeout_ms=5000,
        )
    except Exception as e:
        logger.warning(f"Kafka unavailable: {e}")
        _producer = None
    return _producer


def _push_to_kafka(event: dict):
    producer = _get_producer()
    if not producer:
        return
    try:
        producer.send(KAFKA_TOPIC, value=event)
        producer.flush(timeout=3)
    except Exception as e:
        logger.error(f"Kafka publish failed: {e}")


VALID_EVENT_TYPES = {
    "view_start", "view_complete", "skip", "swipe_left",
    "swipe_right", "double_tap", "share", "unmute",
}

# Signal strengths for embedding updates
SIGNAL_STRENGTHS = {
    "swipe_left":    1.0,   # Cart add — strongest signal
    "double_tap":    0.8,   # Explicit like
    "view_complete": 0.5,   # Watched fully
    "swipe_right":   0.4,   # Saved to wishlist
    "share":         0.6,   # Shared — strong engagement
    "view_start":    0.2,   # Mild signal
    "skip":          0.0,   # Used only as negative signal
    "unmute":        0.3,   # Sound-on = interested
}


class InteractionEvent(BaseModel):
    session_id:        str
    video_id:          str
    event_type:        str
    watch_duration_ms: int   = 0
    completion_pct:    float = 0.0
    timestamp_utc:     str   = ""
    # Optional — client should pass these for richer embedding updates
    household_id:      str   = ""
    venture_category:  str   = ""   # e.g. "biryani", "produce", "outfit"


@router.post("/event", status_code=204)
def track_event(event: InteractionEvent):
    if event.event_type not in VALID_EVENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid event_type. Must be one of: {sorted(VALID_EVENT_TYPES)}"
        )

    db: Session = SessionLocal()
    try:
        video = db.query(Video).filter(Video.id == event.video_id).first()

        # ── 1. DB counters ────────────────────────────────────────────
        if video:
            if event.event_type == "view_complete":
                video.view_count = (video.view_count or 0) + 1
            elif event.event_type == "swipe_left":
                video.cart_add_count = (video.cart_add_count or 0) + 1
            db.commit()

        # ── 2. Session context for ranking ────────────────────────────
        update_session_context(
            session_id=event.session_id,
            event_type=event.event_type,
            video_id=event.video_id,
            venture=str(video.venture) if video else "grokly",
            sku_id=str(video.sku_id) if video and event.event_type == "swipe_left" else None,
        )

        # ── 3. Personalisation embeddings (Phase 6) ───────────────────
        if event.household_id and video:
            household_id = event.household_id
            venture      = str(video.venture)
            category     = event.venture_category or str(video.venture_category or venture)
            signal       = SIGNAL_STRENGTHS.get(event.event_type, 0.2)
            is_negative  = event.event_type == "skip"
            is_cart_add  = event.event_type == "swipe_left"
            hour         = datetime.utcnow().hour

            # Interest vector
            update_interest_vector(household_id, venture, category, signal, is_negative)

            # Temporal preference (only on meaningful watch events)
            if event.event_type in ("view_complete", "swipe_left", "double_tap"):
                update_temporal_preference(household_id, venture, hour)

            # Budget context
            price = float(video.price_current or 0.0)
            if price > 0 and event.event_type in ("view_complete", "swipe_left"):
                update_budget_context(household_id, price, is_cart_add)

            # FarmChain affinity (grokly produce signals)
            if venture == "grokly":
                update_farmchain_affinity(household_id, not is_negative)


        if event.household_id:
            from ranking.feature_store import increment_interaction
            increment_interaction(event.household_id)

        # ── 4. Kafka ──────────────────────────────────────────────────
        _push_to_kafka({
            "session_id":        event.session_id,
            "video_id":          event.video_id,
            "event_type":        event.event_type,
            "watch_duration_ms": event.watch_duration_ms,
            "completion_pct":    event.completion_pct,
            "timestamp_utc":     event.timestamp_utc or datetime.utcnow().isoformat(),
            "sku_id":            str(video.sku_id) if video else None,
            "venture":           str(video.venture) if video else None,
            "household_id":      event.household_id or None,
        })

    finally:
        db.close()
