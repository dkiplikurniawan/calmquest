extends Node
## Music and ambience (autoload "MusicManager").
## - Picks a cue for the current place: main menu, each region, the cottage,
##   the caves, the finale. Changes crossfade over a few seconds, and a short
##   hysteresis delay keeps border-walking from restarting tracks.
## - Whispering Meadow uses adaptive layers: a base layer plus a daytime flute
##   layer and a night piano layer that cross over with the clock
##   (AudioStreamSynchronized).
## - Stingers (restoration moments) duck the music briefly; nothing stops abruptly.
## - Settings: continuous music, music with quiet pauses, or music off; separate
##   Music and Ambience volumes. Gentle mode leaves longer quiet pauses.
## - Ambience loops per region (wind, waves, creek, cave drips, night insects,
##   birds) plus rain. The game runs fine if files are missing: it warns once and
##   falls back to the original synthesized pad.
## Music files: rendered recordings in assets/music/rendered/ (Ogg, then WAV;
## made by tools/music/render_music.py with MuseScore) are preferred. When a
## piece has no rendered file, the SYNTHESIZED PLACEHOLDER rendered from MIDI by
## tools/music/compose.py is used, with one warning (see docs/MUSIC_PIPELINE.md).
## As of 0.4.0 no rendered files exist, so every piece uses its placeholder.

signal cue_changed(cue: String)

const MUSIC_DIR := "res://assets/music/placeholder"
const RENDERED_DIR := "res://assets/music/rendered"
const RENDERED_EXTENSIONS: PackedStringArray = ["ogg", "wav"]
const AMBIENCE_DIR := "res://assets/ambience/placeholder"
const CROSSFADE := 3.0
const AMBIENCE_FADE := 2.0
const HYSTERESIS := 2.0
const SILENT_DB := -60.0
const DUCK_DB := -9.0
const MEADOW := "meadow"
const MEADOW_LAYERS: PackedStringArray = ["meadow_base", "meadow_day", "meadow_night"]
const REGION_CUES := {
	"whispering_meadow": MEADOW, "firefly_grove": "grove", "crystal_creek": "creek",
	"moonlit_sanctuary": "sanctuary", "misty_pinewood": "pinewood", "sunpetal_coast": "coast",
	"sunpetal_isles": "coast", "frostbloom_highlands": "highlands",
}
const DAY_AMBIENCE := {
	"whispering_meadow": "meadow_birds", "firefly_grove": "meadow_birds", "crystal_creek": "creek",
	"moonlit_sanctuary": "night_insects", "misty_pinewood": "wind_pines", "sunpetal_coast": "waves",
	"sunpetal_isles": "waves", "frostbloom_highlands": "highland_wind",
}
const NIGHT_AMBIENCE := {
	"whispering_meadow": "night_insects", "firefly_grove": "night_insects", "crystal_creek": "creek",
	"moonlit_sanctuary": "night_insects", "misty_pinewood": "wind_pines", "sunpetal_coast": "waves",
	"sunpetal_isles": "waves", "frostbloom_highlands": "highland_wind",
}
const CUE_TITLES := {
	"lumeria_theme": "the Lumeria theme", MEADOW: "Whispering Meadow", "cottage": "the cottage",
	"grove": "Firefly Grove", "creek": "Crystal Creek", "pinewood": "Misty Pinewood", "coast": "Sunpetal Coast",
	"caves": "the Echo Caverns", "sanctuary": "the Moonlit Sanctuary", "highlands": "the Frostbloom Highlands",
	"finale": "the Festival of Light",
}

var current_cue: String = ""
## Where rendered music is looked for first (tests point it elsewhere).
var rendered_dir: String = RENDERED_DIR
## How many times the "using placeholders" warning was given (at most once).
var placeholder_warnings: int = 0
var current_ambience: String = ""
var fallback_active: bool = false
var night: float = 0.0
var _pending_cue: String = ""
var _pending_t: float = 0.0
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _amb_players: Array[AudioStreamPlayer] = []
var _amb_active: int = 0
var _rain_player: AudioStreamPlayer
var _stinger_player: AudioStreamPlayer
var _meadow_sync: AudioStreamSynchronized
var _warned: Dictionary = {}
var _pause_left: float = -1.0
var _duck_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = AudioManager.MUSIC_BUS
		p.volume_db = SILENT_DB
		p.finished.connect(_on_music_finished.bind(p))
		add_child(p)
		_players.append(p)
		var a := AudioStreamPlayer.new()
		a.bus = AudioManager.AMBIENCE_BUS
		a.volume_db = SILENT_DB
		add_child(a)
		_amb_players.append(a)
	_rain_player = AudioStreamPlayer.new()
	_rain_player.bus = AudioManager.AMBIENCE_BUS
	_rain_player.volume_db = SILENT_DB
	add_child(_rain_player)
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.bus = AudioManager.MUSIC_BUS
	add_child(_stinger_player)
	GameSettings.settings_changed.connect(_on_settings_changed)
	AudioManager.sound_played.connect(func(s: StringName) -> void:
		if s == &"restore":
			stinger())


func _exit_tree() -> void:
	for p in _players + _amb_players + [_rain_player, _stinger_player]:
		p.stop()
		p.stream = null


# --- Streams --------------------------------------------------------------------------

## Loads a placeholder loop (cached by Godot). Returns null, and warns once, if
## the file is missing, so the game keeps running without it.
func load_loop(dir: String, file_name: String, loop: bool = true) -> AudioStream:
	var path := "%s/%s.wav" % [dir, file_name]
	if not ResourceLoader.exists(path):
		if not _warned.has(path):
			_warned[path] = true
			push_warning("MusicManager: %s is missing; continuing without it." % path)
		return null
	var stream := load(path) as AudioStream
	var wav := stream as AudioStreamWAV
	if wav != null:
		var copy := wav.duplicate() as AudioStreamWAV
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		copy.loop_begin = 0
		copy.loop_end = int(wav.get_length() * wav.mix_rate)
		return copy
	return stream


## The file used for a music piece: a rendered recording if there is one,
## otherwise the synthesized placeholder.
func music_path(file_name: String) -> String:
	for ext in RENDERED_EXTENSIONS:
		var path := "%s/%s.%s" % [rendered_dir, file_name, ext]
		if ResourceLoader.exists(path):
			return path
	return "%s/%s.wav" % [MUSIC_DIR, file_name]


func is_rendered(file_name: String) -> bool:
	return not music_path(file_name).begins_with(MUSIC_DIR)


## Loads a music piece, preferring the rendered recording.
func load_music(file_name: String, loop: bool = true) -> AudioStream:
	var path := music_path(file_name)
	if not path.begins_with(MUSIC_DIR):
		return _load_stream(path, loop)
	if placeholder_warnings == 0:
		placeholder_warnings += 1
		push_warning("MusicManager: no rendered recording in %s; using the synthesized placeholders (see docs/MUSIC_PIPELINE.md)." % rendered_dir)
	return load_loop(MUSIC_DIR, file_name, loop)


func _load_stream(path: String, loop: bool) -> AudioStream:
	var stream := load(path) as AudioStream
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		var copy := ogg.duplicate() as AudioStreamOggVorbis
		copy.loop = loop
		return copy
	var wav := stream as AudioStreamWAV
	if wav != null:
		var wav_copy := wav.duplicate() as AudioStreamWAV
		wav_copy.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		wav_copy.loop_begin = 0
		wav_copy.loop_end = int(wav.get_length() * wav.mix_rate)
		return wav_copy
	return stream


func _loops() -> bool:
	return GameSettings.music_mode == 0


func music_stream(cue: String) -> AudioStream:
	if cue == MEADOW:
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = MEADOW_LAYERS.size()
		for i in MEADOW_LAYERS.size():
			var s := load_music(MEADOW_LAYERS[i], _loops())
			if s == null:
				return null
			sync.set_sync_stream(i, s)
		_meadow_sync = sync
		_apply_meadow_layers()
		return sync
	return load_music(cue, _loops())


func _apply_meadow_layers() -> void:
	if _meadow_sync == null:
		return
	_meadow_sync.set_sync_stream_volume(0, 0.0)
	_meadow_sync.set_sync_stream_volume(1, linear_to_db(maxf(0.001, 1.0 - night)))
	_meadow_sync.set_sync_stream_volume(2, linear_to_db(maxf(0.001, night)))


# --- Cue selection ------------------------------------------------------------------------

static func cue_for(region: String, sublevel: String, finale: bool) -> String:
	if finale:
		return "finale"
	if sublevel.begins_with("cave_"):
		return "caves"
	if not sublevel.is_empty():
		return "cottage"
	return String(REGION_CUES.get(region, ""))


static func ambience_for(region: String, sublevel: String, is_night: bool) -> String:
	if sublevel.begins_with("cave_"):
		return "cave_drips"
	if not sublevel.is_empty():
		return ""
	return String((NIGHT_AMBIENCE if is_night else DAY_AMBIENCE).get(region, ""))


## Called by the overworld a few times a second.
func set_context(region: String, sublevel: String, night_amount: float, finale: bool, raining: bool) -> void:
	night = night_amount
	var cue := cue_for(region, sublevel, finale)
	if not cue.is_empty():
		request_cue(cue, finale)
	request_ambience(ambience_for(region, sublevel, night_amount > 0.5))
	set_rain(raining and sublevel.is_empty() and GameSettings.weather_effects)


## Asks for a cue. The same cue never restarts; a new one waits HYSTERESIS
## seconds (unless `immediate`) so walking along a border doesn't flip tracks.
func request_cue(cue: String, immediate: bool = false) -> void:
	if cue == current_cue:
		_pending_cue = ""
		return
	if immediate:
		_switch_to(cue)
		return
	if cue != _pending_cue:
		_pending_cue = cue
		_pending_t = 0.0


func _process(delta: float) -> void:
	if not _pending_cue.is_empty():
		_pending_t += delta
		if _pending_t >= HYSTERESIS:
			_switch_to(_pending_cue)
	if current_cue == MEADOW:
		_apply_meadow_layers()
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0 and GameSettings.music_mode == 1:
			var p := _players[_active]
			if p.stream != null:
				p.play()


func _switch_to(cue: String) -> void:
	_pending_cue = ""
	if cue == current_cue:
		return
	current_cue = cue
	_pause_left = -1.0
	cue_changed.emit(cue)
	var old := _players[_active]
	_active = 1 - _active
	var fresh := _players[_active]
	_fade_out(old, CROSSFADE)
	if GameSettings.music_mode == 2:
		return
	var stream := music_stream(cue)
	if stream == null:
		if not fallback_active:
			fallback_active = true
			AudioManager.start_music()
		return
	if fallback_active:
		fallback_active = false
		AudioManager.stop_music()
	fresh.stream = stream
	fresh.volume_db = SILENT_DB
	fresh.play()
	create_tween().tween_property(fresh, "volume_db", 0.0, CROSSFADE)


func _fade_out(p: AudioStreamPlayer, seconds: float) -> void:
	if not p.playing:
		p.stop()
		p.stream = null
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", SILENT_DB, seconds)
	t.tween_callback(func() -> void:
		if p != _players[_active] or p.volume_db <= SILENT_DB + 1.0:
			p.stop()
			p.stream = null)


## "Music with quiet pauses": a gentle silence before the piece plays again.
func _on_music_finished(p: AudioStreamPlayer) -> void:
	if p != _players[_active] or GameSettings.music_mode != 1:
		return
	var gentle := SessionState.get_config().mode_id == &"gentle"
	_pause_left = _rng.randf_range(40.0, 70.0) if gentle else _rng.randf_range(20.0, 45.0)


func request_ambience(amb: String) -> void:
	if amb == current_ambience:
		return
	current_ambience = amb
	var old := _amb_players[_amb_active]
	_amb_active = 1 - _amb_active
	var fresh := _amb_players[_amb_active]
	var t := create_tween()
	t.tween_property(old, "volume_db", SILENT_DB, AMBIENCE_FADE)
	t.tween_callback(func() -> void:
		if old != _amb_players[_amb_active]:
			old.stop()
			old.stream = null)
	if amb.is_empty():
		return
	var stream := load_loop(AMBIENCE_DIR, amb)
	if stream == null:
		return
	fresh.stream = stream
	fresh.volume_db = SILENT_DB
	fresh.play()
	create_tween().tween_property(fresh, "volume_db", 0.0, AMBIENCE_FADE)


func set_rain(on: bool) -> void:
	if on == _rain_player.playing:
		return
	if on:
		var stream := load_loop(AMBIENCE_DIR, "rain")
		if stream == null:
			return
		_rain_player.stream = stream
		_rain_player.volume_db = SILENT_DB
		_rain_player.play()
		create_tween().tween_property(_rain_player, "volume_db", -3.0, AMBIENCE_FADE)
	else:
		var t := create_tween()
		t.tween_property(_rain_player, "volume_db", SILENT_DB, AMBIENCE_FADE)
		t.tween_callback(_rain_player.stop)


## A short phrase for special moments; the music ducks underneath and returns.
func stinger(name_: String = "stinger_restore") -> void:
	if GameSettings.music_mode == 2:
		return
	var stream := load_music(name_, false)
	if stream == null:
		return
	_stinger_player.stream = stream
	_stinger_player.play()
	var p := _players[_active]
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(p, "volume_db", DUCK_DB, 0.6)
	_duck_tween.tween_interval(maxf(1.0, stream.get_length() - 2.5))
	_duck_tween.tween_property(p, "volume_db", 0.0, 2.0)


func stop_all() -> void:
	current_cue = ""
	current_ambience = ""
	_pending_cue = ""
	for p in _players + _amb_players:
		_fade_out(p, 1.0)
	set_rain(false)


## Number of music players currently producing sound (tests: never more than
## one after a crossfade has finished).
func playing_music_players() -> int:
	var n := 0
	for p in _players:
		if p.playing:
			n += 1
	return n


func _on_settings_changed() -> void:
	if GameSettings.music_mode == 2:
		for p in _players:
			_fade_out(p, 1.0)
		var keep := current_cue
		current_cue = ""
		_pending_cue = keep
		_pending_t = -INF
		return
	if _players[_active].stream == null and not current_cue.is_empty():
		var cue := current_cue
		current_cue = ""
		_switch_to(cue)
	elif not _pending_cue.is_empty() and _pending_t < 0.0:
		_pending_t = HYSTERESIS
