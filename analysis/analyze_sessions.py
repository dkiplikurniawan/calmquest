"""Reusable analysis for CALMQUEST session records.

Loads the CSV written by the game (user://sessions.csv or an export), validates
it against the versioned schema, separates invalid records, and produces
descriptive statistics and charts.

Score convention (identical to the game, see docs/DATA_DICTIONARY.md):
    score_delta = post_stress_score - pre_stress_score
Negative = lower self-reported score after the session, positive = higher,
zero = no numerical change. Missing answers stay missing; they are never
replaced with 0.

All results are descriptive. Nothing here supports causal claims about the
game's effect on stress.

Usage:
    python analysis/analyze_sessions.py data/sample_sessions_SYNTHETIC.csv --out analysis/output
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

SCHEMA_VERSION = 1
EXPECTED_COLUMNS = [
    "schema_version",
    "session_id",
    "session_started_at",
    "pre_stress_score",
    "recommended_mode",
    "selected_mode",
    "final_mode",
    "session_duration_seconds",
    "hints_used",
    "interaction_help_events",
    "items_collected",
    "garden_restored",
    "post_stress_score",
    "score_delta",
    "experience_rating",
    "completed",
]
INT_COLUMNS = [
    "schema_version",
    "pre_stress_score",
    "session_duration_seconds",
    "hints_used",
    "interaction_help_events",
    "items_collected",
    "post_stress_score",
    "score_delta",
    "experience_rating",
]
BOOL_COLUMNS = ["garden_restored", "completed"]
MODE_COLUMNS = ["recommended_mode", "selected_mode", "final_mode"]
VALID_MODES = ("gentle", "balanced", "playful")
SCORE_RANGE = (0, 10)
RATING_RANGE = (1, 5)
# Sessions longer than this are flagged as implausible (e.g. a game left open overnight).
MAX_PLAUSIBLE_DURATION_SECONDS = 4 * 60 * 60

# Chart styling: reference data-viz palette (fixed categorical order, recessive chrome).
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_SECONDARY = "#52514e"
MUTED = "#898781"
GRID = "#e1e0d9"
BASELINE = "#c3c2b7"
SERIES = ["#2a78d6", "#eb6834", "#1baf7a"]
DIVERGING_LOW = "#2a78d6"  # lower score afterwards
DIVERGING_MID = "#b9b8b2"  # no change (neutral gray)
DIVERGING_HIGH = "#e34948"  # higher score afterwards


# ---------------------------------------------------------------------------
# Loading and validation
# ---------------------------------------------------------------------------

def load_raw(path: str | Path) -> pd.DataFrame:
    """Read every cell as text so empty cells and invalid tokens are preserved."""
    return pd.read_csv(path, dtype=str, keep_default_na=False, na_values=[])


def validate_schema(raw: pd.DataFrame) -> dict:
    """Compare the file's columns with the expected schema."""
    columns = list(raw.columns)
    versions = sorted(set(raw["schema_version"])) if "schema_version" in raw else []
    return {
        "missing_columns": [c for c in EXPECTED_COLUMNS if c not in columns],
        "unexpected_columns": [c for c in columns if c not in EXPECTED_COLUMNS],
        "column_order_matches": columns == EXPECTED_COLUMNS,
        "schema_versions": versions,
    }


def coerce_types(raw: pd.DataFrame) -> pd.DataFrame:
    """Convert text cells to typed columns. Empty cells become <NA>.

    Non-integer or non-numeric text also becomes <NA> here; find_issues()
    reports those cells so they are never silently treated as valid answers.
    """
    df = raw.copy()
    for col in INT_COLUMNS:
        numeric = pd.to_numeric(raw[col].str.strip().replace("", pd.NA), errors="coerce")
        whole = numeric.where(numeric.isna() | (numeric == numeric.round()))
        df[col] = whole.astype("Int64")
    for col in BOOL_COLUMNS:
        df[col] = raw[col].str.strip().str.lower().map({"true": True, "false": False}).astype("boolean")
    for col in MODE_COLUMNS:
        df[col] = raw[col].str.strip().replace("", pd.NA)
    df["session_started_at"] = pd.to_datetime(raw["session_started_at"], errors="coerce", format="%Y-%m-%dT%H:%M:%S")
    return df


@dataclass
class ValidationReport:
    issues: pd.DataFrame
    duplicate_ids: list[str] = field(default_factory=list)

    @property
    def invalid_session_ids(self) -> set[str]:
        return set(self.issues["session_id"])


def find_issues(raw: pd.DataFrame, df: pd.DataFrame) -> ValidationReport:
    """List every problem as (row, session_id, column, value, problem)."""
    problems: list[dict] = []

    def add(mask: pd.Series, column: str, problem: str) -> None:
        for idx in raw.index[mask.fillna(False).astype(bool)]:
            problems.append({
                "row": int(idx) + 2,  # +2: header line and 1-based numbering
                "session_id": raw.at[idx, "session_id"],
                "column": column,
                "value": raw.at[idx, column],
                "problem": problem,
            })

    for col in INT_COLUMNS:
        text = raw[col].str.strip()
        add((text != "") & df[col].isna(), col, "not a whole number")
    for col in ("pre_stress_score", "post_stress_score"):
        add((df[col] < SCORE_RANGE[0]) | (df[col] > SCORE_RANGE[1]), col, "score outside 0-10")
    add((df["experience_rating"] < RATING_RANGE[0]) | (df["experience_rating"] > RATING_RANGE[1]),
        "experience_rating", "rating outside 1-5")
    for col in ("session_duration_seconds", "hints_used", "interaction_help_events", "items_collected"):
        add(df[col] < 0, col, "negative value")
    add(df["session_duration_seconds"] > MAX_PLAUSIBLE_DURATION_SECONDS,
        "session_duration_seconds", "implausibly long session")
    add(df["session_duration_seconds"].isna(), "session_duration_seconds", "missing duration")
    for col in ("selected_mode", "final_mode"):
        add(~raw[col].str.strip().isin(VALID_MODES), col, "unknown or missing mode")
    rec = raw["recommended_mode"].str.strip()
    add((rec != "") & ~rec.isin(VALID_MODES), "recommended_mode", "unknown mode")
    for col in BOOL_COLUMNS:
        add(df[col].isna(), col, "expected true/false")
    add(df["session_started_at"].isna(), "session_started_at", "unparseable timestamp")
    add(raw["schema_version"].str.strip() != str(SCHEMA_VERSION), "schema_version", "unsupported schema version")
    expected_delta = df["post_stress_score"] - df["pre_stress_score"]
    both = df["pre_stress_score"].notna() & df["post_stress_score"].notna()
    add(both & (df["score_delta"] != expected_delta), "score_delta", "does not equal post - pre")
    add(~both & df["score_delta"].notna(), "score_delta", "delta present without both scores")

    dup_mask = raw["session_id"].duplicated(keep="first")
    add(dup_mask, "session_id", "duplicate session_id (later copy)")
    issues = pd.DataFrame(problems, columns=["row", "session_id", "column", "value", "problem"])
    return ValidationReport(issues=issues, duplicate_ids=sorted(set(raw.loc[dup_mask, "session_id"])))


def split_valid(raw: pd.DataFrame, df: pd.DataFrame, report: ValidationReport) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Return (valid records, excluded records). Rows with any issue are excluded whole."""
    bad_rows = set(report.issues["row"] - 2) if not report.issues.empty else set()
    mask = df.index.isin(bad_rows)
    return df.loc[~mask].copy(), raw.loc[mask].copy()


def load_sessions(path: str | Path) -> tuple[pd.DataFrame, pd.DataFrame, ValidationReport, dict]:
    """Load, validate and split a session CSV.

    Returns (valid_df, excluded_raw, report, schema_info). Raises ValueError if
    required columns are missing.
    """
    raw = load_raw(path)
    schema = validate_schema(raw)
    if schema["missing_columns"]:
        raise ValueError(f"Missing columns: {schema['missing_columns']}")
    df = coerce_types(raw)
    report = find_issues(raw, df)
    valid, excluded = split_valid(raw, df, report)
    return valid, excluded, report, schema


# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------

def paired_scores(df: pd.DataFrame) -> tuple[pd.DataFrame, int]:
    """Sessions with both scores, delta recomputed as post - pre.

    Returns (pairs, number_of_records_excluded_for_missing_scores).
    """
    both = df["pre_stress_score"].notna() & df["post_stress_score"].notna()
    pairs = df.loc[both].copy()
    pairs["score_delta"] = (pairs["post_stress_score"] - pairs["pre_stress_score"]).astype("Int64")
    return pairs, int((~both).sum())


def missingness(df: pd.DataFrame) -> dict[str, int]:
    pre = df["pre_stress_score"].notna()
    post = df["post_stress_score"].notna()
    return {
        "both answered": int((pre & post).sum()),
        "pre only (after skipped)": int((pre & ~post).sum()),
        "post only (before skipped)": int((~pre & post).sum()),
        "neither answered": int((~pre & ~post).sum()),
    }


def summarize(df: pd.DataFrame) -> dict:
    """Descriptive statistics for valid records."""
    pairs, excluded = paired_scores(df)
    deltas = pairs["score_delta"].astype(float)
    summary = {
        "records": int(len(df)),
        "completed_sessions": int(df["completed"].sum()),
        "paired_records": int(len(pairs)),
        "excluded_from_paired_analysis": excluded,
        "pre_score_mean": _round(df["pre_stress_score"].astype(float).mean()),
        "post_score_mean": _round(df["post_stress_score"].astype(float).mean()),
        "paired_pre_mean": _round(pairs["pre_stress_score"].astype(float).mean()),
        "paired_post_mean": _round(pairs["post_stress_score"].astype(float).mean()),
        "delta_mean": _round(deltas.mean()),
        "delta_median": _round(deltas.median()),
        "delta_negative": int((deltas < 0).sum()),
        "delta_zero": int((deltas == 0).sum()),
        "delta_positive": int((deltas > 0).sum()),
        "duration_median_minutes": _round(df["session_duration_seconds"].astype(float).median() / 60.0),
        "items_collected_median": _round(df["items_collected"].astype(float).median()),
        "garden_restored_share": _round(df["garden_restored"].astype(float).mean()),
        "selected_mode_counts": df["selected_mode"].value_counts().to_dict(),
        "final_mode_counts": df["final_mode"].value_counts().to_dict(),
        "missingness": missingness(df),
    }
    return summary


def describe_change(summary: dict) -> str:
    """Neutral, descriptive sentence about paired scores (never causal)."""
    n = summary["paired_records"]
    if n == 0:
        return "No sessions have both a pre- and a post-session score, so no comparison is possible."
    pre, post = summary["paired_pre_mean"], summary["paired_post_mean"]
    if post < pre:
        direction = "lower than"
    elif post > pre:
        direction = "higher than"
    else:
        direction = "the same as"
    return (
        f"In this dataset (n = {n} paired sessions), the average post-session self-reported score "
        f"({post}) was {direction} the average pre-session score ({pre}). This is a descriptive "
        "observation about self-reports; it does not show that the game caused any change."
    )


def _round(value: float, digits: int = 2) -> float | None:
    if value is None or pd.isna(value):
        return None
    return round(float(value), digits)


# ---------------------------------------------------------------------------
# Charts
# ---------------------------------------------------------------------------

def _style_axes(ax, title: str, xlabel: str, ylabel: str, subtitle: str = "", label: str = "") -> None:
    """Recessive chrome; title and subtitle sit on the figure so they never clip."""
    fig = ax.figure
    ax.set_facecolor(SURFACE)
    fig.text(0.02, 0.965, title, color=INK, fontsize=12, fontweight="bold", va="top", ha="left")
    note = f"{label.strip(' ()')} | {subtitle}" if label else subtitle
    if note:
        fig.text(0.02, 0.905, note, color=INK_SECONDARY, fontsize=9, va="top", ha="left")
    ax.set_xlabel(xlabel, color=INK_SECONDARY)
    ax.set_ylabel(ylabel, color=INK_SECONDARY)
    ax.tick_params(colors=MUTED, labelcolor=INK_SECONDARY)
    ax.grid(axis="y", color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(BASELINE)


def _finish(fig) -> None:
    fig.tight_layout(rect=(0, 0, 1, 0.86))


def _new_figure(width: float = 7.0, height: float = 4.0):
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(width, height), dpi=110)
    fig.patch.set_facecolor(SURFACE)
    return fig, ax


def chart_pre_post(pairs: pd.DataFrame, label: str = ""):
    """Paired slope chart: one thin line per session, means highlighted."""
    fig, ax = _new_figure(6.0, 4.4)
    for _, row in pairs.iterrows():
        ax.plot([0, 1], [row["pre_stress_score"], row["post_stress_score"]], color=MUTED, alpha=0.35, linewidth=1)
    pre_mean = pairs["pre_stress_score"].astype(float).mean()
    post_mean = pairs["post_stress_score"].astype(float).mean()
    ax.plot([0, 1], [pre_mean, post_mean], color=SERIES[0], linewidth=2.5, marker="o", markersize=8, zorder=3)
    ax.annotate(f"mean {pre_mean:.1f}", (0, pre_mean), xytext=(-12, 0), textcoords="offset points", ha="right", va="center", color=INK)
    ax.annotate(f"mean {post_mean:.1f}", (1, post_mean), xytext=(12, 0), textcoords="offset points", ha="left", va="center", color=INK)
    ax.set_xticks([0, 1], ["Before session", "After session"])
    ax.set_xlim(-0.6, 1.6)
    ax.set_ylim(-0.5, 10.5)
    _style_axes(ax, "Self-reported stress before and after", "", "Self-reported score (0-10)",
                f"n = {len(pairs)} sessions with both answers; grey lines are individual sessions", label=label)
    _finish(fig)
    return fig


def chart_score_distribution(df: pd.DataFrame, column: str, title: str, label: str = ""):
    """Counts of one 0-10 score column; missing answers reported, not plotted as 0."""
    fig, ax = _new_figure()
    answered = df[column].dropna().astype(int)
    xs = list(range(SCORE_RANGE[0], SCORE_RANGE[1] + 1))
    ys = [int((answered == x).sum()) for x in xs]
    bars = ax.bar(xs, ys, color=SERIES[0], width=0.8, edgecolor=SURFACE, linewidth=2)
    for bar, y in zip(bars, ys):
        if y > 0:
            ax.text(bar.get_x() + bar.get_width() / 2, y, str(y), ha="center", va="bottom", color=INK, fontsize=9)
    ax.set_xticks(xs)
    missing = int(df[column].isna().sum())
    _style_axes(ax, title, "Self-reported score (0 = very calm, 10 = extremely stressed)", "Sessions",
                f"n = {len(answered)} answered; {missing} skipped (not shown)", label=label)
    _finish(fig)
    return fig


def chart_delta_distribution(pairs: pd.DataFrame, label: str = ""):
    """Counts of score_delta values on a diverging blue / grey / red scale."""
    fig, ax = _new_figure()
    counts = pairs["score_delta"].astype(int).value_counts().sort_index()
    lo, hi = min(-3, counts.index.min()), max(3, counts.index.max())
    xs = list(range(lo, hi + 1))
    ys = [int(counts.get(x, 0)) for x in xs]
    colors = [DIVERGING_LOW if x < 0 else DIVERGING_HIGH if x > 0 else DIVERGING_MID for x in xs]
    bars = ax.bar(xs, ys, color=colors, width=0.8, edgecolor=SURFACE, linewidth=2)
    for bar, y in zip(bars, ys):
        if y > 0:
            ax.text(bar.get_x() + bar.get_width() / 2, y, str(y), ha="center", va="bottom", color=INK, fontsize=9)
    ax.set_xticks(xs)
    _style_axes(ax, "Change in self-reported score (post - pre)", "score_delta (points)", "Sessions",
                f"n = {len(pairs)}; left of 0 = lower afterwards, right of 0 = higher afterwards", label=label)
    _finish(fig)
    return fig


def chart_modes(df: pd.DataFrame, label: str = ""):
    """Grouped bars: mode chosen at the start vs mode at the end."""
    import numpy as np

    fig, ax = _new_figure()
    x = np.arange(len(VALID_MODES))
    selected = [int((df["selected_mode"] == m).sum()) for m in VALID_MODES]
    final = [int((df["final_mode"] == m).sum()) for m in VALID_MODES]
    width = 0.38
    b1 = ax.bar(x - width / 2 - 0.01, selected, width, color=SERIES[0], label="Selected at start")
    b2 = ax.bar(x + width / 2 + 0.01, final, width, color=SERIES[1], label="Mode at end")
    for bars in (b1, b2):
        for bar in bars:
            ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(), str(int(bar.get_height())),
                    ha="center", va="bottom", color=INK, fontsize=9)
    ax.set_xticks(x, [m.capitalize() for m in VALID_MODES])
    ax.legend(frameon=False, labelcolor=INK_SECONDARY)
    _style_axes(ax, "Sessions by gameplay mode", "Mode", "Sessions", f"n = {len(df)} valid records", label=label)
    _finish(fig)
    return fig


def chart_duration(df: pd.DataFrame, label: str = ""):
    fig, ax = _new_figure()
    minutes = df["session_duration_seconds"].astype(float) / 60.0
    ax.hist(minutes, bins=12, color=SERIES[0], edgecolor=SURFACE, linewidth=2)
    _style_axes(ax, "Session duration", "Minutes", "Sessions",
                f"n = {len(df)}; median {minutes.median():.1f} min", label=label)
    _finish(fig)
    return fig


def chart_items(df: pd.DataFrame, label: str = ""):
    fig, ax = _new_figure()
    counts = df["items_collected"].astype(int).value_counts().sort_index()
    ax.bar(counts.index, counts.values, color=SERIES[2], width=0.8, edgecolor=SURFACE, linewidth=2)
    _style_axes(ax, "Items collected per session", "Items collected", "Sessions",
                f"n = {len(df)}; lights, bonus Prism Motes and lanterns combined", label=label)
    _finish(fig)
    return fig


def chart_missingness(df: pd.DataFrame, label: str = ""):
    fig, ax = _new_figure()
    data = missingness(df)
    names = list(data.keys())
    values = list(data.values())
    bars = ax.barh(names, values, color=SERIES[0], height=0.6)
    for bar, v in zip(bars, values):
        ax.text(v, bar.get_y() + bar.get_height() / 2, f"  {v}", va="center", color=INK, fontsize=9)
    ax.invert_yaxis()
    _style_axes(ax, "Which reflection questions were answered", "Sessions", "",
                f"n = {len(df)} valid records; skipped answers are kept as missing, never as 0", label=label)
    ax.grid(axis="y", visible=False)
    ax.grid(axis="x", color=GRID, linewidth=0.8)
    _finish(fig)
    return fig


def chart_duration_vs_delta(pairs: pd.DataFrame, label: str = ""):
    fig, ax = _new_figure()
    minutes = pairs["session_duration_seconds"].astype(float) / 60.0
    ax.scatter(minutes, pairs["score_delta"].astype(float), s=36, color=SERIES[0], edgecolor=SURFACE, linewidth=1.5, alpha=0.85)
    ax.axhline(0, color=BASELINE, linewidth=1)
    _style_axes(ax, "Session duration vs. score change", "Session duration (minutes)", "score_delta (points)",
                f"n = {len(pairs)}; descriptive only - an association here would not imply causation", label=label)
    _finish(fig)
    return fig


def save_all_charts(df: pd.DataFrame, out_dir: str | Path, label: str = "") -> list[Path]:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    pairs, _ = paired_scores(df)
    charts = {
        "missingness.png": chart_missingness(df, label),
        "modes.png": chart_modes(df, label),
        "duration.png": chart_duration(df, label),
        "items_collected.png": chart_items(df, label),
    }
    if len(pairs) > 0:
        charts["pre_post.png"] = chart_pre_post(pairs, label)
        charts["score_delta.png"] = chart_delta_distribution(pairs, label)
        charts["duration_vs_delta.png"] = chart_duration_vs_delta(pairs, label)
    paths = []
    for name, fig in charts.items():
        path = out / name
        fig.savefig(path, facecolor=SURFACE)
        plt.close(fig)
        paths.append(path)
    return paths


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyze CALMQUEST session records (descriptive only).")
    parser.add_argument("csv", help="Path to sessions.csv or an exported CSV")
    parser.add_argument("--out", default="analysis/output", help="Folder for charts and summary.json")
    parser.add_argument("--no-charts", action="store_true", help="Skip chart generation")
    args = parser.parse_args(argv)

    path = Path(args.csv)
    if not path.exists():
        print(f"File not found: {path}", file=sys.stderr)
        return 2
    synthetic = "SYNTHETIC" in path.name.upper()
    label = " (SYNTHETIC example data)" if synthetic else ""
    valid, excluded, report, schema = load_sessions(path)

    print(f"File: {path}")
    if synthetic:
        print("NOTE: this file is SYNTHETIC example data. Results demonstrate the pipeline only.")
    print(f"Schema: {json.dumps(schema)}")
    print(f"Records: {len(valid) + len(excluded)} total, {len(valid)} valid, {len(excluded)} excluded")
    if not report.issues.empty:
        print("Validation issues:")
        print(report.issues.to_string(index=False))
    summary = summarize(valid)
    print(json.dumps(summary, indent=2, default=str))
    print(describe_change(summary))

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    payload = {"source": str(path), "synthetic": synthetic, "schema": schema, "summary": summary,
               "excluded_records": int(len(excluded)), "interpretation": describe_change(summary)}
    (out / "summary.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    if not args.no_charts:
        for p in save_all_charts(valid, out, label):
            print(f"Chart: {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
