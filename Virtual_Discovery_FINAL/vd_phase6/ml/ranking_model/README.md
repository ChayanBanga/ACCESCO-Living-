# Ranking Model Weights

Drop trained tower weights here:
  - user_tower.pt   → user embedding tower (input: 16-dim, output: 64-dim)
  - video_tower.pt  → video embedding tower (input: 12-dim, output: 64-dim)

Until weights are present, the ranker uses a deterministic mock scorer
based on feature dot-product. The feed is fully functional in this mode.

Training: See ml/ranking_model/train.py (Phase 6 deliverable).
Architecture: Two-tower neural network (spec Section 4.1).
