# V2 Progress Log

Each milestone ends with tests run, the game launching, a note here, and a backup (the project is not under git).

## M0 - Inspection and plan (2026-10-11)

- Backup: `E:\CALMQUEST_backups\CALMQUEST_pre_v2_20261011_071149`.
- Baseline: `tools/run_checks.ps1` passed 12/12. The real `sessions.csv` (2 rows) loads in the analysis with 0 issues.
- Report: [V2_INSPECTION_REPORT.md](V2_INSPECTION_REPORT.md).
- Key finding: "World 2.0" was never implemented. Act 1 is therefore built on top of the M2 world.

## M1 - Baseline stabilization (2026-10-11)

- The V1 loop (meadow, Lantern Catch, adaptive modes, reflection, CSV) passes all automated checks. No V1 defects were found that needed fixing before M2.
- Act 1 content moves into M2 because its regions don't exist yet (see the inspection report).

## M2 - Large world foundation and Act 1 (2026-10-11)

**Built:**
- **World:** authored macro map, 10240×6144 px ≈ 8.0 × 8.5 screens, 9 regions (4 playable, 5 stubs).
  - Ground is drawn by a shader with smooth biome blending; paths, an animated river, a bridge and stepping stones are drawn on top.
  - Terrain collision plus a safety ring.
- **Streaming:** deterministic seeded chunks (1024 px) streamed around the view, with world deltas.
- **Camera:** look-ahead, dead zone, region zoom, clamping, and a reduced-motion option.
- **Movement:** Shift to run, with no stamina.
- **Navigation:** region tracking with title cards, world map (M) with fog of war, pins and travel, optional minimap, quest compass, 6 Lantern Waystones with free travel.
- **Act 1:** a data-driven quest system (`QuestBook` / `QuestManager` / `act1.json`). The four quests run from the Lost Lights through Firefly Grove (Lantern Catch moved there) and the Crystal Creek beam puzzle to the Moon Altar finale, which lifts the world's colors. Exploration continues afterwards.
- **Locked places:** honest stub gates (collapsed highland path, two sealed caves) and the moonlit veil.
- **New autoloads:** `EventBus`, `GameState`, `QuestManager`.

**Bugs found by the new tests and fixed:**
- Chunks loaded around the world origin on the first frame, because the camera's screen center was still (0,0). Streaming now centers on the player.
- The camera could show empty space past the map edge, because Godot doesn't clamp `Camera2D.offset`. Look-ahead now moves the camera position instead.
- The meadow waystone was placed 12 px from `light_05` and stole its interaction. It was moved to open ground.

**Deliberate test changes (design changed, not weakened):**
- `tests/smoke/smoke_test.gd` loads `overworld.tscn` instead of the removed `whispering_meadow.tscn`, and reaches meadow objects through `world.meadow`. Reachability now flood-fills the **whole world**: grid 32 px instead of 24 px, because the area is about 16× larger. It also checks that the sanctuary is unreachable before the veil opens. Checks went from 109 to 165, all passing.
- `tests/unit/test_world.gd`: an object-count sanity floor that I set when writing the test was lowered from 3000 to 2000 (actual: 2876). It was a guess, not a requirement.

**Results:** `tools/run_checks.ps1` passed 13/13:
- 64 unit tests;
- 165 smoke checks;
- 68 overworld checks;
- 30 UI checks;
- 6 screens;
- 13 Python tests;
- 88 references.

**Performance** (real window, RTX 3050 Laptop GPU, GL Compatibility, scripted running):
- average 72.6 FPS, minimum 51 FPS;
- chunk build 1.4-8.3 ms, 9-12 chunks and about 270 scenery objects loaded at a time.

**Not done in M2:** day/night cycle, weather, fog layers, music pipeline, gamepad, saves (M5), all gathering/crafting/building systems (M3+).

## M3 - Gathering, inventory, crafting (2026-10-11)

**Built:**
- **Items:** 37 items as data (`game/data/items/items.json`), of which 18 are resource types. The single magic resource is **Luma Light**, an inventory item: lights and prisms now give Luma Light, which the Heart Tree and garden beds spend.
- **Gathering:** gather profiles per biome in `overworld.json`. Gatherable resources are placed by the same deterministic chunk generator; reeds and clay grow only at the river edge. Gathered resources are stored as world deltas and grow back after 1-3 in-game days. Only fallen or loose things are gathered (no tree felling).
- **Inventory** (`Inventory`):
  - 30 slots, stacks of up to 99;
  - an 8-slot hotbar (keys 1-8) on the HUD;
  - sorting and click-to-swap;
  - bags add +10 slots each;
  - unique tools and quest items can never be discarded;
  - a full bag never loses items (they stay in the world).
- **Crafting** (`CraftingBook`):
  - recipes as data;
  - stations: by hand, the workbench beside the cottage (tier 1), the cottage workbench (tier 2, M4);
  - have/need display;
  - a craft that wouldn't fit is refused with no loss.
- **Recipe discovery:** known at the start, from lore notes (4 placed in the world), or from story flags (Bright Lantern after Act 1).
- **First tools:** lantern (starting tool), bright lantern, watering can, fishing rod, crystal tuner, small boat, climbing rope and two bags are craftable. Their gameplay uses arrive in M6-M10.
- **Clock and buffs:**
  - `TimeManager` provides an in-game clock (15/20/24 real minutes per day), "keep it day/night", and a Gentle-mode clock that runs at half speed or pauses.
  - Day/night tint with dusk warmth, plus night lights; night is visual only and always safe.
  - Clock on the HUD.
  - A food buff framework (`ItemConsumer`) for M7.
- **Side quest:** "A Traveler's Toolkit" teaches gathering and crafting.

**Architecture change:**
- Persistent world progress moved from `SessionState` to `GameState`: inventory, collected objects, beds, discoveries, lantern nights.
- `SessionState` keeps only research-session metrics. The V1 API is preserved through read-only properties.
- `garden_restored` in the CSV now explicitly means "restored during this session" (`tree_restored_this_session`), which was always its documented meaning.

**Test runner improvement:** `tests/run_tests.gd` installs a `Logger`, so a runtime error inside a test now counts as a failure. Before, it only showed up in the log (caught by `run_checks.ps1`, but not in the runner's own count). Verified with a deliberate error in a probe project.

**Deliberate test changes:**
- Quest tests count Act 1 quests specifically, because a side-quest file was added.
- The world placement test handles gatherable kinds.
- The reachability test skips optional gatherables inside deliberately locked regions; story POIs must still be reachable.
- "No quest forced after Act 1" now checks that no *main* quest is forced, since a side quest may be tracked.

**Results:** 13/13 checks. 78 unit tests, 525 smoke, 84 overworld, 30 UI, 6 screens, 13 Python, 94 references.

## M5 - Save system V2 (2026-10-11, done before M4 because M4's bed and interiors autosave)

**Built:**
- **`SaveManager` autoload:** 3 slots in `%APPDATA%\CALMQUEST\saves\slot_N.json`, `save_version` 2 with a migration chain. A v1 test format is migrated; future or unknown versions are refused safely.
- **Atomic writes:** the save is written to a `.tmp` file and read back to verify it. Only then does the previous file become `slot_N.bak.json` and the temp file get renamed into place. A damaged main file falls back to the backup with a warning (not an engine error), and an unreadable slot is reported clearly and can be deleted.
- **What is saved:** everything in `GameState`, quest progress, the clock, player position, facing, region and sublevel, the mode at save time (informational; the session's check-in choice is not overridden), Lumi state and playtime. **Settings** persist separately in `settings.cfg`, as before.
- **Autosave:**
  - sleeping and entering/leaving interiors/caves (wired in M4/M8);
  - completing a quest;
  - Finish Session and returning to the main menu;
  - closing the window;
  - every N minutes (Settings: 3/5/10/off; default 5).
- **Manual save and load** from the pause menu. Loading first saves the current journey, so nothing is lost.
- **"Choose a journey" screen** after the check-in: Continue / Begin a new journey / Start over / Delete, with confirmations and the last slot pre-selected.
- **Migration from V1:** V1 had no world save, so `progress.cfg` (journal counters) is copied into a new journey's `legacy_journal` and the file itself is left untouched. "World 2.0" never existed, so there were no World 2.0 saves to migrate.
- **Research data stays separate:** saves never contain check-in, reflection or consent data (tested).
- **Restart Session** now means: a new session timer and metrics, with the world reloaded from the last save. Without a slot (e.g. a scene run directly) it starts a fresh world, as in V1.

**Fixes found while testing:**
- The unit runner now starts on the first processed frame, because autoloads were not yet `_ready` during `SceneTree._initialize`.
- Corrupt-save parsing no longer emits engine errors.

**Results:** 83 unit tests (5 new save tests). The overworld test has 93 checks, including a full simulated quit-and-relaunch round trip.

## M4 - Cottage, homestead, decorating, cooking (2026-10-11)

**Built:**
- **Cottage interior:** a sub-level (11×8 cells of 64 px) placed outside the map and entered through the cottage door with a fade. The camera bounds switch to the interior. Leaving puts the player back at the door, and each transition autosaves. Interior walls have collision, and a flood-fill test checks that every spot inside is reachable from the door.
- **Restoration:** 8 steps, in data (`game/data/homestead/cottage.json`): roof, hearth (after the roof), window, bed, workbench, cooking pot (after the hearth), storage chest, bookshelf.
  - Each step takes materials from the bag and/or the storage chest.
  - Each step sets a flag, can teach decor recipes, and changes how the interior and exterior look (chimney smoke, window glow, warm interior light once the hearth is lit).
  - Missing materials only produce a friendly explanation.
- **Bed:** sleep until morning, with a fade and an autosave. There is no energy meter.
- **Cottage workbench (tier 2), storage chest (40 slots), and crafting that can use the chest's contents** when standing nearby.
- **Cooking pot:** known dishes plus experimentation with up to 3 ingredients. Experimenting never uses ingredients up. 5 dishes in `food.json`/`cooking.json`. Food only gives gentle, temporary, optional buffs (`ItemConsumer`); there is no hunger.
- **Decorating:** 16 decor items with footprints, rotation, and an indoor/outdoor/both flag.
  - Build mode (B) works in the cottage and on the homestead plot outside: grid cursor, color plus shape cue plus text reason, rotate, store back for a full refund, undo, keyboard and mouse.
  - Placements persist in `GameState.systems["decor"]`.
- **HUD:** an 8-slot hotbar, use/eat with F, and a "B: Build mode" hint where building is possible.

**Visual review (screenshots 14-20) and fixes:**
- Pickup notes could pile up (16 at once, covering the quest panel). They are now capped at 5; the oldest note makes room.
- The cooking panel now pre-selects the first known dish, so "Cook" is not greyed out for no visible reason.
- The restoration toast read like a task ("Build a storage chest"). It now reads "Done: …".

**Results:** the overworld test has 150 checks: M4 sections for the cottage, reachability, restoration, sleep, tier 2, chest, cooking, experimenting, buffs, decor, build mode and undo, plus persistence after relaunch. The smoke test has 519 checks.

## M6 - Misty Pinewood, Sunpetal Coast and Isles (2026-10-11)

**Built:**
- **Wildlife:** 16 original creatures in data (`game/data/wildlife/creatures.json`), drawn procedurally (`CreatureArt`, 13 body shapes). Each creature belongs to regions, a time of day and optionally a weather (the rain snail waits for M7 rain).
  - `WildlifeSpawner` keeps up to 5 creatures near the player (10 with the Forest Skewer buff, which also makes rare ones more likely). New ones appear off-screen; far ones are removed.
  - Behavior: idle, wander, move away gently when someone hurries close, and come closer when the player stands still. No harm and no loss.
- **Creature Journal:** watching a creature calmly for 3 s, or greeting it (E), sketches it.
  - Liked treats raise friendship (max 3, once per in-game day). Friendship never decays.
  - Full friendship gives a one-time gift; with a full bag the gift goes to the cottage chest.
- **Tabbed Journal (J):** Quests (with Follow), Map, Creatures, Fish*, Recipes, Lore, Collections, Villagers* (*filled in M7/M9). Q/E switch tabs, and tabs use the cozy theme.
- **Gloom:** 4 patches (3 in the pinewood, 1 on the coast). Inside a soft circle, a shader removes most color and dims the world, with drifting mist on top.
  - Gloom hides the resources inside it and the lost fox kits; one patch also has shadow thorns around a hidden glade.
  - A Bright Lantern (unlocked after Act 1, made from renewable materials) clears gloom at its heart. Color flows back, flowers open, thorns melt, and the patch gives a small reward.
  - Without it, Lumi explains what is needed.
- **Gloomlings:** 4 shy shadow creatures. One sits in a narrow path (a gentle block); all keep something safe.
  - A choice panel offers three kind actions: shine light, hum a melody, or offer food. Every one works; a Gloomling's favourite gets a warmer line.
  - The Gloomling becomes a light spirit, frees the path and leaves its item.
- **Fox family (pinewood Hearthstone):** 3 kits hidden in the pinewood gloom. Coax a kit to follow you (it follows through travel, doors and saves), and it runs home near the den. With all kits home, you receive the Hearthstone of the Pines.
- **Lighthouse (coast Hearthstone):** a data-driven `RestorationSite` (`game/data/sites/sites.json`) with a checklist panel and 4 steps (door, then stairs, then lens, then lamp), using only renewable materials. The lamp stays dark until it is relit; once lit, a beam sweeps the sea at night.
- **Boat and isles:** 4 docks in 2 pairs. With a Small Boat in the bag, E sails to the paired dock (a fade); without one, the dock explains how to build one. Both isles are now playable.
- **Shipwreck puzzle (isles Hearthstone):** 4 signal lanterns around the mast, each with a color plus a shape cue. The captain's log on the isle explains the solution; there is a reset lever and a 3-step Lumi hint ladder (in Gentle mode it highlights the lanterns still to change).
- **Atmosphere:** layered drifting fog and pink light shafts in the pinewood, a light haze on the coast. They fade with the region, dim at night and respect Reduced Motion. Abandoned woodcutter cabins and tide pools added.
- **5 Hearthstone items** (two are for M8/M10). 5 new side quests: Field Sketches, The Dimming Pines, A Family in the Fog, Light on the Water, Across the Calm Sea. They become Act 2's backbone in M9.
- **Map:** shows uncleared gloom and docks; minor points (kits, scenery) stay off the map.

**Performance finding and fix:** the windowed FPS sample dropped from 62 to 41 average after adding M6.
- A new probe (`tools/capture/perf_probe.tscn`) showed the cause: off-screen objects re-recorded their idle animation every frame (about 6-7 ms).
- `ViewCull` now lets animated objects (new ones plus waystones, landmarks, notes, gates) skip redraws when far from the camera. The gloom veil animates in its shader and never redraws.
- After the fix: about 65-74 fps in the probe, and an average of 68.1 fps (minimum 51) in the capture walk.

**Test changes (deliberate design changes):**
- The smoke test's reachability flood fill now follows boat routes (a reachable dock links to its paired dock's landing spot).
- The smoke test skips ambient creatures (they wander and are optional) and lost kits that are still hidden in gloom.
- Gatherables on the isles are no longer skipped.
- The overworld test checks that the hidden kit becomes reachable once its gloom and thorns are gone.

**Results:** 96 unit tests (13 new). The overworld test has 208 checks (58 new: wildlife, gloom, kits, Gloomlings, lighthouse, boat, wreck, quests, journal, plus M6 persistence after a simulated relaunch). The smoke test has 567 checks. Screenshots 21-27 were reviewed; fixes: journal tab styling, lighter pinewood fog.

## M7 - Farming, fishing, cooking, weather (2026-10-11)

**Built:**
- **Weather** (`Weather`): clear, cloudy, rain or mist each day.
  - The roll is deterministic per journey and day, and the first 2 days are always clear.
  - It is remembered in the save, including which days rained.
  - Visuals: an overcast veil, slanted rain streaks (fewer and slower with Reduced Motion) and mist fog. None of them show indoors.
  - A morning toast announces rain ("your crops are watered").
  - Wildlife and fish follow the weather (rain snail, mist koi, rain perch).
- **Farming:**
  - The gardener's note teaches the Garden Plot and the Watering Can, and holds 4 carrot and 4 wheat seeds.
  - Plots are placed on the homestead in build mode and become `FarmPlot` interactables. E plants (with a choice when you carry several kinds of seed), waters or harvests.
  - Each watered or rainy day is one day of growth. **Crops never die**: an unwatered crop simply waits (tested with 60 days).
  - 5 crops: carrot (3 days), wheat (2), strawberry (4, then regrows every 2), pumpkin (5) and Luma Bloom (4).
  - The Luma Bloom harvest also gives Luma Light, so light is now renewable.
  - Seeds come back from harvests and also grow wild, rarely, in the meadow, grove, pinewood and sanctuary.
  - A plot with a growing crop cannot be stored away, and a harvest never loses items: if neither the bag nor the chest has room, the crop waits.
- **The watering can opens paths:** the Forgotten Garden in Firefly Grove is ringed by hedges, and a withered plant fills the only gap. Watering it turns it into a flowering arch; the old chest inside holds strawberry, pumpkin and Luma seeds.
- **Luma Blooms clear gloom:** planting one at a gloom heart works like the Bright Lantern.
- **Fishing:** 11 ripple spots by creeks, ponds, the sea and the isles. With a rod, E opens the minigame: wait, then press when it bites, then reel by holding to keep the fish in a wide, slow zone.
  - There is no fail state: a missed bite swims away and the reel bar never fails.
  - **Gentle mode reels in automatically**, Balanced has a wide zone, and Playful is a bit livelier. The Lucky Line buff halves the wait.
  - 11 fish plus the legendary Old Whiskers at the creek bridge, who comes only after 5 kinds have been caught; it is let go and leaves a plaque (decor).
  - Fish journal tab (caught, biggest, where and when). Full bag: the fish goes to the chest.
- **Cooking:** 8 new experiment dishes from crops and fish (carrot soup, bread, pumpkin pie, jam, fisher's stew, grilled trout, creek skewer, Luma tea). Buffs are optional and gentle.
- **Quests:** The First Harvest, The Forgotten Garden, The Old Whiskers.

**Test changes:**
- The smoke test skips the forgotten garden's chest while the withered plant still blocks it; the overworld test checks the chest is reachable after watering.
- The overworld test's homestead decor count is now 3 (it places a garden plot in M7).
- The deer is put at a known distance before the "moves away" check, because it wandered during the sketch wait (a flaky case seen once).
- `_make_room()` moves stacks to the chest, because the long test filled the bag.

**Results:** 110 unit tests (14 new: weather, crops never die, rain, regrowing, full bag, plot store refusal, fish data, legendary rule, journal, no-fail minigame, Gentle auto-catch, recipes, garden). The overworld test has 250 checks (42 new); 2 consecutive runs were green.

## M8 - Echo Caverns (2026-10-11)

**Built:** two handcrafted cave systems, defined as data in `game/data/caves/caves.json` (ASCII maps plus puzzle definitions). They are sub-levels outside the map, entered through `CaveEntrance` objects that replace the two "sealed cave" stubs.
- **Entering and leaving:** a fade and an autosave each way. A Bright Lantern is needed to enter because it is dark (clearly explained). You can always walk back out, and loading a save made inside a cave puts you back inside it.
- **Whispering Hollow** (Misty Pinewood): a chain of four rooms.
  1. Light four braziers in the order of the dots painted on them. A wrong one gently puts the flames out, with an explanation.
  2. Push two stone blocks onto two pressure plates. E pushes a block one cell away from you; walls and other blocks stop it.
  3. A chasm: shining the Bright Lantern from a pedestal reveals a bridge of light.
  4. A chest (crystal shards, moon dew and a Crystal Lamp) and the *Song of the Crystals* note, which teaches the Crystal Tuner. Opening the chest also opens a shortcut gate.
- **Singing Grotto** (above Crystal Creek): a crystal door opens only with the Crystal Tuner (tool gating). Two light-beam puzzles follow (4×3 and 5×4, reusing the creek's beam logic with their own layouts and hints). They open the inner seal and light the **Hearthstone of the Echoes** pedestal; a sealed chest opens as well.
- **Every puzzle** has clear visual feedback, a reset lever and a 3-step Lumi hint ladder (H inside a cave). Gentle mode highlights the next brazier or crystal. No timing and no precision are required.
- **Persistence:** puzzles, block positions, the revealed bridge, tuned doors, chests and Hearthstones are all saved.
- **Visuals:** caves are dim (tinted) with lit braziers, glowing crystals and Lumi's light. The floor and walls are clearly separated (first screenshots looked like a checkerboard; fixed).
- **Quest:** "Echoes Below" (6 steps).

**Results:**
- Unit tests: 116 (6 new). They verify that every cave can be solved room by room using a grid flood fill from the entrance, that brazier mistakes are gentle, that blocks never get lost and reset correctly, and that the tuner door and beams lead to the Hearthstone.
- Overworld test: 321 checks (71 new). Both caves are entered and solved through real interactions, with a physics flood fill inside each cave with all doors open, the save-inside-a-cave restore, and persistence after relaunch.

## M9 - Villagers, request board, Act 2, Act 3, post-game (2026-10-11)

**Built:**
- **5 original spirit villagers** (`game/data/villagers/villagers.json`): Bramble (moss gardener), Pip (lantern-moth courier), Mossa (mushroom cook), Wren (sea-wind sailor) and Fennel (ember-fox storyteller).
  - Each has a personality, an arrival condition tied to restoring the world (Heart Tree, creek, Act 1, lighthouse, fox family), a home, a daily routine (near home in the morning, a favourite spot by day, the campfire in the evening, asleep at night with "Zzz" at a lit window), gift preferences, about 9 kinds of short original lines, and a 3-4 step personal quest (type `villager`, unlocked on arrival).
- **Homes:** villagers live in a tent until the player builds their home (a 2-step `RestorationSite` each). The village visibly grows: homes, lantern strings over the board, a market stall after 3 homes, and a campfire with music notes in the evening.
- **Friendship:** points and petals (5 max) that never decay.
  - Talking once a day and a gift once a day raise them (loved > liked > anything). Keepsakes cannot be given away.
  - Best friends give a one-time present: a cosmetic plus items.
  - Quest deliveries use a "Hand over" button in the chat panel (data: a `deliver` field on the quest step).
- **Request board:** 12 requests, up to 3 open at a time, only from villagers who live here. They never expire and have no penalties. Requests are deliveries or check-ins (sketch a creature, catch a fish, place lanterns, sail to an isle).
- **Cosmetics:** 3 cloaks for the Traveler and 4 glows for Lumi, purely visual. They are earned from friendships and chosen in the Journal's Collections page; the choice persists.
- **Act 2 "The Five Hearthstones"** (main): listen to the Heart Tree at the new Hearthstone circle, then restore the five Hearthstones in any order (pinewood, coast, isles and caverns from M6/M8; highlands in M10). The M6/M8 side quests guide each activity.
- **Act 3 "Return of the Light"** (main): set the Hearthstones in the circle, invite all five friends, then light the Great Lantern.
  - The finale: a short night cutscene with everyone gathered, Hearthstone beams into the Heart Tree, the world restoration effect, all gloom cleared (patch rewards are still given, silently), and a gentle closing panel.
  - The world stays open afterwards.
- **Post-game:** the "A Wider Journal" quest (optional goals), the Aurora Stag (a creature that appears only after the finale), and an epilogue note at the sanctuary.
- **Journal:** the Villagers tab (petals, loves, home status). Collections now has completion percentages (creatures, fish, recipes, notes, decorations, best friends) and the wardrobe.
- **Quest system:** an optional `unlock` condition, and `rewards` (items, friendship, cosmetic) applied when a quest completes. New facts: waystones relit, notes read, dishes cooked and dish kinds, things placed, sailed to.

**Deliberate test change:** `overworld_test` used to check "no main quest is forced after Act 1". The V2 story continues with Act 2, so the check is now "after Act 1, Act 2 begins as a gentle goal with no time limit". The free-walking check right before it is unchanged.

**Screenshot review fixes:**
- Finished homes no longer show the building signboard.
- The finale gathers villagers instantly (they were still walking in).
- Clearing all gloom in the finale no longer spams four dialogues.

**Results:** 123 unit tests (7 new). The overworld test has 354 checks (33 new): arrivals, home building, chat, gift, delivery, board, Act 2, a real finale run, post-game, and persistence after relaunch.

## M10 - Frostbloom Highlands (2026-10-11)

**Built (a compact but complete region rather than a stub):**
- **The pass:** one cliff cell of the macro map became a mountain pass (`r`, highlands region), the only way up. Fallen rocks fill it completely (`PathBarrier`) until the **old mountain path** is restored.
  - The path is a 3-step `RestorationSite`. Step 1 needs the **Climbing Rope as a tool**: it must be in the bag and is never used up (new `tool` field on site steps). Steps 2-3 need branches, planks and stone.
  - The climber's note on the coast below teaches the rope (twine and resin, cottage workbench).
- **The highlands:** snow pines, frost flowers, frost petals to gather, snowpuffs (wildlife), a new waystone, a lore note, and the existing Frost Peak landmark. The atmosphere adds a cool haze.
- **The aurora shrine** (the highlands Hearthstone): three ice prisms around a sleeping crystal. Each prism sends a beam in the direction it faces and turns a quarter with E. When all three beams meet the crystal, the aurora wakes.
  - There is a reset lever and a 3-step hint ladder (in Gentle mode it highlights the prisms still to turn).
  - The puzzle gives the **Hearthstone of the Aurora**, and afterwards the aurora ribbons dance across the highland sky at night.
- **Quest:** "Above the Clouds" (5 steps). All five Hearthstones (and so Acts 2 and 3) are now reachable through real play.

**Test changes:**
- The smoke test now gates the highlands like the moonlit veil. On the first pass, every highland interactable must be **unreachable** (this proves the pass is closed). On the second pass (path open) they must all be reachable, including highland gatherables, which were skipped before.
- The overworld test's M9 section used to grant the fifth Hearthstone manually. It now runs after the new M10 section and checks that all five were found through play.

**Results:** 127 unit tests (4 new). The overworld test has 369 checks (15 new: the blocked pass, the rope requirement, the rope being kept, walking up through the opened pass, arriving in the region, the shrine, the Hearthstone, the quest). The smoke test has 656 checks.

## M11 - Polish: music pipeline, audio, input, accessibility, visuals (2026-10-11)

**Music, honestly labelled:**
- `tools/music/compose.py` composes **14 cues** as code. A shared Lumeria theme is varied per place; keys are major, Lydian or Mixolydian at 58-76 BPM; 8-bar progressions loop seamlessly.
- It writes **multi-track General MIDI files** (`assets/music/midi/`) with its own small SMF writer, because mido and pretty_midi are not installed. Each file has GM programs, tempo, meter, soft velocities and CC7/11/64/91.
- The machine had no MuseScore, no FluidSynth, no licensed SoundFont and no ogg/ffmpeg encoder. So, as the brief requires, nothing pretends to be orchestral:
  - the game uses **synthesized placeholder loops** rendered from the same notes (numpy additive synthesis, a noise reverb, the reverb tail wrapped onto the start for seamless loops, RMS -22 dBFS as a stand-in for -20 LUFS);
  - they are 16-bit WAVs with a `smpl` loop chunk.
  - `docs/MUSIC_PIPELINE.md` explains how to render them properly.
- Checked numerically: valid MIDI (note on/off balanced), no clipping, equal loudness, and a loop-seam jump far below the typical sample-to-sample change. **Nobody has listened to them yet** (manual checklist).
- `tools/music/ambience.py`: 8 original ambience loops (pine wind, highland wind, waves, creek, cave drips, night insects, meadow birds, rain).

**MusicManager (new autoload):**
- cues per region, cottage, caves and finale;
- 3 s crossfades, and a **2 s hysteresis** so border-walking never restarts the music;
- the meadow uses **adaptive layers** (AudioStreamSynchronized: a base layer, plus a day flute layer and a night piano layer that cross over with the clock);
- the restoration stinger ducks the music;
- "Continuous / Quiet pauses / Off" (longer pauses in Gentle mode);
- ambience per region and time, with rain on rainy days (outdoors only);
- a safe fallback: a missing file logs one warning and the V1 synthesized pad plays.

**Audio buses:** Master, Music, **Ambience**, SFX, **UI**, each with a slider; settings persist.

**Input and accessibility:**
- **Gamepad bindings** for every core action: the left stick or D-pad to move; A, B, X and Y; Start and Back; LB/RB for the hotbar, journal tabs and build items; triggers to use an item or place a pin; stick clicks for the map and build mode. Not tried on a physical gamepad.
- **Key remapping** in Settings > Controls, with a clash note and reset; saved and re-applied at start-up.
- **Captions** for important sounds and music changes.
- A **weather effects** toggle (visual only; rain still waters crops).
- **Hint frequency** (Off / Rare / Normal / Helpful, default by mode): Lumi's occasional nudge toward the followed quest after a while without progress. It uses only the quest's own hint lines and never interrupts menus or dialogue. H always works.

**Adaptive modes, now in every system:**
- Creatures: Gentle are at ease quickly, Playful need more calm.
- Puzzles: Playful gets an optional "fewest moves" bonus, as praise only, on all 6 puzzle types.
- The nudge frequency and the length of music pauses follow the mode.

**Visual polish:** fog banks now have parallax (far banks move slower than the ground, near ones faster), and cloud shadows drift over open regions on clear days. Lumi reacts when a decoration is placed.

**A bug found in screenshot review:** after the finale, the world stayed in the cutscene's forced night forever. The night now lifts afterwards and the clock decides again; a test was added.

**Results:** 138 unit tests (11 new: cue selection, hysteresis, no restart, missing-file fallback, meadow layers, loops, settings persistence, hint frequency, gamepad bindings, remapping, Playful bonus and creature shyness). The overworld test has 378 checks (9 new: in-world music and ambience changes, crossfade cleanup, captions, gamepad hotbar, weather toggle, night after the finale). Capture run: average 60.0 FPS, minimum 42 while walking; the largest chunk build took 10.8 ms.

## M12 - Documentation and final validation (2026-10-11)

- **Rewritten for the finished V2:** README (features, screenshots, controls, walkthrough, tests, limitations, layout), CHANGELOG 0.3.0, GAME_DESIGN_V2, ARCHITECTURE, DATA_SCHEMA (the save format and every `systems` key), ART_DIRECTION, CONTROLS (gamepad and remapping), ASSET_PROVENANCE (music and ambience), the new MUSIC_PIPELINE, MANUAL_TEST_CHECKLIST (V2 systems, all still to be run by a person), PRIVACY (world saves).
- **In-game texts updated:** How to Play (V2 activities, saving, gamepad), Data & Privacy (world saves). `GAME_VERSION` is now 0.3.0.
- **Content counts were checked against the data before writing the docs:** 17 resources, 18 decorations, 13 dishes, 11 fish plus a legendary, 17 creatures, 7 waystones, 40 recipes, 23 quests, 9 notes.
- No network code anywhere (scanned). The real `sessions.csv` and `progress.cfg` in `%APPDATA%` were never written by any test; tests use `user://test_tmp`.

## Bahasa Indonesia (2026-10-11)

Requested after V2: a language setting so the game can be played in English or Bahasa Indonesia.

- **Settings > Language** switches the whole game at once and is saved (`language` in `settings.cfg`, default English, unknown values fall back to English).
- **How it works:** English stays the source text. The Indonesian catalog (`game/data/i18n/id/`, 1,481 entries in six files) is registered as a runtime `Translation` by `L` (`locale.gd`). Labels and buttons translate exact texts automatically; composed text translates the template first (`L.t("Talk to %s") % name`); data getters return translated names, descriptions, quest steps and hints. Saved values stay English.
- **Coverage tool:** `tools/i18n/extract.py` finds every player-facing string (GDScript literals, `L.t(...)` calls, lines marked `# i18n`, JSON text fields) and checks the catalog for missing entries, placeholder order, line breaks and unused entries. It is now check 15 in `run_checks.ps1`.
- **Research data is unaffected:** the CSV stores mode ids and numbers. A unit test compares the header and a row in both languages; `score_delta = post - pre` and schema v1 are unchanged. The record does not store the language.
- **Consent and research texts** (check-in, reflection, results, Data & Privacy) were translated faithfully, without softening or adding claims. The Indonesian stress question is a plain translation, not a validated instrument.
- **Screenshot review in Indonesian** (`capture_screenshots.tscn -- --lang=id`, 50 shots in `screenshots/id/`) found and fixed: an untranslated "(ready)" in crafting and cooking, the volume labels "Music" and "Ambience", progress and save error messages, a map hint that wrapped off-screen (shortened), a build-mode heading that pushed its panel over the toast (shortened), and long region titles covering the HUD (they now shrink to fit). The first capture was interrupted when the window lost focus and the game paused itself; the tool now resumes in that case.
- **Tests:** 6 new unit tests (144 in total) and 9 new UI checks (39 in total). The test runners switch to English first, so a player's chosen language never affects English assertions. No existing test was removed or weakened.
- **Not done:** a native speaker has not reviewed the translation, and the Indonesian text was only checked at the Normal text size in screenshots.

## Polish pass (0.4.0)

Instructions: `CALMQUEST_POLISH_PROMPT_V3.md`. Work happens on the git branch `polish-0.4.0`. The first commit is the untouched 0.3.1 baseline, and each milestone gets its own commit.

**Baseline (before any change, 2026-10-11):** all 15 checks pass: 144 unit tests, 656 smoke, 378 overworld and 39 UI checks, 7 scenes, 1,481/1,481 catalog strings, 13 Python tests.

**What the environment has (checked, not assumed):**
- git: a repository with no commits, on `main`. The polish work is on the branch `polish-0.4.0`; `main` was left as it was.
- **No MuseScore, no FluidSynth, no SoundFont, no ffmpeg or Ogg encoder.** An orchestral render is not possible here, so P3 documents the exact steps instead and keeps the synthesized placeholders. The music is not called orchestral anywhere.
- **No font in `assets/fonts/`.** The custom font step stops there: the developer has to add an OFL font file (the prompt says not to download it). The default font stays.
- Python 3.12 with numpy and scipy (used for the audio tooling and analysis).

**Plan:**
1. **P1, flow:** Start Adventure goes to the journey screen. A new journey shows one mode card. The optional mood check (five drawn faces), the session closing ("Before you go…") with a summary from real events, and the private mood journal (off by default) are added. The completion pop-up no longer appears by itself. Study Mode is a separate autoload with its own setup screen, a temporary save, a fixed duration with a gentle end, and its own CSV files. `analysis/analyze_study.py` and its tests are added.
2. **P2, HUD and UI:** contextual key hints instead of the always-visible buttons, a sun/moon arc, a compact and fading quest tracker, a fading hotbar, toasts grouped below the player, a smaller banner, rings only on the nearest objects, in-world fishing, the About screen, a drawn wordmark, a richer menu backdrop, and new display and interface settings.
3. **P3, audio:** SFX refresh with pitch variation, surface footsteps (with a setting), a mix check, finale and rest-spot moments, `MusicManager` preferring `assets/music/rendered/`, and a listening checklist.
4. **P4, visuals:** ground detail, canopy shadows, a warm night (windows, lantern posts, fireflies, mist near water), Traveler and Lumi animation polish, an optional sprite pipeline, biome signatures, and the finale cinematic with credits (skippable, autosaves).
5. **P5, rest:** 8-12 rest spots (map, journal "Quiet places") and "Breathe with Lumi".
6. **P6:** docs, `STUDY_MODE.md`, version 0.4.0 in `project.godot`, screenshots in EN and ID, and the full validation.

**Risks:**
- *Research data contract:* `sessions.csv` must stay schema v1. Study data goes to new files that reuse `SessionRecord` and `CsvCodec`, and the existing tests must keep passing.
- *The big integration tests* (656/378 checks) drive the HUD, the pause menu and the completion panel directly. Flow and HUD changes must keep their APIs, or the tests are updated only where the design changed on purpose (explained here).
- *Tests must not open the new start cards:* the cards appear only when the menu flow asks for them, never when the overworld is opened directly.
- *Performance:* more ground detail and night lights must stay within the light budget and `ViewCull`.
- *Scope:* the finale cinematic and in-world fishing are the biggest risks. If something is not finished, it is labelled as a stub.
- *Honesty:* no orchestral claim, no font claim, and no manual playtest claim.

### P1 - Player flow and Study Mode

**Default (Steam) flow:**
- *Start Adventure* now opens "Choose a journey" directly. The check-in is no longer in the way.
- A **new journey** shows one small mode card first (Balanced pre-selected). Continuing a journey keeps that journey's saved mode. The pause menu still changes it.
- Then comes the optional **mood check**: a small card (not a full screen) asking "How are you feeling right now?" with **five drawn faces** (Tense, Uneasy, Okay, Calm, Peaceful). The faces differ by brows, eyes and mouth, never by color alone. Each has a text label, a tooltip and an `accessibility_name`. The card has *Skip* and *Don't ask again*. Lumi answers with one of three neutral lines that work for every answer.
- **Leaving:** the pause menu now offers *Return to menu* and *Quit Game*. With Settings > Well-being on, these show **"Before you go…"**: 2-4 summary lines built only from what really happened this session (counter deltas since the world opened, first visits, quests finished; otherwise "A quiet walk is time well spent."), plus the optional faces. There is no comparison, change value or score. Autosave works as before (quit also autosaves).
- **Private mood journal** (opt-in, off by default): `wellbeing_journal.json`, the Journal's "Feelings" page, and export and delete in Data & Privacy. A damaged journal is never overwritten.
- Settings > **Well-being**: mood check Ask / Don't ask, session summary On / Off, mood journal Off / On.
- No research data is stored in this flow: the session starts without a check-in and without consent.

**Study Mode** (`StudyMode` autoload, [STUDY_MODE.md](STUDY_MODE.md)):
- Activation with `--study`, or 7 clicks on the version label plus `LUMERIA-STUDY`.
- Study setup checks the participant code (`P` + 2-3 digits) and sets the length (10/15/20) and language (default ID).
- The existing check-in leads to a fresh journey in `saves/study_tmp.json`, which never touches slots 1-3 and is deleted afterwards.
- No countdown: a fading sun next to the clock. After the set time Lumi gives the gentle line, and after up to 60 more seconds the reflection follows. This never happens during dialogue, a menu or a minigame.
- The existing reflection and results follow, then *Next session* returns to the setup.
- With consent, `study_sessions.csv` gets 6 study columns plus the 16 v1 columns (the same `SessionRecord`, `CsvCodec` and validation), and `study_events.csv` gets coarse events. `sessions.csv` still gets its normal v1 row.
- Export of both files from Data & Privacy. `analysis/analyze_study.py` groups by participant and reuses the v1 validation from `analyze_sessions.py` (unchanged).

**Deliberate changes to earlier behavior:**
- The "Ready to rest for now?" completion panel no longer appears by itself after the Heart Tree and Act 1. It pushed players toward ending, and in the study a fixed length now decides the end. The panel still opens from *Finish Session* in Study Mode. The integration tests already closed it only when it was open, so no assertion changed.
- *Restart Session* was removed from the pause menu. It was a V1 research control: the study journey is temporary, and players can *Load*. The code path (`SessionState.restart_gameplay`) and its smoke-test check remain.
- The pause menu's research storage note is shown only in Study Mode. Other players never store session data.
- The Data & Privacy and How to Play texts now say that the 0-10 check-in belongs to Study Mode, and they describe the mood check and journal.

**Tests:** 19 new unit tests (`test_wellbeing.gd`, `test_study_mode.gd`), 33 new UI checks (main menu unlock, Study setup, mood card, closing panel, Settings, Journal tab, and a real world with the start cards), and 8 new Python tests (`test_analyze_study.py`). The Indonesian catalog has 117 new entries in `game/data/i18n/id/polish.json`, and 8 entries for removed texts were deleted.

### P2 - HUD and UI cleanup

**HUD** (`hud.gd` rewritten, same public API, so the world, the tests and the capture tool needed no changes):
- **The always-visible buttons are gone** ("Mode: Gentle", "Ask Lumi (H)", "Journal (J)", "Pause (Esc)"). Mouse users get a small menu icon in the top-right that fades in when the mouse moves. It opens Ask Lumi, Journal, Map and Pause, and shows the mode and the clock.
- **Contextual key hints** (Settings > Interface: Always / Sometimes / Never, default Sometimes):
  - when a control first becomes useful in a journey (interact, bag, use, build, journal, map; remembered in the world save);
  - when Lumi's nudge fires;
  - after 45 seconds without input.
  - The hints always show the current (possibly remapped) key.
- **Time:** a small sun/moon arc with the day number replaces "Day 12 11:31". The exact clock is in the mouse menu.
- **Quest tracker:** a compact title, step and guidance line (the old separate compass panel is merged in). It fades to 55% while walking and returns fully on quest updates. It can collapse to the title.
- **The hotbar** fades to 35% after 6 s unused and returns on any hotbar input.
- **Toasts:**
  - pickups within 2 s merge into one toast ("+6 Pinecone, +4 Forest Mushroom"), and at most 2 toasts show;
  - they are placed below the player, or above them when the prompt area is in the way, using the player's real screen position (the camera is clamped inside rooms and at the world's edge);
  - large banners are kept for five major moments.
- **Region titles** sit in the upper part, below the tracker if they would touch it, and never over the player.
- **Rings:** the golden ring was already only on the one target. Gentle's soft markers are now limited to the 2 nearest objects within reach (they used to mark every object within reach).
- **The prompt** is hidden while an overlay is open.

**Fishing in the world:** `FishingPanel` keeps its logic and API (no fail state, Gentle auto-catch, keyboard, mouse and gamepad). It no longer dims or covers the world: a bobber with ripples and a line from the player's hand sits in the water, and a small bar sits beside the player. The bar is larger, with an outline, with High contrast or a larger text size.

**Main menu and About:**
- The menu order is Continue (the most recently saved journey, when one exists), Start Adventure, Settings, About, Data & Privacy, Quit.
- The title is a drawn **wordmark** with Lumi as the light motif.
- The backdrop has three parallax layers of isles, fireflies, and a dusk/twilight drift over 150 s that holds still with *Reduce motion*.
- **About** has the disclaimer (moved off the main menu), the credits (from `game/data/credits.json`), the licenses, the version and *How to Play*. How to Play is also in the pause menu now.
- The developer name in `credits.json` is currently the repository's git user name ("dkiplikurniawan"). Replace it with the name players should see.

**Settings:**
- *Display:* Window (Windowed / Fullscreen / Borderless; older files with only `fullscreen` are migrated), resolution, VSync, and interface scale 90-130 % (the canvas scales and the world camera zooms out by the same factor, so only the interface grows).
- *Interface:* control hints, HUD fade, and the compact tracker.

**Font:** `assets/fonts/` has no font file. As the prompt says, it was not downloaded. `UiTheme` uses Nunito or Quicksand automatically once the file is there (`assets/fonts/README.md` lists the exact files and `OFL.txt`). Until then the default font is used, and a test checks that fallback.

**Found in screenshot review:**
- toasts covered the player inside the cottage (the camera is clamped there);
- the fishing bar covered the toasts and the old prompt;
- "B: Build mode" was shown twice;
- the day label was under the arc;
- the region title touched the tracker.

All were fixed and checked again in screenshots.

**Tests:**
- 65 new UI checks (137 in total):
  - no visible key buttons, the mouse menu, the three hint settings;
  - grouped toasts and the cap of 2, and toasts and titles avoiding the player;
  - tracker and hotbar fades, and the compact tracker;
  - rings with 5 probe objects (exactly 2 Gentle markers on the nearest, none in Balanced);
  - fishing with keyboard, mouse and gamepad in all three modes (18 runs) plus the large bar;
  - the menu order, the wordmark, About and the disclaimer, the font fallback;
  - display settings persistence and migration;
  - every screen and panel built in Indonesian.
- The unit, smoke (656) and overworld (378) tests needed no changes.

### P3 - Audio

- **Orchestral render: not possible here, and not faked.** There is no MuseScore, FluidSynth, SoundFont or encoder on this machine.
  - `MusicManager` now prefers `assets/music/rendered/<cue>.ogg|.wav` and falls back to the synthesized placeholder with one warning per run.
  - `tools/music/render_music.py` automates the MuseScore render: seamless loop by wrapping the reverb tail, normalization to RMS -22 dBFS with a -1 dBFS ceiling, a numeric seam check, a loop chunk, and Ogg if `oggenc` exists.
  - Its processing has 9 Python tests (`tools/music/tests`, now check 17 in `run_checks.ps1`). The seam check also confirms that the current placeholders loop smoothly. The MuseScore call itself has not run.
  - `MUSIC_PIPELINE.md` has the exact steps.
- **SFX refresh** (`SoundSynth`):
  - softer attacks, fewer high partials and warm low-passed noise;
  - new sounds for gathering (a soft pluck and rustle), crafting (a wooden knock and chime), cooking (bubbles and a chime), placing (a thud and a tiny chime), quest steps, the fishing splash and catch, and a slow "swell" for the rest spots and the finale;
  - a quieter UI hover and click;
  - every play varies the pitch by ±4% (`AudioManager.varied_pitch`).
  - The library returns raw samples, so tests can check levels: every sound peaks at 0.5 or less and starts softly, footsteps at 0.2 or less, and the hover at 0.06 or less. The test caught "restore" at 0.518, which was lowered.
- **Footsteps:** six surfaces (grass, path, wood, sand, snow, stone), two variations each. The surface comes from the world (paths, river crossings, docks, coast and highland regions) or the sub-level (cottage, caves). They fire on the walk bob's zero crossings, about 4 per second. Settings > Audio > Footsteps.
- **Mix:**
  - music files measure RMS -22 dBFS and ambience -27 dBFS (consistent);
  - the default SFX volume was lowered from 0.8 to 0.7 and Interface from 0.7 to 0.6 for new players (existing settings are kept);
  - the stinger duck (-9 dB, 0.6 s in, 2 s out) is unchanged.
  - The numbers are in `MUSIC_PIPELINE.md`; listening is in the new developer listening checklist.
- **Tests:** 7 new unit tests (`test_audio_polish.gd`: rendered preference and the single warning, surface rules and real-world surfaces, setting persistence, pitch bounds, gentle levels, missing audio), 4 new UI checks (footstep cadence, silence when still, the right surface sound, the setting off), and 9 Python tests for the render tool.

### P4 - Visual atmosphere and the finale

- **World:**
  - ground detail per chunk;
  - 24 small features in 9 regions;
  - fireflies, water mist, stars, needles, snow, gulls and the lighthouse beam;
  - lantern posts in the village and festival lanterns after the finale;
  - a warm cottage window.
  - Details are in `ART_DIRECTION.md`. New random streams keep the existing scenery and object ids identical.
- **Characters:** the Traveler swings their arms, sways, breathes, blinks and puffs dust when starting to run; Lumi has a layered glow, a sparkle trail and a finale celebration. An optional sprite-sheet path is in place, with the procedural art as the fallback; no sheets are included.
- **Finale cinematic:** about 36 s, skippable at any moment by holding Esc. It autosaves before ("before the Festival of Light") and after. The world ends up in the same state whether or not it is skipped, the HUD returns, the player is unblocked, and free exploration continues. Esc no longer opens the pause menu during the finale (it is held to skip).
- **Bug found by the new tests:** the first feature generator tried one spot per chunk; the chunks are large, so every spot was rejected and the world had **zero** features. It now tries up to 10 seeded spots per chunk.
- **Performance** (`tools/capture/perf_probe.tscn`, a real window on this machine: RTX 3050 Laptop GPU, GL Compatibility, VSync on), running through 5 spots with everything on:
  - first measurement: 50.1 fps on average. The new ground detail cost 4-5 ms because it drew every shape separately; the village at night lost about 4 ms to up to 40 large overlapping mist shapes.
  - **After the fixes:** ground detail is one mesh per chunk, small atmosphere particles are batched, and mist is capped at 12 shapes. The result is **61.1 fps on average** (grove 60, creek 65, pinewood 58, coast 62, village at night 60), with a 1% low of 37 fps and a worst frame of 39 ms.
  - The worst frames also happen with all 0.4.0 features hidden (chunk streaming while running), so they are older than this pass. Pinewood stays slightly under 60 because of its dense trees.
- **Light budget:** `Overworld.LIGHT_BUDGET` = 16 lights near the screen. The test measures 12 at the festival and 7 in the village at night. 24 lights are switched on in the whole world, but most are far off-screen (waystones, landmarks, caves, all from before 0.4.0), and the renderer does not draw lights that do not touch the screen.
- **Deliberate test changes (nothing weakened):**
  - The overworld test still waits `FINALE_SECONDS + 1` in total; the constant grew from 9 to 36 s. The wait is now split so that it can also check the cinematic, the hidden HUD, the guests, the Esc behaviour, the credits, the wide shot, both autosaves, the clean-up and the festival lanterns.
  - It then replays the finale with the `act3_complete` flag cleared (test only) to check the skip path, and walks afterwards.
  - The streaming test expects a chunk's children to be exactly its objects. The ground detail is added as an *internal* child, so that contract holds without changing the test.
- **New tests (P4):** 8 unit tests (`test_visual_polish.gd`: feature determinism and placement rules, no collision, an unchanged scenery stream, ground detail determinism, sprite fallback and frame mapping, blink and puff with Reduce motion, Lumi's celebration, a skip that happens only once) and 17 new overworld checks.

### P5 - Rest spots and "Breathe with Lumi"

- **12 rest spots** (`game/data/rest_spots.json`):
  - Sunset Hill, the Village Bench, the Creekside Log, the Waterfall View, the Firefly Bench and the Lookout Stump;
  - the Moonlit Bench (sanctuary), the Cliff Edge, the Driftwood Seat, Aurora Ridge (highlands) and Isle Rock;
  - the Crystal Pool, inside the Singing Grotto.
  - The positions were searched in open, dry ground at least 60 px from all generated scenery, with room around the seat. The generator was not changed: scenery ids are numbered in order, so new clear zones would have shifted the ids that saves use for gathered objects.
- **Sitting:** "[E] Sit and rest" (also a click on the seat, or gamepad A).
  - The Traveler sits and Lumi curls up beside them.
  - The camera drifts and widens (a crossfade with Reduce motion), and the HUD fades out completely.
  - Music +2.5 dB and ambience +4 dB through the bus volumes, plus the soft swell sound.
  - With **Settings > Well-being > "Watch time pass while resting"** the clock runs 6 game minutes per second.
  - Any movement, Esc or Run stands up again (gamepad: the stick, B or Start; in Godot 4.7 the default `ui_cancel` has no gamepad button, and B is the Run button in this game). The Stand up button works too.
  - There is no minimum or maximum time and nothing is counted.
- **Quiet places:** a place is found when the player comes within 300 px or sits there. It then shows on the map (a small bench) and on the journal page "Quiet places", with its line. The page shows no total, only a gentle note when more exist. Finding all 12 unlocks one cosmetic, Lumi's dusk glow; there is no other reward.
- **Breathe with Lumi** (rest spots: E; also in the pause menu, in both layers):
  - paces Gentle 4/6, Even 4/4 and Slow 5/7; lengths 1, 2 or 3 minutes, or until stopped;
  - the required note about breathing comfortably;
  - any key, click or gamepad button stops it at once;
  - no counters, scores, streaks or judgements; when the time is up it simply fades and closes;
  - Reduce motion: a steady glow that brightens and dims, with a progress line.
  - It stores only the chosen pace and length (`settings.cfg`). In Study Mode with consent it logs only `activity_started` / `activity_finished` with `breathing`.
- **Study Mode events:** `rest_spot_used` (spot id) and the activities `resting` and `breathing`. `lantern_catch` was listed in the P1 documentation but never logged; it is now logged when a Lantern Night starts and ends.
- **Deliberate test change:** the overworld test expected exactly 8 journal pages; it now expects exactly 9, because "Quiet places" was added. It is still an exact count.
- **Tests:**
  - **Smoke:** reachability now covers the 11 open-world spots (before the veil opens, the Moonlit Bench and Aurora Ridge are correctly unreachable). The cave spot is covered by the overworld test's cave check.
  - **Unit** (8 in `test_rest_and_breathe.gd` + 1 in `test_study_mode.gd`):
    - data completeness;
    - open ground away from scenery;
    - cave floor;
    - found once, and the single cosmetic;
    - the timing of every pace;
    - Reduce motion;
    - stops on a key, a click and a gamepad button and writes no journal, study or research file;
    - ends by itself after a minute, and "Until I stop" keeps going;
    - in a study, only started and stopped are logged.
  - **UI smoke** (31 checks):
    - discovery, the journal page, sitting with E, the seat, Lumi, the camera;
    - the HUD fading out and back, the swell;
    - E opening breathing and any key stopping it;
    - time passing;
    - standing up with a movement key, Esc (without the pause menu), gamepad A/B and the stick, a mouse click on the seat and the Stand up button;
    - breathing from the pause menu.

### P6 - Documentation, version, screenshots, validation

- **Version:** `SaveManager.GAME_VERSION` and `project.godot` `config/version` are both 0.4.0 (`config/version` had stayed at 0.1.0 since V1).
- **Docs updated:** README, CHANGELOG (0.4.0), GAME_DESIGN_V2, ARCHITECTURE (with a section on where a Steamworks integration would go later; no SDK added), DATA_SCHEMA (new settings keys, `rest_spots`, study events), DATA_DICTIONARY and PRIVACY (from P1, checked again), ART_DIRECTION, MUSIC_PIPELINE (finale, rest and breathing audio), ASSET_PROVENANCE, CONTROLS, MANUAL_TEST_CHECKLIST (new sections for the flow, Study Mode, HUD, visuals and the finale, rest and breathing) and STUDY_MODE.
- **Gamepad bug found while documenting the controls:** Godot 4.7's built-in `ui_accept` and `ui_cancel` have no gamepad button. Gamepad A and B therefore did nothing in menus, although the controls doc (since M11) said they did. `InputSetup` now adds A to `ui_accept` and B to `ui_cancel`, with a unit test. This has not been tried with a physical gamepad.
- **Screenshot tool:**
  - captures the new screens: the mode card, mood check, "Before you go...", a rest spot at sunset, the breathing setup and breathing, the journal's "Quiet places", About and Study setup, plus the finale's gathering and credits (61 shots);
  - saves anything written while capturing (the breathing preference) to `capture_tmp`, never to the player's `settings.cfg`.
  - The first run showed the mood card left behind in later shots: the tool closed it without pressing Skip. It now presses Skip, as a player would. The finale caption was caught mid-fade, so the timing was moved.
  - The finale's captions and credits got a dark outline and a soft veil behind the credits, for readability.
- A few 0.3.1 shots are kept in `screenshots/before_0.4.0/` for before/after comparison.
- **Two rest-spot fixes found while reviewing the screenshots and the study flow:**
  - **Study end while sitting:** in Study Mode, if the time ran out while the participant was sitting, Lumi's end line would have been hidden, because sitting fades the HUD. The announcement now stands the player up first. This is checked in the UI smoke test.
  - **Breathing at a rest spot:** the rest spot's name, line and buttons showed faintly through the breathing screen. They now step aside while breathing and come back hidden (they reappear when the mouse moves). This is also checked.
- **Final validation (2026-10-12):** `tools/run_checks.ps1` passed all **18 checks**:
  - 174 references;
  - import;
  - **188/188 unit tests** (baseline 144);
  - smoke **678** (baseline 656);
  - overworld **396** (baseline 378);
  - UI **175** (baseline 39);
  - **9/9 scenes** (baseline 7);
  - catalog **1,673/1,673** (baseline 1,481);
  - 9 music-tool tests and **21** Python analysis tests (baseline 13).
  - After that run, only the breathing panel's "Press any key to stop" style changed (from subtle to light, for readability). The unit tests (188/188) and the UI smoke test (175/175) were run again after it.
- **Performance:** the perf probe averaged 61.1 fps (1% low 37, worst frame 39 ms). The screenshot runs measured 54-57 fps on average while running, minimum 36-41; screenshots are being saved during those runs.

