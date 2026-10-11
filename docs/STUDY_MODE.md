# Study Mode: running a research session

Study Mode is a hidden layer of CALMQUEST for a study with participants. It runs the same game as everyone else, adds a 0-10 check-in and reflection, and writes its own files. Players do not see it unless it is activated.

This guide is for the researcher. Read it once before the first participant.

## 1. Activate Study Mode

Use one of these two ways:

- **Command line (one run only):** start the game with the user argument `--study`:
  ```
  CALMQUEST.exe -- --study
  godot --path . -- --study          (from the project folder)
  ```
  Study Mode is then on until the game closes. Nothing is remembered.
- **Hidden unlock (remembered):** on the main menu, click the small version label in the bottom-right corner **7 times within 4 seconds**. A small dialog asks for the unlock phrase. Type `LUMERIA-STUDY` (any case) and press *Unlock*. Study Mode stays on across restarts until you turn it off.

While Study Mode is on, a small **"Study Mode"** badge shows on the main menu and in the pause menu.

To turn it off: main menu -> *Data & Privacy* -> *Leave Study Mode*.

## 2. Before the participant arrives

1. Start the game in Study Mode.
2. Main menu -> *Start Adventure* opens **Study setup**.
3. Fill in:
   - **Participant code:** `P` followed by 2 or 3 digits (`P01` to `P999`). The game refuses anything else and shows why. Use your own key that links codes to people, and keep it outside this computer.
   - **Session length:** 10, 15 or 20 minutes (default 15).
   - **Language:** Bahasa Indonesia (default) or English. The whole game switches to it.
4. Press *Start session*. The **check-in** follows. It is the same screen as in V1: the optional 0-10 question, the mode suggestion and the **consent box (unticked by default)**.

## 3. The session

1. The participant answers (or skips) the check-in, may tick consent, and presses *Begin Adventure*.
2. The game opens a **fresh study journey**. Every study session starts from the same state: a new world at the normal start of Act 1, day 1, 08:00. It uses its own temporary save, `saves/study_tmp.json`, and **never touches the three journey slots**.
3. **No countdown is shown.** A small sun next to the clock fades slowly as time passes.
4. When the set time is up, Lumi says: *"Our walk is almost done for today. Shall we rest?"* The participant has up to **60 more seconds** to finish what they are doing. The game never interrupts dialogue, a menu or a minigame: it waits until those are closed.
5. The game then moves to the **reflection** (the same 0-10 question and the optional game rating) and the **results** screen. Both are unchanged from V1.
6. On the results screen, *Next session* returns to Study setup. The temporary study save has already been deleted.

If you must stop early: pause (Esc) -> *Finish Session* goes to the reflection. *Main Menu* ends the session without the reflection; with consent, an incomplete record (`completed = false`) is still written.

## 4. What is written (only with consent)

All files are in `%APPDATA%\CALMQUEST\` on Windows:

| File | Contents |
|---|---|
| `study_sessions.csv` | one row per study session: `study_schema_version`, `participant_code`, `language`, `build_version`, `git_commit`, `target_duration_seconds`, then the **16 schema-v1 columns** (same order and meaning as `sessions.csv`) |
| `study_events.csv` | coarse events: `participant_code`, `session_id`, `t_seconds`, `event`, `detail` (region entered, activity started/finished, puzzle solved, hint requested, mode changed, gentle end) |
| `sessions.csv` | the normal schema-v1 row for the same session, as in V1 |

Without consent, none of these files is written. No positions finer than a region, no keystrokes and no personal data are recorded. Details: [DATA_SCHEMA.md](DATA_SCHEMA.md).

`git_commit` is filled in only if the build contains `build_commit.txt` (for example `git rev-parse HEAD > build_commit.txt` in the project folder before exporting). Otherwise it is empty.

## 5. Export the data

Main menu -> *Data & Privacy* -> *Export study data...* and choose a folder (for example a USB stick). Both study files are copied there with a timestamp in the name. The originals stay on the computer.

## 6. Between participants

- Nothing needs resetting: each session starts from the same fresh study world, and the temporary save is deleted at the end.
- Check that the next participant gets a new code.
- If the computer is shared, export the data and then delete the files you no longer need from `%APPDATA%\CALMQUEST\` (or use *Delete session records* for `sessions.csv`).
- The participant's choices in Settings (text size, volume, language) persist. Reset them in Settings if you want every participant to start with the same defaults.

## 7. Analysis

```
python analysis/analyze_study.py path/to/study_sessions.csv --events path/to/study_events.csv --out analysis/output/study
```

This prints and saves a table per participant code (`by_participant.csv`), event counts per participant (`event_counts.csv`) and an overall summary (`summary.json`). The v1 columns are validated with the same rules as `analyze_sessions.py`. All results are descriptive and do not show that the game caused any change.

## 8. Troubleshooting

| Problem | What to do |
|---|---|
| No Study setup after *Start Adventure* | Study Mode is not on: look for the badge on the main menu, or start with `-- --study`. |
| "Participant code must be P followed by 2 or 3 digits" | Use `P01`-`P999`, for example `P07`. |
| The session never ends | The game waits while a menu, dialogue or minigame is open. Close it, and the reflection follows within about a minute. |
| No study files after a session | The consent box was not ticked, which is allowed. Nothing is stored then. |
| "does not have the expected CALMQUEST header" | A file with that name but another format is in the data folder. The game never changes it. Move it away. |
| The study is finished | Data & Privacy -> *Leave Study Mode*. |
