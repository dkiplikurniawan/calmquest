# V2 Inspection Report (Milestone M0)

Date: 2026-10-11. The project was inspected directly in code, scenes and data, not from documentation alone.
Backup made before any V2 edit: `E:\CALMQUEST_backups\CALMQUEST_pre_v2_20261011_071149` (231 files, verified identical). The project is **not** a git repository.

## 0. Most important finding

**"World 2.0" does not exist in this project.** No code, scene, data file or document mentions Firefly Grove, Crystal Creek, Moonlit Sanctuary, a "Follow the Lost Lights" quest chain, or a crystal puzzle. These names appear only in `CALMQUEST_V2_PROMPT.md`. The playable game is the **V1 MVP**: one area, Whispering Meadow.

Consequences for the plan:
- **M1 (stabilize World 2.0)** is reinterpreted as: verify and stabilize the real V1 baseline, then *build* Act 1 (Lost Lights, Firefly Grove, Crystal Creek, Moonlit Sanctuary) inside the new large world, because Act 1 needs regions that only M2 creates.
- **The Lantern Catch site** moves from the meadow to Firefly Grove, as the prompt asks.
- **There is no existing crystal puzzle to "preserve"**, so a new one is written for Crystal Creek.

## 1. What exists and works (verified by the baseline run below)

| System | Where | Notes |
|---|---|---|
| Boot flow | `splash.tscn` → main menu → check-in → meadow → reflection → results | `SceneRouter` fades, always unpauses |
| Autoloads | `GameSettings`, `AudioManager`, `SessionState`, `SceneRouter` | input actions are registered at runtime in `InputSetup` (not in `project.godot`) |
| Display | 1280×720 viewport, `canvas_items` stretch, `expand` aspect, GL Compatibility | no MSAA |
| World | `whispering_meadow.tscn` + `MeadowLayout` data + `MeadowGround` `_draw` | **2560×1600 px ≈ 2.0 × 2.2 screens**. No tiles; all art drawn procedurally. Decorations spawned once (≈ 400 nodes) |
| Player | `Player` (CharacterBody2D, floating motion, 220 px/s) | reach-limited E interaction through the `interactables` group; input block after modals |
| Camera | `Camera2D` child of the Player | smoothing 6, limits = map rect. No look-ahead, dead zone or zoom |
| Lumi | `Lumi` | exponential follow, dead zone, recovery at 520 px, reactions. Hints via H (`LumiGuide`) |
| Core loop | 12 lights → Heart Tree (8) → 3 garden beds, 3 hidden details, Journal | state in `SessionState` (per session) |
| Lantern Catch | `LanternCatch` + `Lantern` + `LanternShrine` (in the meadow) | night via `CanvasModulate`, PointLight2D on lanterns, Lumi, shrine and tree |
| Adaptive engine | `AdaptiveComfortEngine` + `ModeConfig` | Gentle/Balanced/Playful presets, bounded, hint and reach-help rules |
| Reflection and data | check-in, reflection, results; `SessionRecord`, `SessionStorage`, `CsvCodec` | consent off by default; `sessions.csv` schema v1 (16 columns) |
| Persistence | `settings.cfg`, `progress.cfg` (journal counters), `sessions.csv` | **the world itself does not persist**: every session starts a fresh meadow |
| Audio | `AudioManager` + `SoundSynth` | runtime-synthesized SFX and one ambient pad. Buses Master/Music/SFX |
| UI | built in code with `UiKit`/`UiTheme`. HUD, pause and completion are on CanvasLayers, which receive the theme explicitly | text size, high contrast, reduce motion |
| Tests | `tools/run_checks.ps1` | static refs, unit, smoke, UI smoke, 6 scene loads, Python |
| Analysis | `analysis/analyze_sessions.py`, notebook, synthetic sample | reads the real `sessions.csv` (2 real rows present; loads with 0 issues) |

## 2. Exists but broken or incomplete

- No functional bugs are known from automated tests. Manual play items from `docs/TEST_PLAN.md` (keyboard feel, fullscreen, native export dialog) are still unverified by me.
- Known non-blocking warning: "2 ObjectDB instances leaked at exit" in some headless runs (audio playback freed asynchronously at forced quit).
- Gamepad: not supported. Key remapping: not supported.

## 3. Only documented, not implemented

- Everything described as "World 2.0" (see section 0).
- Moonwater Lake and Starlight Garden (V1 roadmap only).
- Co-op (documented concept only).

## 4. Technical constraints

| Constraint | Impact on V2 |
|---|---|
| One scene, all objects spawned at once | Must become chunk-streamed for a world at least 8×8 screens |
| Hard-coded absolute positions in `MeadowLayout` | Must become relative to a region origin inside the world |
| No tile art; procedural vector drawing | `TileMapLayer` needs tile textures that don't exist. Ground will instead be rendered by one shader quad from an authored macro map (see plan) |
| Ground drawn in `_draw` over the whole map | Fine for 2560 px, not for 10240 px. Replaced by the shader |
| Gameplay authority mixed into `SessionState` (session metrics and world state) | V2 adds `GameState` for world state. The meadow loop keeps using `SessionState` until inventory and saves (M3/M5) consolidate it |
| Physics layers: all default layer 1 | Document and keep (no layer-dependent logic yet) |
| Input map created at runtime | Keep. Add new actions in the same table |
| UI built in code | Keep the pattern (consistent theme, testable) |

## 5. Extend / refactor / create

| Extend | Refactor | Create |
|---|---|---|
| `Player` (run toggle), `Lumi` (wider-world catch-up), `Decoration` (biome kinds), `Hud` (tracked quest, region card, compass, minimap), `PauseMenu`, `SettingsPanel`, `JournalPanel` (quests), `InputSetup` (map, run, pin), `GameSettings` (new options), `SceneRouter` (overworld path) | `WhisperingMeadow` becomes the **Overworld** orchestrator; the meadow content becomes a region placed at an origin. V1 smoke test retargeted to the new scene | `WorldData` + `overworld.json` (authored macro map), ground shader, terrain collision, `WorldStreamer` (chunks), `ChunkGenerator` (seeded placement), `WorldCamera`, `GameState` and `EventBus` autoloads, `QuestBook` / `QuestManager` (data-driven quests), waystones and fast travel, world map with fog of war, region tracking, Crystal Creek beam puzzle, Moon Altar finale |

## 6. Baseline test results (before any V2 change)

`tools/run_checks.ps1` on Godot 4.7.2 / Python 3.12.10, Windows 11:

| Check | Result |
|---|---|
| Static `res://` references | PASS, 66 checked, 0 missing |
| Godot headless import | PASS |
| GDScript unit tests | PASS, 44/44 |
| Integration smoke test | PASS, 109/109 |
| UI smoke test | PASS, 27/27 |
| Six screens load headless | PASS, 6/6 |
| Python analysis tests | PASS, 13/13 |
| Real `sessions.csv` through the analysis loader | 2 valid, 0 excluded, schema matches |

## 7. Risks

| Risk | Mitigation |
|---|---|
| Performance with a much larger world | Stream decorations per 1024 px chunk around the camera (budgeted builds per frame); ground on the GPU; few PointLight2D. Measure FPS in a real window |
| Pop-in at chunk borders | Load chunks for the camera rect plus a margin before they become visible |
| Breaking the research flow | Keep check-in, reflection, results, consent and CSV untouched; re-run all existing tests each milestone |
| Save compatibility (`progress.cfg`, `sessions.csv`) | M2 does not change either format. M5 adds a separate versioned save with migration from `progress.cfg` |
| Node-path fragility in a bigger scene | Prefer `@onready` with unique names and signals; data-driven placement |
| Scope (M0-M12 is very large) | Vertical-slice rule: finish M0-M2 properly, label every region stub honestly |
| Test drift | Update tests only where the design deliberately changed and explain why in `V2_PROGRESS.md` |

## 8. Implementation plan (mapped to milestones)

**M1: baseline stabilization.** The V1 loop is verified (section 6). Act 1 depends on M2 regions, so it is built as part of M2.

**M2: large world foundation and Act 1.**
1. **Authored macro map** `game/data/world/overworld.json`: 40×24 cells of 256 px gives **10240×6144 px ≈ 8.0 × 8.5 screens**. It also defines region legend and palettes, paths, river, POIs, waystones, landmarks and gates. Grid size comes from data, so 16×16 screens needs no refactor.
2. **Ground:** one shader quad blending biome colors with noise-warped bilinear interpolation (no rectangular seams), plus Line2D paths and an animated river.
3. **Terrain collision:** ocean, cliff and deep-water cells, river banks (with gaps at bridges and stepping stones), outer safety ring.
4. **Chunks:** 1024 px. Decorations are generated deterministically (seed + FastNoiseLite) and streamed by camera rect + margin, at most a set number of builds per frame. World deltas are stored in `GameState` and re-applied on reload.
5. **Camera:** smoothing, look-ahead, dead zone, world clamping, context zoom per region and viewpoints, and a *reduced camera motion* setting.
6. **Run toggle** (Shift: hold or toggle), no stamina.
7. **World map (M)** with fog of war, region names, discovered POIs, waystones, player pins and travel. Optional minimap (off by default) and a quest compass (on by default, can be turned off).
8. **Waystones:** discover, relight, then travel freely at no cost.
9. **Region tracking** with a first-visit title card.
10. **Migrate V1 content** into the Whispering Meadow region. Move the Lantern Shrine to Firefly Grove.
11. **Act 1 as data-driven quests:** Follow the Lost Lights → Lanterns of Firefly Grove → Awaken Crystal Creek (new beam puzzle with reset and hint ladder) → Restore the Heart of Lumeria (Moon Altar finale). Free exploration continues afterwards.
12. **Region shells** for Misty Pinewood, Sunpetal Coast and Frostbloom Highlands: terrain, decorations, landmark, waystone. They are explicitly labelled stubs; content arrives in M6/M10. Gated areas (islands, highland path, cave entrances) show visual hints.
13. **Tests:** world determinism, chunk delta restore, camera clamp, bounds and reachability, quests (early collection, prerequisites, no reset), puzzle (solvable, reset), waystones, map fog, and Act 1 completable end-to-end.

**M3-M12** follow the order in the V2 prompt and are not started in this pass.
