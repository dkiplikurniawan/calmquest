extends Node
## Player preferences (autoload "GameSettings"), persisted to user://settings.cfg.
## Every setting shown in the Settings panel is applied for real here or by
## the system that listens to `settings_changed`.

signal settings_changed

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
## Motion multiplier applied when "Reduce motion" is on.
const REDUCED_MOTION_SCALE := 0.35

const KEYS: PackedStringArray = [
	"master_volume", "music_volume", "sfx_volume", "fullscreen", "window_size_index",
	"text_scale_index", "high_contrast", "reduce_motion", "lumi_chatter", "adaptive_assistance",
	"run_toggle", "reduced_camera_motion", "show_minimap", "show_compass", "region_titles",
	"day_length_minutes", "time_mode", "gentle_clock", "autosave_minutes", "last_slot",
	"ambience_volume", "ui_volume", "music_mode", "hint_frequency", "weather_effects", "captions", "key_bindings",
	"language",
]

const MUSIC_MODE_NAMES: PackedStringArray = ["Continuous music", "Music with quiet pauses", "Music off"]
const HINT_FREQUENCY_NAMES: PackedStringArray = ["Off", "Rare", "Normal", "Helpful"]

var master_volume: float = 0.8
var music_volume: float = 0.5
var sfx_volume: float = 0.8
var fullscreen: bool = false
var window_size_index: int = 0
var text_scale_index: int = 0
var high_contrast: bool = false
var reduce_motion: bool = false
## Lumi's occasional unprompted lines (welcome, milestones). Hints on request always work.
var lumi_chatter: bool = true
## Allows the adaptive engine's automatic assistance rules (guiding glow after
## repeated hint requests, reach explanation after near misses).
var adaptive_assistance: bool = true
## Run with Shift: false = hold Shift, true = press Shift to switch walk/run.
var run_toggle: bool = false
## Turns off camera look-ahead and context zoom changes.
var reduced_camera_motion: bool = false
## Small corner map. Off by default to keep the HUD minimal.
var show_minimap: bool = false
## Direction arrow toward the tracked quest step. On by default; can be turned off.
var show_compass: bool = true
## Region title cards: 0 = first visit only, 1 = every visit, 2 = off.
var region_titles: int = 0
## Real minutes per in-game day (15-24).
var day_length_minutes: int = 20
## 0 = normal day/night cycle, 1 = keep it day, 2 = keep it night.
var time_mode: int = 0
## Clock in Gentle mode: 0 = normal speed, 1 = half speed, 2 = paused.
var gentle_clock: int = 1
## Periodic autosave interval in minutes (0 = only on sleep, travel and quests).
var autosave_minutes: int = 5
## The save slot chosen last time (pre-selected on the slot screen).
var last_slot: int = 1
var ambience_volume: float = 0.6
var ui_volume: float = 0.7
## 0 = continuous, 1 = with quiet pauses between pieces, 2 = off.
var music_mode: int = 0
## Lumi's unprompted nudges toward the followed quest: -1 = by mode (Gentle:
## Helpful, Balanced: Normal, Playful: Rare), 0 = off, 1 = rare, 2 = normal,
## 3 = helpful. Hints on request (H) always work.
var hint_frequency: int = -1
## Rain, clouds and mist visuals (the weather still waters crops when off).
var weather_effects: bool = true
## Short text captions for important sounds.
var captions: bool = false
## Remapped keys: action name -> physical keycode (replaces the first key).
var key_bindings: Dictionary = {}
## Interface language: "en" (English) or "id" (Bahasa Indonesia).
var language: String = "en"

var last_error: String = ""
## Where settings are saved. Tests point this at a temporary file.
var settings_path: String = DEFAULT_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure_actions()
	load_settings()
	L.set_language(language)
	InputSetup.apply_overrides(key_bindings)
	apply_display()
	apply_theme()


func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(settings_path)
	if err != OK:
		last_error = "Settings could not be read (%s); defaults are used." % error_string(err)
		push_warning(last_error)
		return
	for key in KEYS:
		if cfg.has_section_key(SECTION, key):
			set(key, cfg.get_value(SECTION, key))
	_sanitize()


func save_settings() -> bool:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value(SECTION, key, get(key))
	var err := cfg.save(settings_path)
	if err != OK:
		last_error = "Settings could not be saved (%s)." % error_string(err)
		push_warning(last_error)
		return false
	return true


## Changes one setting, applies it immediately and saves.
func set_setting(key: String, value: Variant) -> void:
	if not KEYS.has(key):
		push_warning("GameSettings: unknown setting '%s'." % key)
		return
	set(key, value)
	_sanitize()
	if key in ["fullscreen", "window_size_index"]:
		apply_display()
	if key in ["text_scale_index", "high_contrast"]:
		apply_theme()
	if key == "language":
		L.set_language(language)
	save_settings()
	settings_changed.emit()


func get_text_scale() -> float:
	return UiTheme.TEXT_SCALES[text_scale_index]


## 1.0 normally, REDUCED_MOTION_SCALE when the player asked for less motion.
func motion_scale() -> float:
	return REDUCED_MOTION_SCALE if reduce_motion else 1.0


## Group for UI roots living under a CanvasLayer: CanvasLayers do not pass the
## Window theme down, so those roots receive the theme explicitly (UiKit.adopt_theme).
const THEMED_ROOTS_GROUP := &"themed_ui_roots"

var ui_theme: Theme


func apply_theme() -> void:
	ui_theme = UiTheme.build(get_text_scale(), high_contrast)
	get_tree().root.theme = ui_theme
	for node in get_tree().get_nodes_in_group(THEMED_ROOTS_GROUP):
		(node as Control).theme = ui_theme


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	var target := WINDOW_SIZES[window_size_index]
	var screen := window.current_screen
	var usable := DisplayServer.screen_get_usable_rect(screen)
	target = Vector2i(mini(target.x, usable.size.x), mini(target.y, usable.size.y))
	window.size = target
	window.position = usable.position + (usable.size - target) / 2


func _sanitize() -> void:
	master_volume = clampf(float(master_volume), 0.0, 1.0)
	music_volume = clampf(float(music_volume), 0.0, 1.0)
	sfx_volume = clampf(float(sfx_volume), 0.0, 1.0)
	window_size_index = clampi(int(window_size_index), 0, WINDOW_SIZES.size() - 1)
	text_scale_index = clampi(int(text_scale_index), 0, UiTheme.TEXT_SCALES.size() - 1)
	fullscreen = bool(fullscreen)
	high_contrast = bool(high_contrast)
	reduce_motion = bool(reduce_motion)
	lumi_chatter = bool(lumi_chatter)
	adaptive_assistance = bool(adaptive_assistance)
	run_toggle = bool(run_toggle)
	reduced_camera_motion = bool(reduced_camera_motion)
	show_minimap = bool(show_minimap)
	show_compass = bool(show_compass)
	region_titles = clampi(int(region_titles), 0, 2)
	day_length_minutes = clampi(int(day_length_minutes), 15, 24)
	time_mode = clampi(int(time_mode), 0, 2)
	gentle_clock = clampi(int(gentle_clock), 0, 2)
	autosave_minutes = clampi(int(autosave_minutes), 0, 30)
	last_slot = clampi(int(last_slot), 1, 3)
	ambience_volume = clampf(float(ambience_volume), 0.0, 1.0)
	ui_volume = clampf(float(ui_volume), 0.0, 1.0)
	music_mode = clampi(int(music_mode), 0, 2)
	hint_frequency = clampi(int(hint_frequency), -1, 3)
	weather_effects = bool(weather_effects)
	captions = bool(captions)
	if typeof(key_bindings) != TYPE_DICTIONARY:
		key_bindings = {}
	language = String(language) if L.LANGUAGES.has(String(language)) else "en"


## The hint frequency in use (resolving "by mode").
func effective_hint_frequency(mode_id: StringName) -> int:
	if hint_frequency >= 0:
		return hint_frequency
	match mode_id:
		&"gentle":
			return 3
		&"playful":
			return 1
	return 2


## Remaps an action's main key and saves it. Returns the action already using
## that key, if any ("" otherwise), so the panel can mention it.
func rebind(action: StringName, keycode: int) -> String:
	var clash := InputSetup.action_for_key(keycode, action)
	key_bindings[String(action)] = keycode
	InputSetup.apply_overrides(key_bindings)
	save_settings()
	settings_changed.emit()
	return clash


func reset_bindings() -> void:
	key_bindings = {}
	InputSetup.reset_keyboard()
	save_settings()
	settings_changed.emit()
