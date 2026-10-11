"""CALMQUEST ambience loops, synthesized from noise and sine tones (original,
no samples). Each loop is seamless (its tail is cross-faded onto its start)
and written as a 16-bit mono WAV with a 'smpl' loop chunk.

    python tools/music/ambience.py

Output: assets/ambience/placeholder/<name>.wav
"""
import os
import struct

import numpy as np
from scipy.signal import butter, lfilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ambience", "placeholder")
SR = 22050
SECONDS = 12.0
TARGET_RMS_DB = -27.0


def lowpass(x, hz):
    b, a = butter(2, hz / (SR / 2), btype="low")
    return lfilter(b, a, x)


def highpass(x, hz):
    b, a = butter(2, hz / (SR / 2), btype="high")
    return lfilter(b, a, x)


def bandpass(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return lfilter(b, a, x)


def lfo(n, hz, depth, offset=0.0):
    t = np.arange(n) / SR
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * hz * t + offset))


def chirp(n_total, at, f0, f1, dur, amp):
    out = np.zeros(n_total)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.linspace(f0, f1, n)
    w = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / dur) ** 2 * amp
    s = int(at * SR)
    e = min(n_total, s + n)
    out[s:e] += w[: e - s]
    return out


def make(name, rng):
    n = int((SECONDS + 2.0) * SR)
    white = rng.standard_normal(n)
    if name == "wind_pines":
        x = lowpass(white, 500) * lfo(n, 0.12, 0.6) + 0.4 * bandpass(white, 900, 2200) * lfo(n, 0.07, 0.8, 1.0)
    elif name == "highland_wind":
        x = bandpass(white, 300, 1400) * lfo(n, 0.09, 0.7) + 0.2 * bandpass(white, 2000, 4000) * lfo(n, 0.05, 0.9, 2.0)
    elif name == "waves":
        swell = np.zeros(n)
        for k in range(0, int(SECONDS + 2), 4):
            t = np.arange(n) / SR - k - rng.uniform(0, 1)
            swell += np.where(t > 0, np.exp(-t * 0.9) * (1 - np.exp(-t * 6)), 0)
        x = lowpass(white, 900) * (0.25 + swell) + 0.3 * highpass(white, 3000) * swell
    elif name == "creek":
        x = 0.5 * bandpass(white, 400, 2500) * lfo(n, 0.5, 0.3)
        for _ in range(60):
            x += chirp(n, rng.uniform(0, SECONDS + 1), rng.uniform(500, 900), rng.uniform(900, 1600), rng.uniform(0.04, 0.09), 0.25)
    elif name == "cave_drips":
        x = 0.08 * lowpass(white, 200)
        for _ in range(14):
            at = rng.uniform(0, SECONDS + 1)
            f = rng.uniform(900, 1800)
            for echo, a in ((0.0, 0.6), (0.33, 0.25), (0.7, 0.1)):
                x += chirp(n, min(at + echo, SECONDS + 1.5), f * 1.2, f, 0.18, a)
    elif name == "night_insects":
        x = 0.05 * lowpass(white, 300)
        t = np.arange(n) / SR
        for k in range(5):
            f = rng.uniform(3200, 4800)
            gate = (np.sin(2 * np.pi * rng.uniform(5, 9) * t) > 0.6).astype(float)
            x += 0.08 * np.sin(2 * np.pi * f * t) * gate * lfo(n, rng.uniform(0.1, 0.3), 0.9, k)
    elif name == "meadow_birds":
        x = 0.12 * lowpass(white, 400) * lfo(n, 0.1, 0.5)
        for _ in range(18):
            at = rng.uniform(0, SECONDS + 1)
            f = rng.uniform(2200, 3600)
            for j in range(rng.integers(2, 5)):
                x += chirp(n, min(at + j * 0.13, SECONDS + 1.5), f, f * rng.uniform(1.1, 1.4), 0.09, 0.22)
    elif name == "rain":
        x = highpass(white, 1500) * 0.7 + lowpass(white, 600) * 0.3
        drops = (rng.random(n) > 0.9993).astype(float)
        x += 1.5 * highpass(lfilter([1.0], [1.0, -0.97], drops), 1200)
    else:
        raise ValueError(name)
    loop = int(SECONDS * SR)
    fade = int(1.5 * SR)
    out = x[:loop].copy()
    w = np.linspace(0, 1, fade)
    out[:fade] = out[:fade] * w + x[loop:loop + fade] * (1 - w)
    rms = np.sqrt(np.mean(out ** 2)) + 1e-9
    out *= 10 ** (TARGET_RMS_DB / 20.0) / rms
    peak = np.max(np.abs(out))
    if peak > 0.8:
        out *= 0.8 / peak
    return out


def write_wav(path, samples):
    data = (np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"smpl" + struct.pack("<I", len(smpl)) + smpl
    chunks += b"data" + struct.pack("<I", len(data)) + data
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, name in enumerate(["wind_pines", "highland_wind", "waves", "creek", "cave_drips", "night_insects", "meadow_birds", "rain"]):
        samples = make(name, np.random.default_rng(100 + i))
        write_wav(os.path.join(OUT, name + ".wav"), samples)
        print(f"{name:14s} {len(samples) / SR:.1f} s loop")


if __name__ == "__main__":
    main()
