extends Node
## Audio playback (autoload "AudioManager").
## Creates the Music, Ambience, SFX and UI buses, synthesizes all sound effects
## once, and applies the volume settings. Music and ambience loops are played
## by MusicManager. The game is fully playable with audio muted or unavailable;
## important sounds can also be shown as captions (Settings).

signal sound_played(sound: StringName)

const MUSIC_BUS := &"Music"
const AMBIENCE_BUS := &"Ambience"
const SFX_BUS := &"SFX"
const UI_BUS := &"UI"
const UI_SOUNDS: Array[StringName] = [&"ui_click", &"ui_hover"]
const SFX_VOICES := 8
const MIN_LINEAR_VOLUME := 0.001
## Every play varies the pitch by up to +-4%, so repeats never sound mechanical.
const PITCH_VARIATION := 0.04
## Footsteps are quiet: this much below the other sound effects.
const FOOTSTEP_DB := -6.0

var _sounds: Dictionary = {}
var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_player: AudioStreamPlayer
var _next_voice: int = 0
var _footstep_variant: int = 1
## The last pitch used (for tests).
var last_pitch: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(AMBIENCE_BUS)
	_ensure_bus(SFX_BUS)
	_ensure_bus(UI_BUS)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = UI_BUS
	add_child(_ui_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_players.append(p)
	var raw := SoundSynth.build_library()
	for key: StringName in raw:
		_sounds[key] = SoundSynth.to_wav(raw[key], SoundSynth.SFX_RATE, false)
	apply_volumes()
	GameSettings.settings_changed.connect(apply_volumes)


func has_sound(sound: StringName) -> bool:
	return _sounds.has(sound)


func play(sound: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _sounds.get(sound)
	if stream == null:
		push_warning("AudioManager: unknown sound '%s'." % sound)
		return
	var player := _ui_player
	if not UI_SOUNDS.has(sound):
		player = _sfx_players[_next_voice]
		_next_voice = (_next_voice + 1) % _sfx_players.size()
	sound_played.emit(sound)
	player.stream = stream
	last_pitch = varied_pitch(pitch, randf())
	player.pitch_scale = last_pitch
	player.volume_db = volume_db
	player.play()


## `unit` in 0..1 maps to pitch * (1 - 4%) .. pitch * (1 + 4%).
static func varied_pitch(pitch: float, unit: float) -> float:
	return pitch * (1.0 + PITCH_VARIATION * (clampf(unit, 0.0, 1.0) * 2.0 - 1.0))


## A quiet footstep for a surface (alternating between two variations).
func play_footstep(surface: String) -> void:
	_footstep_variant = 3 - _footstep_variant
	var sound := StringName("step_%s_%d" % [surface, _footstep_variant])
	if not _sounds.has(sound):
		sound = StringName("step_grass_%d" % _footstep_variant)
	play(sound, 1.0, FOOTSTEP_DB)


## The V1 synthesized ambient pad. MusicManager uses it only as a fallback when
## the music files are missing.
func start_music() -> void:
	if _music_player.playing:
		return
	if _music_player.stream == null:
		_music_player.stream = SoundSynth.build_ambient_pad()
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


## Release the looping stream on shutdown so no playback object outlives the engine.
func _exit_tree() -> void:
	_music_player.stop()
	_music_player.stream = null
	for p in _sfx_players:
		p.stop()
		p.stream = null


func apply_volumes() -> void:
	_set_bus_volume(&"Master", GameSettings.master_volume)
	_set_bus_volume(MUSIC_BUS, GameSettings.music_volume if GameSettings.music_mode != 2 else 0.0)
	_set_bus_volume(AMBIENCE_BUS, GameSettings.ambience_volume)
	_set_bus_volume(SFX_BUS, GameSettings.sfx_volume)
	_set_bus_volume(UI_BUS, GameSettings.ui_volume)


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= MIN_LINEAR_VOLUME)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, MIN_LINEAR_VOLUME)))


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")
