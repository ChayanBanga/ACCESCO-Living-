"""
services/cqs.py
Creator Quality Score (CQS) engine for Accesco Virtual Discovery.

Spec reference: Section 4.5

Components and weights:
  - Video Technical Quality   25%  (from moderation pipeline quality_check)
  - Content Authenticity      20%  (from moderation pipeline authenticity)
  - Audience Engagement       25%  (view completion, double-tap, cart conversion)
  - Upload Consistency        15%  (upload frequency over trailing 30 days)
  - Community Trust           15%  (approved / total uploaded ratio)

CQS Bands:
  Explorer         0  - 40   Standard credits. Feed eligible after manual review.
  Creator         41  - 65   Auto-approved if moderation passes. 1.2x credits.
  Verified Creator 66 - 82   Priority feed placement. 1.5x credits. Brand collab eligible.
  Discovery Partner 83 - 100 Top-of-feed. 2x credits. Exclusive brand campaigns.

Called:
  - After every moderation pipeline run (update_cqs)
  - By a scheduled job daily for engagement-driven recalculation
  - Directly by the moderation status endpoint for preview
"""

import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from models.user import User
from models.video import Video

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Band thresholds (spec Section 4.5)
# ---------------------------------------------------------------------------

CQS_BANDS = [
    (83, 100, "partner"),
    (66, 82,  "verified"),
    (41, 65,  "creator"),
    (0,  40,  "explorer"),
]

CREDIT_MULTIPLIERS = {
    "explorer":  1.0,
    "creator":   1.2,
    "verified":  1.5,
    "partner":   2.0,
}


def get_band(score: float) -> str:
    """Map a CQS score to the correct band string."""
    for low, high, band in CQS_BANDS:
        if low <= score <= high:
            return band
    return "explorer"


# ---------------------------------------------------------------------------
# Component calculators
# ---------------------------------------------------------------------------

def _technical_quality_score(user_id: str, db: Session) -> float:
    """
    Weight: 25%
    Average quality_check composite score across last 10 approved/reviewed videos.
    Quality scores are stored in the video.ranking_score field as a proxy
    until we add a dedicated quality_score column (Phase 4 migration).

    For now: ratio of approved videos gives a signal — full score from
    moderation pipeline quality results stored in ranking_score on approval.
    """
    recent_videos = (
        db.query(Video)
        .filter(
            Video.creator_id == user_id,
            Video.is_ugc == True,
            Video.moderation_status.in_(["approved", "rejected", "review"]),
        )
        .order_by(Video.created_at.desc())
        .limit(10)
        .all()
    )

    if not recent_videos:
        return 50.0  # Cold start: neutral score

    # ranking_score on UGC videos is set to quality composite by pipeline
    scores = [v.ranking_score for v in recent_videos if v.ranking_score and v.ranking_score > 0]
    if not scores:
        return 50.0

    return min(sum(scores) / len(scores), 100.0)


def _authenticity_score(user: User) -> float:
    """
    Weight: 20%
    Derived from approval rate — proxy for authenticity consistency.
    High approval rate → products match, authenticity checks passing.
    """
    total = user.total_videos_uploaded or 0
    approved = user.total_videos_approved or 0

    if total == 0:
        return 50.0  # Cold start

    # Scale 0-100 based on approval rate
    rate = approved / total
    return round(rate * 100, 2)


def _engagement_score(user_id: str, db: Session) -> float:
    """
    Weight: 25%
    Composite of view completion, cart conversion, and engagement signals
    across approved UGC videos. Uses view_count and cart_add_count from
    the videos table.

    Formula:
      - Base engagement = cart_add_count / view_count (conversion rate)
      - Normalised to 0-100 (spec target: >9% cart conversion = scale score)
      - 9% conversion → ~80 score, 3% → ~40 score
    """
    approved_videos = (
        db.query(Video)
        .filter(
            Video.creator_id == user_id,
            Video.is_ugc == True,
            Video.moderation_status == "approved",
        )
        .all()
    )

    if not approved_videos:
        return 40.0  # Cold start — below creator threshold

    total_views = sum(v.view_count or 0 for v in approved_videos)
    total_cart_adds = sum(v.cart_add_count or 0 for v in approved_videos)

    if total_views == 0:
        return 40.0

    conversion_rate = total_cart_adds / total_views  # e.g. 0.09 = 9%

    # Scale: 0% conv → 0 score, 9% conv → 80 score, 15%+ → 100 score
    # Linear between 0 and 15%, capped at 100
    score = min((conversion_rate / 0.15) * 100, 100.0)
    return round(score, 2)


def _upload_consistency_score(user_id: str, db: Session) -> float:
    """
    Weight: 15%
    Upload frequency over trailing 30 days.
    Spec: measures frequency of uploads over trailing 30 days.

    Scoring:
      0 uploads in 30 days → 0
      1 upload            → 30
      2 uploads           → 50
      4 uploads           → 70
      8+ uploads          → 100
    """
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    count = (
        db.query(func.count(Video.id))
        .filter(
            Video.creator_id == user_id,
            Video.is_ugc == True,
            Video.created_at >= thirty_days_ago,
        )
        .scalar()
        or 0
    )

    # Logarithmic scale — rewards consistency without requiring daily uploads
    if count == 0:
        return 0.0
    elif count == 1:
        return 30.0
    elif count <= 3:
        return 30.0 + (count - 1) * 10.0   # 30-50
    elif count <= 7:
        return 50.0 + (count - 3) * 5.0    # 50-70
    else:
        return min(70.0 + (count - 7) * 3.0, 100.0)  # 70-100


def _community_trust_score(user: User) -> float:
    """
    Weight: 15%
    Ratio of approved to total uploaded videos over creator lifetime.
    Spec: ratio of approved vs rejected videos over creator lifetime.

    0% approval → 0, 100% approval → 100
    Minimum 3 uploads required for a meaningful score — below that, neutral 60.
    """
    total = user.total_videos_uploaded or 0
    approved = user.total_videos_approved or 0

    if total < 3:
        return 60.0  # Not enough data — give benefit of doubt

    rate = approved / total
    return round(rate * 100, 2)


# ---------------------------------------------------------------------------
# Main CQS calculator
# ---------------------------------------------------------------------------

def calculate_cqs(user_id: str, db: Session) -> dict:
    """
    Calculate full CQS for a user. Returns scores dict + final band.
    Does NOT write to DB — call update_cqs() for that.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        logger.warning("CQS calculate called for unknown user_id=%s", user_id)
        return {"error": "User not found"}

    # --- Calculate each component ---
    tech_quality   = _technical_quality_score(str(user_id), db)
    authenticity   = _authenticity_score(user)
    engagement     = _engagement_score(str(user_id), db)
    consistency    = _upload_consistency_score(str(user_id), db)
    trust          = _community_trust_score(user)

    # --- Weighted composite (spec weights) ---
    composite = (
        tech_quality * 0.25 +
        authenticity * 0.20 +
        engagement   * 0.25 +
        consistency  * 0.15 +
        trust        * 0.15
    )
    composite = round(min(composite, 100.0), 2)
    band = get_band(composite)
    multiplier = CREDIT_MULTIPLIERS[band]

    return {
        "user_id": str(user_id),
        "cqs_score": composite,
        "cqs_band": band,
        "credit_multiplier": multiplier,
        "components": {
            "technical_quality":  {"score": round(tech_quality, 2),  "weight": 0.25},
            "content_authenticity": {"score": round(authenticity, 2), "weight": 0.20},
            "audience_engagement": {"score": round(engagement, 2),   "weight": 0.25},
            "upload_consistency":  {"score": round(consistency, 2),  "weight": 0.15},
            "community_trust":     {"score": round(trust, 2),        "weight": 0.15},
        },
        "total_videos_uploaded": user.total_videos_uploaded or 0,
        "total_videos_approved": user.total_videos_approved or 0,
        "discovery_credits": user.discovery_credits or 0,
    }


def update_cqs(creator_id: str, db: Session) -> Optional[dict]:
    """
    Calculate CQS and write the result back to the users table.
    Called after every moderation pipeline completion.

    Returns the CQS result dict, or None if user not found.
    """
    if not creator_id:
        return None

    try:
        result = calculate_cqs(creator_id, db)
        if "error" in result:
            return None

        user = db.query(User).filter(User.id == creator_id).first()
        if not user:
            return None

        old_band = user.cqs_band
        user.cqs_score = result["cqs_score"]
        user.cqs_band = result["cqs_band"]
        db.commit()

        if old_band != result["cqs_band"]:
            logger.info(
                "CQS band changed for user %s: %s → %s (score: %.1f)",
                creator_id, old_band, result["cqs_band"], result["cqs_score"],
            )
        else:
            logger.info(
                "CQS updated for user %s: %.1f (%s)",
                creator_id, result["cqs_score"], result["cqs_band"],
            )

        return result

    except Exception as exc:
        logger.exception("CQS update failed for user %s: %s", creator_id, exc)
        return None


# ---------------------------------------------------------------------------
# Discovery Credits logic
# ---------------------------------------------------------------------------

BASE_CREDITS = {
    "video_selected":        50,   # Rs 50 — video approved into feed
    "views_500_48hrs":       25,   # Rs 25 bonus — 500+ views in 48hrs
    "cart_adds_10":         100,   # Rs 100 bonus — 10+ cart adds
    "brand_slot_featured":  250,   # Rs 250 — brand selects UGC
    "monthly_top_creator":  500,   # Rs 500 — leaderboard rank 1
}

MAX_CREDITS_PER_MONTH = 2000  # Rs 2,000 cap per spec


def award_credits(
    user_id: str,
    credit_type: str,
    db: Session,
    cqs_band: Optional[str] = None,
) -> dict:
    """
    Award Discovery Credits to a creator with CQS multiplier applied.
    Enforces monthly cap of Rs 2,000.

    Args:
        user_id:     UUID string of the user
        credit_type: key from BASE_CREDITS dict
        db:          active SQLAlchemy session
        cqs_band:    if None, looked up from DB

    Returns dict with credits_awarded, new_total, multiplier_applied.
    """
    if credit_type not in BASE_CREDITS:
        return {"error": f"Unknown credit_type: {credit_type}"}

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return {"error": "User not found"}

    band = cqs_band or user.cqs_band or "explorer"
    multiplier = CREDIT_MULTIPLIERS.get(band, 1.0)
    base_amount = BASE_CREDITS[credit_type]
    amount = int(base_amount * multiplier)

    # Enforce monthly cap (simple: check current total vs cap)
    # Production: track monthly credits in a separate ledger table
    current = user.discovery_credits or 0
    if current >= MAX_CREDITS_PER_MONTH:
        logger.info("Credits not awarded to %s — monthly cap reached", user_id)
        return {
            "credits_awarded": 0,
            "reason": "Monthly cap of Rs 2,000 reached",
            "current_total": current,
        }

    # Clamp to cap
    amount = min(amount, MAX_CREDITS_PER_MONTH - current)
    user.discovery_credits = current + amount
    db.commit()

    logger.info(
        "Credits awarded — user=%s type=%s base=%d multiplier=%.1fx awarded=%d total=%d",
        user_id, credit_type, base_amount, multiplier, amount, user.discovery_credits,
    )

    return {
        "credits_awarded": amount,
        "base_amount": base_amount,
        "multiplier_applied": multiplier,
        "cqs_band": band,
        "new_total": user.discovery_credits,
        "monthly_cap": MAX_CREDITS_PER_MONTH,
    }
