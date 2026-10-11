# Architecture (V2, updated for 0.4.0)

## Overview

```
 check-in / reflection / results        game/data/*.json (world, quests, items, recipes,
          |                             wildlife, sites, caves, villagers, lore, homestead)
   +------v-------+   owns   +---------------+          |
   | SessionState |--------->| Adaptive      |          v
   | (research    |          | ComfortEngine |   +----------------------+
   |  session)    |          +-------+-------+   | QuestManager         |
   +------+-------+                  |ModeConfig | (QuestBook: pure)    |
          |                          v           +----------+-----------+
          |      +-------------------------------------------+ reads facts
          |      | Overworld (scene orchestrator)                        |
          |      |  Terrain, WorldStreamer (+ChunkGenerator), MeadowLoop |
          |      |  StoryContent (Act 1), HomesteadController (cottage,  |
          |      |  decor, farm plots), RegionFeatures (wildlife, gloom, |
          |      |  docks, sites, wreck, fox family, fishing, gardens,   |
          |      |  highlands, atmosphere), CavesController, Village-    |
          |      |  Controller (villagers, board, Acts 2-3), Player,     |
          |      |  WorldCamera, Lumi, HUD, menus                        |
          |      +---------------------------+---------------------------+
          v                                  | writes world facts
 SessionRecord -> sessions.csv               v
                                    GameState <-> EventBus      SaveManager -> saves/slot_N.json
                                    TimeManager, Weather        MusicManager / AudioManager
```

**Principles:**
- **One authority per kind of state:**
  - `SessionState`: the research session;
  - `GameState`: the persistent world (flags, counters, inventory, storage, recipes, puzzles, fog, deltas, and one `systems` entry per V2 system);
  - `QuestManager`: quests;
  - `TimeManager`: the clock;
  - `GameSettings`: preferences.
- **Data-driven content.** Everything authorable is JSON under `game/data/`: the world map and POIs, quests, items (including crop, fish, food and decor metadata), recipes, creatures, restoration sites, caves, villagers and requests, lore, and the cottage. Adding a fish, quest, request or decoration needs no code. (The root `data/` folder is research data and is ignored by Godot.)
- **Pure, testable logic:** `WorldData`, `ChunkGenerator`, `QuestBook`, `BeamPuzzle`, `CraftingBook`, `Inventory`, `DecorRules`, `Farming`, `Fishing`, `CreatureDB`, `VillageDB`, `Weather`, `Cosmetics`, `AdaptiveComfortEngine`, `SessionRecord` and `CsvCodec`. Most are static helpers over `GameState.systems[...]`.
- **Gameplay code does not know the UI.** Controllers push text to the HUD and open overlay panels through `Overworld`. Panels only emit signals.
- **One game, two layers (0.4.0).** The default game and Study Mode run the same `Overworld`. Study Mode only changes what happens around it: the setup screen, a temporary save slot, a fixed duration with a gentle end, and its own CSV files. The well-being layer (`Wellbeing`) is optional and never writes research data.

## Autoloads (load order)

| Name | Responsibility |
|---|---|
| `GameSettings` | input actions (`InputSetup`: keyboard, gamepad, remapping), `settings.cfg`, window, UI theme, `motion_scale()`, hint frequency, the interface language (`L`) |
| `AudioManager` | buses Master/Music/Ambience/SFX/UI, synthesized sound effects, `sound_played` (captions), the fallback ambient pad |
| `MusicManager` | music cues with crossfade and hysteresis, meadow adaptive layers, stingers with ducking, quiet pauses, ambience and rain |
| `EventBus` | global gameplay signals |
| `TimeManager` | the day/night clock (length, keep day/night, Gentle slow/pause), sleeping |
| `GameState` | persistent world state (see [DATA_SCHEMA.md](DATA_SCHEMA.md)) |
| `SessionState` | research session and the adaptive engine |
| `QuestManager` | loads quest JSON, re-evaluates when state changes, follows the HUD quest, applies `unlock` |
| `SaveManager` | slots, versioning and migration, atomic writes and backups, autosaves, restoring the player (including sub-levels); `STUDY_SLOT` (0) for Study Mode's temporary world; `GAME_VERSION` (0.4.0, the same as `config/version`) |
| `Wellbeing` (0.4.0) | the optional mood check and session closing: faces, Lumi's replies, the "Before you go..." summary from real events, and the private mood journal (`wellbeing_journal.json`, opt-in, export and delete) |
| `StudyMode` (0.4.0) | activation (`--study` or the hidden unlock), participant codes, duration and the gentle end, `study_sessions.csv` and `study_events.csv` (through `CsvFileStore`, `SessionRecord` and `CsvCodec`), export, leave |
| `SceneRouter` | scene changes and `fade_through()`; also `STUDY_SETUP` and `ABOUT` |

## Overworld controllers (children of `overworld.tscn`)

| Node | Script | Owns |
|---|---|---|
| `Terrain`, `MeadowGround` | `world/terrain.gd` | shader ground, paths, river, terrain collision |
| `WorldStreamer` | `world/world_streamer.gd` | chunked scenery and gatherables |
| `MeadowLoop` | `world/meadow_loop.gd` | the V1 loop: lights, Heart Tree, beds, Lantern Night |
| `StoryContent` | `world/story_content.gd` | Act 1: waystones, landmarks, the creek puzzle, the veil, the altar, lore notes |
| `Homestead` | `homestead/homestead_controller.gd` | cottage restoration, the interior sub-level, decor, farm plots |
| `Features` | `world/region_features.gd` | wildlife spawner, gloom and Gloomlings, docks and sailing, restoration sites (lighthouse, mountain path), wreck puzzle, fox family, fishing spots, forgotten garden, aurora shrine, Hearthstone grants, `RegionAtmosphere` |
| `Caves` | `caves/caves_controller.gd` | two `CaveLevel` sub-levels built from `caves.json`, cave entrances, entering and leaving |
| `Village` | `village/village_controller.gd` | villagers and homes, request board, campfire and stall, lantern posts, the Hearthstone circle, the Act 3 finale (`FinaleCinematic`: skippable, autosaves before and after), quest rewards |
| `Rest` (0.4.0, created in code) | `rest/rest_controller.gd` | rest spots (`RestSpot`, data in `rest_spots.json`, state in `RestSpots`): sitting and standing, Lumi, the camera drift, the HUD fade, the music swell, time passing, discovering quiet places; opens `BreathePanel` |
| `Hud`, `PauseMenu`, `SessionComplete` | `ui/*.gd` | HUD (a fading tracker with the compass, the day arc, the hotbar, key hints, toasts, captions, minimap, the mouse menu) and menus. HUD items live under one node, so they can fade out together while resting; overlays, captions and the study light stay visible |

**Sub-levels** (the cottage at (12000, 400) and the caves at (12000, 1400) and (12000, 3000)):
- They are placed outside the world map.
- `Overworld.enter_sublevel()` / `leave_sublevel()` switch the camera bounds and zoom.
- `current_sublevel` is saved, so a load restores the player inside.

## World pipeline (unchanged from M2)

1. `WorldData.load_from()` parses `overworld.json`: cells, regions, walkability, paths, rivers and POIs.
2. `Terrain` draws the shader ground, paths and rivers, and builds row-run collision for blocked cells and river banks plus a safety ring.
3. `ChunkGenerator` places seeded scenery and gatherables per 1024 px chunk; `WorldStreamer` streams them around the camera (at most one chunk build per frame; deltas live in `GameState`).
4. Controllers spawn hand-placed POIs. Their clearings keep scenery away.
5. **0.4.0:** each chunk also gets a `GroundDetail` (an internal child, one triangle mesh, its own `"ground"` random stream) and at most one small feature (`generate_features`, its own `"feature"` stream). Separate streams keep the scenery and its object ids identical, and saves refer to those ids for gathered objects. Rest spots were placed where the scenery is already clear for the same reason.

## Rendering and performance

- **Lighting:**
  - `NightTint` (CanvasModulate) follows the clock and Lantern Night;
  - interiors are warm and caves are dim;
  - `PointLight2D` glows at night (Lumi, lanterns, braziers, homes, campfire, lighthouse).
- **Atmosphere (`RegionAtmosphere`, CanvasLayer 2):** screen-space fog with parallax, light shafts, cloud shadows, rain, overcast, mist and the aurora.
- **Gloom veil:** a canvas shader reading the screen texture in its own follow-viewport CanvasLayer (1), so it desaturates the finished world image. The mist is drawn after it.
- **`ViewCull`:** objects animated by `_draw()` only redraw when near the camera. This was the main M6 performance fix (about 6-7 ms per frame saved).
- **Light budget (0.4.0):** `Overworld.LIGHT_BUDGET` = 16 `PointLight2D` near the screen. New lights (lantern posts, the cottage window) switch on only at night and near the camera. The overworld test measures the festival and the village at night.
- **Batching (0.4.0):** ground detail is one `canvas_item_add_triangle_array` per chunk, and atmosphere particles (stars, fireflies, snow, needles) are one per effect. Mist is capped at 12 shapes.
- **Measurements and the probe:** `tools/capture/perf_probe.tscn` measures frame times per region with features on and off.

## Quests

- `QuestBook` conditions: `flag`, `counter`, `region`, `waystone`, `any`, `all`.
- Optional per quest: `requires` (other quests), `unlock` (a condition), `rewards` (items, friendship, cosmetic), `hints`.
- Optional per step: `target` (a POI id for the compass and guidance), `progress` (a counter shown as x/n) and `deliver` (a villager hand-over).
- `QuestFacts` reads `GameState` only.
- Evaluation loops until stable, so early progress counts, several steps can complete at once, and completed quests never revert.
- Facts come from counters such as `obtained:<item>`, `crafted:<item>`, `harvested:<crop>`, `placed:<decor>`, `fish_species`, `creatures_sketched`, `hearthstones`, `kits_home`, `notes_read`, `dish_kinds`, `waystones_relit` and `festival_invites`, and from flags such as `read:<note>`, `sketched:<creature>`, `caught:<fish>`, `delivered:<villager>:<item>`, `puzzle_solved:<id>`, `hearthstone_<id>` and `act3_complete`.

## Saves

See [DATA_SCHEMA.md](DATA_SCHEMA.md).
- `SaveManager.build_save_data()` collects `GameState.to_state()`, the clock, quests, the player runtime state (position, facing, region, sub-level) and the mode.
- `apply_save_data()` restores them, and `migrate()` upgrades old versions.
- Research data is never part of a save.

## Audio

`AudioManager` synthesizes the sound effects (0.4.0: softer, ±4% pitch variation, footsteps on six surfaces chosen by `Footsteps`). Resting raises the Music and Ambience bus volumes a little (`set_rest_boost`). `MusicManager` plays the cue chosen by `Overworld._update_music()` from the region, sub-level, night amount, finale and rain. It prefers `assets/music/rendered/<cue>.ogg|wav` and falls back to `assets/music/placeholder` (one warning per run). Ambience comes from `assets/ambience/placeholder`, generated by `tools/music/`; see [MUSIC_PIPELINE.md](MUSIC_PIPELINE.md).

## Session data flow

**Default game (0.4.0):** Start Adventure, then "Choose a journey" (`slot_select.start_play_session`), then the world. A session is begun without consent, so `finalize_and_save` never writes. The optional mood check and "Before you go..." go through `Wellbeing`. Leaving: autosave, the optional journal entry, then the menu or quit.

**Study Mode (research):**
1. The study setup sets the participant code, the minutes and the language.
2. The check-in calls `SessionState.begin_session` (with the participant's consent choice).
3. `StudyMode.begin_play()` starts a fresh world in `STUDY_SLOT`.
4. When the time is up, `end_step()` announces the end and waits until nothing is open. Then `end_gameplay`, the reflection, and `finalize_and_save`: with consent it writes the unchanged v1 row to `sessions.csv` and the study row to `study_sessions.csv`.
5. Then the results and "Next session". The temporary save is deleted.
6. Events go to `study_events.csv` only during a consented study session.

## Error handling

- Invalid JSON is reported with `push_error`, and the data classes expose `load_errors`; unit tests assert that there are none.
- Unknown quest conditions evaluate to false with a warning.
- Damaged saves fall back to the backup.
- Missing music files log one warning and use the fallback pad.
- Storage errors are shown to the player.

## Pause and input safety

- Every overlay panel is modal: the tree pauses, panels process always, and input is blocked for 0.25 s after closing.
- HUD buttons cannot take focus.
- The fishing panel's buttons are mouse-only, so the reel key can never trigger them.
- Focus loss opens the pause menu.

## Physics layers

All bodies use the default layer 1 and mask 1: the player, decorations, terrain, POIs, doors, blocks, thorns and barriers. Interactables are found by group (`interactables`), not by physics. Creatures and villagers have no collision, so they never block the way.

## Localization (English and Bahasa Indonesia)

- **English is the source language.** Every player-facing string is written in English in the code and the JSON data. The Indonesian catalog is in `game/data/i18n/id/*.json` as `{"English": "Bahasa Indonesia"}`, split by area (`ui`, `game`, `items`, `quests`, `villagers`, `world`) and merged at load.
- `L` (`game/scripts/systems/locale.gd`) registers the catalog as a runtime `Translation` and switches `TranslationServer`'s locale. `GameSettings.language` stores the choice; Settings > Language switches it at any time.
- **How text is translated:**
  - Labels, buttons, check boxes and tabs translate their text automatically when it matches a catalog entry exactly (their `.text` keeps the English source).
  - Composed text translates the template first: `L.t("Talk to %s") % name`. Placeholders keep their order, because GDScript fills them by position.
  - Data getters (`ItemDB.display_name`, `CreatureDB`, `VillageDB`, quest titles, steps and hints, region names for display) return translated text.
  - Values that are saved stay English (for example the region name in a save summary); they are translated when shown.
- On a language change, open panels' labels update at once, the Settings buttons are rebuilt, and the overworld rebuilds the HUD texts.
- **The research data never depends on the language:** the CSV stores mode ids and numbers, and a unit test compares the header and a row in both languages.
- `python tools/i18n/extract.py` collects every player-facing string and reports missing translations, placeholder or line-break mismatches and unused entries; `run_checks.ps1` runs it. Text in a table that is translated where it is used gets a trailing `# i18n` comment so the extractor finds it.
- **To add a language:** add its code to `L.LANGUAGES` and `L.ORDER`, create `game/data/i18n/<code>/`, and run the extractor with `--locale <code> --missing` for the list to translate.

## Platform integration (later; not included)

There is no Steamworks SDK in this project (out of scope for 0.4.0). If it is added later, keep it in one optional autoload (for example `Platform`), loaded before `SaveManager`:
- **achievements** listen to `EventBus` signals (quests, Hearthstones, quiet places) and never change gameplay;
- **cloud saves** sync the files in `SaveManager.save_dir` and never the research or study files;
- the game must still run unchanged when the SDK is missing.

## Extension points

| To add | How |
|---|---|
| An item, fish, crop, dish or decoration | An entry in `game/data/items/*.json` (`crop`, `fish`, `food`, `decor` metadata), plus a recipe if craftable |
| A creature | An entry in `creatures.json` (the shape must exist in `CreatureArt`) |
| A restoration site | An entry in `sites.json` and a `site` POI (or create a `RestorationSite` in code) |
| A cave | An ASCII map and puzzle data in `caves.json`, plus a `cave` POI with `"cave": "<id>"` |
| A villager or request | `villagers.json`, `requests.json`, and a `home_<id>` site and POI |
| A quest | An entry in `game/data/quests/*.json` |
| A POI kind | A spawn case in `RegionFeatures.build` (or `StoryContent`, `VillageController`) |
| A music cue | An entry in `CUES` in `tools/music/compose.py`, then regenerate, then map it in `MusicManager.REGION_CUES` |
| Player-facing text | Write it in English, add the Indonesian entry to `game/data/i18n/id/`, and run `tools/i18n/extract.py` |

## Future co-op ("Shared Dream Garden")

Not implemented. Adding it would require:
- host-authoritative world state;
- events replicated by stable IDs (already used for objects and puzzles);
- reconnection;
- safety features;
- reflection data that never leaves the device.
