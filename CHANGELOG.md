# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.4.0] - 2026-10-12 (Polish pass: "Ready for Steam, ready for research")

### Added
- **One game, two layers (P1).**
  - *Default flow:* Start Adventure opens "Choose a journey". A new journey shows one comfort-mode card (Balanced pre-selected) and then an optional mood check (five drawn faces; Skip; "Don't ask again").
  - *Leaving* from the pause menu shows "Before you go...", with up to four lines from real events and an optional face.
  - *Private mood journal* (off by default, `user://wellbeing_journal.json`) with export and delete, and a "Feelings" journal page when it is on.
  - The default flow stores no research data.
- **Study Mode (P1),** hidden:
  - activated by `--study`, or by clicking the version label 7 times and typing `LUMERIA-STUDY`;
  - participant codes `P01`-`P999`, 10/15/20 minutes, a fresh temporary world, and a gentle end that never interrupts;
  - with consent, `study_sessions.csv` (participant code, language, build, minutes and the 16 schema-v1 columns) and a coarse `study_events.csv`;
  - export, leave, `analysis/analyze_study.py` and `docs/STUDY_MODE.md`.
- **A calm HUD (P2):**
  - a compact quest tracker with the guidance arrow, which fades while walking;
  - a sun/moon day arc, a hotbar that fades, and a mouse menu icon;
  - contextual key hints (Always / Sometimes / Never), toasts grouped below the player, a smaller banner for major moments, and rings only on the nearest objects;
  - in-world fishing (a bobber and a bar beside the player).
- **Menus (P2):**
  - a drawn wordmark, a parallax isles backdrop, and Continue on the main menu;
  - an About screen (credits from `game/data/credits.json`, licenses, version, disclaimer);
  - display settings (window mode, VSync, UI scale) and interface settings (hints, fading, compact tracker);
  - automatic use of an OFL font in `assets/fonts/` when one is added.
- **Audio (P3):**
  - `MusicManager` prefers rendered recordings in `assets/music/rendered/`;
  - `tools/music/render_music.py` for a MuseScore render (seamless loops, loudness, seam check);
  - softer synthesized SFX with ±4% pitch variation, new sounds for gathering, crafting, cooking, placing, quest steps, fishing and the rest swell, and footsteps on six surfaces (with a setting).
- **Visuals (P4):**
  - ground detail per chunk and 24 small features;
  - fireflies, water mist, stars, needles, snow, gulls and the lighthouse beam;
  - village lantern posts, festival lanterns and a warm cottage window;
  - Traveler arm swing, breathing, blinking and run puffs; Lumi's trail and celebration;
  - an optional sprite-sheet path (no sheets are included).
- **Finale cinematic (P4):** about 36 s with letterbox, befriended creatures, closing lines, a wide shot, rising motes and credits. "Hold Esc to skip" leads to the same result. It autosaves before and after, and free exploration continues.
- **Rest spots (P5):**
  - 12 quiet places (11 in the open world and a crystal pool in the Singing Grotto). "[E] Sit and rest": the Traveler sits, Lumi curls up, the camera drifts, the HUD fades out, and the music and ambience swell.
  - Optional "Watch time pass while resting".
  - The places appear on the map and on the journal page "Quiet places". Finding them all unlocks one cosmetic glow.
- **Breathe with Lumi (P5),** from a rest spot or the pause menu:
  - Gentle 4/6, Even 4/4 and Slow 5/7, for 1, 2 or 3 minutes or until stopped;
  - any input stops it; no scores or counters;
  - a Reduce motion variant.
  - Study Mode logs only that it started and stopped.
- **Tests:** `test_wellbeing`, `test_study_mode`, `test_audio_polish`, `test_visual_polish` and `test_rest_and_breathe` (44 new unit tests, including the gamepad menu buttons), and new UI, overworld and smoke checks.
  - Python: 8 tests for `analyze_study.py` and 9 for the music tool.
  - `run_checks.ps1` now runs 18 checks.

### Changed
- The completion panel no longer appears by itself. Players leave from the pause menu, and study sessions end on their own time.
- "Restart Session" was removed from the player's pause menu. Study Mode has Finish Session and Main Menu.
- Default volumes: SFX 0.7 (was 0.8) and Interface 0.6 (was 0.7) for new players. Existing settings are kept.
- During the finale, Esc is held to skip it instead of opening the pause menu.
- The journal has a ninth page, "Quiet places".
- Performance work for the new layers: ground detail is one mesh per chunk, small atmosphere particles are batched, and mist is capped. The perf probe went from 50.1 to 61.1 fps on average.
- `GAME_VERSION` and `project.godot` `config/version` are both **0.4.0** (`config/version` was still 0.1.0).

### Fixed
- `lantern_catch` was documented as a Study Mode activity but never logged. It now is.
- Gamepad A and B did nothing in menus (Godot 4.7's `ui_accept` / `ui_cancel` have no gamepad button). They now choose and go back.
- In Study Mode, the end announcement while sitting at a rest spot stands the player up, so Lumi's line is visible.
- The first small-feature generator placed nothing (one candidate spot per large chunk). It now tries up to 10 seeded spots.

### Unchanged
- `sessions.csv` schema v1, `score_delta = post - pre`, missing answers left empty, the save format (`save_version` 2), and `analyze_sessions.py`.
- The generated scenery and its object ids (new random streams only), so existing saves keep their gathered objects.
- No network code, analytics or trackers. No health or therapeutic claims.

### Not done here (needs the developer)
- **Font:** no OFL font file is included (`assets/fonts/README.md`).
- **Orchestral music:** no MuseScore on this machine. The music is still the synthesized placeholders (`docs/MUSIC_PIPELINE.md`).
- **Sprite sheets:** none (`assets/sprites/README.md`).
- **Listening and playtesting:** no manual listening or playtest was done (see `docs/MANUAL_TEST_CHECKLIST.md`).

## [0.3.1] - 2026-10-11 (Bahasa Indonesia)

### Added
- **Language setting:** Settings > Language switches the whole game between English and Bahasa Indonesia at any time. The choice is saved in `settings.cfg` (`language`).
- **Indonesian catalog:** 1,481 strings (menus, HUD, prompts, Lumi, quests, items, creatures, villagers, places, notes, the check-in, reflection, results and Data & Privacy) in `game/data/i18n/id/`.
- `L` (localization helper), `tools/i18n/extract.py` (coverage and placeholder check, now part of `run_checks.ps1`), and `--lang=id` for the screenshot tool (saved to `screenshots/id/`).
- Tests: 6 unit tests (catalog, placeholders in order, English default, switching, persistence, research CSV independent of the language) and 9 UI checks (the Settings option, live switching, HUD and results in Indonesian).

### Changed
- Player-facing text is translated where it is shown: composed text uses `L.t()` on the template, and data getters return translated names and descriptions. Saved values (such as the region name in a save summary) stay English.
- The brazier prompt uses separate texts for "1 dot" and "%d dots" instead of building the plural from parts.
- The test runners switch to English first, so a player's chosen language never changes English assertions.
- Very long region titles (often translated ones) are drawn smaller instead of covering the HUD panels.
- The screenshot tool resumes when the game pauses itself because its window lost focus.
- `GAME_VERSION` is 0.3.1.

### Unchanged
- `sessions.csv` schema v1, `score_delta = post - pre`, the save format (`save_version` 2) and the Python analysis. The session record does not store the language.

## [0.3.0] - 2026-10-11 (V2 milestones M3-M12, "The Wide World of Lumeria")

### Added
- **Gathering, inventory, crafting (M3):** 17 regrowing resources, a 30-slot inventory with an 8-slot hotbar and bag upgrades, three crafting tiers, recipe discovery (notes, restorations, experiments), lore notes, and the day/night clock with settings.
- **Cottage and homestead (M4):** the interior sub-level, 8 restoration steps, bed and sleep, storage chest, cottage workbench, cooking pot (experiments use nothing up), a grid build mode with rotate, store and undo, 18 decorations.
- **Save system V2 (M5):** 3 slots, a "Choose a journey" screen, `save_version` 2 with migration, atomic writes with a backup, autosaves, manual save and load, and the V1 journal imported as a legacy record.
- **Misty Pinewood and Sunpetal Coast (M6):**
  - 16 creatures with a sketch journal, friendship and gifts;
  - gloom patches (a desaturating shader) and Gloomlings;
  - the lost fox family, the lighthouse restoration, boats to two isles, the shipwreck signal puzzle;
  - fog and light shafts;
  - the tabbed Journal.
- **Farming, fishing, cooking, weather (M7):** 5 crops that never die, rain, a watering can that opens the forgotten garden, Luma Blooms, a no-fail fishing minigame with 11 fish and Old Whiskers, and 8 new dishes.
- **Echo Caverns (M8):** two handcrafted cave systems (braziers, blocks, a light bridge, a tuned crystal door, two beam puzzles) with reset levers and hint ladders.
- **Villagers and story (M9):**
  - 5 spirit villagers with homes, routines, gifts, friendship and personal quests;
  - the request board and cosmetics;
  - Act 2 (five Hearthstones in any order) and Act 3 (the Festival of Light finale);
  - post-game goals, the Aurora Stag and an epilogue note.
- **Frostbloom Highlands (M10):** the mountain pass (climbing rope as a tool), snow region, waystone, the aurora shrine, and the aurora at night.
- **Polish (M11):**
  - music composed as code (14 MIDI cues) with **synthesized placeholder** loops, and 8 ambience loops;
  - `MusicManager` (crossfades, hysteresis, adaptive meadow layers, stingers, quiet pauses);
  - Ambience and UI buses;
  - gamepad bindings, key remapping, captions, weather toggle, hint frequency;
  - a Playful puzzle bonus and mode-based creature shyness;
  - parallax fog and cloud shadows;
  - `ViewCull` performance work and a perf probe.
- Tests: 138 unit tests, a 656-check smoke test, a 378-check overworld test (every system played through and persisted after a simulated relaunch), a 30-check UI test.
- Docs: MUSIC_PIPELINE; updated architecture, design, data schema, art direction, controls, asset provenance, manual test checklist, progress log.

### Changed
- After Act 1 the story continues with Act 2 (the old "no main quest after Act 1" test expectation was deliberately updated).
- The smoke test's reachability now follows boat routes and the mountain pass, and skips only content that is hidden by design until unlocked; those cases are checked separately in the overworld test.

### Fixed
- Off-screen objects redrawing every frame (about 6-7 ms per frame).
- Pickup notes piling up; a misleading restoration toast; journal tab styling; heavy pinewood fog; a checkerboard cave floor; the world staying in forced night after the finale.

### Unchanged
- The research flow, consent, `sessions.csv` schema v1, the `score_delta` definition, and the Python analysis.

## [0.2.0-dev] - 2026-10-11 (V2 milestones M0-M2)

### Added
- Open world of about 8 × 8.5 screens from an authored macro map (`game/data/world/overworld.json`): nine regions, shader-blended biome ground, paths, an animated river with a bridge and stepping stones, terrain collision.
- Deterministic, seeded chunk streaming of scenery with world deltas; new biome decorations.
- World camera (look-ahead, dead zone, region zoom, clamping, reduced-motion option); Shift to run.
- World map with fog of war, pins and travel; quest compass; optional minimap; region title cards.
- Six Lantern Waystones with free fast travel.
- Data-driven quests (`QuestBook`, `QuestManager`, `game/data/quests/act1.json`) and a complete Act 1: Lost Lights, Firefly Grove, Crystal Creek beam puzzle, Moon Altar finale.
- `EventBus` and `GameState` autoloads; V2 tests (world, quests, puzzle, overworld integration).
- Docs: V2 inspection report, progress log, V2 design, art direction, data schema, asset provenance, controls, manual test checklist.

### Changed
- Whispering Meadow is now a region of the overworld (the V1 scene was replaced by `overworld.tscn`). The Lantern Shrine moved to Firefly Grove.
- The V1 smoke test was retargeted to the overworld; reachability is now checked across the whole world.

### Fixed
- Chunk streaming used the camera's lagging screen center (wrong chunks on the first frame).
- The camera could show empty space beyond the map edge (look-ahead moved to the camera position).

### Unchanged
- Research flow, consent, `sessions.csv` schema v1, `score_delta` definition, Python analysis.

## [0.1.0] - 2026-10-11

First playable MVP.

### Added
- Godot 4.7 project with splash, main menu, How to Play, Settings, Data & Privacy, check-in, gameplay, pause, session completion, reflection and results screens.
- Whispering Meadow: data-driven layout, procedural art, collision boundary, 12 light motes, Heart Tree restoration, 3 garden beds, 3 hidden details, journal.
- Lumi companion with smoothed following, dead zone, recovery and short optional hints.
- Lantern Catch mini-game (night over the meadow, no timer, no failure, replayable).
- Adaptive Comfort Engine: Gentle / Balanced / Playful presets, transparent score-based suggestions, explicit overrides, hint and reach-help rules, bounded parameters.
- Optional pre/post self-reflection with neutral results (`score_delta = post - pre`).
- Opt-in local CSV storage with validation, safe append, export and deletion.
- Runtime-synthesized audio with master/music/SFX volume; text size, high contrast and reduce-motion settings.
- Python analysis module, executed notebook, synthetic sample data and unit tests.
- GDScript unit tests, integration smoke test, reference checker and Windows check runner.
- Documentation: design, architecture, data dictionary, privacy, test plan, roadmap, evaluation plan.
