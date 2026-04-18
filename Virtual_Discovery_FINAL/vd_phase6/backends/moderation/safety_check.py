"""
safety_check.py
Frame-level visual safety classifier.
Spec: block if unsafe confidence > 0.85.

Architecture: lightweight MobileNetV3 fine-tuned binary classifier
(safe / unsafe). In dev/local mode runs a deterministic mock so the
pipeline works end-to-end without a GPU or trained weights.
Swap _load_model() for real weights in production.
"""

import os
import cv2
import numpy as np
from dataclasses import dataclass
from pathlib import Path

import torch
import torch.nn as nn
from torchvision import transforms, models


SAFETY_BLOCK_THRESHOLD = 0.85
MODEL_PATH = Path(__file__).parent.parent.parent / "ml" / "moderation_model" / "safety_classifier.pt"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# Frames to sample for safety check — more than quality check since
# a single bad frame is enough to block
SAFETY_FRAME_SAMPLE = 30


@dataclass
class SafetyResult:
    passed: bool                    # True = safe to proceed
    max_unsafe_confidence: float    # Highest unsafe score across all frames
    flagged_frame_count: int        # Frames that exceeded threshold
    total_frames_checked: int
    action: str                     # "approved" | "rejected"
    reason: str | None


def _build_model() -> nn.Module:
    """MobileNetV3-Small binary classifier: output[0] = unsafe probability."""
    model = models.mobilenet_v3_small(weights=None)
    # Replace classifier head for binary output
    model.classifier[3] = nn.Linear(model.classifier[3].in_features, 2)
    return model


def _load_model() -> nn.Module | None:
    """
    Load trained weights if available.
    Returns None if weights file doesn't exist yet (dev mode).
    """
    if not MODEL_PATH.exists():
        return None
    try:
        model = _build_model()
        model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
        model.eval()
        model.to(DEVICE)
        return model
    except Exception:
        return None


# Module-level model load — happens once on import
_model = _load_model()

_transform = transforms.Compose([
    transforms.ToPILImage(),
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                         std=[0.229, 0.224, 0.225]),
])


def _classify_frame_mock(frame: np.ndarray) -> float:
    """
    Deterministic mock for dev — returns low unsafe score.
    Replace with real inference once weights are trained.
    """
    # Use image statistics as a proxy (not a real classifier)
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    mean_val = float(np.mean(gray))
    # Extremely dark or extremely bright frames get a slightly higher score
    # This is purely to make the mock non-trivial for testing
    if mean_val < 15 or mean_val > 245:
        return 0.30
    return 0.05


def _classify_frame_model(frame: np.ndarray, model: nn.Module) -> float:
    """Run real model inference on a single frame."""
    tensor = _transform(frame).unsqueeze(0).to(DEVICE)
    with torch.no_grad():
        logits = model(tensor)
        probs = torch.softmax(logits, dim=1)
        unsafe_prob = probs[0][1].item()   # index 1 = unsafe class
    return float(unsafe_prob)


def _sample_frames(video_path: str, max_frames: int = SAFETY_FRAME_SAMPLE) -> list[np.ndarray]:
    cap = cv2.VideoCapture(video_path)
    frames = []
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total <= 0:
        cap.release()
        return frames
    indices = np.linspace(0, total - 1, min(max_frames, total), dtype=int)
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, int(idx))
        ret, frame = cap.read()
        if ret:
            frames.append(frame)
    cap.release()
    return frames


def run_safety_check(video_path: str) -> SafetyResult:
    """
    Main entry point. Runs frame-level safety classification.
    Uses real model if weights are loaded, mock otherwise.
    """
    frames = _sample_frames(video_path)

    if not frames:
        return SafetyResult(
            passed=False,
            max_unsafe_confidence=1.0,
            flagged_frame_count=0,
            total_frames_checked=0,
            action="rejected",
            reason="Could not read video frames for safety check.",
        )

    classify_fn = (
        lambda f: _classify_frame_model(f, _model)
        if _model is not None
        else _classify_frame_mock(f)
    )

    scores = [classify_fn(f) for f in frames]
    max_score = float(max(scores))
    flagged = sum(1 for s in scores if s > SAFETY_BLOCK_THRESHOLD)

    passed = max_score <= SAFETY_BLOCK_THRESHOLD

    return SafetyResult(
        passed=passed,
        max_unsafe_confidence=round(max_score, 4),
        flagged_frame_count=flagged,
        total_frames_checked=len(frames),
        action="approved" if passed else "rejected",
        reason=None if passed else (
            f"Unsafe content detected in {flagged} frame(s) "
            f"(confidence {max_score:.2f} > threshold {SAFETY_BLOCK_THRESHOLD})"
        ),
    )