"""
api/ugc.py — Phase 6 complete.
On moderation approval: awards video_selected credits and triggers CQS update.
Also sets quality_score on video record (not piggybacked on ranking_score).
"""
import os
import uuid
import logging
import tempfile
from pathlib import Path

from fastapi import APIRouter, Depends, UploadFile, File, Form, BackgroundTasks, Header
from sqlalchemy.orm import Session

from models.database import get_db
from models.video import Video
from models.user import User
from moderation.pipeline import run_moderation_pipeline, ModerationDecision
from services.cqs import update_cqs
from services.credits import award_credits

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/discovery", tags=["UGC Upload"])

UPLOAD_DIR = Path(tempfile.gettempdir()) / "accesco_ugc"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
MAX_FILE_SIZE = 150 * 1024 * 1024  # 150MB


def _save_video(contents: bytes, upload_id: str, filename: str) -> str:
    ext  = Path(filename).suffix or ".mp4"
    path = UPLOAD_DIR / f"{upload_id}{ext}"
    path.write_bytes(contents)
    return str(path)


def _run_pipeline_background(
    video_id: str, video_path: str, sku_id: str,
    caption: str, creator_id: str, db: Session,
) -> None:
    try:
        result = run_moderation_pipeline(
            video_id=video_id, video_path=video_path,
            sku_id=sku_id, caption=caption,
            creator_id=creator_id, db=db,
        )

        # Write quality_score to dedicated column (Phase 6)
        if result.quality_score is not None:
            video = db.query(Video).filter(Video.id == video_id).first()
            if video:
                video.quality_score = result.quality_score
                db.commit()

        # Award credits on approval
        if creator_id and result.final_decision == ModerationDecision.APPROVED:
            award_credits(
                user_id=creator_id,
                credit_type="video_selected",
                db=db,
                video_id=video_id,
                note="Video approved into Discovery feed",
            )

        # Update CQS
        if creator_id:
            update_cqs(creator_id=creator_id, db=db)

        logger.info("Moderation complete — video=%s decision=%s", video_id, result.final_decision.value)

    except Exception as exc:
        logger.exception("Background moderation failed for video=%s: %s", video_id, exc)
    finally:
        try:
            if os.path.exists(video_path):
                os.remove(video_path)
        except Exception:
            pass


@router.post("/upload")
async def upload_ugc(
    background_tasks: BackgroundTasks,
    order_id:   str        = Form(...),
    sku_id:     str        = Form(...),
    caption:    str        = Form(..., max_length=150),
    video_file: UploadFile = File(...),
    x_household_id: str   = Header(default=None, alias="X-Household-ID"),
    db: Session = Depends(get_db),
):
    """
    POST /api/v1/discovery/upload

    Upload a UGC product review video.
    Returns immediately with upload_id and pending status.
    Moderation pipeline runs in background — poll /api/v1/moderation/status/{video_id}.

    Form fields:
      video_file  — MP4 or MOV, max 150MB
      order_id    — links video to verified purchase
      sku_id      — product being reviewed
      caption     — max 150 chars

    Headers:
      X-Household-ID — household identifier
    """
    allowed = {"video/mp4", "video/quicktime"}
    if video_file.content_type not in allowed:
        return {"error": "Only MP4 and MOV files are allowed", "received": video_file.content_type}

    contents = await video_file.read()
    if len(contents) > MAX_FILE_SIZE:
        return {"error": "File exceeds 150MB limit"}

    upload_id = str(uuid.uuid4())

    # Resolve creator
    creator_id  = None
    current_cqs = 0.0
    cqs_band    = "explorer"
    if x_household_id:
        user = db.query(User).filter(User.household_id == x_household_id).first()
        if user:
            creator_id  = str(user.id)
            current_cqs = user.cqs_score or 0.0
            cqs_band    = user.cqs_band or "explorer"

    video_path = _save_video(contents, upload_id, video_file.filename or "video.mp4")

    # DB record
    new_video = Video(
        title=f"UGC Review - {sku_id}",
        duration_seconds=0,
        venture="grokly",
        sku_id=sku_id,
        caption=caption,
        creator_id=creator_id,
        is_ugc=True,
        moderation_status="pending",
    )
    db.add(new_video)
    db.commit()
    db.refresh(new_video)
    video_id = str(new_video.id)

    background_tasks.add_task(
        _run_pipeline_background,
        video_id=video_id, video_path=video_path,
        sku_id=sku_id, caption=caption,
        creator_id=creator_id or "", db=db,
    )

    logger.info("UGC upload received — upload_id=%s video_id=%s", upload_id, video_id)

    return {
        "upload_id":         upload_id,
        "video_id":          video_id,
        "moderation_status": "pending",
        "estimated_review_time_mins": 120,
        "message":           "Upload received. Moderation running in background.",
        "cqs_impact_preview": {
            "current_cqs":  round(current_cqs, 2),
            "current_band": cqs_band,
            "projected_cqs": round(min(current_cqs + 5.0, 100.0), 2),
        },
        "poll_status_url": f"/api/v1/moderation/status/{video_id}",
    }
