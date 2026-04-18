"""
services/credits.py
Discovery Credits ledger service — Phase 6.

Spec Section 2.2 — full implementation:
  video_selected       Rs 50   quality score > 72%
  views_500_48hrs      Rs 25   organic reach threshold (500+ views in 48hrs)
  cart_adds_10         Rs 100  commerce conversion (10+ cart adds)
  brand_slot_featured  Rs 250  brand selects UGC for paid slot
  monthly_top_creator  Rs 500  leaderboard rank 1

Rules from spec:
  - Credits expire in 90 days
  - Max Rs 2,000 per user per month
  - Non-transferable, redeemable only on Accesco Living orders
  - CQS multiplier applied to base amount

All awards written to credits_ledger table for audit trail.
Monthly cap tracked on user.credits_awarded_this_month.
"""

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from models.user import User
from models.video import Video
from models.credits_ledger import CreditsLedger
from services.cqs import CREDIT_MULTIPLIERS, get_band

logger = logging.getLogger(__name__)

BASE_CREDITS = {
    "video_selected":       50,
    "views_500_48hrs":      25,
    "cart_adds_10":        100,
    "brand_slot_featured": 250,
    "monthly_top_creator": 500,
}

MAX_CREDITS_PER_MONTH = 2000
CREDITS_EXPIRY_DAYS   = 90


def _ensure_monthly_reset(user: User, db: Session) -> None:
    """Reset monthly counter at start of each calendar month."""
    now = datetime.utcnow()
    last_reset = user.credits_last_reset_at

    should_reset = (
        last_reset is None or
        last_reset.month != now.month or
        last_reset.year  != now.year
    )
    if should_reset:
        user.credits_awarded_this_month = 0
        user.credits_last_reset_at = now
        db.commit()


def award_credits(
    user_id: str,
    credit_type: str,
    db: Session,
    video_id: Optional[str] = None,
    note: Optional[str] = None,
) -> dict:
    """
    Award Discovery Credits to a creator.
    Applies CQS multiplier, enforces monthly cap, writes ledger entry.

    Returns dict with credits_awarded, new_total, cap_remaining.
    """
    if credit_type not in BASE_CREDITS:
        return {"error": f"Unknown credit_type: {credit_type}"}

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return {"error": "User not found"}

    _ensure_monthly_reset(user, db)

    # Monthly cap check
    awarded_this_month = user.credits_awarded_this_month or 0
    if awarded_this_month >= MAX_CREDITS_PER_MONTH:
        logger.info("Credits not awarded to %s — monthly cap reached", user_id)
        return {
            "credits_awarded": 0,
            "reason": "Monthly cap of Rs 2,000 reached",
            "current_total": user.discovery_credits or 0,
            "cap_remaining": 0,
        }

    # Apply CQS multiplier
    band = user.cqs_band or "explorer"
    multiplier = CREDIT_MULTIPLIERS.get(band, 1.0)
    base = BASE_CREDITS[credit_type]
    amount = int(base * multiplier)

    # Clamp to monthly cap
    cap_remaining = MAX_CREDITS_PER_MONTH - awarded_this_month
    amount = min(amount, cap_remaining)

    # Update user record
    user.discovery_credits = (user.discovery_credits or 0) + amount
    user.credits_awarded_this_month = awarded_this_month + amount

    # Write ledger entry
    expires_at = datetime.utcnow() + timedelta(days=CREDITS_EXPIRY_DAYS)
    ledger_entry = CreditsLedger(
        user_id=str(user_id),
        video_id=video_id,
        credit_type=credit_type,
        amount=amount,
        multiplier=multiplier,
        base_amount=base,
        expires_at=expires_at,
        note=note or f"Auto-awarded: {credit_type}",
    )
    db.add(ledger_entry)
    db.commit()

    logger.info(
        "Credits awarded — user=%s type=%s base=%d x%.1f = %d (total=%d)",
        user_id, credit_type, base, multiplier, amount, user.discovery_credits,
    )

    return {
        "credits_awarded": amount,
        "base_amount": base,
        "multiplier": multiplier,
        "cqs_band": band,
        "new_total": user.discovery_credits,
        "cap_remaining": MAX_CREDITS_PER_MONTH - user.credits_awarded_this_month,
        "expires_at": expires_at.isoformat(),
    }


def check_and_award_milestone_credits(
    video_id: str,
    db: Session,
) -> list[dict]:
    """
    Check if a video has hit any milestone thresholds and award credits.
    Called by a background job every hour (or triggered by event pipeline).

    Milestones checked:
      - 500+ views within 48hrs   → views_500_48hrs (Rs 25)
      - 10+ cart adds             → cart_adds_10 (Rs 100)
    """
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video or not video.creator_id or video.moderation_status != "approved":
        return []

    awarded = []
    user_id = video.creator_id
    vid_id_str = str(video.id)

    # Check if already awarded for this video (avoid double-award)
    def already_awarded(credit_type: str) -> bool:
        return db.query(CreditsLedger).filter(
            CreditsLedger.user_id == user_id,
            CreditsLedger.video_id == vid_id_str,
            CreditsLedger.credit_type == credit_type,
        ).first() is not None

    # Milestone: 500+ views in 48hrs
    if (video.view_count or 0) >= 500 and not already_awarded("views_500_48hrs"):
        age_hrs = 0.0
        if video.created_at:
            age_hrs = (datetime.utcnow() - video.created_at).total_seconds() / 3600
        if age_hrs <= 48:
            result = award_credits(
                user_id=user_id,
                credit_type="views_500_48hrs",
                db=db,
                video_id=vid_id_str,
                note=f"500+ views in {age_hrs:.1f}hrs",
            )
            awarded.append({"milestone": "views_500_48hrs", **result})

    # Milestone: 10+ cart adds
    if (video.cart_add_count or 0) >= 10 and not already_awarded("cart_adds_10"):
        result = award_credits(
            user_id=user_id,
            credit_type="cart_adds_10",
            db=db,
            video_id=vid_id_str,
            note=f"{video.cart_add_count} cart adds reached",
        )
        awarded.append({"milestone": "cart_adds_10", **result})

    return awarded


def get_credits_summary(user_id: str, db: Session) -> dict:
    """
    Returns full credit summary for a user — used by creator dashboard.
    Includes ledger history, expiring soon, and monthly stats.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return {"error": "User not found"}

    _ensure_monthly_reset(user, db)

    # All active (non-expired) ledger entries
    now = datetime.utcnow()
    active_entries = (
        db.query(CreditsLedger)
        .filter(
            CreditsLedger.user_id == str(user_id),
            CreditsLedger.amount > 0,
            (CreditsLedger.expires_at >= now) | (CreditsLedger.expires_at == None),
        )
        .order_by(CreditsLedger.created_at.desc())
        .limit(20)
        .all()
    )

    # Credits expiring within 7 days
    expiring_soon = [
        e for e in active_entries
        if e.expires_at and (e.expires_at - now).days <= 7
    ]

    return {
        "user_id": str(user_id),
        "total_credits": user.discovery_credits or 0,
        "credits_awarded_this_month": user.credits_awarded_this_month or 0,
        "monthly_cap": MAX_CREDITS_PER_MONTH,
        "cap_remaining": MAX_CREDITS_PER_MONTH - (user.credits_awarded_this_month or 0),
        "expiry_days": CREDITS_EXPIRY_DAYS,
        "credits_expiring_in_7_days": sum(e.amount for e in expiring_soon),
        "recent_awards": [
            {
                "credit_type": e.credit_type,
                "amount": e.amount,
                "base_amount": e.base_amount,
                "multiplier": e.multiplier,
                "video_id": e.video_id,
                "note": e.note,
                "awarded_at": e.created_at.isoformat() if e.created_at else None,
                "expires_at": e.expires_at.isoformat() if e.expires_at else None,
            }
            for e in active_entries
        ],
    }


def get_leaderboard(db: Session, limit: int = 10) -> list[dict]:
    """
    Monthly credits leaderboard — top creators by credits_awarded_this_month.
    Rank 1 gets Rs 500 monthly_top_creator bonus (awarded separately by cron).
    """
    top_users = (
        db.query(User)
        .filter(User.credits_awarded_this_month > 0)
        .order_by(User.credits_awarded_this_month.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "rank": i + 1,
            "household_id": u.household_id,
            "display_name": u.display_name or "Anonymous Creator",
            "cqs_band": u.cqs_band,
            "credits_this_month": u.credits_awarded_this_month or 0,
            "total_credits": u.discovery_credits or 0,
        }
        for i, u in enumerate(top_users)
    ]
