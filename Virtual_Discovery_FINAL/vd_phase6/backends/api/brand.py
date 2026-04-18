"""
api/brand.py
Brand dashboard API — Phase 5.

Spec Section 3.2 requirements:
  - Real-time view count, completion rate, drop-off analytics per video
  - Cart conversion tracking: views → swipe_left → checkout → order
  - Audience segment breakdown
  - A/B testing: test 2 video variants, auto-optimise to winner
  - Spend pacing controls: daily budget, hourly bid, blackout windows
  - UGC library access: browse and select user videos for brand boost
  - Attribution reporting: first-touch, last-touch, multi-touch

All brand endpoints require X-Brand-Key header.
In production: replaced with OAuth2 + brand portal login.

Flutter/Next.js integration:
  - Brand dashboard is a web-only interface (Next.js)
  - Flutter app does NOT call these endpoints
  - CORS is already open in main.py — restrict to brand dashboard domain in production
"""

import json
import logging
import os
from datetime import datetime, timedelta
from typing import Optional

import redis
from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from models.database import get_db
from models.video import Video
from models.user import User
from services.ad_auction import (
    SponsoredBid,
    set_active_bids,
    load_active_bids,
    _get_daily_spend,
    _today_key,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/brand", tags=["Brand Dashboard"])

_redis: redis.Redis = redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))

BRAND_API_KEY = os.getenv("BRAND_API_KEY", "dev-brand-key-change-in-prod")


# ---------------------------------------------------------------------------
# Auth guard
# ---------------------------------------------------------------------------

def _require_brand_key(x_brand_key: str = Header(...)):
    if x_brand_key != BRAND_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid brand API key.",
        )


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------

class CreateCampaignRequest(BaseModel):
    brand_id: str
    video_id: str = Field(..., description="Sponsored video UUID to serve in feed")
    hls_url: str
    thumbnail_url: str
    venture: str = Field(default="all", description="grokly | swadisht | instastyle | all")
    sku_id: Optional[str] = None
    product_name: Optional[str] = None
    pricing_model: str = Field(..., description="cpm | cpc | cpa | revenue_share | flat")
    bid_amount: float = Field(..., gt=0, description="Rs bid amount")
    daily_budget: float = Field(..., gt=0, description="Rs daily spend cap")


class CampaignResponse(BaseModel):
    brand_id: str
    video_id: str
    venture: str
    pricing_model: str
    bid_amount: float
    daily_budget: float
    daily_spend_today: float
    budget_remaining: float
    status: str


class VideoAnalytics(BaseModel):
    video_id: str
    view_count: int
    cart_add_count: int
    conversion_rate: float          # cart_adds / views
    completion_rate: float          # proxy: ranking_score as quality signal
    is_sponsored: bool
    venture: str
    created_at: Optional[datetime]


class CampaignAnalyticsResponse(BaseModel):
    brand_id: str
    date: str
    total_impressions: int
    total_cart_adds: int
    total_spend_rs: float
    effective_ctr: float
    videos: list[VideoAnalytics]


class ABTestRequest(BaseModel):
    brand_id: str
    video_id_a: str
    video_id_b: str
    venture: str = "all"
    test_name: str


class ABTestResult(BaseModel):
    test_name: str
    video_id_a: str
    video_id_b: str
    views_a: int
    views_b: int
    cart_adds_a: int
    cart_adds_b: int
    conversion_a: float
    conversion_b: float
    winner: Optional[str]           # video_id of winner, or None if inconclusive
    confidence: float               # 0.0 - 1.0, statistical confidence
    recommendation: str


class UGCVideoItem(BaseModel):
    video_id: str
    creator_id: str
    sku_id: Optional[str]
    view_count: int
    cart_add_count: int
    conversion_rate: float
    thumbnail_url: Optional[str]
    hls_url: Optional[str]
    created_at: Optional[datetime]


class UGCLibraryResponse(BaseModel):
    items: list[UGCVideoItem]
    total: int
    page: int
    page_size: int


class BudgetPacingRequest(BaseModel):
    brand_id: str
    daily_budget: float
    blackout_hours: list[int] = Field(
        default=[],
        description="UTC hours (0-23) when ads should not serve"
    )
    hourly_bid_adjustments: dict = Field(
        default={},
        description="Hour (str) → multiplier (float). e.g. {'7': 1.5, '22': 0.5}"
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post(
    "/campaign",
    response_model=CampaignResponse,
    summary="Create or update a sponsored campaign",
    dependencies=[Depends(_require_brand_key)],
)
def create_campaign(body: CreateCampaignRequest, db: Session = Depends(get_db)):
    """
    Creates or updates a sponsored campaign.
    Immediately adds the bid to the active bids cache so it participates
    in the next feed auction.
    """
    # Load existing bids, replace or append
    existing = load_active_bids()
    bid_dicts = [
        {k: v for k, v in vars(b).items()}
        for b in existing
        if b.brand_id != body.brand_id or b.video_id != body.video_id
    ]

    new_bid = {
        "brand_id": body.brand_id,
        "video_id": body.video_id,
        "hls_url": body.hls_url,
        "thumbnail_url": body.thumbnail_url,
        "venture": body.venture,
        "sku_id": body.sku_id,
        "product_name": body.product_name,
        "pricing_model": body.pricing_model,
        "bid_amount": body.bid_amount,
        "daily_budget": body.daily_budget,
        "targeting_score": 1.0,
        "is_active": True,
        "effective_cpm": 0.0,
    }
    bid_dicts.append(new_bid)
    set_active_bids(bid_dicts)

    daily_spend = _get_daily_spend(body.brand_id)

    logger.info(
        "Campaign created/updated — brand=%s video=%s pricing=%s bid=%.2f",
        body.brand_id, body.video_id, body.pricing_model, body.bid_amount,
    )

    return CampaignResponse(
        brand_id=body.brand_id,
        video_id=body.video_id,
        venture=body.venture,
        pricing_model=body.pricing_model,
        bid_amount=body.bid_amount,
        daily_budget=body.daily_budget,
        daily_spend_today=daily_spend,
        budget_remaining=max(0.0, body.daily_budget - daily_spend),
        status="active",
    )


@router.delete(
    "/campaign/{brand_id}/{video_id}",
    summary="Pause / remove a sponsored campaign",
    dependencies=[Depends(_require_brand_key)],
)
def pause_campaign(brand_id: str, video_id: str):
    """Removes the bid from the active auction cache."""
    existing = load_active_bids()
    filtered = [
        {k: v for k, v in vars(b).items()}
        for b in existing
        if not (b.brand_id == brand_id and b.video_id == video_id)
    ]
    set_active_bids(filtered)
    return {"message": f"Campaign paused for brand {brand_id}, video {video_id}"}


@router.get(
    "/analytics/{brand_id}",
    response_model=CampaignAnalyticsResponse,
    summary="Real-time campaign analytics",
    dependencies=[Depends(_require_brand_key)],
)
def get_campaign_analytics(
    brand_id: str,
    db: Session = Depends(get_db),
):
    """
    Returns real-time analytics for all sponsored videos belonging to a brand.
    Pulls view_count and cart_add_count directly from the videos table.

    Spec requirements:
      - Real-time view count, completion rate, drop-off point
      - Cart conversion tracking
      - Audience segment breakdown (Phase 6: add household segment join)
    """
    # Get all sponsored videos for this brand
    # In production: brands table with brand_id FK on videos
    # For now: filter sponsored videos where creator_id matches brand_id
    sponsored_videos = (
        db.query(Video)
        .filter(
            Video.is_sponsored == True,
            Video.creator_id == brand_id,
        )
        .all()
    )

    video_analytics = []
    total_impressions = 0
    total_cart_adds = 0

    for v in sponsored_videos:
        views = v.view_count or 0
        adds = v.cart_add_count or 0
        conv = adds / max(views, 1)

        total_impressions += views
        total_cart_adds += adds

        video_analytics.append(VideoAnalytics(
            video_id=str(v.id),
            view_count=views,
            cart_add_count=adds,
            conversion_rate=round(conv, 4),
            completion_rate=round(float(v.ranking_score or 0.0), 4),
            is_sponsored=True,
            venture=v.venture,
            created_at=v.created_at,
        ))

    daily_spend = _get_daily_spend(brand_id)
    effective_ctr = total_cart_adds / max(total_impressions, 1)

    return CampaignAnalyticsResponse(
        brand_id=brand_id,
        date=_today_key(),
        total_impressions=total_impressions,
        total_cart_adds=total_cart_adds,
        total_spend_rs=daily_spend,
        effective_ctr=round(effective_ctr, 4),
        videos=video_analytics,
    )


@router.get(
    "/ugc-library",
    response_model=UGCLibraryResponse,
    summary="Browse UGC library for brand boost campaigns",
    dependencies=[Depends(_require_brand_key)],
)
def get_ugc_library(
    venture: str = Query(default="all"),
    sku_id: Optional[str] = Query(default=None),
    min_views: int = Query(default=100),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, le=50),
    db: Session = Depends(get_db),
):
    """
    Browse approved UGC videos for brand boost campaigns.
    Brands can select high-performing user videos and pay to amplify them.
    Spec: UGC Brand Boost flat fee Rs 5,000–25,000 per video.
    """
    query = (
        db.query(Video)
        .filter(
            Video.is_ugc == True,
            Video.moderation_status == "approved",
            Video.view_count >= min_views,
        )
    )
    if venture != "all":
        query = query.filter(Video.venture == venture)
    if sku_id:
        query = query.filter(Video.sku_id == sku_id)

    total = query.count()
    offset = (page - 1) * page_size
    videos = (
        query
        .order_by(Video.cart_add_count.desc(), Video.view_count.desc())
        .offset(offset)
        .limit(page_size)
        .all()
    )

    items = [
        UGCVideoItem(
            video_id=str(v.id),
            creator_id=str(v.creator_id or ""),
            sku_id=v.sku_id,
            view_count=v.view_count or 0,
            cart_add_count=v.cart_add_count or 0,
            conversion_rate=round(
                (v.cart_add_count or 0) / max(v.view_count or 1, 1), 4
            ),
            thumbnail_url=v.thumbnail_url,
            hls_url=v.hls_url,
            created_at=v.created_at,
        )
        for v in videos
    ]

    return UGCLibraryResponse(items=items, total=total, page=page, page_size=page_size)


@router.post(
    "/ab-test",
    response_model=ABTestResult,
    summary="Run A/B test between two video variants",
    dependencies=[Depends(_require_brand_key)],
)
def run_ab_test(body: ABTestRequest, db: Session = Depends(get_db)):
    """
    Compare performance of two sponsored video variants.
    Spec: test 2 video variants simultaneously, auto-optimise to winner.

    Statistical significance: simple z-test on conversion rates.
    Winner declared when confidence > 0.95.
    """
    video_a = db.query(Video).filter(Video.id == body.video_id_a).first()
    video_b = db.query(Video).filter(Video.id == body.video_id_b).first()

    if not video_a or not video_b:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="One or both video IDs not found.",
        )

    views_a = video_a.view_count or 0
    views_b = video_b.view_count or 0
    adds_a = video_a.cart_add_count or 0
    adds_b = video_b.cart_add_count or 0

    conv_a = adds_a / max(views_a, 1)
    conv_b = adds_b / max(views_b, 1)

    # Simple proportions z-test
    confidence, winner, recommendation = _ab_significance(
        views_a, adds_a, conv_a,
        views_b, adds_b, conv_b,
        body.video_id_a, body.video_id_b,
    )

    return ABTestResult(
        test_name=body.test_name,
        video_id_a=body.video_id_a,
        video_id_b=body.video_id_b,
        views_a=views_a,
        views_b=views_b,
        cart_adds_a=adds_a,
        cart_adds_b=adds_b,
        conversion_a=round(conv_a, 4),
        conversion_b=round(conv_b, 4),
        winner=winner,
        confidence=round(confidence, 3),
        recommendation=recommendation,
    )


@router.post(
    "/pacing",
    summary="Set budget pacing and blackout windows",
    dependencies=[Depends(_require_brand_key)],
)
def set_budget_pacing(body: BudgetPacingRequest):
    """
    Configure daily budget cap, blackout hours, and hourly bid adjustments.
    Stored in Redis — applied by auction engine on each bid evaluation.

    Spec: daily budget caps, hourly bid adjustment, blackout windows.
    """
    pacing_key = f"ad:pacing:{body.brand_id}"
    pacing_config = {
        "brand_id": body.brand_id,
        "daily_budget": body.daily_budget,
        "blackout_hours": body.blackout_hours,
        "hourly_bid_adjustments": body.hourly_bid_adjustments,
        "updated_at": datetime.utcnow().isoformat(),
    }
    _redis.setex(pacing_key, 86400, json.dumps(pacing_config))

    logger.info(
        "Budget pacing updated for brand %s: daily_budget=%.2f blackouts=%s",
        body.brand_id, body.daily_budget, body.blackout_hours,
    )

    return {
        "message": "Budget pacing updated",
        "brand_id": body.brand_id,
        "daily_budget": body.daily_budget,
        "blackout_hours": body.blackout_hours,
        "hourly_bid_adjustments": body.hourly_bid_adjustments,
    }


@router.get(
    "/spend/{brand_id}",
    summary="Get today's spend for a brand",
    dependencies=[Depends(_require_brand_key)],
)
def get_spend(brand_id: str):
    """Real-time spend tracking. Spend recorded per impression in Redis."""
    daily_spend = _get_daily_spend(brand_id)
    return {
        "brand_id": brand_id,
        "date": _today_key(),
        "daily_spend_rs": daily_spend,
    }


# ---------------------------------------------------------------------------
# A/B test statistics helper
# ---------------------------------------------------------------------------

def _ab_significance(
    n_a: int, k_a: int, p_a: float,
    n_b: int, k_b: int, p_b: float,
    id_a: str, id_b: str,
) -> tuple[float, Optional[str], str]:
    """
    Two-proportion z-test.
    Returns (confidence, winner_id_or_None, recommendation_string).
    """
    import math

    if n_a < 100 or n_b < 100:
        return (0.0, None,
                "Not enough data yet. Need at least 100 views per variant.")

    # Pooled proportion
    p_pool = (k_a + k_b) / max(n_a + n_b, 1)
    se = math.sqrt(p_pool * (1 - p_pool) * (1 / max(n_a, 1) + 1 / max(n_b, 1)))

    if se == 0:
        return (0.0, None, "Insufficient variance to compute significance.")

    z = (p_a - p_b) / se
    # Approximate p-value from z-score (two-tailed normal CDF)
    from math import erf, sqrt
    p_value = 1 - erf(abs(z) / sqrt(2))
    confidence = 1 - p_value

    if confidence < 0.95:
        return (confidence, None,
                f"Test inconclusive (confidence {confidence:.1%}). "
                f"Continue running — need more impressions.")

    winner = id_a if p_a > p_b else id_b
    loser = id_b if winner == id_a else id_a
    winning_conv = max(p_a, p_b)
    losing_conv = min(p_a, p_b)
    lift = ((winning_conv - losing_conv) / max(losing_conv, 0.001)) * 100

    return (confidence, winner,
            f"Winner: {winner} with {winning_conv:.1%} conversion "
            f"vs {losing_conv:.1%} ({lift:.0f}% lift). "
            f"Pause {loser} and promote the winner.")
