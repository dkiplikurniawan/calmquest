"""CALMQUEST music: composition as code.

Generates every music cue as a multi-track General MIDI file
(assets/music/midi/<cue>.mid) and, because no orchestral renderer or licensed
SoundFont is available on this machine, a clearly labelled SYNTHESIZED
PLACEHOLDER loop (assets/music/placeholder/<cue>.wav) rendered from the same
notes with simple additive synthesis. See docs/MUSIC_PIPELINE.md for how to
render the MIDI files with a real orchestral library.

Everything musical is data at the top of this file: the shared Lumeria theme,
and for each cue its key, mode, tempo, meter, chord progression and parts.

Usage:
    python tools/music/compose.py              # MIDI + placeholder WAVs
    python tools/music/compose.py --midi-only  # MIDI only
    python tools/music/compose.py --cues meadow_base,cottage

Standard library + numpy + scipy only (no mido/pretty_midi needed).
"""
import argparse
import math
import os
import struct

import numpy as np
from scipy.signal import fftconvolve

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MIDI_DIR = os.path.join(ROOT, "assets", "music", "midi")
WAV_DIR = os.path.join(ROOT, "assets", "music", "placeholder")
SAMPLE_RATE = 22050
TARGET_RMS_DB = -22.0  # stand-in for about -20 LUFS (no loudness meter available)
TAIL_SECONDS = 4.0

# --- Composition data -------------------------------------------------------------------

# Scale steps (semitones) for each mode. Only gentle, consonant colours.
MODES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
}

# The Lumeria theme: (scale degree, beats). Degree 0 = rest. 8 = octave.
THEME = [(1, 1.5), (3, 0.5), (5, 1.0), (6, 1.0), (5, 1.5), (3, 0.5), (2, 2.0)]
ANSWER = [(3, 1.5), (2, 0.5), (1, 1.0), (6, 1.0), (5, 3.0), (0, 1.0)]
THEME_HIGH = [(3, 1.5), (5, 0.5), (8, 1.0), (6, 1.0), (5, 1.5), (3, 0.5), (4, 2.0)]
CADENCE = [(4, 1.0), (3, 1.0), (2, 1.0), (3, 1.0), (2, 3.0), (0, 1.0)]
# The same ideas in a lilting 6/8 feel (3 quarter-beats per bar).
THEME_68 = [(1, 1.0), (3, 0.5), (5, 1.0), (6, 0.5), (5, 1.5), (3, 1.5)]
ANSWER_68 = [(3, 1.0), (2, 0.5), (1, 1.0), (6, 0.5), (5, 3.0)]
CADENCE_68 = [(4, 1.0), (3, 0.5), (2, 1.5), (2, 2.5), (0, 0.5)]

# General MIDI programs (0-based) and their placeholder timbres.
INSTRUMENTS = {
    "piano": {"program": 0, "synth": "piano"},
    "celesta": {"program": 8, "synth": "bell"},
    "glockenspiel": {"program": 9, "synth": "glock"},
    "harp": {"program": 46, "synth": "harp"},
    "strings": {"program": 49, "synth": "strings"},
    "high_strings": {"program": 49, "synth": "strings"},
    "cello": {"program": 42, "synth": "strings"},
    "choir": {"program": 52, "synth": "choir"},
    "flute": {"program": 73, "synth": "flute"},
    "clarinet": {"program": 71, "synth": "clarinet"},
    "horn": {"program": 60, "synth": "horn"},
    "pad": {"program": 89, "synth": "pad"},
}

# Each cue: key root (MIDI note), mode, tempo, beats per bar, progression (one
# chord degree per bar, looping: the last chord leads back to the first), and
# parts (instrument, role, octave offset, velocity). Roles: pad, bass, arp,
# melody, counter, bells. "phrases" picks the melody for each two-bar phrase.
CUES = {
    "lumeria_theme": {"root": 60, "mode": "major", "tempo": 72, "beats": 4,
        "progression": [1, 4, 6, 5, 1, 4, 2, 5],
        "phrases": ["THEME", "ANSWER", "THEME_HIGH", "CADENCE"],
        "parts": [("piano", "melody", 12, 52), ("strings", "pad", 0, 38), ("cello", "bass", -24, 40), ("piano", "arp", 0, 30)]},
    "meadow_base": {"root": 62, "mode": "major", "tempo": 76, "beats": 4,
        "progression": [1, 4, 6, 5, 1, 4, 2, 5],
        "phrases": [],
        "parts": [("harp", "arp", 0, 34), ("strings", "pad", -12, 34), ("cello", "bass", -24, 36)]},
    "meadow_day": {"root": 62, "mode": "major", "tempo": 76, "beats": 4,
        "progression": [1, 4, 6, 5, 1, 4, 2, 5],
        "phrases": ["THEME", "ANSWER", "THEME_HIGH", "CADENCE"],
        "parts": [("flute", "melody", 12, 50), ("celesta", "bells", 24, 24)]},
    "meadow_night": {"root": 62, "mode": "major", "tempo": 76, "beats": 4,
        "progression": [1, 4, 6, 5, 1, 4, 2, 5],
        "phrases": ["THEME", "REST", "ANSWER", "REST"],
        "parts": [("piano", "melody", 0, 40), ("pad", "pad", 0, 26)]},
    "cottage": {"root": 65, "mode": "major", "tempo": 60, "beats": 4,
        "progression": [1, 6, 4, 5, 1, 2, 4, 5],
        "phrases": ["THEME", "REST", "CADENCE", "REST"],
        "parts": [("piano", "melody", 0, 38), ("piano", "arp", -12, 26), ("cello", "counter", -12, 30)]},
    "grove": {"root": 57, "mode": "lydian", "tempo": 70, "beats": 4,
        "progression": [1, 2, 1, 5, 6, 2, 4, 5],
        "phrases": ["THEME_HIGH", "ANSWER", "THEME", "CADENCE"],
        "parts": [("celesta", "melody", 24, 40), ("harp", "arp", 12, 34), ("pad", "pad", 0, 26)]},
    "creek": {"root": 55, "mode": "major", "tempo": 74, "beats": 4,
        "progression": [1, 5, 6, 4, 1, 5, 4, 5],
        "phrases": ["THEME", "ANSWER", "THEME_HIGH", "CADENCE"],
        "parts": [("clarinet", "melody", 12, 46), ("harp", "arp", 12, 32), ("glockenspiel", "bells", 24, 22), ("strings", "pad", 0, 28)]},
    "pinewood": {"root": 50, "mode": "mixolydian", "tempo": 64, "beats": 4,
        "progression": [1, 7, 4, 1, 6, 7, 4, 5],
        "phrases": ["REST", "THEME", "REST", "CADENCE"],
        "parts": [("horn", "melody", 12, 36), ("strings", "pad", 0, 32), ("cello", "bass", -12, 34)]},
    "coast": {"root": 58, "mode": "major", "tempo": 66, "beats": 3,
        "progression": [1, 4, 1, 5, 6, 4, 2, 5],
        "phrases": ["THEME_68", "ANSWER_68", "THEME_68", "CADENCE_68"],
        "parts": [("flute", "melody", 12, 46), ("strings", "pad", 0, 30), ("harp", "arp", 0, 30), ("cello", "bass", -24, 32)]},
    "caves": {"root": 60, "mode": "lydian", "tempo": 58, "beats": 4,
        "progression": [1, 2, 1, 7, 1, 2, 6, 5],
        "phrases": ["REST", "THEME", "REST", "REST"],
        "parts": [("piano", "melody", 12, 30), ("pad", "pad", -12, 26), ("celesta", "bells", 24, 18)]},
    "sanctuary": {"root": 51, "mode": "major", "tempo": 60, "beats": 4,
        "progression": [1, 4, 1, 5, 6, 4, 1, 5],
        "phrases": ["REST", "THEME", "REST", "ANSWER"],
        "parts": [("choir", "pad", 12, 32), ("strings", "melody", 12, 36), ("cello", "bass", -12, 30)]},
    "highlands": {"root": 64, "mode": "major", "tempo": 68, "beats": 4,
        "progression": [1, 5, 4, 1, 6, 4, 2, 5],
        "phrases": ["THEME_HIGH", "REST", "THEME", "CADENCE"],
        "parts": [("celesta", "melody", 12, 38), ("high_strings", "pad", 12, 28), ("harp", "arp", 0, 26)]},
    "finale": {"root": 60, "mode": "major", "tempo": 72, "beats": 4,
        "progression": [1, 4, 6, 5, 1, 4, 5, 1],
        "phrases": ["THEME", "ANSWER", "THEME_HIGH", "CADENCE"],
        "parts": [("strings", "melody", 12, 54), ("horn", "counter", 0, 40), ("harp", "arp", 0, 36), ("choir", "pad", 0, 32), ("cello", "bass", -24, 42), ("celesta", "bells", 24, 26)]},
    "stinger_restore": {"root": 60, "mode": "major", "tempo": 66, "beats": 4, "loop": False,
        "progression": [4, 1],
        "phrases": ["THEME"],
        "parts": [("strings", "melody", 12, 50), ("strings", "pad", 0, 40), ("harp", "arp", 0, 34)]},
}

PHRASES = {"THEME": THEME, "ANSWER": ANSWER, "THEME_HIGH": THEME_HIGH, "CADENCE": CADENCE,
           "THEME_68": THEME_68, "ANSWER_68": ANSWER_68, "CADENCE_68": CADENCE_68, "REST": []}


# --- Music theory helpers ---------------------------------------------------------------

def degree_to_note(root, mode, degree, octave=0):
    """Scale degree (1-based, may exceed 7) to a MIDI note."""
    steps = MODES[mode]
    d = degree - 1
    return root + 12 * (octave + d // 7) + steps[d % 7]


def chord_notes(root, mode, degree):
    """A triad on a scale degree (root, third, fifth)."""
    return [degree_to_note(root, mode, degree + i) for i in (0, 2, 4)]


def arrange(cue):
    """Returns {part_index: [(start_beat, length_beats, note, velocity)]}."""
    c = CUES[cue]
    root, mode, bpb = c["root"], c["mode"], c["beats"]
    prog = c["progression"]
    out = {}
    for pi, (inst, role, octave, vel) in enumerate(c["parts"]):
        notes = []
        for bar, deg in enumerate(prog):
            t0 = bar * bpb
            chord = chord_notes(root, mode, deg)
            if role == "pad":
                for k, n in enumerate(chord):
                    notes.append((t0, bpb, n + octave + (12 if k == 0 and deg > 4 else 0), vel - 4 * k))
            elif role == "bass":
                notes.append((t0, bpb * 0.75, chord[0] + octave, vel))
                if bpb == 4:
                    notes.append((t0 + 2.5, 1.5, chord[2] + octave - 12, vel - 8))
            elif role == "arp":
                pattern = [0, 1, 2, 1] if bpb == 4 else [0, 2, 1]
                step = 1.0 if bpb == 4 else 1.0
                tones = chord + [chord[0] + 12]
                for i in range(int(bpb / step)):
                    n = tones[pattern[i % len(pattern)]]
                    notes.append((t0 + i * step, step * 1.8, n + octave, vel - (6 if i % 2 else 0)))
            elif role == "counter":
                notes.append((t0, bpb / 2, chord[1] + octave, vel))
                notes.append((t0 + bpb / 2, bpb / 2, chord[2] + octave - 12 if chord[2] + octave - 12 > 36 else chord[2] + octave, vel - 6))
            elif role == "bells":
                if bar % 2 == 1:
                    notes.append((t0 + (1.5 if bpb == 4 else 1.0), 2.0, chord[2] + octave, vel))
                    notes.append((t0 + (3.0 if bpb == 4 else 2.0), 2.0, chord[1] + octave, vel - 6))
        if role == "melody":
            beat = 0.0
            for phrase in c.get("phrases", []):
                start = beat
                for deg, dur in PHRASES[phrase]:
                    if deg > 0:
                        notes.append((beat, dur * 0.95, degree_to_note(root, mode, deg) + octave, vel + (4 if dur >= 1.5 else 0)))
                    beat += dur
                beat = start + 2 * bpb
        out[pi] = notes
    return out


def cue_length_beats(cue):
    c = CUES[cue]
    return len(c["progression"]) * c["beats"]


# --- MIDI writer (Standard MIDI File, format 1) --------------------------------------------

PPQ = 480


def _vlq(value):
    out = [value & 0x7F]
    value >>= 7
    while value:
        out.insert(0, (value & 0x7F) | 0x80)
        value >>= 7
    return bytes(out)


def _track(events):
    """events: list of (tick, bytes). Returns an MTrk chunk."""
    events.sort(key=lambda e: (e[0], e[2] if len(e) > 2 else 0))
    data = bytearray()
    last = 0
    for e in events:
        tick, msg = e[0], e[1]
        data += _vlq(tick - last) + msg
        last = tick
    data += _vlq(0) + b"\xff\x2f\x00"
    return b"MTrk" + struct.pack(">I", len(data)) + bytes(data)


def write_midi(cue, path):
    c = CUES[cue]
    parts = arrange(cue)
    tracks = []
    tempo_us = int(60_000_000 / c["tempo"])
    num, den = (6, 3) if c["beats"] == 3 else (4, 2)
    meta = [(0, b"\xff\x03" + _vlq(len(cue)) + cue.encode("ascii")),
            (0, b"\xff\x51\x03" + struct.pack(">I", tempo_us)[1:]),
            (0, b"\xff\x58\x04" + bytes([num, den, 24, 8]))]
    tracks.append(_track(meta))
    for pi, (inst, role, octave, vel) in enumerate(c["parts"]):
        ch = pi if pi < 9 else pi + 1  # skip channel 10 (drums)
        program = INSTRUMENTS[inst]["program"]
        name = f"{inst} ({role})".encode("ascii")
        ev = [(0, b"\xff\x03" + _vlq(len(name)) + name, 0),
              (0, bytes([0xC0 | ch, program]), 1),
              (0, bytes([0xB0 | ch, 7, 90]), 1),   # channel volume
              (0, bytes([0xB0 | ch, 11, 100]), 1),  # expression
              (0, bytes([0xB0 | ch, 91, 50]), 1)]   # reverb send
        if inst in ("piano", "harp"):
            for bar in range(len(c["progression"])):
                t = int(bar * c["beats"] * PPQ)
                ev.append((t, bytes([0xB0 | ch, 64, 127]), 2))       # sustain pedal down
                ev.append((t + int((c["beats"] - 0.05) * PPQ), bytes([0xB0 | ch, 64, 0]), 1))
        for start, length, note, v in parts[pi]:
            on = int(start * PPQ)
            off = int((start + length) * PPQ)
            v = max(1, min(127, int(v)))
            note = max(0, min(127, note))
            ev.append((on, bytes([0x90 | ch, note, v]), 3))
            ev.append((off, bytes([0x80 | ch, note, 0]), 0))
        tracks.append(_track(ev))
    header = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), PPQ)
    with open(path, "wb") as f:
        f.write(header + b"".join(tracks))


# --- Placeholder synthesis ------------------------------------------------------------------

def midi_freq(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def _env(n, sr, attack, release, sustain_len):
    env = np.ones(n)
    a = max(1, int(attack * sr))
    env[:a] = np.linspace(0.0, 1.0, a)
    s = min(n, int(sustain_len * sr))
    r = n - s
    if r > 0:
        env[s:] = np.linspace(1.0, 0.0, r) ** 1.5
    return env


def synth_note(kind, note, dur, vel, sr):
    """A gentle placeholder timbre. Returns a mono float array."""
    f = midi_freq(note)
    amp = (vel / 127.0) ** 1.4
    if kind in ("piano", "harp", "bell", "glock"):
        length = dur + (2.5 if kind != "glock" else 1.6)
    else:
        length = dur + 0.9
    n = int(length * sr)
    t = np.arange(n) / sr
    rng = np.random.default_rng(note * 7 + int(dur * 100))
    phase = rng.uniform(0, 2 * np.pi)
    if kind == "piano":
        partials = [(1, 1.0, 1.2), (2, 0.45, 2.0), (3, 0.2, 3.0), (4, 0.1, 4.5), (5, 0.05, 6.0)]
        sig = sum(a * np.sin(2 * np.pi * f * r * (1 + 0.0004 * r * r) * t + phase) * np.exp(-d * t) for r, a, d in partials)
        sig *= _env(n, sr, 0.004, 0, length) * np.where(t < dur, 1.0, np.exp(-(t - dur) * 3.0))
    elif kind == "harp":
        partials = [(1, 1.0, 1.6), (2, 0.35, 2.8), (3, 0.12, 4.0)]
        sig = sum(a * np.sin(2 * np.pi * f * r * t + phase) * np.exp(-d * t) for r, a, d in partials)
        sig *= _env(n, sr, 0.003, 0, length)
    elif kind in ("bell", "glock"):
        ratios = [(1, 1.0), (2.76, 0.4), (5.4, 0.18)] if kind == "glock" else [(1, 1.0), (2.0, 0.3), (3.01, 0.15), (4.1, 0.06)]
        sig = sum(a * np.sin(2 * np.pi * f * r * t + phase) * np.exp(-(2.2 + r) * t) for r, a in ratios)
        sig *= _env(n, sr, 0.002, 0, length)
    else:
        vib = 1 + 0.0035 * np.sin(2 * np.pi * 4.8 * t) * np.clip(t / 0.6, 0, 1)
        ph = 2 * np.pi * np.cumsum(f * vib) / sr + phase
        if kind == "strings":
            sig = sum((1.0 / k) * np.sin(k * ph + rng.uniform(0, 1)) for k in range(1, 7)) * 0.6
            env = _env(n, sr, 0.45, 0.6, dur)
        elif kind == "choir":
            sig = sum(np.sin(ph * (1 + d)) for d in (-0.003, 0.0, 0.0035)) / 3.0
            sig += 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
            env = _env(n, sr, 0.6, 0.8, dur)
        elif kind == "pad":
            sig = sum(np.sin(ph * (1 + d)) for d in (-0.004, 0.0, 0.004)) / 3.0 + 0.2 * np.sin(2 * ph)
            env = _env(n, sr, 0.8, 0.9, dur)
        elif kind == "flute":
            sig = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
            sig += 0.015 * rng.standard_normal(n)
            env = _env(n, sr, 0.09, 0.25, dur)
        elif kind == "clarinet":
            sig = np.sin(ph) + 0.35 * np.sin(3 * ph) + 0.15 * np.sin(5 * ph) + 0.05 * np.sin(7 * ph)
            env = _env(n, sr, 0.06, 0.25, dur)
        else:  # horn
            sig = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph) + 0.08 * np.sin(4 * ph)
            env = _env(n, sr, 0.25, 0.5, dur)
        sig *= env
    return sig * amp


def reverb(signal, sr, seconds=2.4, mix=0.3):
    n = int(seconds * sr)
    rng = np.random.default_rng(7)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / sr * 3.2)
    ir = np.convolve(ir, np.ones(8) / 8, mode="same")
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = fftconvolve(signal, ir)[: len(signal)]
    return signal * (1 - mix) + wet * mix * 0.9


def render(cue, sr=SAMPLE_RATE):
    c = CUES[cue]
    beat_s = 60.0 / c["tempo"]
    loop_s = cue_length_beats(cue) * beat_s
    loops = c.get("loop", True)
    total = int((loop_s + TAIL_SECONDS) * sr)
    buf = np.zeros(total + sr * 4)
    parts = arrange(cue)
    for pi, (inst, role, octave, vel) in enumerate(c["parts"]):
        kind = INSTRUMENTS[inst]["synth"]
        gain = {"pad": 0.45, "bass": 0.7, "arp": 0.55, "bells": 0.5, "counter": 0.55, "melody": 0.8}[role]
        for start, length, note, v in parts[pi]:
            s = int(start * beat_s * sr)
            w = synth_note(kind, note, length * beat_s, v, sr) * gain
            end = min(len(buf), s + len(w))
            buf[s:end] += w[: end - s]
    buf = reverb(buf[:total], sr)
    n_loop = int(loop_s * sr)
    if loops:
        # Wrap the tail onto the start: the loop point is seamless.
        out = buf[:n_loop].copy()
        tail = buf[n_loop:]
        out[: len(tail)] += tail[: n_loop]
    else:
        out = buf
        fade = int(1.5 * sr)
        out[-fade:] *= np.linspace(1, 0, fade)
    rms = np.sqrt(np.mean(out ** 2)) + 1e-9
    out *= 10 ** (TARGET_RMS_DB / 20.0) / rms
    peak = np.max(np.abs(out))
    if peak > 0.89:
        out *= 0.89 / peak
    return out, loops


def write_wav(path, samples, sr, loops):
    """16-bit mono WAV; looping files carry a 'smpl' chunk so Godot detects the loop."""
    data = (np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, sr, sr * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    if loops:
        frames = len(samples)
        smpl = struct.pack("<9I", 0, 0, int(1e9 / sr), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    chunks += b"data" + struct.pack("<I", len(data)) + data
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--midi-only", action="store_true")
    ap.add_argument("--cues", default="")
    args = ap.parse_args()
    os.makedirs(MIDI_DIR, exist_ok=True)
    os.makedirs(WAV_DIR, exist_ok=True)
    cues = [c for c in args.cues.split(",") if c] or list(CUES)
    for cue in cues:
        write_midi(cue, os.path.join(MIDI_DIR, cue + ".mid"))
        line = f"{cue:16s} midi ok ({CUES[cue]['tempo']} bpm, {cue_length_beats(cue)} beats)"
        if not args.midi_only:
            samples, loops = render(cue)
            write_wav(os.path.join(WAV_DIR, cue + ".wav"), samples, SAMPLE_RATE, loops)
            line += f", placeholder wav {len(samples) / SAMPLE_RATE:.1f} s{' loop' if loops else ''}"
        print(line)


if __name__ == "__main__":
    main()
