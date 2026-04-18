"""
ranking/feature_store.py
Real-time feature store for the Virtual Discovery ranking model.

Mirrors the spec Section 4.1 feature groups:
  - User Context       (household profile, orders, dietary flags, budget)
  - Video Metadata     (category, SKU, brand, duration, recency)
  - Engagement Signals (views, completion, swipe-left, saves)
  - Inventory State    (live stock, price, ETA from nearest dark store)
  - Session Context    (last 5 watched, last 3 cart adds, current cart)
  - Sponsored Bid      (CPM/CPC/CPA bid, targeting match, budget remaining)

Redis is used for sub-millisecond feature reads.
All feature vectors are dicts — serialisable for Flutter/Next.js debug endpoints.

Flutter/Next.js integration:
  - Features are internal to the ranking engine, never sent to the client.
  - The client only sees the ranked video list from GET /api/v1/discovery/feed.
"""

import json
import logging
import os
from datetime import datetime, timedelta
from typing import Optional

import redis
from sqlalchemy.orm import Session

from models.video import Video
from models.user import User
from models.inventory import Inventory

logger = logging.getLogger(__name__)

_redis: redis.Redis = redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))

# TTLs
USER_FEATURES_TTL    = 900   # 15 min — spec: pre-compute every 15 min
SESSION_FEATURES_TTL = 3600  # 1 hr
VIDEO_FEATURES_TTL   = 300   # 5 min — refreshed with inventory


# ---------------------------------------------------------------------------
# User feature builder
# ---------------------------------------------------------------------------

def get_user_features(household_id: str, db: Session) -> dict:
    """
    Build or fetch cached user feature vector.
    Cache key: feature:user:{household_id}
    """
    cache_key = f"feature:user:{household_id}"
    cached = _redis.get(cache_key)
    if cached:
        return json.loads(cached)

    user = db.query(User).filter(User.household_id == household_id).first()
    if not user:
        # Cold start — return neutral features
        return _cold_start_user_features(household_id)

    features = {
        "household_id": household_id,
        "user_id": str(user.id),
        "budget_bracket": user.budget_bracket or "medium",
        "dietary_flags": user.dietary_flags or [],
        "preferred_ventures": user.preferred_ventures or [],
        "cqs_score": float(user.cqs_score or 0.0),
        "cqs_band": user.cqs_band or "explorer",
        "discovery_credits": int(user.discovery_credits or 0),
        "total_approved_videos": int(user.total_videos_approved or 0),
        # Time context — affects temporal preference vector
        "hour_of_day": datetime.utcnow().hour,
        "day_of_week": datetime.utcnow().weekday(),
        # Interaction counters (from Redis session)
        "interaction_count": _get_interaction_count(household_id),
    }

    _redis.setex(cache_key, USER_FEATURES_TTL, json.dumps(features))
    return features


def _cold_start_user_features(household_id: str) -> dict:
    """Neutral features for new households — spec Section 4.3."""
    return {
        "household_id": household_id,
        "user_id": None,
        "budget_bracket": "medium",
        "dietary_flags": [],
        "preferred_ventures": ["grokly", "swadisht", "instastyle"],
        "cqs_score": 0.0,
        "cqs_band": "explorer",
        "discovery_credits": 0,
        "total_approved_videos": 0,
        "hour_of_day": datetime.utcnow().hour,
        "day_of_week": datetime.utcnow().weekday(),
        "interaction_count": _get_interaction_count(household_id),
    }


def _get_interaction_count(household_id: str) -> int:
    """Count total interactions to determine personalisation activation level."""
    key = f"session:interactions:{household_id}"
    val = _redis.get(key)
    return int(val) if val else 0


def increment_interaction(household_id: str) -> int:
    """Called by event endpoint on each interaction. Returns new count."""
    key = f"session:interactions:{household_id}"
    count = _redis.incr(key)
    _redis.expire(key, 86400 * 30)  # 30 days
    # Invalidate user feature cache so next fetch recomputes with new count
    _redis.delete(f"feature:user:{household_id}")
    return int(count)


# ---------------------------------------------------------------------------
# Video feature builder
# ---------------------------------------------------------------------------

def get_video_features(video: Video) -> dict:
    """
    Build feature dict for a single video.
    Cache key: feature:video:{video_id}
    """
    cache_key = f"feature:video:{str(video.id)}"
    cached = _redis.get(cache_key)
    if cached:
        return json.loads(cached)

    now = datetime.utcnow()
    age_hours = 0.0
    if video.created_at:
        delta = now - video.created_at
        age_hours = delta.total_seconds() / 3600

    features = {
        "video_id": str(video.id),
        "venture": video.venture or "grokly",
        "sku_id": video.sku_id or "",
        "is_ugc": bool(video.is_ugc),
        "is_sponsored": bool(video.is_sponsored),
        "duration_seconds": int(video.duration_seconds or 0),
        "age_hours": round(age_hours, 2),
        # Spec: freshness boost — videos < 4hrs old get +0.15 multiplier
        "is_fresh": age_hours < 4.0,
        "freshness_boost": 0.15 if age_hours < 4.0 else 0.0,
        # Engagement signals
        "view_count": int(video.view_count or 0),
        "cart_add_count": int(video.cart_add_count or 0),
        # Conversion rate proxy (avoid div/0)
        "conversion_rate": (
            (video.cart_add_count or 0) / max(video.view_count or 1, 1)
        ),
        # Inventory state
        "units_available": int(video.units_available or 0),
        "price_current": float(video.price_current or 0.0),
        "delivery_eta_mins": int(video.delivery_eta_mins or 30),
        "freshness_score": float(video.freshness_score or 0.5),
        # Current ranking score (used as base before re-ranking)
        "base_ranking_score": float(video.ranking_score or 0.0),
    }

    _redis.setex(cache_key, VIDEO_FEATURES_TTL, json.dumps(features))
    return features


def invalidate_video_features(video_id: str) -> None:
    """Call when video metadata or inventory changes."""
    _redis.delete(f"feature:video:{video_id}")


# ---------------------------------------------------------------------------
# Session context
# ---------------------------------------------------------------------------

def get_session_context(session_id: str) -> dict:
    """
    Retrieve session context for re-ranking.
    Tracks last 5 watched ventures + last 3 cart-added SKUs.
    Cache key: session:ctx:{session_id}
    """
    key = f"session:ctx:{session_id}"
    cached = _redis.get(key)
    if cached:
        return json.loads(cached)
    return {
        "session_id": session_id,
        "last_5_ventures": [],
        "last_3_cart_skus": [],
        "videos_seen": [],
        "skip_streak": {},   # venture → consecutive skip count
    }


def update_session_context(
    session_id: str,
    event_type: str,
    video_id: str,
    venture: str,
    sku_id: Optional[str] = None,
) -> None:
    """
    Update session context after each user interaction.
    Called by the events endpoint.
    """
    ctx = get_session_context(session_id)

    if event_type in ("view_complete", "view_start"):
        ctx["videos_seen"] = (ctx.get("videos_seen", []) + [video_id])[-20:]
        ventures = ctx.get("last_5_ventures", [])
        ventures.append(venture)
        ctx["last_5_ventures"] = ventures[-5:]

    elif event_type == "swipe_left" and sku_id:
        cart_skus = ctx.get("last_3_cart_skus", [])
        cart_skus.append(sku_id)
        ctx["last_3_cart_skus"] = cart_skus[-3:]

    elif event_type == "skip":
        # Track consecutive skips per venture for suppression logic
        skip_streak = ctx.get("skip_streak", {})
        skip_streak[venture] = skip_streak.get(venture, 0) + 1
        ctx["skip_streak"] = skip_streak
    else:
        # Any positive interaction resets skip streak for that venture
        skip_streak = ctx.get("skip_streak", {})
        if venture in skip_streak:
            skip_streak[venture] = 0
        ctx["skip_streak"] = skip_streak

    key = f"session:ctx:{session_id}"
    _redis.setex(key, SESSION_FEATURES_TTL, json.dumps(ctx))


def get_suppressed_ventures(session_id: str) -> list[str]:
    """
    Spec Section 4.3: 3 consecutive skips on a category suppresses it for 48hrs.
    Returns list of venture names that should be suppressed.
    """
    ctx = get_session_context(session_id)
    skip_streak = ctx.get("skip_streak", {})
    return [v for v, count in skip_streak.items() if count >= 3]
