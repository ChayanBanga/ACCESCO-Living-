"""
api/moderation.py
Moderation status & human review queue endpoints for Accesco Virtual Discovery.

Endpoints:
  GET  /api/v1/moderation/status/{video_id}   — Creator polls for their video's status
  GET  /api/v1/moderation/queue               — Internal: human reviewer queue
  POST /api/v1/moderation/review/{video_id}   — Internal: human reviewer submits decision
  POST /api/v1/moderation/trigger/{video_id}  — Internal/dev: manually re-trigger pipeline

All "Internal" endpoints require X-Internal-Key header (set in .env).
In production these will sit behind an internal VPN — the header is a
lightweight guard for dev/staging.

Flutter/Next.js integration notes:
  - Creators should poll GET /status/{video_id} every 30s after upload
    until moderation_status is no longer "pending"
  - The creator_message field is always safe to display directly in the app UI
  - The stages[] array is internal detail — do not expose in the creator UI
"""

import logging
import os
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, BackgroundTasks, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from models.database import get_db
from models.video import Video
from models.user import User
from moderation.pipeline import (
    run_moderation_pipeline,
    ModerationDecision,
    PipelineResult,
    StageResult,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/moderation", tags=["Moderation"])

INTERNAL_KEY = os.getenv("INTERNAL_API_KEY", "dev-internal-key-change-in-prod")


# ---------------------------------------------------------------------------
# Auth guard for internal endpoints
# ---------------------------------------------------------------------------

def _require_internal_key(x_internal_key: str = Header(...)):
    if x_internal_key != INTERNAL_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid internal API key.",
        )


# ---------------------------------------------------------------------------
# Shared response schemas
# (Pydantic models — FastAPI auto-documents these in /docs)
# ---------------------------------------------------------------------------

class StageDetail(BaseModel):
    stage: str
    passed: bool
    decision: str
    code: Optional[str] = None
    reason: Optional[str] = None
    duration_ms: float

    class Config:
        from_attributes = True


class ModerationStatusResponse(BaseModel):
    """
    Returned to creators polling for their video's moderation result.
    Safe to pass directly to Flutter/Next.js — no internal-only fields.
    """
    video_id: str
    moderation_status: str                  # pending | approved | rejected | review
    creator_message: Optional[str] = None   # Human-readable, show in app
    requires_human_review: bool = False
    quality_score: Optional[float] = None   # 0–100, show in creator dashboard
    estimated_review_time_mins: int = 120   # Spec: 2hr SLA
    updated_at: Optional[datetime] = None


class ModerationDetailResponse(BaseModel):
    """
    Extended response for internal reviewer dashboard.
    Includes per-stage breakdown.
    """
    video_id: str
    moderation_status: str
    creator_message: Optional[str] = None
    requires_human_review: bool
    quality_score: Optional[float] = None
    safety_score: Optional[float] = None
    authenticity_score: Optional[float] = None
    stages: list[StageDetail] = []
    updated_at: Optional[datetime] = None


class QueueItem(BaseModel):
    """Single item in the human review queue."""
    video_id: str
    creator_id: str
    sku_id: str
    caption: Optional[str] = None
    review_reason: Optional[str] = None    # Which stage flagged it
    uploaded_at: Optional[datetime] = None
    hls_url: Optional[str] = None
    thumbnail_url: Optional[str] = None


class ReviewQueueResponse(BaseModel):
    items: list[QueueItem]
    total: int
    page: int
    page_size: int


class HumanReviewRequest(BaseModel):
    decision: str = Field(
        ...,
        description="approved | rejected | escalate",
        pattern="^(approved|rejected|escalate)$",
    )
    reason: Optional[str] = Field(
        None,
        max_length=500,
        description="Required if decision is rejected. Shown to creator.",
    )
    reviewer_id: str = Field(..., description="Internal reviewer identifier")


class HumanReviewResponse(BaseModel):
    video_id: str
    decision: str
    message: str


class TriggerPipelineResponse(BaseModel):
    video_id: str
    message: str
    pipeline_result: Optional[dict] = None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/status/{video_id}",
    response_model=ModerationStatusResponse,
    summary="Get moderation status for a video",
    description=(
        "Creators poll this endpoint after uploading a video. "
        "Poll every 30 seconds until moderation_status is no longer 'pending'. "
        "The creator_message field is safe to display directly in the app."
    ),
)
def get_moderation_status(
    video_id: str,
    db: Session = Depends(get_db),
) -> ModerationStatusResponse:
    video = db.query(Video).filter(Video.id == video_id).first()

    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Video {video_id} not found.",
        )

    # Map DB status to a creator-friendly message if no pipeline message stored
    status_messages = {
        "pending": "Your video is in the moderation queue. Check back in a few minutes.",
        "approved": "Your video has been approved and is now live in the Discovery feed!",
        "rejected": "Your video did not pass moderation. Please review the feedback below.",
        "review": (
            "Your video is under human review. "
            "You'll be notified within 2 hours."
        ),
    }

    return ModerationStatusResponse(
        video_id=str(video.id),
        moderation_status=video.moderation_status,
        creator_message=status_messages.get(video.moderation_status),
        requires_human_review=video.moderation_status == "review",
        # Quality score stored on the video record (set during pipeline)
        quality_score=getattr(video, "quality_score", None),
        estimated_review_time_mins=120,
        updated_at=video.updated_at,
    )


@router.get(
    "/queue",
    response_model=ReviewQueueResponse,
    summary="[Internal] Get human review queue",
    description=(
        "Returns all videos currently flagged for human review, "
        "ordered by upload time (oldest first — FIFO). "
        "Requires X-Internal-Key header."
    ),
    dependencies=[Depends(_require_internal_key)],
)
def get_review_queue(
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_db),
) -> ReviewQueueResponse:
    if page < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="page must be >= 1",
        )
    if page_size < 1 or page_size > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="page_size must be between 1 and 100",
        )

    offset = (page - 1) * page_size

    query = (
        db.query(Video)
        .filter(Video.moderation_status == "review")
        .order_by(Video.created_at.asc())   # FIFO — oldest flagged first
    )

    total = query.count()
    videos = query.offset(offset).limit(page_size).all()

    items = [
        QueueItem(
            video_id=str(v.id),
            creator_id=str(v.creator_id),
            sku_id=v.sku_id,
            caption=getattr(v, "caption", None),
            review_reason="Flagged by automated moderation — see stage detail",
            uploaded_at=v.created_at,
            hls_url=v.hls_url,
            thumbnail_url=v.thumbnail_url,
        )
        for v in videos
    ]

    return ReviewQueueResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.post(
    "/review/{video_id}",
    response_model=HumanReviewResponse,
    summary="[Internal] Submit human review decision",
    description=(
        "Human reviewer approves, rejects, or escalates a video from the review queue. "
        "Rejection reason is shown to the creator. "
        "Requires X-Internal-Key header."
    ),
    dependencies=[Depends(_require_internal_key)],
)
def submit_human_review(
    video_id: str,
    body: HumanReviewRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> HumanReviewResponse:
    video = db.query(Video).filter(Video.id == video_id).first()

    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Video {video_id} not found.",
        )

    if video.moderation_status != "review":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Video {video_id} is not in the review queue "
                f"(current status: {video.moderation_status}). "
                f"Only videos with status 'review' can be actioned here."
            ),
        )

    if body.decision == "rejected" and not body.reason:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A rejection reason is required so the creator knows what to fix.",
        )

    # Map reviewer decision to DB status
    decision_map = {
        "approved": "approved",
        "rejected": "rejected",
        "escalate": "review",   # Stays in review queue for senior reviewer
    }
    new_status = decision_map[body.decision]

    video.moderation_status = new_status
    video.updated_at = datetime.now(timezone.utc)
    db.commit()

    # Publish Kafka event in background — doesn't block the reviewer response
    background_tasks.add_task(
        _publish_human_review_event,
        video_id=video_id,
        decision=body.decision,
        reviewer_id=body.reviewer_id,
        reason=body.reason,
    )

    logger.info(
        "Human review submitted — video_id=%s decision=%s reviewer=%s",
        video_id,
        body.decision,
        body.reviewer_id,
    )

    messages = {
        "approved": "Video approved. It will appear in the Discovery feed shortly.",
        "rejected": "Video rejected. Creator has been notified with your feedback.",
        "escalate": "Video escalated. It remains in the queue for senior review.",
    }

    return HumanReviewResponse(
        video_id=video_id,
        decision=body.decision,
        message=messages[body.decision],
    )


@router.post(
    "/trigger/{video_id}",
    response_model=TriggerPipelineResponse,
    summary="[Internal/Dev] Re-trigger moderation pipeline for a video",
    description=(
        "Manually re-runs the full moderation pipeline for a video. "
        "Useful in dev for testing pipeline changes without re-uploading. "
        "In production, use only to reprocess videos after model updates. "
        "Requires X-Internal-Key header."
    ),
    dependencies=[Depends(_require_internal_key)],
)
def trigger_moderation(
    video_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> TriggerPipelineResponse:
    video = db.query(Video).filter(Video.id == video_id).first()

    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Video {video_id} not found.",
        )

    # In dev, video files are stored locally under uploads/
    # In production this will pull from S3/R2 to a temp path
    upload_dir = os.getenv("UPLOAD_DIR", "uploads")
    video_path = os.path.join(upload_dir, f"{video_id}.mp4")

    if not os.path.exists(video_path):
        # Try .mov extension as well
        video_path_mov = os.path.join(upload_dir, f"{video_id}.mov")
        if os.path.exists(video_path_mov):
            video_path = video_path_mov
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=(
                    f"Video file for {video_id} not found on disk. "
                    f"Checked: {video_path}. "
                    f"In production, ensure S3 fetch is wired before calling this endpoint."
                ),
            )

    # Reset to pending before re-running
    video.moderation_status = "pending"
    video.updated_at = datetime.now(timezone.utc)
    db.commit()

    # Run pipeline in background so the endpoint responds immediately
    background_tasks.add_task(
        _run_pipeline_background,
        video_id=video_id,
        video_path=video_path,
        sku_id=video.sku_id,
        caption=getattr(video, "caption", ""),
        creator_id=str(video.creator_id),
    )

    return TriggerPipelineResponse(
        video_id=video_id,
        message=(
            "Moderation pipeline triggered. "
            "Poll GET /api/v1/moderation/status/{video_id} for the result."
        ),
    )


# ---------------------------------------------------------------------------
# Background task helpers
# ---------------------------------------------------------------------------

def _run_pipeline_background(
    video_id: str,
    video_path: str,
    sku_id: str,
    caption: str,
    creator_id: str,
) -> None:
    """
    Runs the full moderation pipeline in a FastAPI background task.
    Gets its own DB session since background tasks run after response is sent.
    """
    from models.database import SessionLocal

    db = SessionLocal()
    try:
        run_moderation_pipeline(
            video_id=video_id,
            video_path=video_path,
            sku_id=sku_id,
            caption=caption,
            creator_id=creator_id,
            db=db,
        )
    except Exception as exc:
        logger.exception(
            "Background moderation pipeline failed for video %s: %s",
            video_id,
            exc,
        )
    finally:
        db.close()


def _publish_human_review_event(
    video_id: str,
    decision: str,
    reviewer_id: str,
    reason: Optional[str],
) -> None:
    """
    Publishes human review decision to Kafka topic: 'moderation-decisions'
    Same topic as pipeline — consumers distinguish by event_type field.
    Non-fatal if Kafka is unavailable.
    """
    try:
        from kafka import KafkaProducer
        import json

        producer = KafkaProducer(
            bootstrap_servers=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            acks="all",
            retries=3,
        )
        producer.send("moderation-decisions", value={
            "event_type": "human_review_decision",
            "video_id": video_id,
            "decision": decision,
            "reviewer_id": reviewer_id,
            "reason": reason,
        })
        producer.flush(timeout=5)
        producer.close()
        logger.info(
            "Human review Kafka event published — video_id=%s decision=%s",
            video_id, decision,
        )
    except Exception as exc:
        logger.error(
            "Kafka publish failed for human review event (non-fatal): %s", exc
        )
