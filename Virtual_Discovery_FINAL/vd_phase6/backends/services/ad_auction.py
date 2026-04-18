"""
services/ad_auction.py
Second-price auction engine for sponsored Discovery feed slots.

Spec Section 3.1 — Sponsorship formats and pricing:
  Discovery Slot:   CPM  — Rs 800–2,400 per 1,000 views
  FarmChain Brand:  CPC  — Rs 12–28 per cart click
  Chef Collab:      CPA  — Rs 45–120 per confirmed order
  Style Brand:      Revenue share — 8–15% of attributed GMV
  UGC Brand Boost:  Flat — Rs 5,000–25,000 per video

Auction mechanics:
  - Second-price (Vickrey) auction: winner pays second-highest bid + Re 1
  - Targeting score multiplied into effective CPM for fair comparison
  - Budget pacing: daily spend tracked in Redis, exhausted brands excluded
  - Auction clears in < 10ms per spec

Flutter/Next.js integration:
  - is_sponsored: true on sponsored video objects in feed response
  - sponsored_label: "SPONSORED" string — render persistently throughout playback
  - Brands never identified by name in the API response (only to internal dashboard)

Security:
  - Brand API keys authenticate to brand dashboard separately
  - Auction is internal — not exposed to client apps
"""

import json
import logging
import os
import time
import uuid
from dataclasses import dataclass, field
from typing import Optional

import redis

logger = logging.getLogger(__name__)

_redis: redis.Redis = redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

@dataclass
class SponsoredBid:
    """A single brand's bid for a Discovery feed slot."""
    brand_id: str
    video_id: str                   # The sponsored video to show
    hls_url: str
    thumbnail_url: str
    venture: str                    # "grokly" | "swadisht" | "instastyle" | "all"
    sku_id: Optional[str]           # Product being promoted
    product_name: Optional[str]

    pricing_model: str              # "cpm" | "cpc" | "cpa" | "revenue_share" | "flat"
    bid_amount: float               # Rs amount (CPM basis for comparison)
    daily_budget: float             # Rs daily cap
    targeting_score: float = 1.0   # 0.0–1.0 match to this household
    is_active: bool = True

    # Computed
    effective_cpm: float = 0.0     # bid_amount * targeting_score


@dataclass
class AuctionResult:
    """Result of a single auction run for one feed slot."""
    slot_id: str
    winner: Optional[SponsoredBid]
    clearing_price: float           # Second price + Re 1
    auction_duration_ms: float
    runner_up_bid: float = 0.0
    no_fill: bool = False           # True if no eligible bids


# ---------------------------------------------------------------------------
# Budget pacing (Redis-backed)
# ---------------------------------------------------------------------------

def _get_daily_spend(brand_id: str) -> float:
    """Today's spend for a brand. Resets at midnight UTC."""
    key = f"ad:spend:{brand_id}:{_today_key()}"
    val = _redis.get(key)
    return float(val) if val else 0.0


def _record_impression_spend(brand_id: str, amount: float) -> float:
    """Record spend for an impression. Returns new daily total."""
    key = f"ad:spend:{brand_id}:{_today_key()}"
    new_total = _redis.incrbyfloat(key, amount)
    _redis.expire(key, 86400 * 2)  # Keep 2 days for reporting
    return float(new_total)


def _today_key() -> str:
    from datetime import datetime
    return datetime.utcnow().strftime("%Y-%m-%d")


def _brand_within_budget(bid: SponsoredBid) -> bool:
    """Check if brand still has daily budget remaining."""
    spend = _get_daily_spend(bid.brand_id)
    return spend < bid.daily_budget


# ---------------------------------------------------------------------------
# Targeting score calculator
# ---------------------------------------------------------------------------

def calculate_targeting_score(
    bid: SponsoredBid,
    user_features: dict,
    venture_filter: str = "all",
) -> float:
    """
    Compute targeting match score (0.0–1.0) between bid and household.
    Higher score = better match = higher effective bid in auction.

    Factors:
      - Venture match (grokly bid in swadisht feed = 0 score)
      - Preferred ventures of household
      - Budget bracket match
      - Time of day relevance (breakfast content at 7am etc.)
    """
    score = 0.0

    # Venture match — hard filter
    if bid.venture != "all" and venture_filter != "all":
        if bid.venture != venture_filter:
            return 0.0  # Disqualified

    # Venture preference match
    preferred = user_features.get("preferred_ventures", [])
    if bid.venture == "all" or bid.venture in preferred:
        score += 0.4
    else:
        score += 0.1

    # Budget bracket match
    budget = user_features.get("budget_bracket", "medium")
    bid_venture_budget_map = {
        ("grokly",     "low"):     0.9,
        ("grokly",     "medium"):  0.8,
        ("instastyle", "high"):    0.9,
        ("instastyle", "premium"): 1.0,
        ("swadisht",   "medium"):  0.85,
    }
    budget_score = bid_venture_budget_map.get((bid.venture, budget), 0.6)
    score += budget_score * 0.3

    # Time-of-day relevance
    hour = user_features.get("hour_of_day", 12)
    if bid.venture == "swadisht":
        # Food content: breakfast 7-9, lunch 12-14, dinner 19-22
        if 7 <= hour <= 9 or 12 <= hour <= 14 or 19 <= hour <= 22:
            score += 0.3
        else:
            score += 0.1
    elif bid.venture == "grokly":
        # Grocery: morning and evening peaks
        if 8 <= hour <= 11 or 17 <= hour <= 20:
            score += 0.3
        else:
            score += 0.15
    else:
        score += 0.2

    return min(score, 1.0)


# ---------------------------------------------------------------------------
# Effective CPM normalisation
# ---------------------------------------------------------------------------

def _normalise_to_cpm(bid: SponsoredBid) -> float:
    """
    Convert all pricing models to a comparable CPM figure for auction.
    Assumes average engagement rates from spec KPI targets.

    CTR target (scale): 3.2%
    Cart conversion:    9% of views
    Order conversion:   assume 30% of cart adds → 2.7% of views
    """
    if bid.pricing_model == "cpm":
        return bid.bid_amount

    elif bid.pricing_model == "cpc":
        # CPC: Rs 12–28 per click. Assume 3.2% CTR.
        # Effective CPM = CPC * CTR * 1000
        assumed_ctr = 0.032
        return bid.bid_amount * assumed_ctr * 1000

    elif bid.pricing_model == "cpa":
        # CPA: Rs 45–120 per confirmed order. Assume 2.7% order rate.
        assumed_order_rate = 0.027
        return bid.bid_amount * assumed_order_rate * 1000

    elif bid.pricing_model == "revenue_share":
        # Revenue share: 8–15% GMV. Assume avg order value Rs 400.
        avg_order_value = 400.0
        assumed_order_rate = 0.027
        effective_rev_per_view = (bid.bid_amount / 100.0) * avg_order_value * assumed_order_rate
        return effective_rev_per_view * 1000

    elif bid.pricing_model == "flat":
        # Flat fee: Rs 5,000–25,000 per video.
        # Assume 5,000 impressions per day.
        assumed_daily_impressions = 5000.0
        return (bid.bid_amount / assumed_daily_impressions) * 1000

    return bid.bid_amount  # fallback


# ---------------------------------------------------------------------------
# Auction
# ---------------------------------------------------------------------------

def run_auction(
    bids: list[SponsoredBid],
    user_features: dict,
    venture_filter: str = "all",
    n_slots: int = 3,
) -> list[AuctionResult]:
    """
    Run second-price auction for up to n_slots sponsored slots in the feed.
    Spec: auction clears in < 10ms.

    Args:
        bids:           All active brand bids (loaded from DB / Redis)
        user_features:  Household feature dict for targeting
        venture_filter: Which venture feed is being served
        n_slots:        Number of sponsored slots to fill (default 3 per 24 organic)

    Returns:
        List of AuctionResult (one per slot). no_fill=True if not enough bids.
    """
    t0 = time.perf_counter()

    # Step 1: Compute effective CPM for each eligible bid
    eligible = []
    for bid in bids:
        if not bid.is_active:
            continue
        if not _brand_within_budget(bid):
            logger.debug("Brand %s excluded — daily budget exhausted", bid.brand_id)
            continue

        targeting = calculate_targeting_score(bid, user_features, venture_filter)
        if targeting == 0.0:
            continue  # Venture mismatch — disqualified

        raw_cpm   = _normalise_to_cpm(bid)
        eff_cpm   = raw_cpm * targeting
        bid.targeting_score = targeting
        bid.effective_cpm   = eff_cpm
        eligible.append(bid)

    # Step 2: Sort by effective CPM descending
    eligible.sort(key=lambda b: b.effective_cpm, reverse=True)

    # Step 3: Second-price auction per slot (without replacement)
    results = []
    used_brands = set()

    for slot_idx in range(n_slots):
        slot_id = f"slot_{slot_idx + 1}"
        slot_duration = (time.perf_counter() - t0) * 1000

        # Find next eligible winner not already used this session
        winner = None
        runner_up_cpm = 0.0

        for i, bid in enumerate(eligible):
            if bid.brand_id in used_brands:
                continue
            if winner is None:
                winner = bid
                # Runner-up is next non-used bid
                for j in range(i + 1, len(eligible)):
                    if eligible[j].brand_id not in used_brands:
                        runner_up_cpm = eligible[j].effective_cpm
                        break
                break

        if winner is None:
            results.append(AuctionResult(
                slot_id=slot_id,
                winner=None,
                clearing_price=0.0,
                auction_duration_ms=slot_duration,
                no_fill=True,
            ))
            continue

        # Second-price: winner pays runner-up price + Re 1
        clearing_price = runner_up_cpm + 1.0

        # Record spend (CPM basis — actual charge when impression fires)
        spend_per_impression = clearing_price / 1000.0
        _record_impression_spend(winner.brand_id, spend_per_impression)

        used_brands.add(winner.brand_id)

        results.append(AuctionResult(
            slot_id=slot_id,
            winner=winner,
            clearing_price=clearing_price,
            runner_up_bid=runner_up_cpm,
            auction_duration_ms=(time.perf_counter() - t0) * 1000,
        ))

    total_ms = (time.perf_counter() - t0) * 1000
    logger.info(
        "Ad auction complete: %d bids → %d slots filled in %.2fms",
        len(eligible), sum(1 for r in results if not r.no_fill), total_ms,
    )

    return results


# ---------------------------------------------------------------------------
# Sponsored video builder (converts auction result → feed video dict)
# ---------------------------------------------------------------------------

def build_sponsored_video(result: AuctionResult) -> Optional[dict]:
    """
    Convert an auction winner into a feed-compatible video dict.
    is_sponsored=True and sponsored_label='SPONSORED' per spec.
    ranking_score stripped in production.
    """
    if result.no_fill or result.winner is None:
        return None

    winner = result.winner
    return {
        "video_id": winner.video_id,
        "hls_url": winner.hls_url,
        "thumbnail_url": winner.thumbnail_url,
        "duration_seconds": 60,
        "venture": winner.venture,
        "sku_id": winner.sku_id,
        "product_name": winner.product_name,
        "is_sponsored": True,
        "sponsored_label": "SPONSORED",
        "units_available": 999,     # Sponsored videos skip inventory gate
        "is_fresh": True,
        "freshness_boost": 0.0,
        # Internal fields — strip from production response
        "_auction_slot": result.slot_id,
        "_clearing_price_cpm": result.clearing_price,
        "_targeting_score": winner.targeting_score,
    }


# ---------------------------------------------------------------------------
# Active bids loader (stub — replace with DB query in production)
# ---------------------------------------------------------------------------

def load_active_bids() -> list[SponsoredBid]:
    """
    Load active sponsored bids from Redis cache.
    In production: query brands table in DB, cache in Redis for 5 min.

    Cache key: ad:active_bids
    Format: JSON array of bid dicts.

    Returns empty list if no bids configured — feed runs fully organic.
    """
    cache_key = "ad:active_bids"
    cached = _redis.get(cache_key)
    if cached:
        try:
            raw_bids = json.loads(cached)
            return [SponsoredBid(**b) for b in raw_bids]
        except Exception as exc:
            logger.warning("Failed to deserialise active bids: %s", exc)

    # No bids configured — return empty (organic-only feed)
    return []


def set_active_bids(bids: list[dict], ttl: int = 300) -> None:
    """
    Cache a list of active brand bids in Redis.
    Called by brand dashboard when a campaign is activated.
    ttl: seconds (default 5 min — bids refresh frequently).
    """
    _redis.setex("ad:active_bids", ttl, json.dumps(bids))
    logger.info("Active bids cache updated: %d bids, TTL=%ds", len(bids), ttl)
