# Game Design - V2 "The Wide World of Lumeria"

Status labels used throughout this document:

| Label | Meaning |
|---|---|
| **built** | implemented and covered by automated tests |
| **placeholder** | works, but with stand-in assets (the music) |
| **not built** | not implemented |

The V1 design (core loop, modes, reflection) is still valid: see [GAME_DESIGN_DOCUMENT.md](GAME_DESIGN_DOCUMENT.md). Milestone notes are in [V2_PROGRESS.md](V2_PROGRESS.md).

## Vision

A wide, softly glowing world where the Traveler and Lumi wander forests, coasts, caves and highlands, slowly bringing light back to Lumeria. It stays calm, kind and free of pressure:
- no damage, death or failure;
- no survival meters and no mandatory timers;
- no streaks;
- nothing is lost by stopping.

Core loop: **wander, discover, gather, craft and help, restore, see the world brighten.**

## World (built)

| Property | Value |
|---|---|
| Size | 40 × 24 macro cells of 256 px = **10240 × 6144 px ≈ 8 × 8.5 screens** (1280×720), plus sub-levels (cottage, two caves) outside the map |
| Data | Authored macro map and all points of interest in `game/data/world/overworld.json` |
| Chunks | 1024 px (4×4 cells), 60 chunks streamed around the camera. Scenery and gatherables are generated from a fixed seed |
| Boundaries | Sea and cliffs all around. The highlands are reached through one mountain pass |

### Regions

| Region | Status | Highlights |
|---|---|---|
| Whispering Meadow (home hub) | built | Heart Tree plaza and Hearthstone circle, cottage and homestead, spirit village, pond fishing |
| Firefly Grove | built | Lantern Shrine (Lantern Night), forgotten garden behind a withered plant |
| Crystal Creek | built | river with a bridge, beam puzzle, fishing, the Singing Grotto cave above it |
| Moonlit Sanctuary | built | moonlit veil, Moon Altar, moon dew, epilogue note (post-game) |
| Misty Pinewood | built | fog and light shafts, 3 gloom patches, Gloomlings, fox den and lost kits, cabins, pond, Whispering Hollow cave |
| Sunpetal Coast | built | lighthouse restoration, tide pools, coastal gloom, docks, sea fishing |
| Sunpetal Isles (2) | built | reached by boat. Wreck Isle (signal puzzle, captain's log), Little Gull Isle (Gloomling) |
| Echo Caverns (2) | built | Whispering Hollow and Singing Grotto, handcrafted puzzle chains |
| Frostbloom Highlands | built (compact) | mountain pass (climbing rope), snow, waystone, aurora shrine, aurora at night |

## Navigation (built)

- **Camera:** smooth follow, look-ahead, zoom per region, clamped to the world or the sub-level. *Reduced camera motion* turns the moving parts off.
- **Run:** Shift (hold or toggle). There is no stamina.
- **Region titles:** shown on the first visit (configurable).
- **World map:** fog of war, region names, landmarks, gloom, docks, caves, pins, quest marker and waystone travel.
- **Minimap and compass:** both optional.
- **Waystones (7):** walk near one to discover it and press E to relight it. Travel between relit waystones is free.
- **Boat:** paired docks; a fade carries you to the other shore.

## Story (built)

- **Act 1, The Lost Light** (V1 content): lights, the Heart Tree, Lantern Night, the Crystal Creek puzzle, the veil, and the Moon Altar.
- **Act 2, The Five Hearthstones:** the Heart Tree circle explains that the light only reaches the meadow. Five Hearthstones can be found **in any order**, and each one needs a different activity:

| Hearthstone | Activity |
|---|---|
| of the Pines | Clear the pinewood gloom (Bright Lantern or Luma Bloom) and lead three lost fox kits home |
| of the Shore | Restore and relight the lighthouse (4 steps) |
| of the Isles | Build a boat, sail to the Wreck Isle, solve the signal lanterns |
| of the Echoes | Two caves: braziers, blocks, a light bridge, a tuned crystal door, two beam puzzles |
| of the Aurora | Restore the mountain pass with the climbing rope, then align the aurora shrine |

- **Act 3, Return of the Light:** set the stones in the circle, invite the five villagers, and light the Great Lantern. The finale is a short cutscene: everyone gathers, beams rise, all gloom fades, the world brightens, and a closing panel appears.
- **Post-game:** free exploration continues, with "A Wider Journal" goals, the Aurora Stag, and an epilogue note.

**Quest system:** data-driven JSON with these types: main, side, villager. Quests have prerequisites, `unlock` conditions, `deliver` steps and rewards.
- Anything done early counts.
- Quests never reset.
- No step can become impossible: every tool's materials are renewable and tested.

## Systems (built)

| System | Summary |
|---|---|
| Gathering | 17 resources respawn after N days (plus wild seeds); gloom hides those inside it |
| Inventory | 30 slots plus 2 bag upgrades, an 8-slot hotbar, sorting and swapping. Keepsakes can never be lost |
| Crafting | Hand, workbench and cottage workbench tiers. Recipes are discovered through notes, restorations and experiments. Tools open the world (table below) |
| Cottage | 8 restoration steps, bed (sleep and autosave), storage chest, cottage workbench, cooking pot |
| Decorating | 18 decorations, a grid build mode inside and outside (rotate, store, undo), and garden plots |
| Farming | 5 crops, watering can or rain. **Crops never die.** Strawberries regrow; Luma Blooms give Luma Light and clear gloom |
| Fishing | 11 spots, 11 fish (by water, region, time and weather) plus the legendary Old Whiskers. Gentle auto-catches. No fail state |
| Cooking | 13 dishes, experiments use nothing up, gentle optional buffs. No hunger |
| Wildlife | 17 creatures, sketches, friendship and gifts. Behavior depends on the mode |
| Gloom and Gloomlings | Desaturating veil, thorns and hidden kits. Gloomlings are comforted with light, song or food |
| Caves | 2 handcrafted cave systems (sub-levels). Every puzzle has a reset lever and a hint ladder |
| Villagers | 5 spirit villagers with homes, routines, gifts, friendship (never decays), personal quests and a request board |
| Weather | Clear, cloudy, rain or mist each day. Rain waters crops. Visuals can be turned off |
| Day and night | 15-24 real minutes per day. It can be kept day or night, slowed or paused in Gentle mode. Night is always safe |
| Journal | 8 tabs: Quests, Map, Creatures, Fish, Recipes, Lore, Collections (percentages and wardrobe), Villagers |
| Cosmetics | 3 cloaks and 4 Lumi glows, earned from friendships |
| Saves | 3 slots, versioned and migrated, atomic writes with a backup, autosaves (see DATA_SCHEMA.md) |
| Audio | Music cues per place with crossfades, meadow day and night layers, stingers, ambience and rain. **The music files are synthesized placeholders** rendered from original MIDI scores (see MUSIC_PIPELINE.md) |

### Tools open the world

| Tool | Opens |
|---|---|
| Bright Lantern | gloom patches, dark caves, the hidden light bridge |
| Watering Can | farming; the withered plant guarding the forgotten garden |
| Fishing Rod | fishing, and the Old Whiskers quest |
| Small Boat | both isles |
| Crystal Tuner | the crystal door in the Singing Grotto |
| Climbing Rope | the mountain pass to the highlands (kept as a tool) |

## Adaptive modes in V2 systems (built)

| System | Gentle | Balanced | Playful |
|---|---|---|---|
| Interaction reach | 104 px | 72 px | 64 px |
| Lumi's nudges (default) | Helpful (about 2.5 min) | Normal (5 min) | Rare (10 min) |
| Puzzle hints | last step highlights what to change | text | text, plus an optional "fewest moves" bonus (praise only) |
| Fishing | automatic catch | wide, slow zone | livelier fish, narrower zone |
| Lantern Catch | slow, few lanterns | relaxed | livelier, with bonus lanterns |
| Creature approach | very easy | normal | needs a little more calm |
| Clock | can be slowed or paused | normal | normal |
| Music pauses | longer quiet pauses (when chosen) | normal | normal |

Switching modes at any time never affects progress, and no mode adds punishment.

## Not built / honest limits

- Real orchestral recordings: the music is synthesized placeholders, and the MIDI scores are ready to render.
- Localization: UI strings are mostly in data files and scripts, not yet in a translation table.
- Gamepad support is implemented and tested in code, but not with a physical gamepad.
- The highlands are a compact region (one pass, one shrine, one waystone) rather than a large area.
