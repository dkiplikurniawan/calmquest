class_name InputSetup
extends RefCounted
## Registers the game's input actions at startup.
## Defining them in one table keeps the control scheme documented and consistent.
## Physical key codes are used so movement keys stay in the same place on any layout.
## Every action also has a gamepad binding (see docs/CONTROLS.md), and the main
## key of each remappable action can be changed in Settings (GameSettings.key_bindings).

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
const INTERACT := &"interact"
const PAUSE := &"pause"
const HINT := &"request_hint"
const JOURNAL := &"open_journal"
const RUN := &"run"
const MAP := &"open_map"
const PIN := &"place_pin"
const INVENTORY := &"open_inventory"
const USE_ITEM := &"use_item"
const BUILD := &"build_mode"
const ROTATE := &"rotate_item"
const STORE := &"store_item"
const UNDO := &"undo"
const HOTBAR_NEXT := &"hotbar_next"
const HOTBAR_PREV := &"hotbar_prev"
const HOTBAR_PREFIX := "hotbar_"

const BINDINGS := {
	MOVE_LEFT: [KEY_A, KEY_LEFT],
	MOVE_RIGHT: [KEY_D, KEY_RIGHT],
	MOVE_UP: [KEY_W, KEY_UP],
	MOVE_DOWN: [KEY_S, KEY_DOWN],
	INTERACT: [KEY_E],
	PAUSE: [KEY_ESCAPE],
	HINT: [KEY_H],
	JOURNAL: [KEY_J],
	RUN: [KEY_SHIFT],
	MAP: [KEY_M],
	PIN: [KEY_P],
	INVENTORY: [KEY_I, KEY_TAB],
	USE_ITEM: [KEY_F],
	BUILD: [KEY_B],
	ROTATE: [KEY_R],
	STORE: [KEY_X, KEY_BACKSPACE],
	UNDO: [KEY_Z],
	HOTBAR_NEXT: [],
	HOTBAR_PREV: [],
	&"hotbar_1": [KEY_1], &"hotbar_2": [KEY_2], &"hotbar_3": [KEY_3], &"hotbar_4": [KEY_4],
	&"hotbar_5": [KEY_5], &"hotbar_6": [KEY_6], &"hotbar_7": [KEY_7], &"hotbar_8": [KEY_8],
}

## Gamepad buttons (Xbox-style names; other pads map to the same positions).
const PAD_BUTTONS := {
	INTERACT: [JOY_BUTTON_A],
	RUN: [JOY_BUTTON_B],
	INVENTORY: [JOY_BUTTON_X],
	HINT: [JOY_BUTTON_Y],
	JOURNAL: [JOY_BUTTON_BACK],
	PAUSE: [JOY_BUTTON_START],
	MAP: [JOY_BUTTON_RIGHT_STICK],
	BUILD: [JOY_BUTTON_LEFT_STICK],
	HOTBAR_PREV: [JOY_BUTTON_LEFT_SHOULDER],
	HOTBAR_NEXT: [JOY_BUTTON_RIGHT_SHOULDER],
	MOVE_UP: [JOY_BUTTON_DPAD_UP],
	MOVE_DOWN: [JOY_BUTTON_DPAD_DOWN],
	MOVE_LEFT: [JOY_BUTTON_DPAD_LEFT],
	MOVE_RIGHT: [JOY_BUTTON_DPAD_RIGHT],
	ROTATE: [JOY_BUTTON_Y],
	STORE: [JOY_BUTTON_X],
	UNDO: [JOY_BUTTON_BACK],
	# Menus: Godot 4.7's built-in ui_accept / ui_cancel have no gamepad button,
	# so A chooses and B goes back (0.4.0 fix).
	&"ui_accept": [JOY_BUTTON_A],
	&"ui_cancel": [JOY_BUTTON_B],
}
## Gamepad axes: [axis, direction].
const PAD_AXES := {
	MOVE_LEFT: [JOY_AXIS_LEFT_X, -1.0],
	MOVE_RIGHT: [JOY_AXIS_LEFT_X, 1.0],
	MOVE_UP: [JOY_AXIS_LEFT_Y, -1.0],
	MOVE_DOWN: [JOY_AXIS_LEFT_Y, 1.0],
	USE_ITEM: [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	PIN: [JOY_AXIS_TRIGGER_LEFT, 1.0],
}
## Actions players can remap in Settings (their first key).
const REMAPPABLE: Array[StringName] = [MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, INTERACT, RUN, HINT, JOURNAL, MAP, INVENTORY, USE_ITEM, BUILD, PIN]
const ACTION_NAMES := {
	MOVE_UP: "Move up", MOVE_DOWN: "Move down", MOVE_LEFT: "Move left", MOVE_RIGHT: "Move right",
	INTERACT: "Interact", RUN: "Run", HINT: "Ask Lumi", JOURNAL: "Journal", MAP: "Map",
	INVENTORY: "Bag and crafting", USE_ITEM: "Use or eat", BUILD: "Build mode", PIN: "Place map pin",
}


static func ensure_actions() -> void:
	for action: StringName in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var existing := InputMap.action_get_events(action)
		for keycode: int in BINDINGS[action]:
			if _has_key(existing, keycode):
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
	for action: StringName in PAD_BUTTONS:
		for button: int in PAD_BUTTONS[action]:
			if not _has_pad_button(InputMap.action_get_events(action), button):
				var jb := InputEventJoypadButton.new()
				jb.button_index = button
				InputMap.action_add_event(action, jb)
	for action: StringName in PAD_AXES:
		var spec: Array = PAD_AXES[action]
		if not _has_pad_axis(InputMap.action_get_events(action), int(spec[0]), float(spec[1])):
			var jm := InputEventJoypadMotion.new()
			jm.axis = int(spec[0])
			jm.axis_value = float(spec[1])
			InputMap.action_add_event(action, jm)


## The main (first) keyboard key of an action.
static func primary_key(action: StringName) -> int:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := e as InputEventKey
			return k.physical_keycode if k.physical_keycode != 0 else k.keycode
	return 0


static func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode) if keycode != 0 else "-"


## Replaces the first keyboard key of each remapped action.
static func apply_overrides(bindings: Dictionary) -> void:
	for action_name: String in bindings:
		var action := StringName(action_name)
		if not InputMap.has_action(action):
			continue
		var keycode := int(bindings[action_name])
		var events := InputMap.action_get_events(action)
		for e in events:
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
				break
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)
		# Keep the new key first so it is shown as the main key.
		var rest := InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, ev)
		for e in rest:
			if e != ev:
				InputMap.action_add_event(action, e)


## Restores every keyboard binding to the defaults (gamepad bindings stay).
static func reset_keyboard() -> void:
	for action: StringName in BINDINGS:
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
	ensure_actions()


## The other remappable action that already uses this key ("" if none).
static func action_for_key(keycode: int, except: StringName) -> String:
	for action in REMAPPABLE:
		if action == except:
			continue
		if _has_key(InputMap.action_get_events(action), keycode):
			return String(ACTION_NAMES.get(action, action))
	return ""


static func _has_key(events: Array[InputEvent], keycode: int) -> bool:
	for e in events:
		if e is InputEventKey and ((e as InputEventKey).physical_keycode == keycode or (e as InputEventKey).keycode == keycode):
			return true
	return false


static func _has_pad_button(events: Array[InputEvent], button: int) -> bool:
	for e in events:
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return true
	return false


static func _has_pad_axis(events: Array[InputEvent], axis: int, direction: float) -> bool:
	for e in events:
		if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == axis and signf((e as InputEventJoypadMotion).axis_value) == signf(direction):
			return true
	return false
