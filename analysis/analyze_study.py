"""Descriptive analysis of CALMQUEST Study Mode data, grouped by participant.

Reads study_sessions.csv (exported from Data & Privacy in Study Mode). Each
row has 6 study columns followed by the 16 schema-v1 session columns, in the
same order and with the same meaning as sessions.csv. The v1 part is validated
with exactly the same rules as analyze_sessions.py (reused, not copied).
Optionally reads study_events.csv for coarse activity counts.

Score convention (identical to the game):
    score_delta = post_stress_score - pre_stress_score
Missing answers stay missing; they are never replaced with 0.

All results are descriptive. Nothing here supports causal claims about the
game's effect on stress.

Usage:
    python analysis/analyze_study.py study_sessions.csv --events study_events.csv --out analysis/output/study
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import analyze_sessions as sessions  # noqa: E402

STUDY_SCHEMA_VERSION = 1
STUDY_COLUMNS = [
    "study_schema_version",
    "participant_code",
    "language",
    "build_version",
    "git_commit",
    "target_duration_seconds",
]
EXPECTED_COLUMNS = STUDY_COLUMNS + sessions.EXPECTED_COLUMNS
EVENT_COLUMNS = ["participant_code", "session_id", "t_seconds", "event", "detail"]
PARTICIPANT_PATTERN = re.compile(r"^P\d{2,3}$")
LANGUAGES = ("en", "id")
DURATIONS_SECONDS = (600, 900, 1200)


def validate_schema(raw: pd.DataFrame) -> dict:
    columns = list(raw.columns)
    return {
        "missing_columns": [c for c in EXPECTED_COLUMNS if c not in columns],
        "unexpected_columns": [c for c in columns if c not in EXPECTED_COLUMNS],
        "column_order_matches": columns == EXPECTED_COLUMNS,
    }


def study_issues(raw: pd.DataFrame) -> pd.DataFrame:
    """Problems in the 6 study columns, as (row, session_id, column, value, problem)."""
    problems: list[dict] = []

    def add(mask: pd.Series, column: str, problem: str) -> None:
        for idx in raw.index[mask.fillna(False).astype(bool)]:
            problems.append({"row": int(idx) + 2, "session_id": raw.at[idx, "session_id"], "column": column,
                             "value": raw.at[idx, column], "problem": problem})

    add(raw["study_schema_version"].str.strip() != str(STUDY_SCHEMA_VERSION), "study_schema_version", "unsupported study schema version")
    add(~raw["participant_code"].str.strip().str.match(PARTICIPANT_PATTERN), "participant_code", "participant code must be P + 2-3 digits")
    add(~raw["language"].str.strip().isin(LANGUAGES), "language", "unknown language")
    duration = pd.to_numeric(raw["target_duration_seconds"].str.strip(), errors="coerce")
    add(~duration.isin(DURATIONS_SECONDS), "target_duration_seconds", "target duration must be 600, 900 or 1200")
    return pd.DataFrame(problems, columns=["row", "session_id", "column", "value", "problem"])


def load_study(path: str | Path) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, dict]:
    """Load, validate and split a study CSV.

    Returns (valid_df, excluded_raw, issues, schema_info). valid_df has the
    typed v1 columns plus participant_code, language and target_duration_seconds.
    Raises ValueError if required columns are missing.
    """
    raw = sessions.load_raw(path)
    schema = validate_schema(raw)
    if schema["missing_columns"]:
        raise ValueError(f"Missing columns: {schema['missing_columns']}")
    v1_raw = raw[sessions.EXPECTED_COLUMNS]
    v1 = sessions.coerce_types(v1_raw)
    report = sessions.find_issues(v1_raw, v1)
    issues = pd.concat([report.issues, study_issues(raw)], ignore_index=True)
    bad_rows = set(issues["row"] - 2) if not issues.empty else set()
    mask = raw.index.isin(bad_rows)
    valid = v1.loc[~mask].copy()
    valid["participant_code"] = raw.loc[~mask, "participant_code"].str.strip()
    valid["language"] = raw.loc[~mask, "language"].str.strip()
    valid["target_duration_seconds"] = pd.to_numeric(raw.loc[~mask, "target_duration_seconds"]).astype("Int64")
    return valid, raw.loc[mask].copy(), issues, schema


def by_participant(valid: pd.DataFrame) -> pd.DataFrame:
    """One row per participant code (descriptive only)."""
    rows = []
    for code, group in valid.groupby("participant_code", sort=True):
        pairs, _ = sessions.paired_scores(group)
        deltas = pairs["score_delta"].astype(float)
        rows.append({
            "participant_code": code,
            "sessions": int(len(group)),
            "completed_sessions": int(group["completed"].sum()),
            "paired_sessions": int(len(pairs)),
            "pre_mean": sessions._round(pairs["pre_stress_score"].astype(float).mean()),
            "post_mean": sessions._round(pairs["post_stress_score"].astype(float).mean()),
            "delta_mean": sessions._round(deltas.mean()),
            "duration_median_minutes": sessions._round(group["session_duration_seconds"].astype(float).median() / 60.0),
            "languages": ",".join(sorted(set(group["language"]))),
            "final_modes": ",".join(sorted(set(group["final_mode"].dropna()))),
        })
    return pd.DataFrame(rows, columns=["participant_code", "sessions", "completed_sessions", "paired_sessions", "pre_mean",
                                       "post_mean", "delta_mean", "duration_median_minutes", "languages", "final_modes"])


def load_events(path: str | Path) -> pd.DataFrame:
    raw = sessions.load_raw(path)
    missing = [c for c in EVENT_COLUMNS if c not in raw.columns]
    if missing:
        raise ValueError(f"Missing event columns: {missing}")
    raw["t_seconds"] = pd.to_numeric(raw["t_seconds"], errors="coerce")
    return raw


def event_counts(events: pd.DataFrame) -> pd.DataFrame:
    """How often each event happened per participant (a long, tidy table)."""
    if events.empty:
        return pd.DataFrame(columns=["participant_code", "event", "count"])
    counts = events.groupby(["participant_code", "event"]).size().reset_index(name="count")
    return counts.sort_values(["participant_code", "event"]).reset_index(drop=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyze CALMQUEST Study Mode data by participant (descriptive only).")
    parser.add_argument("csv", help="Path to study_sessions.csv (or an export)")
    parser.add_argument("--events", help="Optional path to study_events.csv")
    parser.add_argument("--out", default="analysis/output/study", help="Folder for the summary files")
    args = parser.parse_args(argv)

    path = Path(args.csv)
    if not path.exists():
        print(f"File not found: {path}", file=sys.stderr)
        return 2
    valid, excluded, issues, schema = load_study(path)
    print(f"File: {path}")
    print(f"Schema: {json.dumps(schema)}")
    print(f"Records: {len(valid) + len(excluded)} total, {len(valid)} valid, {len(excluded)} excluded")
    if not issues.empty:
        print("Validation issues:")
        print(issues.to_string(index=False))
    table = by_participant(valid)
    print(table.to_string(index=False))
    overall = sessions.summarize(valid) if not valid.empty else {}
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    table.to_csv(out / "by_participant.csv", index=False)
    payload = {"source": str(path), "schema": schema, "participants": int(len(table)), "excluded_records": int(len(excluded)),
               "overall": overall, "interpretation": sessions.describe_change(overall) if overall else ""}
    if args.events:
        counts = event_counts(load_events(args.events))
        counts.to_csv(out / "event_counts.csv", index=False)
        payload["events_file"] = args.events
        print(counts.to_string(index=False))
    (out / "summary.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    if overall:
        print(sessions.describe_change(overall))
    return 0


if __name__ == "__main__":
    sys.exit(main())
