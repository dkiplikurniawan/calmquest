# Data Schema (V2)

CALMQUEST keeps **research data** and **game data** strictly separate. Saves never contain check-in, reflection or consent data, and the research CSV never contains gameplay state. Both rules are covered by tests.

| File (`%APPDATA%\CALMQUEST\`) | Purpose | Written when |
|---|---|---|
| `sessions.csv` | consented research session records, **schema v1, unchanged** (see [DATA_DICTIONARY.md](DATA_DICTIONARY.md)) | Study Mode only (0.4.0): the participant ticked consent at the check-in and the session ends |
| `study_sessions.csv` | Study Mode records: 6 study columns + the 16 schema-v1 columns (see below) | Study Mode, with consent, when the study session ends |
| `study_events.csv` | Study Mode's coarse event log (see below) | Study Mode, with consent, during the session |
| `wellbeing_journal.json` | the **private mood journal** (opt-in, off by default; see below) | the journal is on and the player leaves |
| `saves/study_tmp.json` | Study Mode's temporary journey; never one of slots 1-3 | during a study session; deleted when it ends |
| `progress.cfg` | V1 journal counters (discoveries, Heart Tree restorations, Lantern Nights) | gameplay milestones (unchanged) |
| `settings.cfg` | preferences, including key bindings | a setting changes |
| `saves/slot_N.json` (N = 1-3) | **world saves** (V2) | autosave and manual save |
| `saves/slot_N.bak.json` | the previous good save of that slot | before each successful save |

`score_delta = post_stress_score - pre_stress_score` keeps exactly the same meaning. `analysis/analyze_sessions.py` and the notebook read the session file unchanged.

## Research CSV fields under V2

The meaning of each field is unchanged:

| Field | Meaning in V2 |
|---|---|
| `items_collected` | light motes, bonus Prism Motes and lanterns collected this session |
| `garden_restored` | the Heart Tree was restored **during this session** |
| `completed` | the session ended through Finish Session |

No V2 data (regions, quests, inventory, villagers...) is written to the research CSV.

## World save (`saves/slot_N.json`)

The file is pretty-printed JSON.

**Writing (atomic):**
1. The data goes to `slot_N.tmp.json`.
2. It is read back and verified.
3. The old file becomes `slot_N.bak.json`.
4. The temporary file is renamed to `slot_N.json`.

**Loading:** a damaged main file falls back to the backup with a warning. A slot whose main file and backup are both unreadable is reported as damaged and can be deleted.

```json
{
  "save_version": 2,
  "game_version": "0.3.1",
  "saved_at": "2026-10-11 14:00:00",
  "summary": {"day": 12, "region": "Misty Pinewood", "act1_quests": 4, "explored_percent": 63, "playtime_minutes": 95},
  "player": {"pos": [x, y], "facing": [x, y], "region": "misty_pinewood", "region_name": "...", "sublevel": "" | "cottage" | "cave_hollow" | "cave_grotto"},
  "time": {"day": 12, "minute": 650.0},
  "world": { ...GameState.to_state()... },
  "quests": {"status": {...}, "step": {...}},
  "mode": "gentle",
  "lumi": {"glow_style": "default"},
  "playtime_seconds": 5700
}
```

`world` (GameState):
- `version`;
- `flags`, `counters`;
- `visited_regions`, `seen_landmarks`, `waystones`;
- `removed_objects`: chunk deltas with respawn days;
- `puzzles`: puzzle states by id (beam mirrors, signal lanterns, braziers, blocks, bridge, shrine);
- `pins`, and `fog` (base64, one byte per 128 px cell) with `fog_size`;
- `inventory`, `storage`: slot arrays;
- `known_recipes`, `collected`, `bloomed_beds`, `discoveries`, `lore_read`;
- `systems`: one dictionary per V2 system (below).

### `systems` keys

| Key | Owner | Contents |
|---|---|---|
| `cottage` | HomesteadController | restored steps |
| `decor` | DecorRules | placements per area: `{"item", "x", "y", "rot"}` |
| `buffs` | ItemConsumer | active food buffs and seconds left |
| `farm` | Farming | `"<area>:<x>,<y>" → {"seed", "planted", "watered": {"<day>": true}, "regrown"?}` |
| `weather` | Weather | `{"day", "today", "rain_days": {"<day>": true}}` |
| `fish` | Fishing | `id → {"caught", "biggest"}` |
| `creatures` | CreatureDB | `id → {"seen", "sketched", "friendship", "gifted", "fed_day"}` |
| `gloom`, `gloomlings` | GloomPatch, Gloomling | cleared patches, comforted Gloomlings (and how) |
| `fox_kits` | LostKit | `kit → "lost" / "following" / "home"` |
| `sites` | RestorationSite | `site → {step: true}` (lighthouse, villager homes, mountain path) |
| `withered` | WitheredGarden | `{"revived", "opened"}` |
| `villagers` | VillageDB | `id → {"points", "talked_day", "gifted_day", "rewarded", "invited"}` |
| `requests` | VillageDB | completed request ids and the day each was done |
| `cosmetics` | Cosmetics | unlocked cloaks and glows, and the current choice |
| `rest_spots` | RestSpots (0.4.0) | `{"found": {id: true}}`: the quiet places found (for the map and the journal). Nothing about how long or how often the player rested |
| `puzzle_bonus` | PuzzleBonus | best move counts (Playful) |
| `legacy_journal` | SaveManager | V1 `progress.cfg` counters copied in for new journeys |

### Versioning and migration

- `SaveManager.migrate()` upgrades step by step (currently v1 to v2).
- Unknown future versions are refused safely, without overwriting the file.
- There were never any "World 2.0" saves (V1 had no world save), so `progress.cfg` is copied into `legacy_journal` and left untouched.
- New V2 systems need no migration: they live in `systems` and start empty, so older v2 saves load with those systems fresh.

### Autosave

Autosave happens when the player:
- sleeps;
- enters or leaves the cottage or a cave;
- completes a quest;
- builds a home;
- finds a Hearthstone or makes cave progress;
- sees the finale;
- finishes the session, returns to the menu or closes the window.

It also runs every N minutes (Settings: 3/5/10/off).

## Settings (`settings.cfg`, section `settings`)

V1 keys are unchanged. Keys added in V2:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `run_toggle` | bool | false | Shift toggles running |
| `reduced_camera_motion` | bool | false | no look-ahead or zoom changes |
| `show_minimap` / `show_compass` | bool | false / true | HUD helpers |
| `region_titles` | int 0-2 | 0 | first visit / every visit / off |
| `day_length_minutes` | int 15-24 | 20 | real minutes per in-game day |
| `time_mode` | int 0-2 | 0 | normal / keep day / keep night |
| `gentle_clock` | int 0-2 | 1 | Gentle mode clock: normal / half / paused |
| `autosave_minutes` | int | 5 | 0 = event autosaves only |
| `last_slot` | int 1-3 | 1 | pre-selected journey |
| `ambience_volume`, `ui_volume` | float 0-1 | 0.6, 0.6 | bus volumes (0.4.0: Interface 0.6 for new players, was 0.7; `sfx_volume` 0.7, was 0.8) |
| `music_mode` | int 0-2 | 0 | continuous / quiet pauses / off |
| `hint_frequency` | int -1..3 | -1 | Lumi's nudges: by mode / off / rare / normal / helpful |
| `weather_effects` | bool | true | rain, cloud and mist visuals (crops are still watered) |
| `captions` | bool | false | text captions for important sounds |
| `key_bindings` | dict | {} | action → physical keycode (remapped main keys) |
| `language` | string | "en" | interface language: `en` (English) or `id` (Bahasa Indonesia); unknown values fall back to `en` |
| `mood_check` | bool | true | Well-being: ask "How are you feeling right now?" when a journey starts (Ask / Don't ask) |
| `session_summary` | bool | true | Well-being: show "Before you go…" when leaving from the pause menu |
| `mood_journal` | bool | false | Well-being: keep the private mood journal (`wellbeing_journal.json`) |
| `study_mode` | bool | false | Study Mode unlocked from the main menu (kept until "Leave Study Mode"); `--study` on the command line turns it on for one run without saving |
| `control_hints` | int 0-2 | 1 | Interface: key hints always / sometimes / never |
| `hud_fade` | bool | true | Interface: the quest tracker fades while walking, and the hotbar when unused |
| `quest_tracker_compact` | bool | false | Interface: the tracker shows only the quest title |
| `window_mode` | int 0-2 | 0 | Display: windowed / fullscreen / borderless. Older files with only `fullscreen = true` are read as fullscreen, and `fullscreen` is kept in sync |
| `vsync` | bool | true | Display: vertical sync |
| `ui_scale_index` | int 0-3 | 1 | Display: interface scale 90 / 100 / 115 / 130 %. The world camera compensates, so only the interface changes size |
| `footsteps` | bool | true | Audio: footsteps that follow the ground |
| `rest_time_passes` | bool | false | Well-being: the clock runs faster while sitting at a rest spot |
| `breathe_pace`, `breathe_length` | int 0-2, int 0-3 | 0, 0 | the last "Breathe with Lumi" choice: Gentle / Even / Slow, and 1 / 2 / 3 minutes / until stopped (preferences only; nothing about the breathing itself is stored) |

## Private mood journal (`wellbeing_journal.json`)

Opt-in (Settings > Well-being, **off by default**). Separate from `sessions.csv`, the world saves and the Study Mode files. Nothing about the mood check is stored while the journal is off. One entry is added when the player leaves from the pause menu (or closes the window), at most once per play session. A damaged file is never overwritten.

```json
{
  "journal_version": 1,
  "entries": [
    {
      "local_time": "2026-10-11T19:30:00",
      "start_face": 4,
      "end_face": null,
      "minutes": 23,
      "summary": ["You planted 3 seeds.", "You found a new place: Misty Pinewood."]
    }
  ]
}
```

| Field | Type | Meaning |
|---|---|---|
| `local_time` | text | local date and time when the entry was written (no time zone) |
| `start_face`, `end_face` | int 1-5 or `null` | the face chosen when starting / leaving: 1 Tense, 2 Uneasy, 3 Okay, 4 Calm, 5 Peaceful; `null` = skipped or not asked |
| `minutes` | int | minutes played in that session |
| `summary` | list of text | the summary lines shown in "Before you go…", in the language used at the time |

The faces are a personal note, not a measurement, and are never compared, averaged or charted in the game. Data & Privacy exports or deletes the file.

## Study Mode files

Written only in Study Mode and only when the participant ticked the consent box at the check-in. See [STUDY_MODE.md](STUDY_MODE.md).

### `study_sessions.csv` (study schema 1)

The header is the 6 study columns followed by **all 16 schema-v1 columns in the same order and with the same meaning** as `sessions.csv` ([DATA_DICTIONARY.md](DATA_DICTIONARY.md)). The same CSV codec and `SessionRecord.validate()` rules apply, and a file with a different header is never modified.

| Column | Type | Meaning |
|---|---|---|
| `study_schema_version` | int | `1` |
| `participant_code` | text | `P` + 2-3 digits (`P01`-`P999`), validated at setup |
| `language` | `en` / `id` | the interface language during the session |
| `build_version` | text | `GAME_VERSION`, e.g. `0.4.0` |
| `git_commit` | text or empty | read from `res://build_commit.txt` when a build script wrote it, else empty |
| `target_duration_seconds` | int | 600, 900 or 1200 |
| (16 v1 columns) | | unchanged; `score_delta = post_stress_score - pre_stress_score`, missing answers stay empty |

`sessions.csv` keeps receiving its normal v1 row for the same session (with the same consent).

### `study_events.csv`

| Column | Meaning |
|---|---|
| `participant_code` | as above |
| `session_id` | the same random ID as the session record (join key) |
| `t_seconds` | seconds since the study session started (one decimal) |
| `event` | `session_started`, `region_entered`, `activity_started`, `activity_finished`, `puzzle_solved`, `hint_requested`, `mode_changed`, `rest_spot_used`, `gentle_end`, `session_ended` |
| `detail` | the region id, activity (`fishing`, `cooking`, `crafting`, `building`, `talking`, `lantern_catch`, `resting`, `breathing`), puzzle id, mode id or rest spot id |

For "Breathe with Lumi" only `activity_started` / `activity_finished` with `breathing` are written: no pace, length, timing or count.

Coarse and non-identifying: no keystrokes, no timing of individual inputs, and no position finer than the region.
