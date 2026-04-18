"""
pipeline.py
UGC Moderation Orchestrator for Accesco Virtual Discovery.

Chains all moderation stages in the correct order as defined in the tech spec
(Section 4.2). Each stage is independent — a failure short-circuits the
pipeline and returns immediately so we don't waste compute on already-failed
videos.

Stage order (spec-defined):
  1. Duration Compliance     — hard reject, no human review
  2. Visual Safety Check     — hard reject, no human review
  3. Audio Moderation        — hard reject, no human review (stub — Phase 3)
  4. Quality Score           — returned to user with tips, no human review
  5. Product Authenticity    — flagged for human review
  6. Misleading Claim Check  — flagged for human review (stub — Phase 3)
  7. Brand Safety Check      — flagged for human review (stub — Phase 3)

Final decision written back to the videos table in PostgreSQL.
Kafka event published on every final decision (view in events pipeline).

Usage:
    from moderation.pipeline import run_moderation_pipeline
    result = await run_moderation_pipeline(video_id, video_path, sku_id, caption)
"""

import logging
import time
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Optional

import cv2
from sqlalchemy.orm import Session

from moderation.quality_check import run_quality_check, QualityResult
from moderation.safety_check import run_safety_check, SafetyResult
from moderation.authenticity import run_authenticity_check, AuthenticityResult

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Enums & constants
# ---------------------------------------------------------------------------

class ModerationDecision(str, Enum):
    APPROVED  = "approved"
    REJECTED  = "rejected"
    REVIEW    = "review"    # Human review queue
    PENDING   = "pending"   # Not yet processed


class RejectionCode(str, Enum):
    DURATION_TOO_SHORT   = "DURATION_TOO_SHORT"
    DURATION_TOO_LONG    = "DURATION_TOO_LONG"
    UNSAFE_CONTENT       = "UNSAFE_CONTENT"
    TOXIC_AUDIO          = "TOXIC_AUDIO"
    LOW_QUALITY          = "LOW_QUALITY"
    CORRUPT_FILE         = "CORRUPT_FILE"


class ReviewCode(str, Enum):
    AUTHENTICITY_MISMATCH  = "AUTHENTICITY_MISMATCH"
    MISLEADING_CLAIM       = "MISLEADING_CLAIM"
    BRAND_SAFETY           = "BRAND_SAFETY"


# Spec Section 1.2 — hard limits
DURATION_MIN_SECONDS = 8
DURATION_MAX_SECONDS = 60


# ---------------------------------------------------------------------------
# Result dataclass
# ---------------------------------------------------------------------------

@dataclass
class StageResult:
    """Captures the outcome of a single moderation stage."""
    stage: str
    passed: bool
    decision: ModerationDecision
    code: Optional[str] = None          # RejectionCode or ReviewCode value
    reason: Optional[str] = None        # Human-readable, returned to creator
    detail: Optional[dict] = None       # Full scoring detail for internal logs
    duration_ms: float = 0.0


@dataclass
class PipelineResult:
    """
    Final result returned to the API layer.
    All stage results are retained for audit logging and the
    moderation status endpoint.
    """
    video_id: str
    final_decision: ModerationDecision
    rejection_code: Optional[str] = None
    creator_message: Optional[str] = None   # Shown to the uploader
    requires_human_review: bool = False
    stages: list[StageResult] = field(default_factory=list)
    total_duration_ms: float = 0.0

    # Per-stage scores exposed for the moderation status API
    quality_score: Optional[float] = None
    safety_score: Optional[float] = None
    authenticity_score: Optional[float] = None

    # CQS component scores (written to user record after pipeline)
    cqs_technical_quality: Optional[float] = None
    cqs_authenticity: Optional[float] = None


# ---------------------------------------------------------------------------
# Individual stage runners
# ---------------------------------------------------------------------------

def _check_duration(video_path: str) -> StageResult:
    """
    Stage 1 — Duration Compliance.
    Uses OpenCV to read frame count and FPS — no FFmpeg dependency here.
    Hard reject outside 8s–60s range. No human review.
    """
    start = time.perf_counter()
    try:
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = cap.get(cv2.CAP_PROP_FRAME_COUNT)
        cap.release()

        if fps <= 0 or total_frames <= 0:
            return StageResult(
                stage="duration_compliance",
                passed=False,
                decision=ModerationDecision.REJECTED,
                code=RejectionCode.CORRUPT_FILE.value,
                reason="Could not read video metadata. The file may be corrupt or unsupported.",
                duration_ms=(time.perf_counter() - start) * 1000,
            )

        duration_seconds = total_frames / fps

        if duration_seconds < DURATION_MIN_SECONDS:
            return StageResult(
                stage="duration_compliance",
                passed=False,
                decision=ModerationDecision.REJECTED,
                code=RejectionCode.DURATION_TOO_SHORT.value,
                reason=(
                    f"Video is {duration_seconds:.1f}s — minimum is {DURATION_MIN_SECONDS}s. "
                    f"Please record a longer clip showing the full product."
                ),
                detail={"duration_seconds": round(duration_seconds, 2)},
                duration_ms=(time.perf_counter() - start) * 1000,
            )

        if duration_seconds > DURATION_MAX_SECONDS:
            return StageResult(
                stage="duration_compliance",
                passed=False,
                decision=ModerationDecision.REJECTED,
                code=RejectionCode.DURATION_TOO_LONG.value,
                reason=(
                    f"Video is {duration_seconds:.1f}s — maximum is {DURATION_MAX_SECONDS}s. "
                    f"Please trim your video before uploading."
                ),
                detail={"duration_seconds": round(duration_seconds, 2)},
                duration_ms=(time.perf_counter() - start) * 1000,
            )

        return StageResult(
            stage="duration_compliance",
            passed=True,
            decision=ModerationDecision.APPROVED,
            detail={"duration_seconds": round(duration_seconds, 2)},
            duration_ms=(time.perf_counter() - start) * 1000,
        )

    except Exception as exc:
        logger.exception("Duration check failed with unexpected error: %s", exc)
        return StageResult(
            stage="duration_compliance",
            passed=False,
            decision=ModerationDecision.REJECTED,
            code=RejectionCode.CORRUPT_FILE.value,
            reason="Video could not be processed. Please re-upload.",
            duration_ms=(time.perf_counter() - start) * 1000,
        )


def _check_safety(video_path: str) -> StageResult:
    """
    Stage 2 — Visual Safety Check.
    Wraps safety_check.run_safety_check(). Hard reject, no human review.
    """
    start = time.perf_counter()
    try:
        result: SafetyResult = run_safety_check(video_path)
        return StageResult(
            stage="visual_safety",
            passed=result.passed,
            decision=(
                ModerationDecision.APPROVED if result.passed
                else ModerationDecision.REJECTED
            ),
            code=None if result.passed else RejectionCode.UNSAFE_CONTENT.value,
            reason=result.reason,
            detail={
                "max_unsafe_confidence": result.max_unsafe_confidence,
                "flagged_frame_count": result.flagged_frame_count,
                "total_frames_checked": result.total_frames_checked,
            },
            duration_ms=(time.perf_counter() - start) * 1000,
        )
    except Exception as exc:
        logger.exception("Safety check failed with unexpected error: %s", exc)
        # Fail safe — reject if safety check itself crashes
        return StageResult(
            stage="visual_safety",
            passed=False,
            decision=ModerationDecision.REJECTED,
            code=RejectionCode.UNSAFE_CONTENT.value,
            reason="Safety check could not complete. Please re-upload.",
            duration_ms=(time.perf_counter() - start) * 1000,
        )


def _check_audio_moderation(video_path: str, caption: str) -> StageResult:
    """
    Stage 3 — Audio Moderation (stub).
    Full implementation in Phase 3 sprint 2:
      - Whisper speech-to-text transcription
      - Detoxify / custom toxicity classifier on transcript
      - NLP misleading claim detection on caption + transcript

    Currently: passes all videos so the pipeline works end-to-end.
    Toxicity threshold from spec: score < 0.3 = pass.
    """
    start = time.perf_counter()
    # TODO: integrate Whisper + toxicity classifier
    return StageResult(
        stage="audio_moderation",
        passed=True,
        decision=ModerationDecision.APPROVED,
        reason=None,
        detail={"stub": True, "toxicity_score": 0.0},
        duration_ms=(time.perf_counter() - start) * 1000,
    )


def _check_quality(video_path: str) -> tuple[StageResult, QualityResult]:
    """
    Stage 4 — Quality Score.
    Wraps quality_check.run_quality_check().
    On fail: returned to user with improvement tips. No human review.
    """
    start = time.perf_counter()
    try:
        result: QualityResult = run_quality_check(video_path)
        stage = StageResult(
            stage="quality_score",
            passed=result.passed,
            decision=(
                ModerationDecision.APPROVED if result.passed
                else ModerationDecision.REJECTED
            ),
            code=None if result.passed else RejectionCode.LOW_QUALITY.value,
            reason=result.failure_reason,
            detail={
                "composite_score": result.composite_score,
                "blur_score": result.blur_score,
                "lighting_score": result.lighting_score,
                "stabilisation_score": result.stabilisation_score,
                "audio_clarity_score": result.audio_clarity_score,
            },
            duration_ms=(time.perf_counter() - start) * 1000,
        )
        return stage, result
    except Exception as exc:
        logger.exception("Quality check failed with unexpected error: %s", exc)
        dummy_result = QualityResult(
            passed=False,
            composite_score=0.0,
            blur_score=0.0,
            lighting_score=0.0,
            stabilisation_score=0.0,
            audio_clarity_score=0.0,
            failure_reason="Quality check could not complete. Please re-upload.",
        )
        return StageResult(
            stage="quality_score",
            passed=False,
            decision=ModerationDecision.REJECTED,
            code=RejectionCode.LOW_QUALITY.value,
            reason="Quality check could not complete. Please re-upload.",
            duration_ms=(time.perf_counter() - start) * 1000,
        ), dummy_result


def _check_authenticity(
    video_path: str,
    sku_id: str,
    reference_image_url: Optional[str],
) -> tuple[StageResult, AuthenticityResult]:
    """
    Stage 5 — Product Authenticity.
    Wraps authenticity.run_authenticity_check().
    On fail: flagged for human review (not hard rejected).
    """
    start = time.perf_counter()
    try:
        result: AuthenticityResult = run_authenticity_check(
            video_path=video_path,
            sku_id=sku_id,
            reference_image_url=reference_image_url,
        )
        decision = (
            ModerationDecision.APPROVED if result.passed
            else ModerationDecision.REVIEW
        )
        stage = StageResult(
            stage="product_authenticity",
            passed=result.passed,
            decision=decision,
            code=None if result.passed else ReviewCode.AUTHENTICITY_MISMATCH.value,
            reason=result.reason,
            detail={
                "match_score": result.match_score,
                "method_used": result.method_used,
                "sku_id": sku_id,
            },
            duration_ms=(time.perf_counter() - start) * 1000,
        )
        return stage, result
    except Exception as exc:
        logger.exception("Authenticity check failed with unexpected error: %s", exc)
        dummy_result = AuthenticityResult(
            passed=False,
            match_score=0.0,
            action="review",
            reason="Authenticity check could not complete — flagged for human review.",
            method_used="error",
        )
        return StageResult(
            stage="product_authenticity",
            passed=False,
            decision=ModerationDecision.REVIEW,
            code=ReviewCode.AUTHENTICITY_MISMATCH.value,
            reason="Authenticity check could not complete — flagged for human review.",
            duration_ms=(time.perf_counter() - start) * 1000,
        ), dummy_result


def _check_misleading_claims(caption: str) -> StageResult:
    """
    Stage 6 — Misleading Claim Detection (stub).
    Full implementation in Phase 3 sprint 2:
      - NLP on caption + audio transcript
      - Flag exaggerated health/price claims
      - Spec threshold: claim confidence < 0.5 = pass

    Currently: passes all videos.
    """
    start = time.perf_counter()
    # TODO: integrate NLP claim classifier
    return StageResult(
        stage="misleading_claims",
        passed=True,
        decision=ModerationDecision.APPROVED,
        detail={"stub": True, "claim_confidence": 0.0},
        duration_ms=(time.perf_counter() - start) * 1000,
    )


def _check_brand_safety(video_path: str) -> StageResult:
    """
    Stage 7 — Brand Safety (stub).
    Full implementation in Phase 3 sprint 2:
      - Logo detection model (YOLOv8 or AWS Rekognition)
      - Flag if competitor logo confidence > 0.6
      - Spec threshold: confidence < 0.6 = pass

    Currently: passes all videos.
    """
    start = time.perf_counter()
    # TODO: integrate logo detection model
    return StageResult(
        stage="brand_safety",
        passed=True,
        decision=ModerationDecision.APPROVED,
        detail={"stub": True, "competitor_logo_confidence": 0.0},
        duration_ms=(time.perf_counter() - start) * 1000,
    )


# ---------------------------------------------------------------------------
# DB write-back helpers
# ---------------------------------------------------------------------------

def _update_video_moderation_status(
    db: Session,
    video_id: str,
    result: PipelineResult,
) -> None:
    """
    Write the final moderation decision back to the videos table.
    Imported here to avoid circular imports with models.
    """
    from models.video import Video

    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        logger.warning("Video %s not found in DB during moderation write-back", video_id)
        return

    video.moderation_status = result.final_decision.value
    db.commit()
    logger.info(
        "Video %s moderation status updated to %s",
        video_id,
        result.final_decision.value,
    )


def _update_user_cqs_components(
    db: Session,
    creator_id: str,
    result: PipelineResult,
) -> None:
    """
    Update the technical_quality and authenticity components of CQS
    on the user record after each moderation run.
    Full CQS calculation (engagement, consistency, trust) happens
    in a separate scheduled job — this just updates the per-upload components.
    """
    from models.user import User

    if result.cqs_technical_quality is None and result.cqs_authenticity is None:
        return

    user = db.query(User).filter(User.id == creator_id).first()
    if not user:
        logger.warning("User %s not found during CQS update", creator_id)
        return

    # Increment upload counters
    user.total_videos_uploaded = (user.total_videos_uploaded or 0) + 1
    if result.final_decision == ModerationDecision.APPROVED:
        user.total_videos_approved = (user.total_videos_approved or 0) + 1

    db.commit()
    logger.info("CQS components updated for user %s", creator_id)


# ---------------------------------------------------------------------------
# Kafka event publisher
# ---------------------------------------------------------------------------

def _publish_moderation_event(result: PipelineResult) -> None:
    """
    Publish the final moderation decision to Kafka topic:
    'moderation-decisions'

    Consumed by:
      - CQS scoring service (updates creator score)
      - Discovery Credits ledger (triggers credit award on approval)
      - Analytics pipeline (moderation funnel metrics)
    """
    try:
        from kafka import KafkaProducer
        import json
        import os

        producer = KafkaProducer(
            bootstrap_servers=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            # Production settings — keeps producer lightweight
            acks="all",             # Wait for all replicas — durability over speed
            retries=3,
            linger_ms=5,            # Small batching window
        )

        payload = {
            "event_type": "moderation_decision",
            "video_id": result.video_id,
            "final_decision": result.final_decision.value,
            "rejection_code": result.rejection_code,
            "requires_human_review": result.requires_human_review,
            "quality_score": result.quality_score,
            "safety_score": result.safety_score,
            "authenticity_score": result.authenticity_score,
            "stage_count": len(result.stages),
            "total_duration_ms": result.total_duration_ms,
        }

        producer.send("moderation-decisions", value=payload)
        producer.flush(timeout=5)
        producer.close()

        logger.info(
            "Kafka moderation event published for video %s — decision: %s",
            result.video_id,
            result.final_decision.value,
        )

    except Exception as exc:
        # Kafka failure must NEVER block the moderation result
        # Log and continue — the DB write-back is the source of truth
        logger.error(
            "Kafka publish failed for video %s (non-fatal): %s",
            result.video_id,
            exc,
        )


# ---------------------------------------------------------------------------
# Main pipeline entry point
# ---------------------------------------------------------------------------

def run_moderation_pipeline(
    video_id: str,
    video_path: str,
    sku_id: str,
    caption: str,
    creator_id: str,
    db: Session,
    reference_image_url: Optional[str] = None,
) -> PipelineResult:
    """
    Main entry point. Called by the UGC upload endpoint after saving
    the video file to disk/S3.

    Args:
        video_id:             UUID of the video record in the videos table
        video_path:           Local path to the uploaded video file
        sku_id:               SKU being reviewed (for authenticity check)
        caption:              Creator's caption text (for claim + audio checks)
        creator_id:           UUID of the uploading user
        db:                   Active SQLAlchemy session
        reference_image_url:  Product reference image URL from inventory (optional)

    Returns:
        PipelineResult with final decision and all stage details
    """
    pipeline_start = time.perf_counter()
    stages: list[StageResult] = []
    quality_result: Optional[QualityResult] = None
    authenticity_result: Optional[AuthenticityResult] = None

    logger.info(
        "Moderation pipeline started — video_id=%s sku_id=%s creator_id=%s",
        video_id, sku_id, creator_id,
    )

    # ------------------------------------------------------------------
    # Stage 1: Duration Compliance — hard reject
    # ------------------------------------------------------------------
    stage = _check_duration(video_path)
    stages.append(stage)
    if not stage.passed:
        result = PipelineResult(
            video_id=video_id,
            final_decision=ModerationDecision.REJECTED,
            rejection_code=stage.code,
            creator_message=stage.reason,
            requires_human_review=False,
            stages=stages,
            total_duration_ms=(time.perf_counter() - pipeline_start) * 1000,
        )
        _update_video_moderation_status(db, video_id, result)
        _update_user_cqs_components(db, creator_id, result)
        _publish_moderation_event(result)
        logger.info("Pipeline short-circuited at duration_compliance for video %s", video_id)
        return result

    # ------------------------------------------------------------------
    # Stage 2: Visual Safety — hard reject
    # ------------------------------------------------------------------
    stage = _check_safety(video_path)
    stages.append(stage)
    if not stage.passed:
        result = PipelineResult(
            video_id=video_id,
            final_decision=ModerationDecision.REJECTED,
            rejection_code=stage.code,
            creator_message=(
                "Your video was automatically removed due to content policy. "
                "Please review our community guidelines before re-uploading."
            ),
            requires_human_review=False,
            stages=stages,
            safety_score=stage.detail.get("max_unsafe_confidence") if stage.detail else None,
            total_duration_ms=(time.perf_counter() - pipeline_start) * 1000,
        )
        _update_video_moderation_status(db, video_id, result)
        _update_user_cqs_components(db, creator_id, result)
        _publish_moderation_event(result)
        logger.info("Pipeline short-circuited at visual_safety for video %s", video_id)
        return result

    safety_score = stage.detail.get("max_unsafe_confidence") if stage.detail else None

    # ------------------------------------------------------------------
    # Stage 3: Audio Moderation — hard reject (stub)
    # ------------------------------------------------------------------
    stage = _check_audio_moderation(video_path, caption)
    stages.append(stage)
    if not stage.passed:
        result = PipelineResult(
            video_id=video_id,
            final_decision=ModerationDecision.REJECTED,
            rejection_code=RejectionCode.TOXIC_AUDIO.value,
            creator_message=stage.reason,
            requires_human_review=False,
            stages=stages,
            safety_score=safety_score,
            total_duration_ms=(time.perf_counter() - pipeline_start) * 1000,
        )
        _update_video_moderation_status(db, video_id, result)
        _update_user_cqs_components(db, creator_id, result)
        _publish_moderation_event(result)
        return result

    # ------------------------------------------------------------------
    # Stage 4: Quality Score — returned to user with tips
    # ------------------------------------------------------------------
    stage, quality_result = _check_quality(video_path)
    stages.append(stage)
    if not stage.passed:
        result = PipelineResult(
            video_id=video_id,
            final_decision=ModerationDecision.REJECTED,
            rejection_code=stage.code,
            creator_message=(
                f"Your video quality score is {quality_result.composite_score}/100 "
                f"(minimum 60). Tips: {stage.reason}"
            ),
            requires_human_review=False,
            stages=stages,
            quality_score=quality_result.composite_score,
            safety_score=safety_score,
            cqs_technical_quality=quality_result.composite_score,
            total_duration_ms=(time.perf_counter() - pipeline_start) * 1000,
        )
        _update_video_moderation_status(db, video_id, result)
        _update_user_cqs_components(db, creator_id, result)
        _publish_moderation_event(result)
        logger.info("Pipeline short-circuited at quality_score for video %s", video_id)
        return result

    # ------------------------------------------------------------------
    # Stage 5: Product Authenticity — flag for review, don't hard reject
    # ------------------------------------------------------------------
    stage, authenticity_result = _check_authenticity(
        video_path, sku_id, reference_image_url
    )
    stages.append(stage)
    needs_review = not stage.passed  # Authenticity fail → human review, not rejection

    # ------------------------------------------------------------------
    # Stage 6: Misleading Claims — flag for review (stub)
    # ------------------------------------------------------------------
    stage = _check_misleading_claims(caption)
    stages.append(stage)
    if not stage.passed:
        needs_review = True

    # ------------------------------------------------------------------
    # Stage 7: Brand Safety — flag for review (stub)
    # ------------------------------------------------------------------
    stage = _check_brand_safety(video_path)
    stages.append(stage)
    if not stage.passed:
        needs_review = True

    # ------------------------------------------------------------------
    # Final decision
    # ------------------------------------------------------------------
    total_ms = (time.perf_counter() - pipeline_start) * 1000

    if needs_review:
        # Collect all review reasons for the human reviewer
        review_reasons = [
            s.reason for s in stages
            if not s.passed and s.decision == ModerationDecision.REVIEW and s.reason
        ]
        final_decision = ModerationDecision.REVIEW
        creator_message = (
            "Your video has been sent for human review. "
            "You'll be notified within 2 hours. "
            "Discovery Credits will be awarded if approved."
        )
    else:
        final_decision = ModerationDecision.APPROVED
        creator_message = (
            "Your video has been approved and will appear in the Discovery feed shortly. "
            "Discovery Credits have been queued for your account."
        )

    result = PipelineResult(
        video_id=video_id,
        final_decision=final_decision,
        rejection_code=None,
        creator_message=creator_message,
        requires_human_review=needs_review,
        stages=stages,
        total_duration_ms=total_ms,
        quality_score=quality_result.composite_score if quality_result else None,
        safety_score=safety_score,
        authenticity_score=authenticity_result.match_score if authenticity_result else None,
        cqs_technical_quality=quality_result.composite_score if quality_result else None,
        cqs_authenticity=authenticity_result.match_score if authenticity_result else None,
    )

    _update_video_moderation_status(db, video_id, result)
    _update_user_cqs_components(db, creator_id, result)
    _publish_moderation_event(result)

    logger.info(
        "Moderation pipeline complete — video_id=%s decision=%s in %.0fms",
        video_id,
        final_decision.value,
        total_ms,
    )

    return result