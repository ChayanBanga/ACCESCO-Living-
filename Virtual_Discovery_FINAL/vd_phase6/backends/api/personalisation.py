"""
api/personalisation.py
Phase 6 — Personalisation endpoints.

Endpoints:
  GET  /api/v1/personalisation/embedding/{household_id}
       Full embedding snapshot — Flutter debug / creator dashboard
  GET  /api/v1/personalisation/profile/{household_id}
       Household profile: dietary flags, budget, venture preferences
  PUT  /api/v1/personalisation/profile/{household_id}
       Update household profile (My Home Profile from spec)
  DELETE /api/v1/personalisation/data/{household_id}
       GDPR/data deletion — purge all embeddings + interaction history
       Spec Section 09: within 72 hours

  GET  /api/v1/personalisation/credits/{household_id}
       Discovery Credits summary for creator dashboard
  GET  /api/v1/personalisation/leaderboard
       Monthly top creator leaderboard

Flutter integration:
  - Embedding endpoint is for debugging only — not shown to end users
  - Profile PUT is called from "My Home" screen in the app
  - Credits endpoint powers the creator dashboard credits widget
  - Data deletion is exposed in Privacy Settings screen
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from models.database import get_db
from models.user import User
from personalisation.embedding import get_full_embedding, reset_embedding
from services.credits import get_credits_summary, get_leaderboard
from services.cqs import calculate_cqs

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/personalisation", tags=["Personalisation"])


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class HouseholdProfileUpdate(BaseModel):
    display_name:      Optional[str]       = None
    dietary_flags:     Optional[list[str]] = None   # ["vegetarian", "vegan", "gluten_free"]
    budget_bracket:    Optional[str]       = None   # low | medium | high | premium
    preferred_ventures: Optional[list[str]] = None  # ["grokly", "swadisht", "instastyle"]


class HouseholdProfileResponse(BaseModel):
    household_id:      str
    display_name:      Optional[str]
    dietary_flags:     list
    budget_bracket:    str
    preferred_ventures: list
    cqs_score:         float
    cqs_band:          str
    discovery_credits: int
    total_videos_uploaded: int
    total_videos_approved: int


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/embedding/{household_id}",
    summary="Get full personalisation embedding for a household",
    description=(
        "Returns all five embedding vectors for the household. "
        "Used for debugging and the creator analytics dashboard. "
        "Shows how the AI understands this household's preferences."
    ),
)
def get_embedding(household_id: str):
    """Returns the live personalisation embedding from Redis."""
    return get_full_embedding(household_id)


@router.get(
    "/profile/{household_id}",
    response_model=HouseholdProfileResponse,
    summary="Get household profile",
)
def get_profile(household_id: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.household_id == household_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Household {household_id} not found. Create it via POST /api/v1/personalisation/profile.",
        )
    return HouseholdProfileResponse(
        household_id=user.household_id,
        display_name=user.display_name,
        dietary_flags=user.dietary_flags or [],
        budget_bracket=user.budget_bracket or "medium",
        preferred_ventures=user.preferred_ventures or [],
        cqs_score=user.cqs_score or 0.0,
        cqs_band=user.cqs_band or "explorer",
        discovery_credits=user.discovery_credits or 0,
        total_videos_uploaded=user.total_videos_uploaded or 0,
        total_videos_approved=user.total_videos_approved or 0,
    )


@router.put(
    "/profile/{household_id}",
    summary="Create or update household profile (My Home Profile)",
    description=(
        "Called from the 'My Home' onboarding screen in the Flutter app. "
        "Sets dietary preferences, budget bracket, and venture preferences. "
        "Creates the user record if it doesn't exist. "
        "These inputs seed the cold-start personalisation feed."
    ),
)
def upsert_profile(
    household_id: str,
    body: HouseholdProfileUpdate,
    db: Session = Depends(get_db),
):
    from datetime import datetime

    user = db.query(User).filter(User.household_id == household_id).first()
    if not user:
        user = User(household_id=household_id)
        db.add(user)

    if body.display_name is not None:
        user.display_name = body.display_name
    if body.dietary_flags is not None:
        user.dietary_flags = body.dietary_flags
    if body.budget_bracket is not None:
        valid = {"low", "medium", "high", "premium"}
        if body.budget_bracket not in valid:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"budget_bracket must be one of: {sorted(valid)}",
            )
        user.budget_bracket = body.budget_bracket
    if body.preferred_ventures is not None:
        valid_v = {"grokly", "swadisht", "instastyle"}
        invalid = set(body.preferred_ventures) - valid_v
        if invalid:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid ventures: {invalid}. Must be subset of {sorted(valid_v)}",
            )
        user.preferred_ventures = body.preferred_ventures

    user.last_active_at = datetime.utcnow()
    db.commit()
    db.refresh(user)

    # Invalidate user feature cache so ranking picks up new profile immediately
    import redis as redis_lib
    import os
    r = redis_lib.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))
    r.delete(f"feature:user:{household_id}")

    return {
        "message": "Profile updated",
        "household_id": household_id,
        "profile": {
            "display_name": user.display_name,
            "dietary_flags": user.dietary_flags,
            "budget_bracket": user.budget_bracket,
            "preferred_ventures": user.preferred_ventures,
        },
    }


@router.delete(
    "/data/{household_id}",
    summary="Delete all personalisation data for a household",
    description=(
        "GDPR / data deletion request. "
        "Purges all embedding vectors, session history, and feature cache from Redis. "
        "Spec Section 09: must complete within 72 hours. "
        "DB interaction records are anonymised separately by a scheduled job."
    ),
)
def delete_personalisation_data(household_id: str, db: Session = Depends(get_db)):
    reset_embedding(household_id)

    # Anonymise DB record (do not delete — order history needed for RBI compliance)
    user = db.query(User).filter(User.household_id == household_id).first()
    if user:
        user.display_name = "Deleted User"
        user.dietary_flags = []
        user.preferred_ventures = []
        user.category_affinity = {}
        user.cross_venture_signals = {}
        db.commit()

    logger.info("Personalisation data deleted for household %s", household_id)

    return {
        "message": "All personalisation data deleted",
        "household_id": household_id,
        "note": "Embeddings and session history purged. DB record anonymised per RBI compliance.",
    }


@router.get(
    "/credits/{household_id}",
    summary="Get Discovery Credits summary for a creator",
    description=(
        "Returns credit balance, recent awards, expiring credits, and monthly cap status. "
        "Powers the creator dashboard credits widget in Flutter."
    ),
)
def get_credits(household_id: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.household_id == household_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Household not found.",
        )
    return get_credits_summary(str(user.id), db)


@router.get(
    "/leaderboard",
    summary="Monthly top creator leaderboard",
    description="Top creators by Discovery Credits awarded this month. Rank 1 gets Rs 500 bonus.",
)
def get_credits_leaderboard(
    limit: int = 10,
    db: Session = Depends(get_db),
):
    return {
        "leaderboard": get_leaderboard(db, limit=limit),
        "note": "Rank 1 earns monthly_top_creator bonus of Rs 500 at month end.",
    }


@router.get(
    "/cqs/{household_id}",
    summary="Get Creator Quality Score breakdown",
    description=(
        "Full CQS breakdown with all 5 components and current band. "
        "Powers the creator dashboard score widget."
    ),
)
def get_cqs_breakdown(household_id: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.household_id == household_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Household not found.",
        )
    return calculate_cqs(str(user.id), db)
