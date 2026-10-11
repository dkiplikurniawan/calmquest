# Character sprite sheets (optional)

The Traveler and Lumi are drawn in code. An artist can replace them with sprite sheets: put the PNG files here and the game uses them automatically. Without them, or if a file is smaller than expected, the procedural drawing is used.

## `traveler.png`

- Frames of **64 x 64 px**, **6 columns x 4 rows** (384 x 256 px in total).
- **Rows** by facing direction: 0 down (toward the viewer), 1 up (back view), 2 left, 3 right.
- **Columns:** 0-3 the walk cycle, 4 idle, 5 idle with eyes closed (used for the occasional blink).
- The feet touch the **bottom center** of each frame (pixel 32, 60). The game adds the walk bob, the shadow and the interaction rings itself.
- The cloak color is drawn into the sheet, so wardrobe colors (cosmetics) only change the procedural Traveler.

## `lumi.png`

- Frames of **48 x 48 px**, **4 columns x 1 row** (192 x 48 px): a gentle floating loop.
- Lumi's body is centered in each frame. The game adds the glow, the trail, the hops and the reaction sparkles.

Original art only. Record the artist, source and licence in `docs/ASSET_PROVENANCE.md`.
