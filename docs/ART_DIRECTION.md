# Art Direction

All art is original and drawn procedurally in GDScript (`_draw`) or shaders. There are no image, font or audio assets beyond `icon.svg` (see [ASSET_PROVENANCE.md](ASSET_PROVENANCE.md)).

## Principles

- **Atmosphere first, readability always.**
  - Interactive objects get a golden target ring plus an "[E] verb" prompt, so meaning never relies on color alone.
  - Decorations have no rings.
- **Soft, rounded silhouettes.** Each biome gets its own silhouette set, not just recolors.
- **Cool ambient, warm lights.**
  - Night is a blue CanvasModulate tint, with warm PointLight2D glows on lanterns, Lumi, waystones, the shrine and the altar.
  - Lights are only enabled at night to keep their count low.
- **Gentle motion only.**
  - Flowers, ferns and reeds sway by rotation (no redraw).
  - Water glints scroll slowly in shaders.
  - Everything scales with *Reduce motion*.
- **No harsh effects:** no flashes, screen shake or heavy bloom.

## Ground and terrain

- The ground is one world-sized quad drawn by `game/shaders/ground.gdshader`.
- **Biome blending:** each macro cell's palette index is blended with its neighbours using smoothed bilinear interpolation, with positions warped by seeded noise. Borders are therefore soft and organic, never rectangular.
- **Texture:** fine noise grain keeps large areas from looking flat.
- **Water:** water cells get slow glints and a lighter shore band.
- **Restoration:** a `restoration` uniform warms and saturates the world after the Act 1 finale (before it: about 86% saturation).
- **Paths and rivers:**
  - Paths are Line2D with an edge stroke and a fill stroke, using round joints and caps.
  - Rivers have a bank stroke, a deep stroke and a water stroke with a world-space glint shader.

## Biome palettes (day)

| Region | Ground (a / b) | Signature silhouettes |
|---|---|---|
| Whispering Meadow | `#a3d39c` / `#c2e5b5` | round trees, flowers, bushes, stones, cottage |
| Firefly Grove | `#6eab8c` / `#5c9a84` | dark teal canopy trees with resting fireflies, glowing teal caps, ferns |
| Crystal Creek | `#9cd2b9` / `#b6e3d0` | crystal clusters (sky, lavender, teal), reeds by the river |
| Moonlit Sanctuary | `#a0a9d2` / `#b6bde0` | moon lilies, broken pillars, lavender veil |
| Misty Pinewood | `#6f9b8c` / `#5f8b82` | tall triangular pines, ferns, mushrooms |
| Sunpetal Coast / Isles | `#f1dfb5` / `#e8d1a1` | beach grass, driftwood, shells, lighthouse |
| Frostbloom Highlands | `#e6edf5` / `#d3dfec` | snow-capped pines, frost flowers, boulders, frost peak with an aurora arc |
| Cliffs | `#8f8ca3` / `#a6a2b9` | dense lavender-grey boulders |
| Sea / lake | `#4f97bd` / `#62adc8`, `#6aaec4` / `#7cbccf` | shader glints |

**Night:** CanvasModulate `Palette.NIGHT_TINT` (0.36, 0.42, 0.66), with warm gold glows on top.

## Layering

| z / layer | Content |
|---|---|
| -20 | ground quad |
| -16..-11 | paths, river, bridges and stepping stones |
| -10 | meadow plaza and pond |
| -5 | ground-level puzzle |
| 0, y-sorted | trees, objects, player, POIs, streamed chunks (nested y-sort) |
| 4-6 | lanterns, Lumi, guiding arrow |
| CanvasLayer 5+ | HUD, menus (themed explicitly; CanvasLayers do not inherit the window theme) |

## V2 additions (M4-M11)

- **Time of day:** a dusk tint between day and night, warm interior light once the hearth is lit, and dim caves (`0.66, 0.66, 0.8`) where braziers, crystals and Lumi provide the light.
- **Atmosphere layer (`RegionAtmosphere`, CanvasLayer 2, under the HUD):**
  - pinewood fog banks in three parallax depths, and pink-gold light shafts by day;
  - a light coastal haze;
  - drifting cloud shadows locked to the ground in open regions on clear days;
  - an overcast veil, slanted rain streaks and mist on weather days;
  - aurora ribbons over the highlands at night once the shrine is aligned.
  - All of these fade in and out gradually, dim at night, and slow down with *Reduce motion*. Weather visuals can be turned off.
- **Gloom:** a screen-reading shader in its own follow-viewport layer. It desaturates (85%) and cools and dims the world inside a softly breathing circle, with drifting mist on top. Clearing it fades the veil over about 2.4 s while flowers grow in.
- **Creatures and villagers:** soft round silhouettes drawn by `CreatureArt` (13 shapes) with tiny eye highlights. Villagers are drawn larger, with a glowing mote above them, so they read as spirits.
- **Shape cues besides color:** signal lanterns (dot, bar, triangle, square), brazier dots, prism arrows, plate outlines, the build-mode check or cross, and the fishing zone outline.
- **Caves:** a clear contrast between dark rock with a lighter rock face where it meets the floor, and a pale floor. The chasm is near-black with sparkles, and the light bridge is pale blue.
- **The village grows visibly:** tents become homes with lit windows at night, then lantern strings, a market stall, and a campfire with music notes.

## Layering (V2)

| z / layer | Content |
|---|---|
| -6 | cave floor |
| -5 / -4 | beam puzzle platforms, plates, the shrine circle, the gloom patch ground |
| -3 | farm plots, tide pools, fishing ripples |
| CanvasLayer 1 (follows viewport) | gloom veils (shader) and mist |
| CanvasLayer 2 | atmosphere and weather |
| CanvasLayer 5+ | HUD, captions, menus |

## Still simple (honest)

- All art is procedural and intentionally simple: there are no sprite sheets, and walk cycles are bob animations.
- There are no particle effects for pollen or snow; snow is suggested by the ground color and snow-capped pines.
