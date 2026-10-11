"""Unit tests for analysis/analyze_study.py (standard-library unittest).

Run from the repository root:
    python -m unittest discover -s analysis/tests -v
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ANALYSIS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ANALYSIS_DIR))

import analyze_study as st  # noqa: E402
import analyze_sessions as an  # noqa: E402

HEADER = ",".join(st.EXPECTED_COLUMNS)


def row(**overrides) -> str:
    values = {
        "study_schema_version": "1", "participant_code": "P01", "language": "id", "build_version": "0.4.0",
        "git_commit": "", "target_duration_seconds": "900",
        "schema_version": "1", "session_id": "cq-0000000000000001", "session_started_at": "2026-10-01T10:00:00",
        "pre_stress_score": "7", "recommended_mode": "gentle", "selected_mode": "gentle", "final_mode": "gentle",
        "session_duration_seconds": "900", "hints_used": "1", "interaction_help_events": "0", "items_collected": "9",
        "garden_restored": "true", "post_stress_score": "4", "score_delta": "-3", "experience_rating": "4",
        "completed": "true",
    }
    values.update(overrides)
    return ",".join(values[c] for c in st.EXPECTED_COLUMNS)


_TEMP_FILES: list[Path] = []


def write(text: str) -> Path:
    tmp = tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False, encoding="utf-8", newline="")
    tmp.write(text)
    tmp.close()
    _TEMP_FILES.append(Path(tmp.name))
    return Path(tmp.name)


def tearDownModule() -> None:
    for path in _TEMP_FILES:
        path.unlink(missing_ok=True)


class StudySchemaTests(unittest.TestCase):
    def test_header_is_study_columns_then_v1_columns(self):
        self.assertEqual(st.EXPECTED_COLUMNS[:6], st.STUDY_COLUMNS)
        self.assertEqual(st.EXPECTED_COLUMNS[6:], an.EXPECTED_COLUMNS)
        self.assertEqual(len(st.EXPECTED_COLUMNS), 22)

    def test_missing_columns_raise(self):
        path = write("participant_code,session_id\nP01,cq-1\n")
        with self.assertRaises(ValueError):
            st.load_study(path)


class StudyValidationTests(unittest.TestCase):
    def test_valid_rows_and_bad_participant_codes(self):
        path = write("\n".join([
            HEADER,
            row(),
            row(participant_code="X9", session_id="cq-0000000000000002"),
            row(participant_code="P1234", session_id="cq-0000000000000003"),
        ]) + "\n")
        valid, excluded, issues, _ = st.load_study(path)
        self.assertEqual(len(valid), 1)
        self.assertEqual(len(excluded), 2)
        self.assertTrue((issues["column"] == "participant_code").all())

    def test_v1_rules_are_reused(self):
        path = write("\n".join([HEADER, row(score_delta="-2"), row(session_id="cq-0000000000000002", target_duration_seconds="700")]) + "\n")
        valid, excluded, issues, _ = st.load_study(path)
        self.assertEqual(len(valid), 0)
        self.assertIn("does not equal post - pre", set(issues["problem"]))
        self.assertIn("target duration must be 600, 900 or 1200", set(issues["problem"]))

    def test_missing_answers_stay_missing(self):
        path = write("\n".join([HEADER, row(post_stress_score="", score_delta="", experience_rating="")]) + "\n")
        valid, _, _, _ = st.load_study(path)
        self.assertEqual(len(valid), 1)
        self.assertTrue(valid["post_stress_score"].isna().all())
        self.assertTrue(valid["score_delta"].isna().all())


class ByParticipantTests(unittest.TestCase):
    def test_grouping_and_delta(self):
        path = write("\n".join([
            HEADER,
            row(participant_code="P01", session_id="cq-0000000000000001", pre_stress_score="7", post_stress_score="4", score_delta="-3"),
            row(participant_code="P01", session_id="cq-0000000000000002", pre_stress_score="5", post_stress_score="5", score_delta="0", language="en"),
            row(participant_code="P02", session_id="cq-0000000000000003", pre_stress_score="6", post_stress_score="", score_delta=""),
        ]) + "\n")
        valid, _, _, _ = st.load_study(path)
        table = st.by_participant(valid).set_index("participant_code")
        self.assertEqual(list(table.index), ["P01", "P02"])
        self.assertEqual(table.loc["P01", "sessions"], 2)
        self.assertEqual(table.loc["P01", "paired_sessions"], 2)
        self.assertEqual(table.loc["P01", "delta_mean"], -1.5)
        self.assertEqual(table.loc["P01", "languages"], "en,id")
        self.assertEqual(table.loc["P02", "paired_sessions"], 0)

    def test_events_are_counted_per_participant(self):
        path = write("\n".join([
            ",".join(st.EVENT_COLUMNS),
            "P01,cq-1,1.0,region_entered,whispering_meadow",
            "P01,cq-1,40.5,region_entered,firefly_grove",
            "P01,cq-1,60.0,activity_started,fishing",
            "P02,cq-2,5.0,hint_requested,",
        ]) + "\n")
        counts = st.event_counts(st.load_events(path))
        p1 = counts[(counts["participant_code"] == "P01") & (counts["event"] == "region_entered")]
        self.assertEqual(int(p1["count"].iloc[0]), 2)
        self.assertEqual(len(counts), 3)

    def test_main_writes_outputs(self):
        path = write("\n".join([HEADER, row()]) + "\n")
        with tempfile.TemporaryDirectory() as out:
            self.assertEqual(st.main([str(path), "--out", out, "--events", str(write(",".join(st.EVENT_COLUMNS) + "\n"))]), 0)
            self.assertTrue((Path(out) / "by_participant.csv").exists())
            self.assertTrue((Path(out) / "summary.json").exists())


if __name__ == "__main__":
    unittest.main()
