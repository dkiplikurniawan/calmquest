# Test Plan and Observed Results

> **V2 note (2026-10-11):** this file records the V1 cases. After V2 milestone M2, the automated suite has 13 checks:
> - 64 unit tests;
> - a 165-check V1 smoke test, retargeted to the overworld (whole-world reachability);
> - a 68-check V2 overworld test;
> - 30 UI checks;
> - 6 screens;
> - 13 Python tests.
>
> All 13 checks pass. V2 manual checks are listed in [MANUAL_TEST_CHECKLIST.md](MANUAL_TEST_CHECKLIST.md); details are in [V2_PROGRESS.md](V2_PROGRESS.md).

**Environment of the recorded run:** Windows 11 Home, Godot 4.7.2-stable (official build, GL Compatibility; headless for automated runs, NVIDIA RTX 3050 Laptop GPU for the rendered screenshot run), Python 3.12.10, pandas 2.2.2, matplotlib 3.8.4. Date: 2026-10-11.

**How to reproduce:** `powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1 -Godot <path-to-Godot_console.exe>`

**Status legend:**

| Status | Meaning |
|---|---|
| **PASS (auto)** | executed by an automated test in the recorded run |
| **PASS (render)** | verified by rendering the real game and inspecting the screenshots in `screenshots/` |
| **MANUAL** | needs a human at the keyboard; **not yet executed** |
| **NOT TESTED** | not executed in any form |

## Automated suites (recorded run)

| Suite | Command / file | Result |
|---|---|---|
| Static references | `python tools/check_references.py` | 66 `res://` references, 0 missing |
| Godot import | `godot --headless --path . --import` | exit 0 |
| GDScript unit tests | `tests/run_tests.gd` (engine, score comparison, CSV/record/storage, Lumi wording) | 44 run, 44 passed |
| Integration smoke test | `tests/smoke/smoke_test.tscn` (real meadow + autoloads) | 109 checks, 0 failed |
| UI smoke test | `tests/smoke/ui_smoke_test.tscn` | 27 checks, 0 failed |
| Screen load | each of 6 screens run headless for 120 frames | 6/6 without script errors |
| Python tests | `python -m unittest discover -s analysis/tests` | 13 run, OK |
| Notebook | `jupyter nbconvert --execute analysis/session_analysis.ipynb` | 38 cells, 0 errors |

**Known non-blocking warning:** in some headless runs Godot prints "2 ObjectDB instances were leaked at exit". `--verbose` shows these are the audio stream and playback objects, released asynchronously by the audio server when the process is force-quit. They do not occur during play.

## Application startup

| Case | Status | Evidence |
|---|---|---|
| Project imports and opens | PASS (auto) | import exit 0 |
| No missing assets or scripts | PASS (auto) | reference check, 6 screens load without script errors |
| Main menu appears correctly | PASS (render) | `01_main_menu.png` |
| Start Adventure, then check-in, then meadow | MANUAL | routes are verified to exist; the click flow itself is not automated |
| Back navigation (Escape, Back buttons) | MANUAL | |
| Quit Game closes the app | MANUAL | |
| Splash can be skipped with any key | MANUAL | |

## Player controls

| Case | Status | Evidence |
|---|---|---|
| WASD and arrow keys move | MANUAL | both bound in `InputSetup.BINDINGS` |
| Diagonal movement normalized | PASS (by construction) | `Input.get_vector` clamps length to 1. Not measured at runtime |
| Collision with trees, stones, cottage, pond, tree trunk, shrine | PASS (auto) | flood-fill uses real collision shapes |
| Player cannot leave the map | PASS (auto) | flood fill stays inside walls: all 5032 free cells form one region bounded by `PLAY_RECT` walls |
| Interaction only within reach | PASS (auto) | smoke: "cannot target a light from far away", "nothing collected from a distance" |

## Gameplay

| Case | Status | Evidence |
|---|---|---|
| Collectibles appear (12 lights, 3 prisms) | PASS (auto + render) | smoke; `03_meadow_gentle.png` |
| Collectibles can be collected | PASS (auto) | all 12 lights, a prism and 6 lanterns collected |
| A collectible cannot be counted twice | PASS (auto) | collected mote not targetable; SessionState rejects duplicate IDs; unit test |
| HUD updates | PASS (render) | `03` "Light 0 / 8"; `04` objective switches after restoration |
| Restoration requirement achievable | PASS (auto) | 12 lights >= 8 + 3 beds; every interactable reachable in the flood fill |
| Garden changes visibly after restoration | PASS (auto + render) | `restored` flag; `04_heart_tree_restored.png` |
| Progress and completion messages correct | PASS (render) | toast, Lumi line, `05_session_complete.png` |
| Restart keeps no duplicate state | PASS (auto) | "restart clears collected state", "restart keeps check-in answer" |
| Hidden detail discovery recorded | PASS (auto) | smoke |
| Lantern Catch start / complete / replay / end early | PASS (auto + render) | smoke; `06_lantern_catch_night.png` |

## Companion

| Case | Status | Evidence |
|---|---|---|
| Lumi follows the player | PASS (render) | Lumi beside the player in all gameplay screenshots |
| Lumi does not jitter when the player stops | MANUAL | dead zone + exponential smoothing implemented |
| Lumi never blocks the player | PASS (by construction) | Lumi has no collision shape |
| Recovery when far away | MANUAL | `recovery_distance` = 520 px fade-and-reappear implemented |
| Dialogue does not interrupt excessively | MANUAL | voluntary lines limited to milestones; can be disabled in Settings |

## Check-in and adaptive engine

| Case | Status | Evidence |
|---|---|---|
| Every valid score 0-10 accepted | PASS (auto) | unit `test_every_valid_score_gets_a_recommendation` |
| Out-of-range / invalid scores rejected | PASS (auto) | unit test (-1, 11, 4.5, "5", true, NaN, INF) |
| Skipping works and defaults to Balanced | PASS (auto) | unit + smoke (`recommended_mode` empty) |
| Recommendation policy 7-10 / 4-6 / 0-3 | PASS (auto) | unit + UI smoke |
| Player can override; suggestions never override a player's choice | PASS (auto) | UI smoke |
| Gentle / Playful change real parameters | PASS (auto) | reach radius, prisms, lantern count and speed asserted |
| Switching modes does not duplicate or corrupt | PASS (auto) | interactable count unchanged; counters kept; no lantern respawn |
| Help available at any time (H / Ask Lumi) | PASS (auto) | hint counted; button present (`03`) |
| Repeated hints enable the guiding glow; player "off" respected | PASS (auto) | unit |
| Near-miss attempts trigger reach help | PASS (auto) | unit |

## Session reflection

| Case | Status | Evidence |
|---|---|---|
| Pre/post compared correctly | PASS (auto) | unit + UI smoke ("7 / 10", "4 / 10", "-3 points") |
| Missing responses handled | PASS (auto) | "Not answered", "Not available", explanation sentence |
| Negative, zero and positive deltas worded correctly | PASS (auto) | unit `test_neutral_descriptions` |
| No sample values shown as real results | PASS (auto) | results read only SessionState; UI smoke |
| No cure or diagnosis claims | PASS (auto) | banned-word tests (unit + UI smoke) |
| Untouched slider is not an answer | PASS (auto) | UI smoke |

## Data collection

| Case | Status | Evidence |
|---|---|---|
| Declining consent stores nothing | PASS (auto) | smoke "declined consent wrote nothing" |
| Consent stores exactly one correct record | PASS (auto) | smoke: values, delta, modes, flags; written once |
| CSV header and values correct | PASS (auto) | unit + smoke; read back by pandas |
| Commas and quotes escaped | PASS (auto) | unit `test_csv_round_trip`; Python quoted-field test |
| Missing scores stay empty, never 0 | PASS (auto) | unit + smoke + Python |
| Write failure reported | PASS (auto) | unit `test_write_failure_is_reported` |
| Foreign or mismatching file never modified | PASS (auto) | unit `test_storage_never_modifies_foreign_file` |
| Exported file readable by pandas | PASS (auto) | export equals source; game-written CSV loaded by `pd.read_csv` and the analysis loader (2 rows, 0 issues) |
| Export via the native Windows dialog | MANUAL | `FileDialog` with `use_native_dialog`; needs a click |
| Local deletion | PASS (auto) | unit `test_export_and_delete` |
| No network transmission | PASS (by inspection) | no HTTPRequest, sockets or analytics code in the project |

## Data science

| Case | Status | Evidence |
|---|---|---|
| Notebook loads data and executes | PASS (auto) | nbconvert, 0 errors |
| Invalid records identified | PASS (auto) | 5 of 5 injected problems found |
| Missing pairs excluded and counted | PASS (auto) | Python tests; notebook reports 16 excluded |
| Sign convention | PASS (auto) | Python `test_delta_sign_convention` |
| Charts labelled (axes, n, synthetic tag) | PASS (render) | charts inspected visually |
| Synthetic data clearly identified | PASS | file name, `data/README.md`, notebook banner, chart subtitles |
| No causal claims | PASS (auto) | `describe_change` wording test |

## User interface and accessibility

| Case | Status | Evidence |
|---|---|---|
| Pause pauses gameplay | PASS (auto) | `get_tree().paused` asserted |
| Modal screens block gameplay input | PASS (by construction) | tree paused; 0.25 s input block after closing; HUD buttons unfocusable |
| Text readable / contrast | PASS (render) | screenshots; high-contrast theme asserted |
| Settings have real effects | PASS (auto) | text size, contrast, reduce motion, volume mute, clamping, save |
| Fullscreen / window size switch | MANUAL | no effect in headless mode |
| Keyboard-only menu navigation | MANUAL | focus ring visible in screenshots |
| Invalid actions do not crash | PASS (auto) | invalid modes, scores and items handled; no script errors in any run |

## Manual test script (to run before publishing)

1. **Full session (each mode).** Launch, skip the splash, Start Adventure, answer 8 and keep the suggested Gentle. Collect 8 lights with WASD and arrows, restore the tree, Continue Exploring, bloom a bed, find a hidden detail. Run Lantern Catch to completion and end one night early. Finish, answer the reflection, and check the results. Repeat for Balanced and Playful, checking that the movement differences are visible.
2. **Pause and settings.** Press Escape in the meadow. Change the mode and toggle the guiding glow. Open Settings, change every control, return, Restart (confirm), then Main Menu (confirm). Then Alt-Tab during play: the game should pause.
3. **Consent.** Play once with consent and once without. Open Data & Privacy, then Export, Open folder and Delete. Open the export in Excel or pandas.
4. **Accessibility.** Run with Extra large text plus High contrast plus Reduce motion, and complete a session with the keyboard only.
5. **Companion.** Stand still and watch Lumi for jitter. Walk quickly in circles and check that Lumi never blocks the player.
