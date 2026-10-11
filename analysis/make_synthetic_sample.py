"""Generate the SYNTHETIC example dataset in data/sample_sessions_SYNTHETIC.csv.

These rows are invented with a fixed random seed. They are NOT player data and
must never be presented as real results. They exist only to demonstrate and
test the analysis pipeline. A few deliberately invalid rows are appended at the
end so the validation steps have something to catch (see data/README.md).

Usage:
    python analysis/make_synthetic_sample.py
"""
from __future__ import annotations

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

from analyze_sessions import EXPECTED_COLUMNS

SEED = 20261011
N_VALID = 60
OUT = Path(__file__).resolve().parent.parent / "data" / "sample_sessions_SYNTHETIC.csv"


def recommend(score: int | None) -> str:
    # Mirrors AdaptiveComfortEngine.recommend(); 0-3 pre-selects Balanced.
    if score is None:
        return ""
    if score >= 7:
        return "gentle"
    return "balanced"


def make_row(rng: random.Random, start: datetime) -> dict:
    pre = None if rng.random() < 0.2 else rng.randint(0, 10)
    recommended = recommend(pre)
    if recommended and rng.random() < 0.75:
        selected = recommended
    else:
        selected = rng.choice(["gentle", "balanced", "playful"])
    final = selected if rng.random() < 0.8 else rng.choice(["gentle", "balanced", "playful"])
    duration = int(max(60, rng.gauss(480, 170)))
    items = max(0, min(25, int(rng.gauss(10, 4))))
    restored = items >= 8 and rng.random() < 0.85
    post = None
    if pre is None:
        post = rng.choice([None, rng.randint(0, 10)])
    elif rng.random() < 0.82:
        # Arbitrary invented change, centered near zero, with spread both ways.
        post = max(0, min(10, pre + round(rng.gauss(-0.3, 1.6))))
    delta = "" if pre is None or post is None else post - pre
    rating = rng.choice(["", 2, 3, 4, 4, 5, 5]) if post is not None else ""
    return {
        "schema_version": 1,
        "session_id": "cq-" + "".join(rng.choice("0123456789abcdef") for _ in range(16)),
        "session_started_at": start.strftime("%Y-%m-%dT%H:%M:%S"),
        "pre_stress_score": "" if pre is None else pre,
        "recommended_mode": recommended,
        "selected_mode": selected,
        "final_mode": final,
        "session_duration_seconds": duration,
        "hints_used": max(0, int(rng.gauss(1.5 if selected == "gentle" else 0.8, 1.2))),
        "interaction_help_events": rng.choice([0, 0, 0, 0, 1]),
        "items_collected": items,
        "garden_restored": "true" if restored else "false",
        "post_stress_score": "" if post is None else post,
        "score_delta": delta,
        "experience_rating": rating,
        "completed": "true" if post is not None or rng.random() < 0.6 else "false",
    }


def main() -> None:
    rng = random.Random(SEED)
    start = datetime(2026, 9, 1, 9, 0, 0)
    rows = []
    for _ in range(N_VALID):
        start += timedelta(hours=rng.randint(3, 30), minutes=rng.randint(0, 59))
        rows.append(make_row(rng, start))
    # Deliberately invalid rows (documented in data/README.md):
    bad = dict(rows[3])
    bad["session_id"] = "cq-badbadbadbad0001"
    bad["pre_stress_score"] = 12                       # out of range
    rows.append(bad)
    bad = dict(rows[5])
    bad["session_id"] = "cq-badbadbadbad0002"
    bad["session_duration_seconds"] = -40              # negative duration
    rows.append(bad)
    rows.append(dict(rows[7]))                          # exact duplicate session
    bad = dict(rows[9])
    bad["session_id"] = "cq-badbadbadbad0003"
    bad["pre_stress_score"], bad["post_stress_score"], bad["score_delta"] = 6, 4, 2   # wrong sign
    rows.append(bad)
    bad = dict(rows[11])
    bad["session_id"] = "cq-badbadbadbad0004"
    bad["hints_used"] = "two"                          # not a number
    rows.append(bad)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=EXPECTED_COLUMNS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} SYNTHETIC rows to {OUT}")


if __name__ == "__main__":
    main()
