class_name AboutScreen
extends Control
## About: what CALMQUEST is (and is not), credits, licenses, the version, and
## How to Play. The disclaimer that used to be on the main menu lives here.

const CREDITS_PATH := "res://game/data/credits.json"
const DISCLAIMER := "A cozy, well-being-oriented game prototype. It is not a medical, diagnostic or therapeutic tool."


## The developer's name from game/data/credits.json ("" if missing).
static func developer_name() -> String:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	return String((data as Dictionary).get("developer", "")) if typeof(data) == TYPE_DICTIONARY else ""


## The credit lines (also used by the finale's credits).
static func credit_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var dev := developer_name()
	if not dev.is_empty():
		lines.append(L.t("Made by %s") % dev)
	lines.append(L.t("Built with the Godot Engine (MIT license)."))
	lines.append(L.t("Music: original compositions written for this game (the current recordings are synthesized placeholders)."))
	lines.append(L.t("Sound effects: synthesized in the game. Art: drawn in code."))
	var font_path := UiTheme.custom_font_path()
	if font_path.is_empty():
		lines.append(L.t("Font: Godot's default font."))
	else:
		lines.append(L.t("Font: %s (SIL Open Font License).") % font_path.get_file().get_basename().get_slice("-", 0))
	lines.append(L.t("No network, analytics or tracking code. Everything stays on this device."))
	return lines


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var box := UiKit.centered_panel(self, 720)
	var head := HBoxContainer.new()
	head.add_child(Wordmark.new(int(34 * GameSettings.get_text_scale())))
	box.add_child(head)
	box.add_child(UiKit.label(L.t("Version %s") % SaveManager.GAME_VERSION, UiTheme.SUBTLE))
	box.add_child(UiKit.label(DISCLAIMER, &"", true))
	box.add_child(UiKit.label("Designed to help you unwind: no timers, no failure, and nothing is ever lost.", UiTheme.SUBTLE, true))
	box.add_child(HSeparator.new())
	box.add_child(UiKit.label("Credits", UiTheme.SUBTLE))
	box.add_child(UiKit.label("\n".join(credit_lines()), &"", true))
	box.add_child(UiKit.label("Full asset and license details: docs/ASSET_PROVENANCE.md in the project.", UiTheme.SUBTLE, true))
	var how := UiKit.button("How to Play", func() -> void: add_child(HowToPlayPanel.new()))
	var back := UiKit.button("Back", func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU), UiTheme.PRIMARY_BUTTON)
	box.add_child(UiKit.hbox([how, back]))
	back.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and get_children().filter(func(c: Node) -> bool: return c is HowToPlayPanel).is_empty():
		get_viewport().set_input_as_handled()
		SceneRouter.go_to(SceneRouter.MAIN_MENU)
