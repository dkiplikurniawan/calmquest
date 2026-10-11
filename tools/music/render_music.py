"""Renders the MIDI cues with MuseScore 4 into assets/music/rendered/.

The game prefers files in assets/music/rendered/ (Ogg Vorbis, then WAV) and
falls back to the synthesized placeholders in assets/music/placeholder/.
See docs/MUSIC_PIPELINE.md for the full steps.

What this script does for each cue in assets/music/midi/:
  1. MuseScore 4 renders the MIDI with its own sounds (MuseScore's built-in
     library, e.g. MuseScore Basic / MS Basic; check its licence and record it
     in docs/ASSET_PROVENANCE.md before shipping).
  2. Looping cues: the part after the loop point (the reverb tail) is wrapped
     onto the start, exactly like the placeholders, so the loop is seamless.
     The seam is then checked numerically.
  3. Every cue is normalized to the same RMS target (TARGET_RMS_DB) with a
     peak ceiling (PEAK_DB), so cues sit at a consistent loudness.
  4. The result is written as 16-bit WAV (with a loop chunk), and also as Ogg
     Vorbis when `oggenc` is available.

Usage:
    python tools/music/render_music.py                     # find MuseScore and render all cues
    python tools/music/render_music.py --musescore "C:/Program Files/MuseScore 4/bin/MuseScore4.exe"
    python tools/music/render_music.py --cues meadow_base,grove
    python tools/music/render_music.py --check             # only check existing rendered files

Status: the processing functions are tested (tools/music/tests). The MuseScore
step itself has not been run yet, because MuseScore was not installed on the
development machine.
"""
from __future__ import annotations

import argparse
import os
import shutil
import struct
import subprocess
import sys

import numpy as np
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose  # noqa: E402  (the cue table: tempo, length, whether it loops)

ROOT = compose.ROOT
MIDI_DIR = compose.MIDI_DIR
RENDERED_DIR = os.path.join(ROOT, "assets", "music", "rendered")
# Same stand-in target as the placeholders (about -20 LUFS); no loudness meter is available.
TARGET_RMS_DB = compose.TARGET_RMS_DB
PEAK_DB = -1.0
# A seam is acceptable when the jump across the loop point is no larger than
# this many times the typical sample-to-sample change of the music itself.
SEAM_TOLERANCE = 4.0
MUSESCORE_CANDIDATES = [
    r"C:\Program Files\MuseScore 4\bin\MuseScore4.exe",
    r"C:\Program Files (x86)\MuseScore 4\bin\MuseScore4.exe",
    "/Applications/MuseScore 4.app/Contents/MacOS/mscore",
    "/usr/bin/mscore4portable",
    "/usr/bin/musescore",
]


def find_musescore(explicit: str = "") -> str:
    """The MuseScore executable, or "" when none is found."""
    if explicit:
        return explicit if os.path.exists(explicit) else ""
    for path in MUSESCORE_CANDIDATES:
        if os.path.exists(path):
            return path
    for name in ("MuseScore4", "mscore4portable", "mscore", "musescore"):
        found = shutil.which(name)
        if found:
            return found
    return ""


def loop_seconds(cue: str) -> float:
    c = compose.CUES[cue]
    return compose.cue_length_beats(cue) * 60.0 / c["tempo"]


def to_float(data: np.ndarray) -> np.ndarray:
    """Any WAV sample format -> float64 in [-1, 1], shape (frames, channels)."""
    if data.dtype == np.int16:
        x = data.astype(np.float64) / 32768.0
    elif data.dtype == np.int32:
        x = data.astype(np.float64) / 2147483648.0
    elif data.dtype == np.uint8:
        x = (data.astype(np.float64) - 128.0) / 128.0
    else:
        x = data.astype(np.float64)
    return x.reshape(len(x), -1)


def make_seamless(samples: np.ndarray, loop_frames: int) -> np.ndarray:
    """Wraps everything after the loop point onto the start, so the end of the
    loop flows into its beginning (the reverb tail continues across the seam)."""
    x = samples.reshape(len(samples), -1)
    if len(x) < loop_frames:
        x = np.vstack([x, np.zeros((loop_frames - len(x), x.shape[1]))])
    out = x[:loop_frames].copy()
    tail = x[loop_frames:]
    while len(tail) > 0:
        n = min(len(tail), loop_frames)
        out[:n] += tail[:n]
        tail = tail[n:]
    return out


def normalize(samples: np.ndarray, target_rms_db: float = TARGET_RMS_DB, peak_db: float = PEAK_DB) -> np.ndarray:
    """Scales to the RMS target, then lowers it further if the peak would pass the ceiling."""
    x = samples.astype(np.float64)
    rms = float(np.sqrt(np.mean(x ** 2)))
    if rms < 1e-9:
        return x
    x = x * (10 ** (target_rms_db / 20.0) / rms)
    peak = float(np.max(np.abs(x)))
    ceiling = 10 ** (peak_db / 20.0)
    if peak > ceiling:
        x = x * (ceiling / peak)
    return x


def rms_db(samples: np.ndarray) -> float:
    return 20.0 * np.log10(float(np.sqrt(np.mean(np.asarray(samples, dtype=np.float64) ** 2))) + 1e-12)


def seam_ratio(samples: np.ndarray) -> float:
    """Jump across the loop point (last frame -> first frame), relative to the
    music's own typical sample-to-sample change (95th percentile). <= 4 is smooth."""
    x = samples.reshape(len(samples), -1)
    steps = np.abs(np.diff(x, axis=0))
    typical = float(np.percentile(steps, 95)) + 1e-12
    jump = float(np.max(np.abs(x[0] - x[-1])))
    return jump / typical


def write_wav(path: str, samples: np.ndarray, rate: int, loops: bool) -> None:
    """16-bit WAV (mono or stereo); looping files carry a 'smpl' chunk so Godot loops them."""
    x = samples.reshape(len(samples), -1)
    channels = x.shape[1]
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, channels, rate, rate * 2 * channels, 2 * channels, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    if loops:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / rate), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    chunks += b"data" + struct.pack("<I", len(data)) + data
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def process(raw_wav: str, cue: str, out_wav: str) -> dict:
    """Seamless loop (if the cue loops), loudness, seam check; writes out_wav."""
    rate, data = wavfile.read(raw_wav)
    x = to_float(data)
    loops = compose.CUES[cue].get("loop", True)
    if loops:
        x = make_seamless(x, int(round(loop_seconds(cue) * rate)))
    else:
        fade = min(len(x), int(1.5 * rate))
        x[-fade:] *= np.linspace(1, 0, fade).reshape(-1, 1)
    x = normalize(x)
    write_wav(out_wav, x, rate, loops)
    report = {"cue": cue, "seconds": round(len(x) / rate, 2), "rms_db": round(rms_db(x), 1), "loops": loops}
    if loops:
        report["seam_ratio"] = round(seam_ratio(x), 2)
        report["seam_ok"] = report["seam_ratio"] <= SEAM_TOLERANCE
    return report


def render_cue(musescore: str, cue: str, work_dir: str) -> str:
    midi = os.path.join(MIDI_DIR, cue + ".mid")
    raw = os.path.join(work_dir, cue + "_raw.wav")
    subprocess.run([musescore, "-o", raw, midi], check=True)
    return raw


def encode_ogg(wav_path: str) -> bool:
    oggenc = shutil.which("oggenc") or shutil.which("oggenc2")
    if not oggenc:
        return False
    subprocess.run([oggenc, "-q", "6", "-o", wav_path[:-4] + ".ogg", wav_path], check=True)
    return True


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Render the MIDI cues with MuseScore into assets/music/rendered/.")
    ap.add_argument("--musescore", default="", help="Path to MuseScore4.exe (found automatically if omitted)")
    ap.add_argument("--cues", default="", help="Comma-separated cue names (default: all)")
    ap.add_argument("--check", action="store_true", help="Only check the seams and loudness of existing rendered WAVs")
    args = ap.parse_args(argv)
    cues = [c for c in args.cues.split(",") if c] or list(compose.CUES)
    os.makedirs(RENDERED_DIR, exist_ok=True)
    if args.check:
        for cue in cues:
            path = os.path.join(RENDERED_DIR, cue + ".wav")
            if os.path.exists(path):
                rate, data = wavfile.read(path)
                x = to_float(data)
                print(f"{cue:16s} {len(x) / rate:6.1f} s  rms {rms_db(x):6.1f} dB  seam {seam_ratio(x):5.2f}")
        return 0
    musescore = find_musescore(args.musescore)
    if not musescore:
        print("MuseScore 4 was not found. Install it (https://musescore.org) or pass --musescore PATH.", file=sys.stderr)
        print("Nothing was rendered; the game keeps using the synthesized placeholders.", file=sys.stderr)
        return 2
    work = os.path.join(RENDERED_DIR, "_raw")
    os.makedirs(work, exist_ok=True)
    failed = 0
    for cue in cues:
        out = os.path.join(RENDERED_DIR, cue + ".wav")
        report = process(render_cue(musescore, cue, work), cue, out)
        ogg = encode_ogg(out)
        print(report, "ogg" if ogg else "wav only")
        if report.get("seam_ok") is False:
            failed += 1
            print(f"  seam check failed for {cue}: listen to it and adjust before shipping", file=sys.stderr)
    shutil.rmtree(work, ignore_errors=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
