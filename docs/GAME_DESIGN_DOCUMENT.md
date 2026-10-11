# Game Design Document - CALMQUEST: The Lost Light

## Premise

The floating islands of **Lumeria Isles** once glowed with magical light. Their gardens and trees have dimmed. As a traveler guided by **Lumi the Lightkeeper**, the player gently restores the light, starting in **Whispering Meadow**.

## Target experience

- A 5-10 minute cozy session. The player can stop at any moment, and nothing is lost by not returning.
- Fun before measurement: the game should feel like a small fantasy adventure, with reflection as an optional extra.
- Low pressure: no timers, lives, failure states, leaderboards, streaks or forced difficulty increases.
- The player controls the intensity at all times through the modes.

### Session flow

Splash -> Main menu -> optional check-in (score, mode, consent) -> Whispering Meadow (explore, gather, restore, optional Lantern Catch) -> Finish Session -> optional reflection -> neutral results -> Play Again or Main Menu.

## Visual direction

- An original, soft 2D style drawn procedurally. The palette lives in `Palette`: mint/sage, cream/ivory, lavender/violet, sky, turquoise, golden light, and dark desaturated blue for night.
- Rounded silhouettes, soft drop shadows, gentle glows.
- Readable interactive objects: a golden target ring plus an "[E] verb" prompt, so meaning never relies on color alone.
- Gentle motion only: bobbing lights, swaying flowers, Lumi's float, and a slow day-to-night fade.
- No flashing, strobing or screen shake. *Reduce motion* scales all motion down.

## Controls

WASD/arrows to move (8 directions, normalized), E to interact, H to ask Lumi for a hint, J for the journal, Escape to pause or go back. Menus support the mouse as well as arrows + Enter/Space.

## Core loop

1. **Explore** the meadow along paths that link the cottage, the Heart Tree, the pond and the shrine.
2. **Gather light.** 12 light motes float around the meadow. Collecting them requires being within reach and pressing E. Each mote can be collected only once.
3. **Restore the Heart Tree** with 8 light. The requirement is shown in the HUD ("Light 3 / 8") and as 8 slots around the roots. The tree blossoms in a 2.8 s animation with rising sparkles, a sound and a toast message.
4. **Optional extras:**
   - bloom 3 garden beds (1 light each; 12 lights cover the tree plus all beds);
   - find 3 hidden details (a sparkle appears when the player is near);
   - collect Prism Motes in Playful mode;
   - play Lantern Catch.
5. **Finish** whenever ready.

**Single resource:** *light*. Lights and prisms add light, and the tree and beds spend it. Lanterns are the mini-game's own progress and do not act as a second currency.

## World: Whispering Meadow

- **Map:** 2560 x 1600 px. The walkable rectangle is enclosed by collision walls hidden behind a tree line, so the boundary looks natural.
- **Landmarks:** cottage with fences, central Heart Tree plaza, pond with lilies, stone cluster, Lantern Shrine in the east.
- **Data-driven layout:** everything is placed from `MeadowLayout`.
- **Reachability:** the smoke test flood-fills the map with the player's collision shape and checks that every interactable is reachable within the smallest reach radius.

Planned areas (not built): **Moonwater Lake** (moonlit pond, glowing lilies, light puzzles) and **Starlight Garden** (crystals, collectible decorations).

## Characters

- **The Traveler:** a small hooded figure in a sage cloak with a lavender scarf and a satchel. Idle breathing, walking bob with alternating feet, a scarf that flutters while moving, eyes that follow the facing direction, and a pulse ring when E is pressed.
- **Lumi:** an original glowing fox-like spirit: a round cream body, pointed ears with lavender insides, and a fluffy tail with a turquoise tip.
  - **Follow:** stays behind the player using exponential smoothing with a dead zone. If more than 520 px away, Lumi fades out and reappears beside the player.
  - **Reactions:** hops with happy eyes and sparkles on collections and discoveries.
  - **Dialogue:** an accessible box at the bottom of the screen. Lumi's voluntary lines are limited to a welcome, the first light and milestones, and can be turned off in Settings.

## Lantern Catch (mini-game)

Started at the Lantern Shrine. Night falls over the same meadow: a `CanvasModulate` tint fades in, and soft lights appear on the lanterns, Lumi and the shrine. Paper lanterns drift around anchor points on open ground, and the player catches them with E.

| | Gentle | Balanced | Playful |
|---|---|---|---|
| Lanterns needed | 6 | 8 | 10 (+2 optional golden) |
| Drift speed | 6 px/s (nearly still) | 18 px/s | 30 px/s |
| Wander radius | 14 px | 60 px | 110 px, livelier figure-eights |
| Reach | 104 px | 72 px | 64 px |

- **Safety cap:** lantern speed is capped at 40 px/s while the player moves at 220 px/s, so no quick reactions are ever needed.
- **No pressure:** there is no countdown and no failure.
- **Ending:** the night ends when all required lanterns are caught (a shrine bowl lights up and the counts are saved to the journal), or at any time at the shrine, with no penalty.
- **Replay:** the night can be started again.
- **Mode switches mid-night:** they ease the motion of lanterns already in the air without respawning them.

## Adaptive modes

| | Gentle | Balanced (default) | Playful |
|---|---|---|---|
| Light movement | 0.35x | 1x | 1.5x |
| Reach radius | 104 px | 72 px | 64 px |
| Nearby markers (more visible prompts) | yes | no | no |
| Guiding glow at start | on | off | off |
| Bonus Prism Motes | none | none | 3 |
| Decorative animation intensity | 0.6 | 1.0 | 1.2 |

- **Recommendation:** 7-10 suggests Gentle; 4-6 suggests Balanced; 0-3 asks "Balanced or Playful?"; a skipped check-in defaults to Balanced.
- **Override:** the player can always pick any mode, before playing or later from the pause menu.
- **In-session assistance:**
  - after 3 hint requests, the guiding glow switches on;
  - after 2 attempts just outside reach, the game explains the control and shows the reach circle.
- **Never:** automatic difficulty increases, or inferring stress from player behaviour.

## Session reflection

- **Question:** the same 0-10 question before and after ("Right now, how stressed do you feel?"), labelled 0 very calm, 5 moderately stressed, 10 extremely stressed.
- **No default bias:** the slider is "not answered" until the player moves or clicks it.
- **Optional rating:** "How did the game feel to play?" (1-5), presented as being about the game, not about well-being.
- **Results:** shows Before, After and Change, with a neutral sentence for each outcome: decreased, stayed the same, increased (*"every answer is welcome"*), or incomplete. A caveat explains that the comparison is not a measurement or diagnosis.

## Audio

Synthesized at startup: a soft bell for collection, a chime arpeggio for restoration, a bloom chime, a lantern chime, a low "night" swell, quiet UI ticks, and a looping ambient Cmaj9 pad. Master, music and SFX volumes are set in Settings.

## Scope limitations

- One area.
- Procedural art.
- No gamepad support, saved world state or localisation yet.
- Lantern Catch is the only mini-game.
- Co-op is a documented future concept only.
