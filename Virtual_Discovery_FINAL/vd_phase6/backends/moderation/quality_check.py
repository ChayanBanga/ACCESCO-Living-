"""
quality_check.py
Analyses a video file for technical quality:
  - Blur score        (Laplacian variance — higher = sharper)
  - Lighting score    (mean luminance in acceptable range)
  - Stabilisation     (frame-to-frame motion variance)
  - Audio clarity     (RMS energy check via FFmpeg probe)

Composite score is 0–100. Spec threshold: > 60 to pass.
"""

import subprocess
import json
import tempfile
import os
from pathlib import Path
import cv2
import numpy as np
from dataclasses import dataclass


@dataclass
class QualityResult:
    passed: bool
    composite_score: float          # 0–100
    blur_score: float               # 0–100
    lighting_score: float           # 0–100
    stabilisation_score: float      # 0–100
    audio_clarity_score: float      # 0–100
    failure_reason: str | None      # human-readable tip if failed


QUALITY_PASS_THRESHOLD = 60.0

# Weights must sum to 1.0
WEIGHTS = {
    "blur": 0.30,
    "lighting": 0.25,
    "stabilisation": 0.25,
    "audio": 0.20,
}


def _score_blur(frames: list[np.ndarray]) -> float:
    """Laplacian variance averaged across sampled frames. Normalised 0–100."""
    if not frames:
        return 0.0
    variances = [cv2.Laplacian(cv2.cvtColor(f, cv2.COLOR_BGR2GRAY), cv2.CV_64F).var()
                 for f in frames]
    avg = float(np.mean(variances))
    # Empirically: < 50 = very blurry, > 500 = sharp. Clamp and scale.
    return float(np.clip((avg / 500.0) * 100, 0, 100))


def _score_lighting(frames: list[np.ndarray]) -> float:
    """Mean luminance across frames. Acceptable range: 40–220 out of 255."""
    if not frames:
        return 0.0
    means = []
    for f in frames:
        hsv = cv2.cvtColor(f, cv2.COLOR_BGR2HSV)
        means.append(float(np.mean(hsv[:, :, 2])))
    avg_lum = float(np.mean(means))
    # Penalise frames that are too dark (< 40) or blown out (> 220)
    if avg_lum < 40:
        return float(np.clip((avg_lum / 40.0) * 60, 0, 60))
    if avg_lum > 220:
        return float(np.clip(((255 - avg_lum) / 35.0) * 60, 0, 60))
    # In the sweet spot: map 40–220 → 60–100
    return float(60 + ((avg_lum - 40) / 180.0) * 40)


def _score_stabilisation(frames: list[np.ndarray]) -> float:
    """Frame-to-frame optical flow magnitude variance. Lower variance = more stable."""
    if len(frames) < 2:
        return 100.0
    prev_gray = cv2.cvtColor(frames[0], cv2.COLOR_BGR2GRAY)
    magnitudes = []
    for frame in frames[1:]:
        curr_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        flow = cv2.calcOpticalFlowFarneback(
            prev_gray, curr_gray, None,
            pyr_scale=0.5, levels=3, winsize=15,
            iterations=3, poly_n=5, poly_sigma=1.2, flags=0
        )
        mag, _ = cv2.cartToPolar(flow[..., 0], flow[..., 1])
        magnitudes.append(float(np.mean(mag)))
        prev_gray = curr_gray
    variance = float(np.var(magnitudes))
    # Variance > 20 = very shaky. Clamp and invert.
    return float(np.clip(100 - (variance / 20.0) * 100, 0, 100))


def _score_audio(video_path: str) -> float:
    """
    Uses FFmpeg to probe mean audio volume (RMS dB).
    Silent or missing audio scores low. Target: mean_volume > -30 dB.
    """
    try:
        result = subprocess.run(
            [
                "ffmpeg", "-i", video_path,
                "-af", "volumedetect",
                "-f", "null", "-"
            ],
            stderr=subprocess.PIPE,
            stdout=subprocess.PIPE,
            timeout=30,
        )
        stderr = result.stderr.decode("utf-8", errors="ignore")
        mean_volume = None
        for line in stderr.splitlines():
            if "mean_volume" in line:
                # e.g. "mean_volume: -23.4 dB"
                parts = line.split(":")
                if len(parts) == 2:
                    mean_volume = float(parts[1].strip().replace(" dB", ""))
                    break

        if mean_volume is None:
            # No audio track — penalise but don't zero out
            return 40.0

        # mean_volume is negative dB. -10 = loud, -40 = quiet/silent.
        # Map -40→0 dB to 0→100 score.
        return float(np.clip(((mean_volume + 40) / 30.0) * 100, 0, 100))

    except Exception:
        return 40.0


def _sample_frames(video_path: str, max_frames: int = 20) -> list[np.ndarray]:
    """Evenly sample up to max_frames from the video."""
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


def run_quality_check(video_path: str) -> QualityResult:
    """
    Main entry point. Accepts a local file path to the video.
    Returns a QualityResult dataclass.
    """
    frames = _sample_frames(video_path)

    if not frames:
        return QualityResult(
            passed=False,
            composite_score=0.0,
            blur_score=0.0,
            lighting_score=0.0,
            stabilisation_score=0.0,
            audio_clarity_score=0.0,
            failure_reason="Could not read video frames. File may be corrupt.",
        )

    blur = _score_blur(frames)
    lighting = _score_lighting(frames)
    stabilisation = _score_stabilisation(frames)
    audio = _score_audio(video_path)

    composite = (
        blur * WEIGHTS["blur"]
        + lighting * WEIGHTS["lighting"]
        + stabilisation * WEIGHTS["stabilisation"]
        + audio * WEIGHTS["audio"]
    )

    passed = composite >= QUALITY_PASS_THRESHOLD

    failure_reason = None
    if not passed:
        tips = []
        if blur < 40:
            tips.append("video appears blurry — ensure camera is in focus")
        if lighting < 40:
            tips.append("lighting is too dark or overexposed — shoot in natural light")
        if stabilisation < 40:
            tips.append("video is shaky — use a stable surface or gimbal")
        if audio < 40:
            tips.append("audio is too quiet or missing — speak clearly close to the mic")
        failure_reason = "; ".join(tips) if tips else "composite quality below threshold"

    return QualityResult(
        passed=passed,
        composite_score=round(composite, 2),
        blur_score=round(blur, 2),
        lighting_score=round(lighting, 2),
        stabilisation_score=round(stabilisation, 2),
        audio_clarity_score=round(audio, 2),
        failure_reason=failure_reason,
    )