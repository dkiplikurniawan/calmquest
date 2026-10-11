# CALMQUEST: The Lost Light

A cozy 2D fantasy adventure built in **Godot 4**, with **transparent, preference-based adaptive gameplay**, an optional **pre/post-session self-reflection**, **consent-based local data logging**, and a **Python data-analysis pipeline**.

**Version 2, "The Wide World of Lumeria"**, turns the single meadow into **an open world about 8 × 8.5 screens wide** with nine regions, two isles, two handcrafted caves, a cottage and homestead, and a spirit village.
- **Activities:** gathering, crafting, farming, fishing, cooking, decorating, wildlife, gloom to clear, and puzzles.
- **Story:** three acts (the Lost Light, the five Hearthstones, the Festival of Light) and post-game goals.
- **Saves:** persistent, in 3 slots.
- **Languages:** English and Bahasa Indonesia, switchable at any time in Settings.

Each milestone is described in [docs/V2_PROGRESS.md](docs/V2_PROGRESS.md).

![Firefly Grove in the V2 open world](screenshots/05_firefly_grove.png)

> CALMQUEST is an entertainment prototype oriented toward well-being. It is **not** a medical device and it does **not** diagnose, detect, treat or measure stress or anxiety. A change between two self-reported scores does not show that the game caused it.

---

## 1. Problem and motivation

Many "relaxation" apps either measure users without explaining how, or present opaque "AI" that claims to know how someone feels. This project explores a different approach. It is a game that is enjoyable first and that people can understand:

- the player is always in control of the gameplay intensity;
- every adaptation is a **named, documented rule** rather than a hidden model;
- reflection questions are optional, and their results are worded neutrally;
- data is stored only with explicit consent, never leaves the device, and can be exported and analysed reproducibly.

## 2. Product concept

The light of **Lumeria Isles** has faded. As a traveler you explore **Whispering Meadow** with **Lumi**, a small fox-like light spirit. You gather drifting magical light, restore the central **Heart Tree**, bloom the garden, discover hidden details, and spend a quiet night catching lanterns. There are no timers, no lives, no streaks and no punishment for stopping.

## 3. Key features (implemented)

| Area | What works |
|---|---|
| Open world | 10240×6144 px authored macro map, shader-blended biomes, seeded chunk streaming, sea and cliff boundaries, a mountain pass, 7 waystones with free travel, a world map with fog of war, pins, compass, minimap |
| Regions | Whispering Meadow (home), Firefly Grove, Crystal Creek, Moonlit Sanctuary, Misty Pinewood, Sunpetal Coast, two Sunpetal Isles (by boat), Frostbloom Highlands, two Echo Caverns |
| Story | Data-driven quests (main, side, villager). Act 1 (V1 content), Act 2 (five Hearthstones in any order, each a different activity), Act 3 (Festival of Light finale), post-game. Exploration always continues |
| Home | Cottage restoration (8 steps), bed and sleep, storage chest, workbench tiers, cooking pot, grid build mode inside and out (18 decorations), garden plots |
| Gathering and crafting | 17 resources plus wild seeds, inventory with a hotbar and bag upgrades, 40 recipes discovered through notes, restorations and experiments. Tools open the world (Bright Lantern, Watering Can, Fishing Rod, Small Boat, Crystal Tuner, Climbing Rope) |
| Farming, fishing, cooking | 5 crops (never die; rain waters them), 11 fishing spots, 12 fish with a no-fail minigame (Gentle catches automatically), 13 dishes with gentle optional buffs |
| Wildlife and gloom | 17 creatures with a sketch journal and friendship; gloom patches (a desaturating shader) and Gloomlings comforted with light, song or food |
| Villagers | 5 spirit villagers: homes, routines, gifts, friendship, personal quests, a never-expiring request board, cosmetic gifts |
| Caves and puzzles | Braziers, block pushing, a light bridge, a tuned crystal door, beam puzzles, a ship's signal lanterns, an aurora shrine. Every puzzle has a reset lever and a 3-step hint ladder |
| Time and weather | Day/night (15-24 min, keep day/night, Gentle slow/pause), clear/cloudy/rain/mist, fog, light shafts, cloud shadows, aurora |
| Saves | 3 slots, versioned with migration, atomic writes plus a backup, autosaves (sleep, doors, quests, timer). Research data is separate |
| Audio | Music per place with crossfades, adaptive meadow layers, stingers, ambience and rain, 5 buses. **Music files are synthesized placeholders** rendered from original MIDI scores (see [docs/MUSIC_PIPELINE.md](docs/MUSIC_PIPELINE.md)) |
| Adaptive engine | Gentle / Balanced / Playful change real parameters in every system (reach, hints, fishing, creatures, puzzles, Lantern Night, clock). There are score-based *suggestions* only, and the player is always in control |
| Reflection and data | Optional 0-10 check-in before and after, `score_delta = post - pre`, opt-in local CSV (schema v1, unchanged), Python analysis |
| Accessibility | Keyboard, mouse and gamepad; key remapping; text size; high contrast; reduce motion; captions; weather effects off; shape cues that never rely on color alone; hint frequency |
| Languages | English and **Bahasa Indonesia** (Settings > Language, switches at once and is remembered). Every player-facing text is translated, including the check-in, reflection and Data & Privacy; the research CSV is the same in both languages |

## 4. Screenshots

| | |
|---|---|
| ![Main menu](screenshots/01_main_menu.png) | ![Choose a journey](screenshots/20_slot_select.png) |
| ![Whispering Meadow](screenshots/03_meadow_gentle.png) | ![Crystal Creek puzzle](screenshots/07_crystal_creek_puzzle.png) |
| ![Misty Pinewood gloom](screenshots/21_pinewood_gloom.png) | ![Wildlife](screenshots/22_creatures.png) |
| ![Cottage restored](screenshots/16_cottage_restored.png) | ![Farm plots](screenshots/28_farm_plots.png) |
| ![Fishing](screenshots/30_fishing.png) | ![Lighthouse at night](screenshots/25_lighthouse_night.png) |
| ![Whispering Hollow cave](screenshots/34_cave_braziers.png) | ![Singing Grotto beams](screenshots/37_grotto_beam.png) |
| ![The spirit village](screenshots/38_village.png) | ![Village evening](screenshots/41_village_evening.png) |
| ![Aurora over the highlands](screenshots/47_aurora_night.png) | ![Festival of Light](screenshots/42_festival_of_light.png) |
| ![Journal](screenshots/27_journal_creatures.png) | ![Settings](screenshots/49_settings_audio.png) |

Screenshots are rendered from the real game by `tools/capture/capture_screenshots.tscn` (50 shots). Some scenes are set up by the script (items, flags, time of day), and the results screen shows a scripted test session, not real player data.

## 5. Technology stack

- **Godot 4.7.2** (tested), GDScript with static typing, GL Compatibility renderer
- **Python 3.12** (3.10+ should work), pandas, matplotlib, Jupyter; numpy and scipy for the music tools
- No external art, fonts, audio samples, SoundFonts, plugins, API keys or online services

## 6. Installation and running the game

1. Install Godot 4.7.x (standard build, not .NET) from <https://godotengine.org/download>.
2. Clone this repository.
3. Open Godot, click **Import**, select `project.godot`, then press **F5** (Run Project).
   The entry point is `res://game/scenes/main/splash.tscn`.

On first open Godot imports the project and registers the script classes, which takes a few seconds.

From the command line:

```powershell
godot --path . --import          # one-time import (registers class_name scripts)
godot --path .                   # run the game
```

### Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move / run | WASD or arrows / Shift | left stick or D-pad / B |
| Interact | E | A |
| Bag and crafting | I or Tab | X |
| Use or eat (hotbar) | F, 1-8 | right trigger, LB/RB |
| Build mode | B (Q/C item, R rotate, X store, Z undo) | left stick click |
| World map / pin | M / P | right stick click / left trigger |
| Ask Lumi | H | Y |
| Journal (Q/E tabs) | J | Back (LB/RB tabs) |
| Pause / back | Escape | Start / B |

Keys can be remapped in Settings > Controls. Full list: [docs/CONTROLS.md](docs/CONTROLS.md).

**Language / Bahasa:** Settings > Language switches between English and Bahasa Indonesia (Pengaturan > Bahasa).

### Gameplay walkthrough

1. Start Adventure, optionally answer the check-in and pick a mode, then choose a journey (save slot).
2. **Act 1:** gather 8 lights and restore the Heart Tree, then Firefly Grove (Lantern Night), the Crystal Creek puzzle, and the Moon Altar in the Moonlit Sanctuary.
3. Along the way: gather, craft at the workbench, restore the cottage, decorate, plant, fish and cook. Spirit villagers move in as the world brightens.
4. **Act 2:** at the Heart Tree circle you learn about five Hearthstones. Find them in any order:
   - lead the fox kits home (Misty Pinewood);
   - relight the lighthouse (Coast);
   - sail to the Wreck Isle;
   - solve the two Echo Caverns;
   - climb to the highlands and wake the aurora.
5. **Act 3:** set the stones, invite your five friends, and light the Great Lantern. The world stays open afterwards.

Use **Finish Session** (pause menu) at any time, answer or skip the reflection, and view your results. Your world is saved automatically.

## 7. Running the Python analysis

```powershell
python -m pip install -r analysis/requirements.txt
python analysis/analyze_sessions.py data/sample_sessions_SYNTHETIC.csv --out analysis/output
jupyter notebook analysis/session_analysis.ipynb
```

To analyse real sessions, export them in-game (**Data & Privacy -> Export CSV...**) and pass that file instead. The synthetic sample can be regenerated with `python analysis/make_synthetic_sample.py`.

## 8. Data schema (summary)

One row per consented session, schema version 1. Full details are in [docs/DATA_DICTIONARY.md](docs/DATA_DICTIONARY.md).

`schema_version, session_id, session_started_at, pre_stress_score, recommended_mode, selected_mode, final_mode, session_duration_seconds, hints_used, interaction_help_events, items_collected, garden_restored, post_stress_score, score_delta, experience_rating, completed`

- `score_delta = post_stress_score - pre_stress_score`: negative means the later self-report was lower.
- A skipped answer is an **empty cell**, never `0`, because 0 is a valid answer.

## 9. Privacy and consent

- Storage is **off by default**. A clearly worded checkbox at the check-in turns it on for that session.
- No name, email, account, location or device identifiers are collected. The session ID is random.
- Files live in `%APPDATA%\CALMQUEST\` (Windows):
  - `sessions.csv` (consented records);
  - `progress.cfg` (V1 journal progress, no answers);
  - `settings.cfg`;
  - `saves/slot_N.json` (world saves, with no research data). See [docs/DATA_SCHEMA.md](docs/DATA_SCHEMA.md).
- The game contains **no network code, analytics or trackers**.
- **Data & Privacy** explains all of this and offers export, open-folder, delete and reset.

See [docs/PRIVACY.md](docs/PRIVACY.md).

## 10. Adaptive engine (how the "AI" works)

`game/scripts/systems/adaptive_comfort_engine.gd` is a deterministic, rule-based module with no scene dependencies. It contains no machine-learning model.

| Rule | Behaviour |
|---|---|
| Check-in score 7-10 | *Suggest* Gentle |
| Score 4-6 | *Suggest* Balanced |
| Score 0-3 | Ask: Balanced or Playful (Balanced pre-selected, never assumed) |
| Skipped or invalid | Balanced, every mode selectable |
| 3 explicit hint requests | Turn on the guiding glow (unless the player turned it off) |
| 2 interaction attempts just outside reach | Explain the control and show the reach circle |
| "Calmer" / "livelier" choice | Switch mode immediately, keeping all progress |

The engine never raises difficulty automatically and never treats speed, pauses or mistakes as signs of stress. All thresholds are named constants, and all parameters are clamped to documented bounds. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

| Parameter | Gentle | Balanced | Playful |
|---|---|---|---|
| Interaction reach (px) | 104 | 72 | 64 |
| Light movement multiplier | 0.35 | 1.0 | 1.5 |
| Guiding glow by default | on | off | off |
| Bonus Prism Motes | 0 | 0 | 3 |
| Lantern Catch lanterns (+ bonus) | 6 | 8 | 10 (+2) |
| Lantern drift speed (px/s) | 6 | 18 | 30 |

## 11. Testing

Run every automated check on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1 -Godot "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
```

Latest local run (Godot 4.7.2, Python 3.12, Windows 11, after adding Bahasa Indonesia): **all 15 checks passed**. The suite covers:

- static `res://` references,
- 144 GDScript unit tests: world determinism, items and crafting, saves and migration, wildlife, farming, fishing, caves, villagers, story chain, highlands, audio and input, localization,
- a 656-check smoke test, which flood-fills reachability of every interactable across the world, including boat routes, the closed and open mountain pass, and the moonlit veil,
- a 378-check V2 overworld test. It plays every system through real interactions, including Acts 1-3, the finale and both caves, and then saves, wipes memory, relaunches and verifies everything persisted,
- a 39-check UI smoke test (including switching the language live),
- all seven screens loading without script errors,
- the Indonesian catalog: every player-facing string translated, with the same placeholders (in order) and line breaks (`tools/i18n/extract.py`),
- 13 Python tests.

The analysis notebook also executes end-to-end.

Visual and feel checks are manual: see [docs/MANUAL_TEST_CHECKLIST.md](docs/MANUAL_TEST_CHECKLIST.md) (V2) and [docs/TEST_PLAN.md](docs/TEST_PLAN.md) (V1 cases).

## 12. Known limitations

- **Music:** all music is **synthesized placeholder audio** rendered from the game's own MIDI scores. No orchestral renderer or licensed SoundFont was available. The MIDI files are ready to render (see [docs/MUSIC_PIPELINE.md](docs/MUSIC_PIPELINE.md)), and nobody has listened to the placeholders yet.
- **No physical gamepad** was available. The gamepad bindings exist and are unit tested, but have not been tried by hand.
- **Not play-tested by people.** Everything above is verified by automated tests and scripted screenshots only. See the [manual test checklist](docs/MANUAL_TEST_CHECKLIST.md).
- The Frostbloom Highlands are a compact region (one pass, one shrine, one waystone).
- Art is procedural and intentionally simple (no sprite animation).
- The Indonesian translation has not been reviewed by a native speaker yet, and the stress question in Indonesian is a plain translation, not a validated instrument. The session record does not store the language.
- The UI is built in code, so screens appear empty in the editor's 2D view until you run them.
- Self-report scores are a single subjective item, not a validated instrument.
- The export dialog uses the native Windows file dialog. Other platforms were not tested.

## 13. Seven-day MVP scope

The MVP scope covers the playable core loop, the three modes, reflection, opt-in storage, the analysis pipeline and documentation (see [docs/DEVELOPMENT_ROADMAP.md](docs/DEVELOPMENT_ROADMAP.md)). Multiplayer, additional areas and machine learning are deliberately out of scope.

## 14. Roadmap

Additional areas, more mini-games, cosmetic customization, a Shared Dream Garden co-op mode, a properly designed usability study ([docs/EVALUATION_PLAN.md](docs/EVALUATION_PLAN.md)), and, only with adequate consented data, a separately evaluated personalization model.

## 15. Repository layout

```
project.godot            Godot project (entry: game/scenes/main/splash.tscn)
game/scenes/             main, ui, world, player, companion, collectibles, garden, minigames
game/scripts/            autoload, systems (adaptive engine...), data (CSV layer), world, ui...
game/data/               world, quests, items, recipes, wildlife, sites, caves, villagers, lore, homestead, i18n/id (JSON)
game/shaders/            ground, river and gloom shaders
assets/music/            midi/ (original scores), placeholder/ (synthesized loops)
assets/ambience/         placeholder/ (synthesized ambience loops)
tests/                   GDScript unit tests + V1 smoke, V2 overworld and UI tests
analysis/                analyze_sessions.py, notebook, tests, synthetic data generator
data/                    sample_sessions_SYNTHETIC.csv (synthetic only)
docs/                    design, architecture, data dictionary, privacy, tests, roadmap, evaluation
tools/                   run_checks.ps1, check_references.py, screenshot capture, perf probe, music/ (compose.py, ambience.py), i18n/extract.py
```

## 16. Acknowledgments and asset licenses

All art is drawn procedurally in GDScript. Sound effects are synthesized at runtime, and music and ambience are synthesized offline from original scores by `tools/music/`. All of it is original to this project. The UI uses Godot's built-in default font. No third-party assets are included. Godot Engine is MIT-licensed (© Godot Engine contributors).

## 17. License

MIT - see [LICENSE](LICENSE).
