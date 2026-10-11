"""Tests for tools/music/render_music.py: the processing steps that turn a
MuseScore render into a seamless, consistently loud loop. MuseScore itself is
not needed (and was not installed on the development machine).

Run from the repository root:
    python -m unittest discover -s tools/music/tests -v
"""
from __future__ import annotations

import os
import sys
import tempfile
import unittest

import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import render_music as rm  # noqa: E402


def tone(seconds: float, rate: int = 22050, freq: float = 220.0, channels: int = 1) -> np.ndarray:
    t = np.arange(int(seconds * rate)) / rate
    x = 0.3 * np.sin(2 * np.pi * freq * t)
    return np.repeat(x.reshape(-1, 1), channels, axis=1)


class SeamTests(unittest.TestCase):
    def test_wrapping_the_tail_makes_the_loop_seamless(self):
        rate = 22050
        loop_frames = rate * 2
        # A held note (not a whole number of cycles in the loop) whose reverb
        # tail rings on past the loop point and then dies away, like a render.
        t = np.arange(int(3.0 * rate)) / rate
        envelope = np.where(t < 2.0, 1.0, np.exp(-(t - 2.0) * 6.0))
        x = (0.3 * np.sin(2 * np.pi * 233.3 * t) * envelope).reshape(-1, 1)
        naive = x[:loop_frames]
        seamless = rm.make_seamless(x, loop_frames)
        self.assertEqual(len(seamless), loop_frames)
        self.assertGreater(rm.seam_ratio(naive), rm.SEAM_TOLERANCE, "cutting at the loop point clicks")
        self.assertLessEqual(rm.seam_ratio(seamless), rm.SEAM_TOLERANCE, "the wrapped loop is smooth")

    def test_shorter_render_is_padded(self):
        out = rm.make_seamless(tone(0.5), 22050)
        self.assertEqual(len(out), 22050)

    def test_stereo_is_kept(self):
        out = rm.make_seamless(tone(2.5, channels=2), 22050 * 2)
        self.assertEqual(out.shape, (44100, 2))

    def test_the_existing_placeholders_loop_smoothly(self):
        folder = os.path.join(rm.ROOT, "assets", "music", "placeholder")
        checked = 0
        for name in ("grove", "creek", "meadow_base"):
            rate, data = wavfile.read(os.path.join(folder, name + ".wav"))
            self.assertLessEqual(rm.seam_ratio(rm.to_float(data)), rm.SEAM_TOLERANCE, name)
            checked += 1
        self.assertEqual(checked, 3)


class LoudnessTests(unittest.TestCase):
    def test_normalize_hits_the_target(self):
        quiet = tone(1.0) * 0.05
        out = rm.normalize(quiet)
        self.assertAlmostEqual(rm.rms_db(out), rm.TARGET_RMS_DB, places=1)

    def test_peak_ceiling_wins(self):
        spiky = np.zeros((22050, 1))
        spiky[100] = 1.0
        out = rm.normalize(spiky)
        self.assertLessEqual(np.max(np.abs(out)), 10 ** (rm.PEAK_DB / 20.0) + 1e-9)

    def test_silence_stays_silent(self):
        self.assertEqual(float(np.max(np.abs(rm.normalize(np.zeros((100, 1)))))), 0.0)


class ProcessTests(unittest.TestCase):
    def test_process_writes_a_loop_with_the_cue_length(self):
        cue = "grove"
        rate = 22050
        seconds = rm.loop_seconds(cue) + 3.0
        with tempfile.TemporaryDirectory() as tmp:
            raw = os.path.join(tmp, "raw.wav")
            out = os.path.join(tmp, "out.wav")
            wavfile.write(raw, rate, (tone(seconds, rate, channels=2) * 32767).astype(np.int16))
            report = rm.process(raw, cue, out)
            self.assertTrue(report["loops"])
            self.assertAlmostEqual(report["seconds"], round(rm.loop_seconds(cue), 2), places=1)
            self.assertAlmostEqual(report["rms_db"], rm.TARGET_RMS_DB, delta=0.6)
            with open(out, "rb") as f:
                self.assertIn(b"smpl", f.read(200), "the loop chunk is written so Godot loops it")

    def test_missing_musescore_is_reported_not_faked(self):
        self.assertEqual(rm.find_musescore("Z:/no/such/MuseScore4.exe"), "")


if __name__ == "__main__":
    unittest.main()
