# Privacy

CALMQUEST is designed to work fully without collecting anything. This page explains exactly what can be stored, why, and how to control it. The in-game **Data & Privacy** screen shows the same information.

## What is collected

Nothing is collected from players. Since 0.4.0 the 0-10 check-in only appears in **Study Mode**, a hidden mode a researcher uses for a study. There, nothing is stored unless the participant ticks **"Save an anonymous record of this session on this device (optional)"** on the check-in screen. The box is **unticked by default** and must be ticked again for each new session.

The optional **mood check** (five faces when a journey starts) and the faces in **"Before you go…"** are not stored at all, unless the player turns on the **private mood journal** (Settings > Well-being, off by default). See below.

With consent, one row is written when the session ends. The 16 fields are listed in [DATA_DICTIONARY.md](DATA_DICTIONARY.md). They are:

- a random session ID,
- the local start time,
- the optional 0-10 answers before and after playing, and their difference,
- the recommended, selected and final gameplay modes,
- play time, hint requests, reach-help events and items collected,
- whether the Heart Tree was restored,
- the optional game rating,
- whether the session was finished normally.

**Never collected:** name, email, phone number, account or login, location, IP address, device or hardware identifiers, diagnoses, demographic data, free text, keystroke logs, reaction times.

## Why

- To let players look back at their own sessions.
- To give the project's analysis notebook real, consented data, if a player chooses to share an export with a researcher.

## Where it is stored

Only on the player's computer, in Godot's user-data folder for this game:

| OS | Folder |
|---|---|
| Windows | `%APPDATA%\CALMQUEST\` |
| Linux | `~/.local/share/CALMQUEST/` |
| macOS | `~/Library/Application Support/CALMQUEST/` |

| File | Contents | Requires consent |
|---|---|---|
| `sessions.csv` | consented session records | yes |
| `progress.cfg` | journal progress (hidden details found, times the Heart Tree was restored, Lantern Nights completed), with no answers | no (ordinary game save) |
| `settings.cfg` | volume, display, accessibility and language settings, and key bindings | no |
| `saves/slot_N.json` (+ `.bak.json`) | world saves: places, items, homes, villagers, quests (V2); never check-in or reflection answers | no (ordinary game save; delete from "Choose a journey") |
| `wellbeing_journal.json` | the private mood journal: date and time, the faces chosen when starting and leaving (or nothing if skipped), minutes played, the short summary | the player's own opt-in (Settings > Well-being) |
| `study_sessions.csv`, `study_events.csv` | Study Mode only: the participant code, language, build, session length and the 16 session fields; coarse events (region entered, activity started or finished, hint requested), no positions or keystrokes | yes (the participant's consent at the check-in) |
| `saves/study_tmp.json` | Study Mode's temporary world; deleted when the study session ends | no |

Only Windows was tested. The Linux and macOS paths are Godot's documented defaults.

## Network transmission

**None.** The project contains no networking, analytics, telemetry, crash-reporting or advertising code, and it needs no internet connection. Data leaves the device only if the player exports a file and shares it themselves.

## Declining, exporting and deleting

- **Decline:** leave the box unticked. The game behaves identically and `sessions.csv` is not written.
- **Leave mid-session:** if consent was given, an incomplete record (`completed = false`, no after-play answer) is saved. The pause menu shows this before the player confirms.
- **Export:** Data & Privacy -> *Export CSV...* opens the system "Save as" dialog. Exports must be `.csv` and cannot overwrite the original data file.
- **Open folder:** Data & Privacy -> *Open data folder*.
- **Delete:** Data & Privacy -> *Delete session records* (with confirmation) permanently removes `sessions.csv`.
- **Reset journal:** Data & Privacy -> *Reset journal progress* removes `progress.cfg`.
- **Mood journal:** Settings > Well-being turns it on or off. Data & Privacy -> *Export mood journal...* and *Delete mood journal* (with confirmation); the Journal's "Feelings" page can delete it too.
- **Study data:** in Study Mode, Data & Privacy -> *Export study data...* copies both study files into a folder the researcher picks; *Leave Study Mode* turns the mode off.

The game reports when a write, export or deletion fails and never claims success after a failed file operation.

## Safety of the file layer

- The game only writes to its own `sessions.csv` or to a path the player picked.
- It refuses to append to a file whose header is not the CALMQUEST schema, so unrelated files are never modified.
- Records that fail validation (for example a score outside 0-10) are not written.

## Limits of anonymity

Records contain no direct identifiers, so they are *de-identified*, not guaranteed anonymous:

- timestamps plus answers could, in principle, be linked to a person by someone who knows when they played;
- anyone with access to the same computer account can read the files;
- once a player shares an export, its handling depends on the recipient.

Players who share a computer may wish to delete their records after use. Any research use of exported data would need its own informed consent and ethics review (see [EVALUATION_PLAN.md](EVALUATION_PLAN.md)).

## Not a medical product

The 0-10 question is a subjective self-reflection. The game does not diagnose, detect, measure, treat or predict stress, anxiety or any health condition, and it does not label players.
