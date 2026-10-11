class_name Hud
extends CanvasLayer
## Gameplay HUD: objective, progress, mode chip, interaction prompt, Lumi's
## dialogue box and short toasts. It only displays what the world tells it and
## reports button presses; it holds no gameplay state.
##
## HUD buttons never take keyboard focus, so Space/Enter/E can't trigger them
## by accident during play. They are for mouse users; keys H/J/Esc do the same.

signal hint_requested
signal journal_requested
signal pause_requested

const DIALOGUE_SECONDS := 6.0
const TOAST_SECONDS := 3.2

var _objective: Label
var _objective_panel: PanelContainer
var _progress_label: Label
var _progress_icon: LightIcon
var _mode_label: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _dialogue_panel: PanelContainer
var _dialogue_label: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _dialogue_tween: Tween
var _toast_tween: Tween
var _dialogue_timer: float = 0.0
var _top_bar: HBoxContainer
var _compass: PanelContainer
var _compass_arrow: CompassArrow
var _compass_label: Label
var _region_card: VBoxContainer
var _region_title: Label
var _region_subtitle: Label
var _region_tween: Tween
var _minimap_panel: PanelContainer
var minimap: MapView
var _minimap_refresh: int = 0
var _hotbar: HBoxContainer
var _hotbar_slots: Array[ItemSlot] = []
var _clock_panel: PanelContainer
var _clock_label: Label
var _pickup_box: VBoxContainer
## item id -> [Label, quantity, seconds left]
var _pickups: Dictionary = {}
var selected_hotbar: int = 0
var _build_hint: PanelContainer
var _caption: Label
var _caption_t: float = 0.0
const CAPTIONS := {
	&"collect": "[soft chime]", &"bonus": "[sparkling chime]", &"lantern": "[lantern bell]",
	&"discover": "[bright twinkle]", &"restore": "[warm rising melody]", &"bloom": "[gentle bloom]",
	&"soft_deny": "[soft low tone]", &"night": "[deep, calm hum]",
}
const PICKUP_SECONDS := 2.6
## At most this many pickup notes are shown; older ones make room.
const MAX_PICKUPS := 5
## Region titles wider than this (in pixels) are drawn smaller.
const REGION_TITLE_MAX_WIDTH := 600.0
var _root: Control


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	UiKit.adopt_theme(root)
	_root = root
	_build_objective(root)
	_build_top_right(root)
	_build_prompt(root)
	_build_dialogue(root)
	_build_toast(root)
	_build_compass(root)
	_build_region_card(root)
	_build_hotbar(root)
	_build_clock(root)


func _build_objective(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.HUD_PANEL
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	_objective_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_objective = UiKit.label("", UiTheme.HUD)
	box.add_child(_objective)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_progress_icon = LightIcon.new(LightIcon.Style.LIGHT, 24)
	row.add_child(_progress_icon)
	_progress_label = UiKit.label("", UiTheme.HUD)
	row.add_child(_progress_label)
	box.add_child(row)


func _build_top_right(root: Control) -> void:
	var bar := HBoxContainer.new()
	_top_bar = bar
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	var chip := PanelContainer.new()
	chip.theme_type_variation = UiTheme.HUD_PANEL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_label = UiKit.label("", UiTheme.HUD)
	chip.add_child(_mode_label)
	bar.add_child(chip)
	for spec: Array in [["Ask Lumi (H)", hint_requested], ["Journal (J)", journal_requested], ["Pause (Esc)", pause_requested]]:
		var sig: Signal = spec[1]
		var b := UiKit.button(spec[0], func() -> void: sig.emit())
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		bar.add_child(b)


func _build_prompt(root: Control) -> void:
	_prompt_panel = PanelContainer.new()
	_prompt_panel.theme_type_variation = UiTheme.HUD_PANEL
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label = UiKit.label("", UiTheme.HUD)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)
	_prompt_panel.visible = false
	root.add_child(_prompt_panel)


func _build_dialogue(root: Control) -> void:
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.theme_type_variation = UiTheme.DIALOGUE_PANEL
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_panel.custom_minimum_size = Vector2(560, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(LightIcon.new(LightIcon.Style.LUMI, 52))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiKit.label("Lumi", UiTheme.SUBTLE))
	_dialogue_label = UiKit.label("", &"", true)
	_dialogue_label.custom_minimum_size.x = 460
	col.add_child(_dialogue_label)
	row.add_child(col)
	_dialogue_panel.add_child(row)
	_dialogue_panel.visible = false
	root.add_child(_dialogue_panel)


func _build_toast(root: Control) -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.theme_type_variation = UiTheme.DIALOGUE_PANEL
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UiKit.label("", UiTheme.HEADING)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false
	root.add_child(_toast_panel)


func _build_compass(root: Control) -> void:
	_compass = PanelContainer.new()
	_compass.theme_type_variation = UiTheme.HUD_PANEL
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	_compass_arrow = CompassArrow.new()
	row.add_child(_compass_arrow)
	_compass_label = UiKit.label("", UiTheme.HUD)
	row.add_child(_compass_label)
	_compass.add_child(row)
	_compass.visible = false
	root.add_child(_compass)


func _build_region_card(root: Control) -> void:
	_region_card = VBoxContainer.new()
	_region_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_region_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_region_title = UiKit.label("", UiTheme.TITLE)
	_region_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_subtitle = UiKit.label("", UiTheme.LIGHT)
	_region_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_card.add_child(_region_title)
	_region_card.add_child(_region_subtitle)
	_region_card.visible = false
	root.add_child(_region_card)


func _build_hotbar(root: Control) -> void:
	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", 3)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Inventory.HOTBAR_SIZE:
		var slot := ItemSlot.new(40)
		slot.hotkey = str(i + 1)
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotbar.add_child(slot)
		_hotbar_slots.append(slot)
	root.add_child(_hotbar)
	_build_hint = PanelContainer.new()
	_build_hint.theme_type_variation = UiTheme.HUD_PANEL
	_build_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hint.add_child(UiKit.label("B: Build mode", UiTheme.HUD))
	_build_hint.visible = false
	root.add_child(_build_hint)
	_caption = UiKit.label("", UiTheme.LIGHT)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	root.add_child(_caption)
	AudioManager.sound_played.connect(_on_sound)
	MusicManager.cue_changed.connect(func(cue: String) -> void:
		if MusicManager.CUE_TITLES.has(cue):
			_show_caption(L.t("[music: %s]") % L.t(String(MusicManager.CUE_TITLES[cue]))))
	_pickup_box = VBoxContainer.new()
	_pickup_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pickup_box.add_theme_constant_override("separation", 2)
	root.add_child(_pickup_box)


func _build_clock(root: Control) -> void:
	_clock_panel = PanelContainer.new()
	_clock_panel.theme_type_variation = UiTheme.HUD_PANEL
	_clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_label = UiKit.label("", UiTheme.HUD)
	_clock_panel.add_child(_clock_label)
	root.add_child(_clock_panel)


## Refreshes the hotbar from the inventory (first 8 slots).
func update_hotbar(inventory: Inventory) -> void:
	for i in _hotbar_slots.size():
		var s: Dictionary = inventory.slots[i] if i < inventory.slots.size() else {}
		_hotbar_slots[i].set_item(String(s.get("id", "")), int(s.get("qty", 0)))
		_hotbar_slots[i].selected = i == selected_hotbar


func select_hotbar(index: int) -> void:
	selected_hotbar = clampi(index, 0, Inventory.HOTBAR_SIZE - 1)
	for i in _hotbar_slots.size():
		_hotbar_slots[i].selected = i == selected_hotbar
		_hotbar_slots[i].queue_redraw()


func set_build_hint(shown: bool) -> void:
	_build_hint.visible = shown


func set_clock(text: String, is_night: bool) -> void:
	_clock_label.text = (L.t("Night") + "  " if is_night else "") + text


## Short, grouped pickup notes ("+3 Fallen Branch"); repeated pickups merge.
func show_pickup(item_id: String, qty: int) -> void:
	if _pickups.has(item_id):
		var entry: Array = _pickups[item_id]
		entry[1] = int(entry[1]) + qty
		entry[2] = PICKUP_SECONDS
		(entry[0] as Label).text = "+%d %s" % [entry[1], ItemDB.display_name(item_id)]
		return
	while _pickups.size() >= MAX_PICKUPS:
		var oldest := ""
		for id: String in _pickups:
			if oldest.is_empty() or float(_pickups[id][2]) < float(_pickups[oldest][2]):
				oldest = id
		(_pickups[oldest][3] as Control).queue_free()
		_pickups.erase(oldest)
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.HUD_PANEL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiKit.label("+%d %s" % [qty, ItemDB.display_name(item_id)], UiTheme.HUD)
	panel.add_child(label)
	_pickup_box.add_child(panel)
	_pickups[item_id] = [label, qty, PICKUP_SECONDS, panel]


func _on_sound(sound: StringName) -> void:
	if CAPTIONS.has(sound):
		_show_caption(L.t(String(CAPTIONS[sound])))


## Captions for important sounds (Settings > Captions), bottom right.
func _show_caption(text: String) -> void:
	if not GameSettings.captions:
		return
	_caption.text = text
	_caption.visible = true
	_caption.reset_size()
	_caption_t = 2.5


func _update_pickups(delta: float) -> void:
	for id: String in _pickups.keys():
		var entry: Array = _pickups[id]
		entry[2] = float(entry[2]) - delta
		if float(entry[2]) <= 0.0:
			(entry[3] as Control).queue_free()
			_pickups.erase(id)


## Optional corner minimap (Settings). `world` is shared with the world map.
func setup_minimap(world: WorldData) -> void:
	_minimap_panel = PanelContainer.new()
	_minimap_panel.theme_type_variation = UiTheme.HUD_PANEL
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap = MapView.new()
	minimap.custom_minimum_size = Vector2(230, 150)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.show_labels = false
	minimap.setup(world)
	_minimap_panel.add_child(minimap)
	_root.add_child(_minimap_panel)
	_minimap_panel.visible = false


# --- Public API used by the world --------------------------------------------------

## Quest compass: arrow toward the tracked step and a short label. Hidden if `shown` is false.
func set_compass(shown: bool, angle: float, text: String) -> void:
	_compass.visible = shown
	if shown:
		_compass_arrow.angle = angle
		_compass_arrow.queue_redraw()
		_compass_label.text = text
		_compass.reset_size()


func show_region_title(title: String, subtitle: String) -> void:
	_region_title.text = title
	_region_subtitle.text = subtitle
	# Long names (often translated ones) shrink instead of covering the HUD panels.
	_region_title.remove_theme_font_size_override("font_size")
	var font_size := _region_title.get_theme_font_size("font_size")
	var width := _region_title.get_theme_font("font").get_string_size(L.t(title), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width > REGION_TITLE_MAX_WIDTH:
		_region_title.add_theme_font_size_override("font_size", int(font_size * REGION_TITLE_MAX_WIDTH / width))
	_region_card.visible = true
	_region_card.reset_size()
	if _region_tween != null:
		_region_tween.kill()
	_region_card.modulate.a = 0.0
	_region_tween = create_tween()
	_region_tween.tween_property(_region_card, "modulate:a", 1.0, 0.8)
	_region_tween.tween_interval(2.4)
	_region_tween.tween_property(_region_card, "modulate:a", 0.0, 1.2)
	_region_tween.tween_callback(func() -> void: _region_card.visible = false)


func update_minimap(shown: bool, player_pos: Vector2, facing: Vector2, quest_target: Vector2) -> void:
	if minimap == null:
		return
	_minimap_panel.visible = shown
	if not shown:
		return
	var span := Vector2(2600, 1700)
	minimap.view_rect = Rect2(player_pos - span / 2.0, span)
	minimap.player_pos = player_pos
	minimap.player_facing = facing
	minimap.quest_target = quest_target
	_minimap_refresh += 1
	if _minimap_refresh % 8 == 1:
		minimap.refresh_fog()
	minimap.queue_redraw()


## Adds a full-screen overlay (e.g. the journal) under the themed HUD root.
func add_overlay(overlay: Control) -> void:
	_root.add_child(overlay)


func set_objective(text: String) -> void:
	_objective.text = text


func set_progress(text: String, icon: LightIcon.Style = LightIcon.Style.LIGHT) -> void:
	_progress_label.text = text
	_progress_icon.style = icon
	_progress_icon.queue_redraw()


func set_mode(display_name: String) -> void:
	_mode_label.text = L.t("Mode: %s") % L.t(display_name)


## Shows "[E] <verb>" (a text + key cue, not only color). Empty text hides it.
func set_prompt(text: String) -> void:
	_prompt_panel.visible = not text.is_empty()
	_prompt_label.text = "[E]  %s" % L.t(text)
	_prompt_panel.reset_size()


func show_dialogue(text: String, seconds: float = DIALOGUE_SECONDS) -> void:
	_dialogue_label.text = text
	_dialogue_panel.visible = true
	_dialogue_panel.reset_size()
	_dialogue_timer = seconds
	if _dialogue_tween != null:
		_dialogue_tween.kill()
	_dialogue_panel.modulate.a = 0.0
	_dialogue_tween = create_tween()
	_dialogue_tween.tween_property(_dialogue_panel, "modulate:a", 1.0, 0.3)


func hide_dialogue() -> void:
	_dialogue_timer = 0.0
	_dialogue_panel.visible = false


func is_dialogue_visible() -> bool:
	return _dialogue_panel.visible


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.reset_size()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.4)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func() -> void: _toast_panel.visible = false)


func _process(delta: float) -> void:
	if _dialogue_timer > 0.0:
		_dialogue_timer -= delta
		if _dialogue_timer <= 0.0:
			var tween := create_tween()
			tween.tween_property(_dialogue_panel, "modulate:a", 0.0, 0.5)
			tween.tween_callback(func() -> void: _dialogue_panel.visible = false)
	_update_pickups(delta)
	if _caption_t > 0.0:
		_caption_t -= delta
		if _caption_t <= 0.0:
			_caption.visible = false
	_layout()


## Positions panels from the current viewport size (works for any window size).
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	_top_bar.position = Vector2(view.x - _top_bar.size.x - 16.0, 16.0)
	_place_centered(_prompt_panel, view, view.y - _prompt_panel.size.y - 150.0)
	_place_centered(_dialogue_panel, view, view.y - _dialogue_panel.size.y - 20.0)
	_place_centered(_toast_panel, view, view.y * 0.31)
	_place_centered(_region_card, view, view.y * 0.12)
	# The compass sits under the quest panel: direction and goal stay together.
	if _compass.visible:
		_compass.position = Vector2(16.0, _objective_panel.position.y + _objective_panel.size.y + 8.0)
	_hotbar.position = Vector2(16.0, view.y - _hotbar.size.y - 16.0)
	_build_hint.position = Vector2(_hotbar.position.x + _hotbar.size.x + 10.0, _hotbar.position.y + 4.0)
	_pickup_box.position = Vector2(16.0, _hotbar.position.y - _pickup_box.size.y - 8.0)
	_pickup_box.reset_size()
	_clock_panel.position = Vector2(view.x - _clock_panel.size.x - 16.0, 72.0)
	if _caption.visible:
		_caption.position = Vector2(view.x - _caption.size.x - 20.0, view.y - _caption.size.y - 76.0)
	if _minimap_panel != null and _minimap_panel.visible:
		_minimap_panel.position = Vector2(view.x - _minimap_panel.size.x - 16.0, view.y - _minimap_panel.size.y - 16.0)


func _place_centered(panel: Control, view: Vector2, y: float) -> void:
	if panel.visible:
		panel.position = Vector2((view.x - panel.size.x) / 2.0, y)


## Small arrow pointing toward the tracked quest target (shape cue + text label).
class CompassArrow extends Control:
	var angle: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(28, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var dir := Vector2.RIGHT.rotated(angle)
		var side := dir.orthogonal()
		var pts := PackedVector2Array([c + dir * 12.0, c - dir * 8.0 + side * 8.0, c - dir * 3.0, c - dir * 8.0 - side * 8.0])
		draw_colored_polygon(pts, Palette.GOLD)
		pts.append(c + dir * 12.0)
		draw_polyline(pts, Palette.INK, 2.0, true)
