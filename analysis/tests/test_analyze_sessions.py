"""Unit tests for analysis/analyze_sessions.py (standard-library unittest).

Run from the repository root:
    python -m unittest discover -s analysis/tests -v
"""
from __future__ import annotations

import re
import sys
import tempfile
import unittest
from pathlib import Path

ANALYSIS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = ANALYSIS_DIR.parent
sys.path.insert(0, str(ANALYSIS_DIR))

import analyze_sessions as an  # noqa: E402

HEADER = ",".join(an.EXPECTED_COLUMNS)


def row(**overrides) -> str:
    values = {
        "schema_version": "1",
        "session_id": "cq-0000000000000001",
        "session_started_at": "2026-10-01T10:00:00",
        "pre_stress_score": "7",
        "recommended_mode": "gentle",
        "selected_mode": "gentle",
        "final_mode": "gentle",
        "session_duration_seconds": "300",
        "hints_used": "1",
        "interaction_help_events": "0",
        "items_collected": "9",
        "garden_restored": "true",
        "post_stress_score": "4",
        "score_delta": "-3",
        "experience_rating": "4",
        "completed": "true",
    }
    values.update({k: str(v) for k, v in overrides.items()})
    return ",".join(values[c] for c in an.EXPECTED_COLUMNS)


class CsvFileTestCase(unittest.TestCase):
    def write_csv(self, *rows: str) -> Path:
        tmp = tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False, encoding="utf-8", newline="")
        tmp.write(HEADER + "\n" + "\n".join(rows) + "\n")
        tmp.close()
        self.addCleanup(Path(tmp.name).unlink)
        return Path(tmp.name)


class SchemaTests(CsvFileTestCase):
    def test_columns_match_the_game_schema(self):
        """The Python schema must match SessionRecord.COLUMNS in the game."""
        gd = (REPO_ROOT / "game/scripts/data/session_record.gd").read_text(encoding="utf-8")
        block = re.search(r"const COLUMNS: PackedStringArray = \[(.*?)\]", gd, re.S).group(1)
        game_columns = re.findall(r'"([a-z_]+)"', block)
        self.assertEqual(game_columns, an.EXPECTED_COLUMNS)

    def test_missing_columns_are_reported(self):
        path = Path(tempfile.mkdtemp()) / "bad.csv"
        path.write_text("session_id,pre_stress_score\ncq-1,5\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            an.load_sessions(path)


class ValidationTests(CsvFileTestCase):
    def test_valid_record_passes(self):
        valid, excluded, report, schema = an.load_sessions(self.write_csv(row()))
        self.assertEqual(len(valid), 1)
        self.assertEqual(len(excluded), 0)
        self.assertTrue(schema["column_order_matches"])

    def test_invalid_values_are_flagged_and_excluded(self):
        path = self.write_csv(
            row(session_id="cq-a", pre_stress_score=12, score_delta=-8),
            row(session_id="cq-b", session_duration_seconds=-5),
            row(session_id="cq-c", hints_used="two"),
            row(session_id="cq-d", post_stress_score=4.5, score_delta=""),
            row(session_id="cq-e", selected_mode="turbo"),
            row(session_id="cq-f", score_delta=3),
            row(session_id="cq-g", experience_rating=9),
            row(session_id="cq-ok"),
        )
        valid, excluded, report, _ = an.load_sessions(path)
        self.assertEqual(list(valid["session_id"]), ["cq-ok"])
        self.assertEqual(len(excluded), 7)
        problems = set(report.issues["problem"])
        self.assertIn("score outside 0-10", problems)
        self.assertIn("negative value", problems)
        self.assertIn("not a whole number", problems)
        self.assertIn("unknown or missing mode", problems)
        self.assertIn("does not equal post - pre", problems)
        self.assertIn("rating outside 1-5", problems)

    def test_invalid_scores_are_never_rounded_into_valid_ones(self):
        valid, _, _, _ = an.load_sessions(self.write_csv(row(post_stress_score=4.5, score_delta="")))
        self.assertEqual(len(valid), 0)

    def test_duplicates_keep_first_copy(self):
        valid, excluded, report, _ = an.load_sessions(self.write_csv(row(), row()))
        self.assertEqual(len(valid), 1)
        self.assertEqual(len(excluded), 1)
        self.assertEqual(report.duplicate_ids, ["cq-0000000000000001"])

    def test_quoted_strings_are_read_correctly(self):
        # A comma inside a quoted field must not shift columns.
        path = self.write_csv(row(session_id='"cq-with,comma"'))
        raw = an.load_raw(path)
        self.assertEqual(raw.loc[0, "session_id"], "cq-with,comma")
        self.assertEqual(raw.loc[0, "completed"], "true")


class AnalysisTests(CsvFileTestCase):
    def test_missing_scores_stay_missing(self):
        valid, _, _, _ = an.load_sessions(self.write_csv(
            row(session_id="cq-1", pre_stress_score="", recommended_mode="", score_delta=""),
            row(session_id="cq-2", post_stress_score="", score_delta="", experience_rating=""),
            row(session_id="cq-3", pre_stress_score=0, post_stress_score=0, score_delta=0),
        ))
        self.assertTrue(valid.loc[valid.session_id == "cq-1", "pre_stress_score"].isna().all())
        self.assertEqual(int(valid.loc[valid.session_id == "cq-3", "pre_stress_score"].iloc[0]), 0)
        pairs, excluded = an.paired_scores(valid)
        self.assertEqual(list(pairs["session_id"]), ["cq-3"])
        self.assertEqual(excluded, 2)

    def test_delta_sign_convention(self):
        valid, _, _, _ = an.load_sessions(self.write_csv(
            row(session_id="cq-down", pre_stress_score=7, post_stress_score=4, score_delta=-3),
            row(session_id="cq-up", pre_stress_score=3, post_stress_score=5, score_delta=2),
            row(session_id="cq-same", pre_stress_score=5, post_stress_score=5, score_delta=0),
        ))
        pairs, _ = an.paired_scores(valid)
        deltas = dict(zip(pairs.session_id, pairs.score_delta.astype(int)))
        self.assertEqual(deltas, {"cq-down": -3, "cq-up": 2, "cq-same": 0})
        summary = an.summarize(valid)
        self.assertEqual((summary["delta_negative"], summary["delta_zero"], summary["delta_positive"]), (1, 1, 1))

    def test_interpretation_is_descriptive_not_causal(self):
        valid, _, _, _ = an.load_sessions(self.write_csv(row()))
        text = an.describe_change(an.summarize(valid)).lower()
        self.assertIn("in this dataset", text)
        self.assertIn("does not show that the game caused", text)
        for banned in ("reduced anxiety", "cured", "proves", "effective"):
            self.assertNotIn(banned, text)

    def test_no_pairs_message(self):
        valid, _, _, _ = an.load_sessions(self.write_csv(row(post_stress_score="", score_delta="")))
        self.assertIn("no comparison is possible", an.describe_change(an.summarize(valid)))


class SampleDataTests(unittest.TestCase):
    def test_synthetic_sample_loads_and_is_labeled(self):
        path = REPO_ROOT / "data" / "sample_sessions_SYNTHETIC.csv"
        self.assertIn("SYNTHETIC", path.name)
        valid, excluded, report, schema = an.load_sessions(path)
        self.assertEqual(schema["missing_columns"], [])
        self.assertEqual(len(excluded), 5, "the five documented invalid rows are excluded")
        self.assertGreater(len(valid), 30)

    def test_charts_are_written(self):
        valid, _, _, _ = an.load_sessions(REPO_ROOT / "data" / "sample_sessions_SYNTHETIC.csv")
        out = Path(tempfile.mkdtemp())
        paths = an.save_all_charts(valid, out, " (SYNTHETIC example data)")
        self.assertEqual(len(paths), 7)
        for p in paths:
            self.assertGreater(p.stat().st_size, 5000)


if __name__ == "__main__":
    unittest.main()
