# Data Dictionary - session records (schema version 1)

**Source of truth:** `SessionRecord.COLUMNS` in `game/scripts/data/session_record.gd`. The Python test `test_columns_match_the_game_schema` fails if `analysis/analyze_sessions.py` disagrees with it.

**File:** `user://sessions.csv`, which on Windows is `%APPDATA%\CALMQUEST\sessions.csv`. Records are written only when the player ticked the consent box at the check-in.

**Format:**
- UTF-8, comma-separated, one header row, `\n` line endings.
- Fields containing commas, quotes or line breaks are quoted RFC 4180-style.
- Empty cell = missing value. Booleans are `true` / `false`.
- The file reads with `pandas.read_csv` without extra options.

## Columns

| # | Column | Type | Allowed values / range | Missing allowed? | Meaning |
|---|---|---|---|---|---|
| 1 | `schema_version` | integer | `1` | no | Version of this schema. Bumped on any change to columns or meaning. |
| 2 | `session_id` | string | `cq-` + 16 lowercase hex characters | no | Random identifier created when the session starts. Contains no personal information and is not linked across sessions. |
| 3 | `session_started_at` | string (ISO 8601, local time, no timezone) | e.g. `2026-10-11T14:05:09` | no | Wall-clock time on the player's computer when the session began. |
| 4 | `pre_stress_score` | integer | 0-10 | **yes** (check-in skipped or slider not touched) | Self-reported "how stressed do you feel right now?" before playing. 0 = very calm, 5 = moderately stressed, 10 = extremely stressed. A subjective reflection, not a measurement. |
| 5 | `recommended_mode` | string | `gentle`, `balanced`, `playful` | **yes** (empty when no pre score) | Mode suggested by the transparent policy: 7-10 -> gentle, 4-6 -> balanced, 0-3 -> the player is asked to choose Balanced or Playful, with `balanced` pre-selected and recorded. |
| 6 | `selected_mode` | string | `gentle`, `balanced`, `playful` | no | Mode the player actually chose when starting. May differ from the recommendation (an override). |
| 7 | `final_mode` | string | `gentle`, `balanced`, `playful` | no | Mode active when the session ended (players may switch in the pause menu). |
| 8 | `session_duration_seconds` | integer | >= 0 | no | Seconds from session start to Finish Session (or to leaving mid-session). Includes time spent paused. |
| 9 | `hints_used` | integer | >= 0 | no | Number of explicit hint requests (H key or "Ask Lumi" button). |
| 10 | `interaction_help_events` | integer | >= 0 | no | Times the game explained the interact control and showed the reach circle, triggered after 2 consecutive E presses just outside reach (`OUT_OF_RANGE_HELP_THRESHOLD`). |
| 11 | `items_collected` | integer | >= 0 | no | Light motes + bonus Prism Motes + Lantern Catch lanterns collected in this session. Hidden details are not counted. |
| 12 | `garden_restored` | boolean | `true` / `false` | no | Whether the Heart Tree was restored during this session. |
| 13 | `post_stress_score` | integer | 0-10 | **yes** (reflection skipped, slider not touched, or session left early) | Same question as `pre_stress_score`, asked after playing. |
| 14 | `score_delta` | integer | -10 to 10 | **yes** (empty unless both scores exist) | `post_stress_score - pre_stress_score`. Negative = lower self-report afterwards; positive = higher; 0 = no numerical change. |
| 15 | `experience_rating` | integer | 1-5 | **yes** | Optional "How did the game feel to play?" (1 = not for me, 5 = lovely). About the game, not about well-being. |
| 16 | `completed` | boolean | `true` / `false` | no | `true` if the player ended through Finish Session (then reflection or skip, then results). `false` if they left mid-session via Main Menu or closed the window. |

## Missing values

- Missing answers are **never** stored as `0`, because 0 is a valid "very calm" answer.
- The game does not store a slider answer unless the player moved or clicked the slider.
- Analysis code excludes incomplete pairs from paired calculations and reports how many were excluded.

## Validation rules (game and analysis)

| Rule | Game (`SessionRecord.validate`) | Analysis (`find_issues`) |
|---|---|---|
| Scores are whole numbers 0-10 or missing | refuses to write | row excluded, reported |
| Rating is a whole number 1-5 or missing | refuses to write | row excluded, reported |
| Modes are known values | refuses to write | row excluded, reported |
| Durations and counters are not negative | refuses to write | row excluded, reported |
| Duration of 4 hours or less | - | flagged as implausible, excluded |
| `score_delta` equals post - pre | computed, never typed in | mismatch excluded, reported |
| Unique `session_id` | random 64-bit ID | later duplicates excluded |
| Header matches schema | refuses to append to a mismatching file | missing columns raise an error |

## Related files (not session data)

- `user://progress.cfg`: journal progress (`heart_tree_restorations`, `lantern_nights_completed`, `discoveries`). It never contains self-reported answers.
- `user://settings.cfg`: volume, display, accessibility and language preferences.
