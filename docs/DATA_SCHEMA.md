# Data Schema (V2)

CALMQUEST keeps **research data** and **game data** strictly separate. Saves never contain check-in, reflection or consent data, and the research CSV never contains gameplay state. Both rules are covered by tests.

| File (`%APPDATA%\CALMQUEST\`) | Purpose | Written when |
|---|---|---|
| `sessions.csv` | consented research session records, **schema v1, unchanged** (see [DATA_DICTIONARY.md](DATA_DICTIONARY.md)) | the player ticked consent at the check-in and the session ends |
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
| `ambience_volume`, `ui_volume` | float 0-1 | 0.6, 0.7 | bus volumes |
| `music_mode` | int 0-2 | 0 | continuous / quiet pauses / off |
| `hint_frequency` | int -1..3 | -1 | Lumi's nudges: by mode / off / rare / normal / helpful |
| `weather_effects` | bool | true | rain, cloud and mist visuals (crops are still watered) |
| `captions` | bool | false | text captions for important sounds |
| `key_bindings` | dict | {} | action → physical keycode (remapped main keys) |
| `language` | string | "en" | interface language: `en` (English) or `id` (Bahasa Indonesia); unknown values fall back to `en` |

## Optional gameplay event log

Not implemented. If one is added later, it must:
- use its own file and schema, documented here;
- be covered by the consent flow;
- never be mixed into `sessions.csv` without a defined join key.
