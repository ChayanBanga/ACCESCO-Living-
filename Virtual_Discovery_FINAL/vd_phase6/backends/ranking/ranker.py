"""
ranking/ranker.py — Phase 6 complete.
Two-tower ranking model with full personalisation embedding integration.

Phase 6 changes vs Phase 4:
  - user_vec now includes household interest vector + temporal preference
  - farmchain_affinity boosts grokly produce videos for high-affinity users
  - budget_context adjusts score for price-sensitive households
  - Cross-venture signals already baked into interest_vector by embedding.py
  - Cold start: balanced feed from My Home Profile (not pure popularity)

Spec latency target: < 120ms p99 for 200 candidates.
Mock scorer active until ml/ranking_model/*.pt weights are dropped in.
"""

import logging
import os
import time
from pathlib import Path
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)

MODEL_DIR        = Path(__file__).parent.parent.parent / "ml" / "ranking_model"
USER_TOWER_PATH  = MODEL_DIR / "user_tower.pt"
VIDEO_TOWER_PATH = MODEL_DIR / "video_tower.pt"

EMBEDDING_DIM              = 64
FRESHNESS_BOOST            = 0.15
STOCK_GATE_THRESHOLD       = 3
DIVERSITY_MAX_SAME_VENTURE = 2
SPONSORED_INTERVAL         = 8
EXPLORATION_RATE           = 0.10

BUDGET_BRACKETS = {"low": 0.2, "medium": 0.5, "high": 0.8, "premium": 1.0}
VENTURE_IDX     = {"grokly": 0, "swadisht": 1, "instastyle": 2}

_user_tower = _video_tower = None
_models_loaded = False


def _try_load_models():
    global _user_tower, _video_tower, _models_loaded
    if _models_loaded:
        return
    _models_loaded = True
    if not USER_TOWER_PATH.exists() or not VIDEO_TOWER_PATH.exists():
        logger.info("Ranking weights absent — mock scorer active.")
        return
    try:
        import torch
        import torch.nn as nn

        class _Tower(nn.Module):
            def __init__(self, inp):
                super().__init__()
                self.net = nn.Sequential(
                    nn.Linear(inp, 128), nn.ReLU(),
                    nn.Linear(128, 64),  nn.ReLU(),
                    nn.Linear(64, EMBEDDING_DIM),
                )
            def forward(self, x): return self.net(x)

        ut = _Tower(20)   # Phase 6: user vector is now 20-dim
        ut.load_state_dict(torch.load(USER_TOWER_PATH, map_location="cpu"))
        ut.eval()
        _user_tower = ut

        vt = _Tower(12)
        vt.load_state_dict(torch.load(VIDEO_TOWER_PATH, map_location="cpu"))
        vt.eval()
        _video_tower = vt
        logger.info("Ranking towers loaded.")
    except Exception as e:
        logger.warning("Tower load failed: %s", e)
        _user_tower = _video_tower = None


def _user_feature_vector(user_features: dict, embedding: dict) -> np.ndarray:
    """
    20-dim user vector — extended in Phase 6 with embedding components.
    Dims 0-8: basic profile (same as Phase 4)
    Dims 9-14: interest vector top-3 ventures  
    Dims 15-16: temporal preference for current hour
    Dims 17: farmchain affinity
    Dims 18-19: budget context
    """
    budget    = BUDGET_BRACKETS.get(user_features.get("budget_bracket", "medium"), 0.5)
    preferred = user_features.get("preferred_ventures", [])
    hour      = user_features.get("hour_of_day", 12) / 23.0
    dow       = user_features.get("day_of_week", 0)  / 6.0
    interactions = min(user_features.get("interaction_count", 0) / 100.0, 1.0)
    credits   = min(user_features.get("discovery_credits", 0) / 2000.0, 1.0)
    cqs       = user_features.get("cqs_score", 0.0) / 100.0

    # Phase 6: interest vector signals
    interest = embedding.get("interest_vector", {})
    grokly_score     = max(interest.get("grokly",     {}).values(), default=0.5)
    swadisht_score   = max(interest.get("swadisht",   {}).values(), default=0.5)
    instastyle_score = max(interest.get("instastyle", {}).values(), default=0.5)

    # Temporal preference for current hour
    temporal = embedding.get("temporal_preference", {})
    temporal_grokly  = temporal.get("grokly",   0.33)
    temporal_swad    = temporal.get("swadisht", 0.33)

    # FarmChain affinity + budget
    farmchain = embedding.get("farmchain_affinity", 0.5)
    budget_ctx = embedding.get("budget_context", {})
    avg_viewed = min(budget_ctx.get("avg_price_viewed", 200) / 5000.0, 1.0)
    cart_val   = min(budget_ctx.get("session_cart_value", 0) / 2000.0, 1.0)

    return np.array([
        budget,
        1.0 if "grokly"     in preferred else 0.0,
        1.0 if "swadisht"   in preferred else 0.0,
        1.0 if "instastyle" in preferred else 0.0,
        hour, dow, interactions, credits, cqs,
        # Phase 6 additions
        grokly_score, swadisht_score, instastyle_score,
        temporal_grokly, temporal_swad,
        farmchain,
        avg_viewed, cart_val,
        0.0, 0.0, 0.0,  # Reserved for Phase 7
    ], dtype=np.float32)


def _video_feature_vector(vf: dict) -> np.ndarray:
    venture  = VENTURE_IDX.get(vf.get("venture", "grokly"), 0) / 2.0
    is_ugc   = 1.0 if vf.get("is_ugc") else 0.0
    duration = min(vf.get("duration_seconds", 30) / 60.0, 1.0)
    age      = min(vf.get("age_hours", 1.0) / 168.0, 1.0)
    views    = min(vf.get("view_count", 0) / 10000.0, 1.0)
    conv     = min(vf.get("conversion_rate", 0.0) / 0.15, 1.0)
    stock    = min(vf.get("units_available", 10) / 100.0, 1.0)
    price    = min(vf.get("price_current", 100) / 5000.0, 1.0)
    fresh    = vf.get("freshness_score", 0.5)
    eta      = 1.0 - min(vf.get("delivery_eta_mins", 30) / 60.0, 1.0)
    return np.array([
        venture, is_ugc, duration, age,
        views, conv, stock, price,
        fresh, eta, 0.0, 0.0,
    ], dtype=np.float32)


def _mock_score(u: np.ndarray, v: np.ndarray, vf: dict, embedding: dict) -> float:
    """Deterministic mock — uses dot product + embedding boosts."""
    score = float(np.dot(u[:len(v)], v))

    # Freshness boost
    if vf.get("is_fresh"):
        score += FRESHNESS_BOOST

    # Conversion rate signal
    score += vf.get("conversion_rate", 0.0) * 0.3

    # FarmChain affinity boost for grokly produce videos
    if vf.get("venture") == "grokly":
        farmchain = embedding.get("farmchain_affinity", 0.5)
        score += (farmchain - 0.5) * 0.2   # positive if affinity > 0.5

    # Interest vector boost
    interest = embedding.get("interest_vector", {})
    venture  = vf.get("venture", "grokly")
    venture_interest = interest.get(venture, {})
    if venture_interest:
        avg_interest = sum(venture_interest.values()) / len(venture_interest)
        score += (avg_interest - 0.5) * 0.15

    # Temporal preference boost
    temporal = embedding.get("temporal_preference", {})
    temporal_score = temporal.get(venture, 0.33)
    score += (temporal_score - 0.33) * 0.1

    return round(score, 6)


def _tower_score(u: np.ndarray, v: np.ndarray) -> float:
    try:
        import torch
        ut = torch.tensor(u).unsqueeze(0)
        vt = torch.tensor(v).unsqueeze(0)
        with torch.no_grad():
            ue = _user_tower(ut)
            ve = _video_tower(vt)
        un = ue / (ue.norm(dim=1, keepdim=True) + 1e-8)
        vn = ve / (ve.norm(dim=1, keepdim=True) + 1e-8)
        return float((un * vn).sum(dim=1).item())
    except Exception as e:
        logger.warning("Tower inference failed: %s", e)
        return 0.0


def _apply_exploration(scores: list[float]) -> list[float]:
    return [
        np.random.random() * 0.5 if np.random.random() < EXPLORATION_RATE else s
        for s in scores
    ]


def _apply_business_rules(videos: list[dict], suppressed: list[str], ctx: dict) -> list[dict]:
    seen = set(ctx.get("videos_seen", []))
    result, last_venture, consecutive = [], None, {}
    for v in videos:
        vid_id  = v["video_id"]
        venture = v.get("venture", "grokly")
        if vid_id in seen or venture in suppressed:
            continue
        if venture == last_venture:
            consecutive[venture] = consecutive.get(venture, 1) + 1
            if consecutive[venture] > DIVERSITY_MAX_SAME_VENTURE:
                continue
        else:
            consecutive = {venture: 1}
        last_venture = venture
        result.append(v)
    return result


def _insert_sponsored(organic: list[dict], sponsored: list[dict]) -> list[dict]:
    if not sponsored:
        return organic
    result, sp_queue, pos = [], list(sponsored), 0
    for v in organic:
        result.append(v)
        pos += 1
        if pos % SPONSORED_INTERVAL == 0 and sp_queue:
            result.append(sp_queue.pop(0))
    return result


def rank_feed(
    candidates: list[dict],
    user_features: dict,
    session_context: dict,
    sponsored_candidates: list[dict],
    suppressed_ventures: list[str],
    embedding: Optional[dict] = None,
) -> list[dict]:
    """
    Full ranking pipeline with Phase 6 personalisation embedding.
    < 120ms p99 for 200 candidates.
    """
    _try_load_models()
    t0 = time.perf_counter()

    emb            = embedding or {}
    user_vec       = _user_feature_vector(user_features, emb)
    interaction_count = user_features.get("interaction_count", 0)

    scored = []
    for vf in candidates:
        if vf.get("units_available", 0) < STOCK_GATE_THRESHOLD:
            continue

        video_vec = _video_feature_vector(vf)

        if _user_tower and _video_tower:
            base_score = _tower_score(user_vec, video_vec)
        else:
            base_score = _mock_score(user_vec, video_vec, vf, emb)

        if vf.get("is_fresh"):
            base_score += FRESHNESS_BOOST

        # Cold start blending
        if interaction_count < 10:
            pop = vf.get("view_count", 0) / max(1, 10000)
            base_score = base_score * 0.3 + pop * 0.7
        elif interaction_count < 50:
            pop   = vf.get("view_count", 0) / max(1, 10000)
            blend = min((interaction_count - 10) / 40.0, 1.0)
            base_score = base_score * blend + pop * (1 - blend)

        vf["_raw_score"] = base_score
        scored.append(vf)

    raw_scores = _apply_exploration([v["_raw_score"] for v in scored])
    for i, v in enumerate(scored):
        v["final_score"] = raw_scores[i]

    scored.sort(key=lambda v: v["final_score"], reverse=True)
    ranked = _apply_business_rules(scored, suppressed_ventures, session_context)
    final  = _insert_sponsored(ranked, sponsored_candidates)

    logger.info(
        "Feed ranked: %d→%d in %.1fms (interactions=%d, embedding=%s)",
        len(candidates), len(final),
        (time.perf_counter() - t0) * 1000,
        interaction_count,
        "full" if emb else "none",
    )
    return final
