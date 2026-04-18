"""
api/moderation.py
Moderation status endpoint for Virtual Discovery UGC.

Endpoints:
  GET  /api/v1/moderation/status/{video_id}   — check moderation status of a video
  POST /api/v1/moderation/review/{video_id}   — human reviewer decision (approve/reject)
"""

import logging
from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from models.database import SessionLocal
from models.video import Video

logger = logging.getLogger(__name__)
router = APIRouter()


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class ModerationStatusResponse(BaseModel):
    video_id: str
    moderation_status: str          # pending | approved | rejected | review
    title: str | None
    sku_id: str | None
    failure_reason: str | None      # populated if rejected
    estimated_review_time_mins: int | None  # populated if status = review


class HumanReviewRequest(BaseModel):
    decision: str                   # "approved" | "rejected"
    reason: str | None = None       # required if rejecting


class HumanReviewResponse(BaseModel):
    video_id: str
    previous_status: str
    new_status: str
    reviewed_by: str


# ---------------------------------------------------------------------------
# GET /api/v1/moderation/status/{video_id}
# ---------------------------------------------------------------------------

@router.get("/status/{video_id}", response_model=ModerationStatusResponse)
def get_moderation_status(video_id: str):
    """
    Returns the current moderation status of a UGC video.
    Called by the app to show creators their video's review state.
    """
    db: Session = SessionLocal()
    try:
        video = db.query(Video).filter(Video.id == video_id).first()
        if not video:
            raise HTTPException(status_code=404, detail="Video not found")

        estimated_review_time = None
        if video.moderation_status == "review":
            estimated_review_time = 120   # 2 hour SLA from spec

        return ModerationStatusResponse(
            video_id=str(video.id),
            moderation_status=video.moderation_status,
            title=video.title,
            sku_id=video.sku_id,
            failure_reason=None,          # Store rejection reason in DB in Phase 3+
            estimated_review_time_mins=estimated_review_time,
        )
    finally:
        db.close()


# ---------------------------------------------------------------------------
# POST /api/v1/moderation/review/{video_id}
# ---------------------------------------------------------------------------

@router.post("/review/{video_id}", response_model=HumanReviewResponse)
def submit_human_review(
    video_id: str,
    body: HumanReviewRequest,
    reviewer_id: str = Header(default="anonymous", alias="X-Reviewer-ID"),
):
    """
    Human reviewer submits their decision on a flagged video.
    Only videos with moderation_status = 'review' or 'pending' can be actioned.
    """
    if body.decision not in ("approved", "rejected"):
        raise HTTPException(
            status_code=400,
            detail="decision must be 'approved' or 'rejected'"
        )

    if body.decision == "rejected" and not body.reason:
        raise HTTPException(
            status_code=400,
            detail="reason is required when rejecting a video"
        )

    db: Session = SessionLocal()
    try:
        video = db.query(Video).filter(Video.id == video_id).first()
        if not video:
            raise HTTPException(status_code=404, detail="Video not found")

        if video.moderation_status not in ("review", "pending"):
            raise HTTPException(
                status_code=409,
                detail=f"Video is already '{video.moderation_status}' — cannot re-review"
            )

        previous_status = video.moderation_status
        video.moderation_status = body.decision
        db.commit()

        logger.info(
            f"Human review: video {video_id} → {body.decision} "
            f"by reviewer {reviewer_id}. Reason: {body.reason}"
        )

        return HumanReviewResponse(
            video_id=video_id,
            previous_status=previous_status,
            new_status=body.decision,
            reviewed_by=reviewer_id,
        )
    finally:
        db.close()