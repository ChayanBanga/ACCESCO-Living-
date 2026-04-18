"""
personalisation/embedding.py
Household interest embedding model — Phase 6.

Spec Section 4.3 — embedding types implemented:
  Household Interest Vector  (real-time, per-interaction update)
  Temporal Preference Vector (hourly — what venture at what time of day)
  Budget Context Vector      (per session — price sensitivity)
  FarmChain Affinity Score   (scalar — weekly)
  Video Format Preference    (daily — talking-head vs overhead etc.)

Cross-venture signals (spec 4.3):
  biryani order on Swadisht  → boost rice + spice content in Grokly
  thali on Swadisht          → boost vegetables + lentils in Grokly
  produce engagement Grokly  → boost fresh/salad content in Swadisht
  outfit engagement InstaStyle → boost accessories in InstaStyle

All embeddings stored in Redis as JSON. No GPU needed.
Incremental EMA (exponential moving average) update — O(1) per event.

Called by:
  api/events.py             → update on every interaction
  ranking/ranker.py         → read for personalised scoring
  api/personalisation.py   → read endpoint for Flutter debug / creator dashboard
"""

import json
import logging
import os
from datetime import datetime
from typing import Optional

import redis

logger = logging.getLogger(__name__)
_redis: redis.Redis = redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))

ALPHA = 0.15   # EMA learning rate — new signal weight

CROSS_VENTURE_SIGNALS = {
    ("swadisht",   "biryani"):   [("grokly", "rice"),       ("grokly", "spices")],
    ("swadisht",   "thali"):     [("grokly", "vegetables"), ("grokly", "lentils")],
    ("swadisht",   "dosa"):      [("grokly", "rice"),       ("grokly", "lentils")],
    ("swadisht",   "chinese"):   [("grokly", "noodles"),    ("grokly", "sauces")],
    ("grokly",     "produce"):   [("swadisht", "fresh"),    ("swadisht", "salads")],
    ("grokly",     "rice"):      [("swadisht", "biryani"),  ("swadisht", "thali")],
    ("instastyle", "outfit"):    [("instastyle", "accessories")],
    ("instastyle", "ethnic"):    [("grokly", "spices")],
}

FORMAT_TYPES = ["talking_head", "hands_only", "overhead", "lifestyle"]

INTEREST_TTL = 0            # Persistent
TEMPORAL_TTL = 3600         # 1hr
BUDGET_TTL   = 86400        # 1 day
AFFINITY_TTL = 86400 * 7    # 1 week
FORMAT_TTL   = 86400        # 1 day


def _ik(hid: str) -> str: return f"embed:interest:{hid}"
def _tk(hid: str) -> str: return f"embed:temporal:{hid}"
def _bk(hid: str) -> str: return f"embed:budget:{hid}"
def _ak(hid: str) -> str: return f"embed:farmchain:{hid}"
def _fk(hid: str) -> str: return f"embed:format:{hid}"


# ── Interest Vector ───────────────────────────────────────────────────────

def get_interest_vector(household_id: str) -> dict:
    raw = _redis.get(_ik(household_id))
    if raw:
        return json.loads(raw)
    return {"grokly": {}, "swadisht": {}, "instastyle": {}, "global": {}}


def update_interest_vector(
    household_id: str,
    venture: str,
    category: str,
    signal_strength: float,
    negative: bool = False,
) -> None:
    """EMA update on every interaction. signal_strength: 1.0=cart, 0.5=complete, 0.2=start."""
    v = get_interest_vector(household_id)
    if venture not in v:
        v[venture] = {}
    cur = v[venture].get(category, 0.5)
    target = 0.0 if negative else 1.0
    v[venture][category] = round(
        min(max(cur * (1 - ALPHA) + target * ALPHA * signal_strength, 0.0), 1.0), 4
    )
    # Cross-venture signals
    for (tv, tc) in CROSS_VENTURE_SIGNALS.get((venture, category), []):
        if tv not in v:
            v[tv] = {}
        cc = v[tv].get(tc, 0.5)
        v[tv][tc] = round(
            min(max(cc * (1 - ALPHA * 0.5) + 1.0 * ALPHA * 0.5 * signal_strength, 0.0), 1.0), 4
        )
    _redis.set(_ik(household_id), json.dumps(v))


# ── Temporal Preference ───────────────────────────────────────────────────

def update_temporal_preference(household_id: str, venture: str, hour: int) -> None:
    raw = _redis.get(_tk(household_id))
    t = json.loads(raw) if raw else {}
    hk = str(hour)
    if hk not in t:
        t[hk] = {}
    cur = t[hk].get(venture, 0.5)
    t[hk][venture] = round(min(cur * (1 - ALPHA) + ALPHA, 1.0), 4)
    _redis.setex(_tk(household_id), TEMPORAL_TTL, json.dumps(t))


def get_temporal_preference(household_id: str, hour: int) -> dict:
    raw = _redis.get(_tk(household_id))
    return json.loads(raw).get(str(hour), {}) if raw else {}


# ── Budget Context ────────────────────────────────────────────────────────

def update_budget_context(household_id: str, price: float, is_cart_add: bool) -> None:
    raw = _redis.get(_bk(household_id))
    b = json.loads(raw) if raw else {
        "avg_price_viewed": 0.0, "avg_price_carted": 0.0, "session_cart_value": 0.0
    }
    if price > 0:
        b["avg_price_viewed"] = round(b.get("avg_price_viewed", 0.0) * (1 - ALPHA) + price * ALPHA, 2)
    if is_cart_add and price > 0:
        b["avg_price_carted"] = round(b.get("avg_price_carted", 0.0) * (1 - ALPHA) + price * ALPHA, 2)
        b["session_cart_value"] = round(b.get("session_cart_value", 0.0) + price, 2)
    _redis.setex(_bk(household_id), BUDGET_TTL, json.dumps(b))


def get_budget_context(household_id: str) -> dict:
    raw = _redis.get(_bk(household_id))
    return json.loads(raw) if raw else {"avg_price_viewed": 0.0, "avg_price_carted": 0.0, "session_cart_value": 0.0}


# ── FarmChain Affinity ────────────────────────────────────────────────────

def update_farmchain_affinity(household_id: str, engaged: bool) -> None:
    raw = _redis.get(_ak(household_id))
    score = float(raw) if raw else 0.5
    target = 1.0 if engaged else 0.0
    score = round(min(max(score * (1 - ALPHA) + target * ALPHA, 0.0), 1.0), 4)
    _redis.setex(_ak(household_id), AFFINITY_TTL, str(score))


def get_farmchain_affinity(household_id: str) -> float:
    raw = _redis.get(_ak(household_id))
    return float(raw) if raw else 0.5


# ── Format Preference ─────────────────────────────────────────────────────

def update_format_preference(household_id: str, format_type: str) -> None:
    if format_type not in FORMAT_TYPES:
        return
    raw = _redis.get(_fk(household_id))
    p = json.loads(raw) if raw else {f: 0.25 for f in FORMAT_TYPES}
    cur = p.get(format_type, 0.25)
    p[format_type] = round(min(cur * (1 - ALPHA) + ALPHA, 1.0), 4)
    _redis.setex(_fk(household_id), FORMAT_TTL, json.dumps(p))


def get_format_preferences(household_id: str) -> dict:
    raw = _redis.get(_fk(household_id))
    return json.loads(raw) if raw else {f: 0.25 for f in FORMAT_TYPES}


# ── Full Snapshot ─────────────────────────────────────────────────────────

def get_full_embedding(household_id: str) -> dict:
    hour = datetime.utcnow().hour
    return {
        "household_id":       household_id,
        "interest_vector":    get_interest_vector(household_id),
        "temporal_preference": get_temporal_preference(household_id, hour),
        "budget_context":     get_budget_context(household_id),
        "farmchain_affinity": get_farmchain_affinity(household_id),
        "format_preferences": get_format_preferences(household_id),
        "current_hour":       hour,
    }


def reset_embedding(household_id: str) -> None:
    """GDPR/data-deletion: wipe all embedding data. Spec: within 72hrs."""
    for key_fn in [_ik, _tk, _bk, _ak, _fk]:
        _redis.delete(key_fn(household_id))
    _redis.delete(
        f"session:interactions:{household_id}",
        f"feature:user:{household_id}",
    )
    logger.info("Full embedding reset for household %s", household_id)
