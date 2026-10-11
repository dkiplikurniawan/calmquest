class_name Hud
extends CanvasLayer
## Gameplay HUD, minimal and calm (0.4.0): a compact quest tracker (with the
## guidance line merged in), a small sun/moon arc, Lumi's dialogue box, the
## interaction prompt, short grouped toasts below the player, a fading hotbar,
## and contextual key hints instead of always-visible buttons. Mouse users get
## a small menu icon in the top-right corner that fades in when the mouse moves.
## It only displays what the world tells it and reports requests; it holds no
## gameplay state.
##
## HUD buttons never take keyboard focus, so Space/Enter/E can't trigger them
## by accident during play.

signal hint_requested
signal journal_requested
signal pause_requested
signal map_requested

const DIALOGUE_SECONDS := 6.0
const TOAST_SECONDS := 3.0
const BANNER_SECONDS := 4.2
## Pickups within this many seconds are combined into one toast.
const PICKUP_GROUP_SECONDS := 2.0
const MAX_TOASTS := 2
const KEY_HINT_SECONDS := 5.0
## The tracker and hotbar fade to these while walking / unused (Settings > Interface).
const TRACKER_FADED_ALPHA := 0.55
const HOTBAR_FADED_ALPHA := 0.35
const HOTBAR_IDLE_SECONDS := 6.0
const TRACKER_FLASH_SECONDS := 4.0
## Region titles wider than this (in pixels) are drawn smaller.
const REGION_TITLE_MAX_WIDTH := 600.0
## Region titles sit in the upper third, toasts in the lower part, so neither
## covers the player (who is always at the center of the screen).
const REGION_TITLE_Y := 0.09
const TOAST_Y := 0.6
## The screen area the player and Lumi occupy (around the player's position).
const PLAYER_AREA := Vector2(200, 200)
## Toasts never go below this (the prompt and Lumi's dialogue live there).
const TOAST_BOTTOM_MARGIN := 170.0
const CAPTIONS := {
	&"collect": "[soft chime]", &"bonus": "[sparkling chime]", &"lantern": "[lantern bell]",
	&"discover": "[bright twinkle]", &"restore": "[warm rising melody]", &"bloom": "[gentle bloom]",
	&"soft_deny": "[soft low tone]", &"night": "[deep, calm hum]",
}
## Key hints: id -> [action, label].
const KEY_HINTS := {
	"hint": [InputSetup.HINT, "Ask Lumi"], "journal": [InputSetup.JOURNAL, "Journal"],
	"map": [InputSetup.MAP, "Map"], "pause": [InputSetup.PAUSE, "Pause"],
	"bag": [InputSetup.INVENTORY, "Bag and crafting"], "build": [InputSetup.BUILD, "Build mode"],
	"interact": [InputSetup.INTERACT, "Interact"], "use": [InputSetup.USE_ITEM, "Use or eat"],
}
const HINT_STRIP := ["hint", "journal", "map", "pause"]

var _root: Control
var _objective_panel: PanelContainer
var _objective: Label
var _progress_row: HBoxContainer
var _progress_label: Label
var _progress_icon: LightIcon
var _compass: HBoxContainer
var _compass_arrow: CompassArrow
var _compass_label: Label
var _mode_label: Label
var _menu: HudMenu
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _dialogue_panel: PanelContainer
var _dialogue_label: Label
var _dialogue_tween: Tween
var _dialogue_timer: float = 0.0
var _toast_box: VBoxContainer
## Each: {"panel", "label", "t", "pickup", "items": {id: qty}, "age"}
var _toasts: Array[Dictionary] = []
var _region_card: VBoxContainer
var _region_title: Label
var _region_subtitle: Label
var _region_tween: Tween
var _minimap_panel: PanelContainer
var minimap: MapView
var _minimap_refresh: int = 0
var _hotbar: HBoxContainer
var _hotbar_slots: Array[ItemSlot] = []
var _hotbar_idle: float = 0.0
var selected_hotbar: int = 0
var _build_hint: PanelContainer
var _day_arc: DayArc
var _clock_text: String = ""
var _caption: Label
var _caption_t: float = 0.0
var _key_hint: PanelContainer
var _key_hint_label: Label
var _key_hint_t: float = 0.0
var _hint_strip: PanelContainer
var _hint_strip_label: Label
var _moving: bool = false
## Where the player is on screen (set by the world each frame; the camera is
## clamped at the edges of the world and inside rooms, so it is not always the center).
var _player_screen := Vector2(-1, -1)
var _build_area: bool = false
var _tracker_flash: float = 0.0
## Study Mode only: a small sun that slowly fades as the session time passes
## (there is never a visible countdown).
var _study_light: StudyLight


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	UiKit.adopt_theme(root)
	_root = root
	_build_tracker(root)
	_build_prompt(root)
	_build_dialogue(root)
	_build_toasts(root)
	_build_region_card(root)
	_build_hotbar(root)
	_build_corner(root)
	_build_key_hints(root)
	_study_light = StudyLight.new()
	_study_light.visible = false
	root.add_child(_study_light)
	GameSettings.settings_changed.connect(_apply_interface_settings)
	_apply_interface_settings()


func _build_tracker(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.HUD_PANEL
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	_objective_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	_objective = UiKit.label("", UiTheme.HUD)
	box.add_child(_objective)
	_progress_row = HBoxContainer.new()
	_progress_row.add_theme_constant_override("separation", 8)
	_progress_icon = LightIcon.new(LightIcon.Style.LIGHT, 22)
	_progress_row.add_child(_progress_icon)
	_progress_label = UiKit.label("", UiTheme.HUD)
	_progress_row.add_child(_progress_label)
	box.add_child(_progress_row)
	# The guidance line is part of the tracker: direction and goal stay together.
	_compass = HBoxContainer.new()
	_compass.add_theme_constant_override("separation", 8)
	_compass_arrow = CompassArrow.new()
	_compass.add_child(_compass_arrow)
	_compass_label = UiKit.label("", UiTheme.SUBTLE)
	_compass.add_child(_compass_label)
	_compass.visible = false
	box.add_child(_compass)


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


func _build_toasts(root: Control) -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.add_theme_constant_override("separation", 6)
	root.add_child(_toast_box)


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


## Top-right: the small sun/moon arc and the mouse menu icon.
func _build_corner(root: Control) -> void:
	_day_arc = DayArc.new()
	root.add_child(_day_arc)
	_menu = HudMenu.new()
	_menu.chosen.connect(_on_menu_chosen)
	root.add_child(_menu)
	_mode_label = _menu.mode_label


func _on_menu_chosen(what: String) -> void:
	match what:
		"hint":
			hint_requested.emit()
		"journal":
			journal_requested.emit()
		"map":
			map_requested.emit()
		"pause":
			pause_requested.emit()


func _build_key_hints(root: Control) -> void:
	_key_hint = PanelContainer.new()
	_key_hint.theme_type_variation = UiTheme.HUD_PANEL
	_key_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_hint_label = UiKit.label("", UiTheme.HUD)
	_key_hint.add_child(_key_hint_label)
	_key_hint.visible = false
	root.add_child(_key_hint)
	_hint_strip = PanelContainer.new()
	_hint_strip.theme_type_variation = UiTheme.HUD_PANEL
	_hint_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_strip_label = UiKit.label("", UiTheme.SUBTLE)
	_hint_strip.add_child(_hint_strip_label)
	_hint_strip.visible = false
	root.add_child(_hint_strip)


func _apply_interface_settings() -> void:
	var always := GameSettings.control_hints == GameSettings.HINTS_ALWAYS
	_hint_strip.visible = always
	if always:
		var parts := PackedStringArray()
		for id: String in HINT_STRIP:
			parts.append(key_hint_text(id))
		_hint_strip_label.text = "   ".join(parts)
		_hint_strip.reset_size()
	if GameSettings.control_hints == GameSettings.HINTS_NEVER:
		_key_hint.visible = false
	var compact := GameSettings.quest_tracker_compact
	_progress_row.visible = not compact
	_compass.visible = _compass.visible and not compact
	_objective_panel.reset_size()


# --- Hotbar --------------------------------------------------------------------------

## Refreshes the hotbar from the inventory (first 8 slots).
func update_hotbar(inventory: Inventory) -> void:
	for i in _hotbar_slots.size():
		var s: Dictionary = inventory.slots[i] if i < inventory.slots.size() else {}
		_hotbar_slots[i].set_item(String(s.get("id", "")), int(s.get("qty", 0)))
		_hotbar_slots[i].selected = i == selected_hotbar
	wake_hotbar()


func select_hotbar(index: int) -> void:
	selected_hotbar = clampi(index, 0, Inventory.HOTBAR_SIZE - 1)
	for i in _hotbar_slots.size():
		_hotbar_slots[i].selected = i == selected_hotbar
		_hotbar_slots[i].queue_redraw()
	wake_hotbar()


## The hotbar returns to full opacity on any hotbar input.
func wake_hotbar() -> void:
	_hotbar_idle = 0.0


func hotbar_alpha() -> float:
	return _hotbar.modulate.a


## Entering a place where build mode works: the B key hint follows the
## control-hint setting (Always: a small pill while there; Sometimes: briefly
## on entering; Never: nothing).
func set_build_hint(shown: bool) -> void:
	if shown and not _build_area and GameSettings.control_hints == GameSettings.HINTS_SOMETIMES:
		show_key_hint("build")
	_build_area = shown
	_build_hint.visible = shown and GameSettings.control_hints == GameSettings.HINTS_ALWAYS


# --- Time of day -----------------------------------------------------------------------

## The clock text (shown in the corner menu); the arc reads the time itself.
func set_clock(text: String, is_night: bool) -> void:
	_clock_text = (L.t("Night") + "  " if is_night else "") + text
	_menu.clock_label.text = _clock_text
	_day_arc.set_time(TimeManager.visual_minute(), TimeManager.day)


func clock_text() -> String:
	return _clock_text


# --- Toasts ----------------------------------------------------------------------------

## Pickups within about 2 seconds are combined into one short toast
## ("+5 Pinecone, +4 Forest Mushroom").
func show_pickup(item_id: String, qty: int) -> void:
	for t: Dictionary in _toasts:
		if bool(t["pickup"]) and float(t["age"]) <= PICKUP_GROUP_SECONDS:
			var items: Dictionary = t["items"]
			items[item_id] = int(items.get(item_id, 0)) + qty
			(t["label"] as Label).text = _pickup_text(items)
			t["age"] = 0.0
			t["t"] = TOAST_SECONDS
			(t["panel"] as Control).reset_size()
			return
	var toast := _add_toast(_pickup_text({item_id: qty}), UiTheme.HUD, TOAST_SECONDS)
	toast["pickup"] = true
	toast["items"] = {item_id: qty}


func _pickup_text(items: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: String in items:
		parts.append("+%d %s" % [int(items[id]), ItemDB.display_name(id)])
	return ", ".join(parts)


## A small toast for everyday news ("Waystone discovered", "Done: ...").
func show_toast(text: String) -> void:
	_add_toast(text, UiTheme.HUD, TOAST_SECONDS)


## A larger banner, reserved for truly major moments.
func show_banner(text: String) -> void:
	_add_toast(text, UiTheme.HEADING, BANNER_SECONDS)


func _add_toast(text: String, variation: StringName, seconds: float) -> Dictionary:
	while _toasts.size() >= MAX_TOASTS:
		var oldest: Dictionary = _toasts.pop_front()
		(oldest["panel"] as Control).queue_free()
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.HUD_PANEL if variation == UiTheme.HUD else UiTheme.DIALOGUE_PANEL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiKit.label(text, variation)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	panel.modulate.a = 0.0
	_toast_box.add_child(panel)
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	var toast := {"panel": panel, "label": label, "t": seconds, "pickup": false, "items": {}, "age": 0.0}
	_toasts.append(toast)
	return toast


## Visible toast texts, oldest first (for tests and tools).
func toast_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for t: Dictionary in _toasts:
		out.append((t["label"] as Label).text)
	return out


func _update_toasts(delta: float) -> void:
	for t: Dictionary in _toasts.duplicate():
		t["age"] = float(t["age"]) + delta
		t["t"] = float(t["t"]) - delta
		var panel: Control = t["panel"]
		if float(t["t"]) <= 0.0:
			_toasts.erase(t)
			var tween := panel.create_tween()
			tween.tween_property(panel, "modulate:a", 0.0, 0.5)
			tween.tween_callback(panel.queue_free)


# --- Captions --------------------------------------------------------------------------

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


# --- Key hints -------------------------------------------------------------------------

## "[H] Ask Lumi", with the player's current key for that action.
static func key_hint_text(id: String) -> String:
	var spec: Array = KEY_HINTS[id]
	return "[%s] %s" % [InputSetup.key_name(InputSetup.primary_key(spec[0])), L.t(String(spec[1]))]


## Shows one contextual key hint briefly. Returns false when the setting is
## Never (and when Always already shows that key in the strip).
func show_key_hint(id: String) -> bool:
	if not KEY_HINTS.has(id) or GameSettings.control_hints == GameSettings.HINTS_NEVER:
		return false
	if GameSettings.control_hints == GameSettings.HINTS_ALWAYS and HINT_STRIP.has(id):
		return false
	_key_hint_label.text = key_hint_text(id)
	_key_hint.visible = true
	_key_hint.reset_size()
	_key_hint_t = KEY_HINT_SECONDS
	return true


func is_key_hint_visible() -> bool:
	return _key_hint.visible


func is_hint_strip_visible() -> bool:
	return _hint_strip.visible


# --- Tracker -----------------------------------------------------------------------------

## Quest guidance (arrow + "A light - very close") inside the tracker.
func set_compass(shown: bool, angle: float, text: String) -> void:
	_compass.visible = shown and not GameSettings.quest_tracker_compact
	if shown:
		_compass_arrow.angle = angle
		_compass_arrow.queue_redraw()
		_compass_label.text = text
	_objective_panel.reset_size()


func set_objective(text: String) -> void:
	if _objective.text != text:
		flash_tracker()
	_objective.text = text
	_objective_panel.reset_size()


func set_progress(text: String, icon: LightIcon.Style = LightIcon.Style.LIGHT) -> void:
	if _progress_label.text != text:
		flash_tracker()
	_progress_label.text = text
	_progress_icon.style = icon
	_progress_icon.queue_redraw()
	_objective_panel.reset_size()


## Shows the tracker fully for a moment (quest updates).
func flash_tracker() -> void:
	_tracker_flash = TRACKER_FLASH_SECONDS


## The world reports whether the player is walking (the tracker fades a little).
func set_moving(moving: bool) -> void:
	_moving = moving


func tracker_alpha() -> float:
	return _objective_panel.modulate.a


func set_mode(display_name: String) -> void:
	_mode_label.text = L.t("Mode: %s") % L.t(display_name)


# --- Region titles -------------------------------------------------------------------------

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
	_region_tween.tween_property(_region_card, "modulate:a", 1.0, 0.9)
	_region_tween.tween_interval(2.4)
	_region_tween.tween_property(_region_card, "modulate:a", 0.0, 1.4)
	_region_tween.tween_callback(func() -> void: _region_card.visible = false)
	_layout()


func region_card_rect() -> Rect2:
	return _region_card.get_global_rect()


func set_player_screen_position(pos: Vector2) -> void:
	_player_screen = pos


## The screen rectangle around the player and Lumi that HUD text must avoid.
func player_screen_rect() -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var center := view / 2.0 if _player_screen.x < 0.0 else _player_screen
	# The player's feet are at the position; the body and Lumi are above it.
	return Rect2(center - Vector2(PLAYER_AREA.x / 2.0, PLAYER_AREA.y * 0.6), PLAYER_AREA)


func toast_area_rect() -> Rect2:
	return _toast_box.get_global_rect()


# --- Minimap ---------------------------------------------------------------------------------

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


# --- Overlays, prompt, dialogue --------------------------------------------------------------

## Adds a full-screen overlay (e.g. the journal) under the themed HUD root.
func add_overlay(overlay: Control) -> void:
	_root.add_child(overlay)


## Shows "[E] <verb>" (a text + key cue, not only color). Empty text hides it.
func set_prompt(text: String) -> void:
	_prompt_panel.visible = not text.is_empty()
	_prompt_label.text = "[%s]  %s" % [InputSetup.key_name(InputSetup.primary_key(InputSetup.INTERACT)), L.t(text)]
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


## Study Mode: 1 at the start of the session, 0 when the time is up.
func set_study_light(fraction: float) -> void:
	_study_light.visible = true
	_study_light.fraction = fraction


# --- Per frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _dialogue_timer > 0.0:
		_dialogue_timer -= delta
		if _dialogue_timer <= 0.0:
			var tween := create_tween()
			tween.tween_property(_dialogue_panel, "modulate:a", 0.0, 0.5)
			tween.tween_callback(func() -> void: _dialogue_panel.visible = false)
	_update_toasts(delta)
	if _caption_t > 0.0:
		_caption_t -= delta
		if _caption_t <= 0.0:
			_caption.visible = false
	if _key_hint_t > 0.0:
		_key_hint_t -= delta
		if _key_hint_t <= 0.0:
			_key_hint.visible = false
	_update_fades(delta)
	_layout()


func _update_fades(delta: float) -> void:
	var fade := GameSettings.hud_fade
	_tracker_flash = maxf(0.0, _tracker_flash - delta)
	var tracker_target := TRACKER_FADED_ALPHA if fade and _moving and _tracker_flash <= 0.0 else 1.0
	_objective_panel.modulate.a = move_toward(_objective_panel.modulate.a, tracker_target, delta * 1.5)
	_hotbar_idle += delta
	var hotbar_target := HOTBAR_FADED_ALPHA if fade and _hotbar_idle > HOTBAR_IDLE_SECONDS else 1.0
	_hotbar.modulate.a = move_toward(_hotbar.modulate.a, hotbar_target, delta * (4.0 if hotbar_target > _hotbar.modulate.a else 0.8))


## Positions panels from the current viewport size (works for any window size).
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	_day_arc.position = Vector2(view.x - _day_arc.size.x - 16.0, 14.0)
	_menu.position = Vector2(view.x - _menu.size.x - 16.0, _day_arc.position.y + _day_arc.size.y + 6.0)
	_place_centered(_prompt_panel, view, view.y - _prompt_panel.size.y - 150.0)
	_place_centered(_dialogue_panel, view, view.y - _dialogue_panel.size.y - 20.0)
	_toast_box.reset_size()
	var player := player_screen_rect()
	var toast_x := clampf(player.get_center().x - _toast_box.size.x / 2.0, 16.0, view.x - _toast_box.size.x - 16.0)
	var toast_y := maxf(view.y * TOAST_Y, player.end.y + 6.0)
	if toast_y + _toast_box.size.y > view.y - TOAST_BOTTOM_MARGIN:
		toast_y = player.position.y - 6.0 - _toast_box.size.y
	_toast_box.position = Vector2(toast_x, toast_y)
	if _region_card.visible:
		# Upper third; below the quest tracker if they would touch, never down to the player.
		var y := view.y * REGION_TITLE_Y
		var x := (view.x - _region_card.size.x) / 2.0
		var tracker := _objective_panel.get_rect()
		if x < tracker.end.x and x + _region_card.size.x > tracker.position.x:
			y = maxf(y, tracker.end.y + 8.0)
		var player_rect := player_screen_rect()
		if Rect2(Vector2(x, y), _region_card.size).intersects(player_rect):
			y = minf(y, player_rect.position.y - _region_card.size.y - 8.0)
			if y < 8.0:
				y = player_rect.end.y + 8.0
		_region_card.position = Vector2(x, y)
	_hotbar.position = Vector2(16.0, view.y - _hotbar.size.y - 16.0)
	_build_hint.position = Vector2(_hotbar.position.x + _hotbar.size.x + 10.0, _hotbar.position.y + 4.0)
	if _study_light.visible:
		_study_light.position = Vector2(_day_arc.position.x - _study_light.size.x - 6.0, _day_arc.position.y + 2.0)
	var bottom_right := view.y - 16.0
	if _minimap_panel != null and _minimap_panel.visible:
		_minimap_panel.position = Vector2(view.x - _minimap_panel.size.x - 16.0, view.y - _minimap_panel.size.y - 16.0)
		bottom_right = _minimap_panel.position.y - 8.0
	if _hint_strip.visible:
		_hint_strip.position = Vector2(view.x - _hint_strip.size.x - 16.0, bottom_right - _hint_strip.size.y)
		bottom_right = _hint_strip.position.y - 6.0
	if _key_hint.visible:
		_key_hint.position = Vector2(view.x - _key_hint.size.x - 16.0, bottom_right - _key_hint.size.y)
		bottom_right = _key_hint.position.y - 6.0
	if _caption.visible:
		_caption.position = Vector2(view.x - _caption.size.x - 20.0, bottom_right - _caption.size.y - 4.0)


func _place_centered(panel: Control, view: Vector2, y: float) -> void:
	if panel.visible:
		panel.position = Vector2((view.x - panel.size.x) / 2.0, y)


## The mouse menu: a small round icon that fades in when the mouse moves and
## opens a short list (Ask Lumi, Journal, Map, Pause) with the mode and clock.
class HudMenu extends VBoxContainer:
	signal chosen(what: String)

	const SHOW_SECONDS := 2.5

	var mode_label: Label
	var clock_label: Label
	var icon: Button
	var list: VBoxContainer
	var _awake: float = 0.0

	func _init() -> void:
		alignment = BoxContainer.ALIGNMENT_END
		add_theme_constant_override("separation", 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon = Button.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.focus_mode = Control.FOCUS_NONE
		icon.size_flags_horizontal = Control.SIZE_SHRINK_END
		icon.tooltip_text = "Menu"
		icon.draw.connect(_draw_icon)
		icon.pressed.connect(func() -> void: list.visible = not list.visible)
		add_child(icon)
		var panel := PanelContainer.new()
		panel.theme_type_variation = UiTheme.HUD_PANEL
		list = VBoxContainer.new()
		list.add_theme_constant_override("separation", 4)
		mode_label = UiKit.label("", UiTheme.SUBTLE)
		list.add_child(mode_label)
		clock_label = UiKit.label("", UiTheme.SUBTLE)
		list.add_child(clock_label)
		for spec: Array in [["hint", InputSetup.HINT, "Ask Lumi"], ["journal", InputSetup.JOURNAL, "Journal"], ["map", InputSetup.MAP, "Map"], ["pause", InputSetup.PAUSE, "Pause"]]:
			var what: String = spec[0]
			var b := UiKit.button("", func() -> void:
				list.visible = false
				chosen.emit(what))
			b.set_meta("label", spec[2])
			b.set_meta("action", spec[1])
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 38)
			list.add_child(b)
		panel.add_child(list)
		list.visible = false
		add_child(panel)
		panel.visible = false
		list.visibility_changed.connect(func() -> void:
			panel.visible = list.visible
			if list.visible:
				_refresh_labels())
		modulate.a = 0.0

	func _refresh_labels() -> void:
		for b in list.get_children():
			if b is Button:
				(b as Button).text = "%s (%s)" % [L.t(String(b.get_meta("label"))), InputSetup.key_name(InputSetup.primary_key(b.get_meta("action")))]

	func is_open() -> bool:
		return list.visible

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion or event is InputEventMouseButton:
			_awake = SHOW_SECONDS

	func _process(delta: float) -> void:
		_awake = maxf(0.0, _awake - delta)
		var target := 1.0 if _awake > 0.0 or list.visible or icon.is_hovered() else 0.0
		modulate.a = move_toward(modulate.a, target, delta * 3.0)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP if modulate.a > 0.05 else Control.MOUSE_FILTER_IGNORE

	func _draw_icon() -> void:
		var c := icon.size / 2.0
		for i in 3:
			var y := c.y - 7.0 + i * 7.0
			icon.draw_line(Vector2(c.x - 9.0, y), Vector2(c.x + 9.0, y), Palette.INK, 2.5, true)


## A small arc across the top-right: the sun by day, the moon by night.
class DayArc extends Control:
	var minute: float = 480.0
	var day: int = 1
	var _label: Label

	func _init() -> void:
		custom_minimum_size = Vector2(132, 40)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = UiKit.label("", UiTheme.SUBTLE)
		_label.position = Vector2(0, 16)
		_label.add_theme_font_size_override("font_size", 14)
		add_child(_label)

	func set_time(m: float, d: int) -> void:
		if absf(m - minute) < 1.0 and d == day:
			return
		minute = m
		day = d
		_label.text = L.t("Day %d") % day
		queue_redraw()

	func _draw() -> void:
		var night := minute < 360.0 or minute >= 1080.0
		var c := Vector2(size.x - 34.0, 34.0)
		var r := 28.0
		draw_arc(c, r, PI, TAU, 24, Palette.with_alpha(Palette.CREAM, 0.7), 2.0, true)
		draw_line(c + Vector2(-r - 4.0, 0), c + Vector2(r + 4.0, 0), Palette.with_alpha(Palette.CREAM, 0.5), 1.5)
		# 06:00-18:00 is the sun's arc, 18:00-06:00 the moon's.
		var t := fposmod(minute - 360.0, 720.0) / 720.0
		var p := c + Vector2.from_angle(PI + PI * t) * r
		if night:
			draw_circle(p, 6.0, Palette.IVORY)
			draw_circle(p + Vector2(2.5, -1.5), 5.0, Palette.NIGHT)
			draw_arc(p, 6.0, 0.0, TAU, 16, Palette.INK, 1.2, true)
		else:
			draw_circle(p, 9.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.4))
			draw_circle(p, 5.5, Palette.GOLD)
			draw_arc(p, 5.5, 0.0, TAU, 16, Palette.INK, 1.2, true)


## A small sun whose glow fades slowly over a study session.
class StudyLight extends Control:
	var fraction: float = 1.0:
		set(value):
			if absf(value - fraction) > 0.002:
				fraction = value
				queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(36, 36)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var a := 0.25 + 0.75 * fraction
		draw_circle(c, 15.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.35 * a))
		draw_circle(c, 9.0, Palette.with_alpha(Palette.GOLD, a))
		for i in 8:
			var d := Vector2.from_angle(TAU * i / 8.0)
			draw_line(c + d * 11.0, c + d * 15.0, Palette.with_alpha(Palette.GOLD, a), 2.0)


## Small arrow pointing toward the tracked quest target (shape cue + text label).
class CompassArrow extends Control:
	var angle: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(24, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var dir := Vector2.RIGHT.rotated(angle)
		var side := dir.orthogonal()
		var pts := PackedVector2Array([c + dir * 10.0, c - dir * 7.0 + side * 7.0, c - dir * 2.5, c - dir * 7.0 - side * 7.0])
		draw_colored_polygon(pts, Palette.GOLD)
		pts.append(c + dir * 10.0)
		draw_polyline(pts, Palette.INK, 2.0, true)
