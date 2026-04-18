import logging
import os
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, Header
from sqlalchemy.orm import Session

from models.database import get_db
from models.video import Video
from models.user import User
from models.inventory import Inventory

from ranking.feature_store import (
    get_user_features, get_video_features,
    get_session_context, get_suppressed_ventures, increment_interaction,
)
from ranking.ranker import rank_feed
from personalisation.embedding import get_full_embedding
from services.ad_auction import load_active_bids, run_auction, build_sponsored_video

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/discovery", tags=["Discovery Feed"])

CANDIDATE_POOL_SIZE = 200
IS_PRODUCTION = os.getenv("ENVIRONMENT", "development") == "production"


@router.get("/feed")
def get_feed(
    venture: str = Query(default="all"),
    limit:   int  = Query(default=10, le=20),
    cursor:  Optional[str] = Query(default=None),
    x_household_id:  Optional[str] = Header(default=None, alias="X-Household-ID"),
    x_dark_store_id: Optional[str] = Header(default="store_001", alias="X-Dark-Store-ID"),
    x_session_id:    Optional[str] = Header(default=None, alias="X-Session-ID"),
    db: Session = Depends(get_db),
):
    session_id   = x_session_id or str(uuid.uuid4())
    household_id = x_household_id or "anonymous"

    # Step 1: Features
    user_features       = get_user_features(household_id, db)
    session_context     = get_session_context(session_id)
    suppressed_ventures = get_suppressed_ventures(session_id)
    embedding           = get_full_embedding(household_id)

    # Step 2: Candidate fetch (FIXED: uses inventory)
    q = (
        db.query(Video)
        .join(Inventory, Video.sku_id == Inventory.sku_id)
        .filter(
            Video.moderation_status == "approved",
            Inventory.units_available > 3,
            Video.is_sponsored.isnot(True),
        )
    )

    if venture != "all":
        q = q.filter(Video.venture == venture)

    if cursor:
        try:
            q = q.filter(Video.id > uuid.UUID(cursor))
        except ValueError:
            pass

    candidate_videos = (
        q.order_by(Video.ranking_score.desc(), Video.created_at.desc())
         .limit(CANDIDATE_POOL_SIZE)
         .all()
    )

    interaction_count = user_features.get("interaction_count", 0)

    if not candidate_videos:
        return {
            "videos": [],
            "next_cursor": None,
            "count": 0,
            "session_id": session_id,
            "personalisation_level": _plevel(interaction_count),
        }

    # Step 3: Features
    candidate_features = [get_video_features(v) for v in candidate_videos]
    video_map   = {str(v.id): v for v in candidate_videos}
    creator_ids = {v.creator_id for v in candidate_videos if v.creator_id}
    creator_map = {}

    if creator_ids:
        creators = db.query(User).filter(User.id.in_(creator_ids)).all()
        creator_map = {str(u.id): u for u in creators}

    # Step 4: Ads
    sponsored_dicts = []
    active_bids = load_active_bids()

    if active_bids:
        n_slots = max(1, limit // 8)
        for result in run_auction(active_bids, user_features, venture, n_slots):
            sv = build_sponsored_video(result)
            if sv:
                sponsored_dicts.append(sv)

    # Step 5: Ranking
    ranked = rank_feed(
        candidates=candidate_features,
        user_features=user_features,
        session_context=session_context,
        sponsored_candidates=sponsored_dicts,
        suppressed_ventures=suppressed_ventures,
        embedding=embedding,
    )

    # ✅ CRITICAL FIX: fallback if ranker returns empty
    if not ranked:
        ranked = [
            {
                "video_id": str(v.id),
                "final_score": v.ranking_score or 0.5
            }
            for v in candidate_videos
        ]

    # Step 6: Pagination
    page = ranked[:limit]

    next_cursor = next(
        (item["video_id"] for item in reversed(page) if not item.get("is_sponsored")),
        None,
    )

    increment_interaction(household_id)

    # Step 7: Build response
    response_videos = []

    for item in page:
        vid_id = item.get("video_id", "")
        video  = video_map.get(vid_id)

        if item.get("is_sponsored"):
            entry = {
                "video_id": vid_id,
                "hls_url": item.get("hls_url", ""),
                "thumbnail_url": item.get("thumbnail_url", ""),
                "duration_seconds": item.get("duration_seconds", 60),
                "product": {},
                "creator": None,
                "is_sponsored": True,
                "sponsored_label": "SPONSORED",
                "venture": item.get("venture", venture),
            }

        elif video:
            creator_obj = creator_map.get(str(video.creator_id))

            entry = {
                "video_id": str(video.id),
                "hls_url": video.hls_url or "",
                "thumbnail_url": video.thumbnail_url or "",
                "duration_seconds": video.duration_seconds,
                "product": {
                    "sku_id": video.sku_id,
                    "name": video.product_name,
                    "price_current": video.price_current,
                    "farmchain_price": video.farmchain_price,
                    "units_available": video.units_available,
                    "delivery_eta_mins": video.delivery_eta_mins,
                    "freshness_score": video.freshness_score,
                },
                "creator": {
                    "id": video.creator_id or "",
                    "display_name": creator_obj.display_name if creator_obj else "",
                    "cqs_band": creator_obj.cqs_band if creator_obj else "explorer",
                },
                "is_sponsored": False,
                "sponsored_label": None,
                "venture": video.venture,
            }
        else:
            continue

        if not IS_PRODUCTION:
            entry["ranking_score"] = round(item.get("final_score", 0.0), 6)

        response_videos.append(entry)

    return {
        "videos": response_videos,
        "next_cursor": next_cursor,
        "count": len(response_videos),
        "session_id": session_id,
        "personalisation_level": _plevel(interaction_count),
    }


def _plevel(n: int) -> str:
    if n < 10:
        return "cold_start"
    if n < 50:
        return "partial"
    return "full"

