# Controls

All gameplay actions are registered in one table: `game/scripts/systems/input_setup.gd`. Movement uses physical key positions, so WASD stays in the same place on any keyboard layout.

## Keyboard and mouse

| Action | Key | Notes |
|---|---|---|
| Move | WASD / arrow keys | 8 directions; diagonal speed is normalized |
| Run | Shift | Hold by default; Settings can switch it to press-to-toggle. No stamina |
| Interact | E | Only when a golden ring shows the target is within reach |
| Ask Lumi for a hint | H | Context-aware: puzzle hint ladder, locked-place explanations, quest direction |
| Journal | J | Tabs: Quests, Map, Creatures, Fish, Recipes, Lore, Collections, Villagers, Quiet places (and Feelings when the private mood journal is on). Q / E (or [ / ]) switch tabs |
| World map | M | Click a relit waystone to travel; click elsewhere to place or remove a pin |
| Place a pin | P | Pins your current position on the map (also works inside the map) |
| Pause / back | Escape | Also closes overlays |
| Use or eat | F | The selected hotbar item |
| Hotbar | 1-8 | Select a slot |
| Bag and crafting | I / Tab | |
| Build mode | B | Q / C change item, R rotate, X store, Z undo |
| Menus | Mouse, or arrow keys + Enter/Space | Visible golden focus ring |
| Sit and rest | E at a rest spot, or click the seat | 0.4.0. While sitting, E opens *Breathe with Lumi* |
| Stand up | Any movement key, Escape or Shift | Or the *Stand up* button (move the mouse to show it) |
| Breathe with Lumi | E while sitting, or the pause menu | Any key, click or button stops it |
| Skip the finale | Hold Escape | A ring fills; letting go cancels |

**Mouse (0.4.0):** the HUD no longer shows key buttons all the time. Move the mouse and a small menu icon fades in at the top right, under the sun/moon arc. It opens Ask Lumi, Journal, Map and Pause, and shows the current mode and the clock. These buttons are mouse-only and never take keyboard focus, so Space and E can't trigger them by accident.

**Key hints:** Settings > Interface > *Show control hints*:
- **Sometimes** (default): a short hint such as "[J] Journal" appears in the bottom-right corner when a control first becomes useful in a journey (interact, bag, use, build, journal, map), when Lumi has a hint, and after about 45 seconds without input.
- **Always:** a small strip of the main keys stays visible.
- **Never:** no hints.

The hints always show the player's current key, including remapped keys.

**Fishing (0.4.0)** happens in the world: the line and the bobber are in the water, and a small bar sits under the player. E, Space, a click anywhere or gamepad A acts. Esc or B leaves.

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
| Sit and rest / Breathe with Lumi (while sitting) | A |
| Stand up | Left stick, B or Start |
| Skip the finale | Hold Start (or B) |

In 0.4.0, A and B were also added to Godot's menu actions (`ui_accept`, `ui_cancel`). Godot 4.7's built-in versions have no gamepad button, so before this fix A and B did nothing in menus. The bindings are covered by automated tests (`tests/unit/test_audio_input.gd`). **They have not been tried with a physical gamepad** (none was available); see the manual test checklist.

## Key remapping

Settings > Controls lists the main key of: move up, down, left and right; interact; run; ask Lumi; journal; map; bag; use or eat; build mode; and place pin.
- Click an action, then press the new key (Esc cancels).
- If the key is already used by another action, the panel says so.
- *Reset controls to defaults* restores everything.
- Bindings are saved in `settings.cfg` and applied at start-up.

Secondary keys (arrow keys, Tab) and the gamepad bindings stay.
