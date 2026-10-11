# Controls

All gameplay actions are registered in one table: `game/scripts/systems/input_setup.gd`. Movement uses physical key positions, so WASD stays in the same place on any keyboard layout.

## Keyboard and mouse

| Action | Key | Notes |
|---|---|---|
| Move | WASD / arrow keys | 8 directions; diagonal speed is normalized |
| Run | Shift | Hold by default; Settings can switch it to press-to-toggle. No stamina |
| Interact | E | Only when a golden ring shows the target is within reach |
| Ask Lumi for a hint | H | Context-aware: puzzle hint ladder, locked-place explanations, quest direction |
| Journal | J | Tabs: Quests, Map, Creatures, Fish, Recipes, Lore, Collections, Villagers. Q / E (or [ / ]) switch tabs |
| World map | M | Click a relit waystone to travel; click elsewhere to place or remove a pin |
| Place a pin | P | Pins your current position on the map (also works inside the map) |
| Pause / back | Escape | Also closes overlays |
| Use or eat | F | The selected hotbar item |
| Hotbar | 1-8 | Select a slot |
| Bag and crafting | I / Tab | |
| Build mode | B | Q / C change item, R rotate, X store, Z undo |
| Menus | Mouse, or arrow keys + Enter/Space | Visible golden focus ring |

HUD buttons (Ask Lumi, Journal, Pause) are mouse-only and never take keyboard focus, so Space and E can't trigger them by accident.

## Gamepad

All core actions have gamepad bindings (Xbox-style names; other controllers use the same positions):

| Action | Gamepad |
|---|---|
| Move | Left stick or D-pad |
| Interact / reel in fishing | A |
| Run (hold) / back in menus | B |
| Bag and crafting | X |
| Ask Lumi | Y |
| Journal | Back / View |
| Pause | Start / Menu |
| World map | Right stick click |
| Build mode | Left stick click |
| Hotbar previous / next (and journal tabs, build-mode items) | LB / RB |
| Use or eat the selected item | Right trigger |
| Place a map pin | Left trigger |
| Build mode: rotate / store / undo | Y / X / Back |
| Menus | D-pad or left stick, A to choose, B to go back |

The bindings are covered by automated tests (`tests/unit/test_audio_input.gd`). **They have not been tried with a physical gamepad** (none was available); see the manual test checklist.

## Key remapping

Settings > Controls lists the main key of: move up, down, left and right; interact; run; ask Lumi; journal; map; bag; use or eat; build mode; and place pin.
- Click an action, then press the new key (Esc cancels).
- If the key is already used by another action, the panel says so.
- *Reset controls to defaults* restores everything.
- Bindings are saved in `settings.cfg` and applied at start-up.

Secondary keys (arrow keys, Tab) and the gamepad bindings stay.
