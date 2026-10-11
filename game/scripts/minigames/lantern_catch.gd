class_name LanternCatch
extends Node
## Lantern Catch mini-game controller. Runs inside Whispering Meadow at night,
## reusing the same player controls, interaction system and HUD.
##
## No timer, no lives, no failure state: the night ends when all required
## lanterns are caught or whenever the player chooses to end it at the shrine.

signal lantern_interacted(lantern: Lantern)
signal progress_changed(caught: int, target: int, bonus_caught: int)
signal night_completed
signal night_ended(completed: bool)

const LANTERN_SCENE := preload("res://game/scenes/minigames/lantern.tscn")
const ANCHOR_JITTER := Vector2(70, 50)

var active: bool = false
var target_count: int = 0
var caught: int = 0
var bonus_caught: int = 0
var night_index: int = 0
## Parent node for spawned lanterns (the y-sorted entity layer).
var spawn_parent: Node2D = null
## World position the lantern anchor offsets are relative to (the shrine).
var anchor_origin: Vector2 = Vector2.ZERO

var _lanterns: Array[Lantern] = []


func start_night(config: ModeConfig, motion_scale: float) -> bool:
	if active or spawn_parent == null:
		return false
	active = true
	night_index += 1
	caught = 0
	bonus_caught = 0
	target_count = config.lantern_count
	var total := target_count + config.bonus_lantern_count
	var anchors: Array = []
	for offset in MeadowLayout.LANTERN_OFFSETS:
		anchors.append(anchor_origin + offset)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + night_index
	_shuffle(anchors, rng)
	for i in total:
		var lantern: Lantern = LANTERN_SCENE.instantiate()
		lantern.interactable_id = "lantern_n%d_%02d" % [night_index, i]
		var wrap := i / anchors.size()
		var anchor: Vector2 = anchors[i % anchors.size()] + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * ANCHOR_JITTER * (0.4 + wrap)
		lantern.setup(anchor, i >= target_count, rng.randi())
		spawn_parent.add_child(lantern)
		lantern.apply_config(config, motion_scale, true)
		lantern.interacted.connect(_on_lantern_interacted)
		_lanterns.append(lantern)
	progress_changed.emit(caught, target_count, bonus_caught)
	return true


## Called by the world after SessionState accepted the catch.
func register_catch(lantern: Lantern) -> void:
	if not active or lantern.collected:
		return
	lantern.mark_collected()
	_lanterns.erase(lantern)
	if lantern.is_bonus:
		bonus_caught += 1
	else:
		caught += 1
	progress_changed.emit(caught, target_count, bonus_caught)
	if caught >= target_count:
		night_completed.emit()
		end_night(true)


func end_night(completed: bool) -> void:
	if not active:
		return
	active = false
	for lantern in _lanterns:
		if is_instance_valid(lantern) and not lantern.collected:
			lantern.dismiss()
	_lanterns.clear()
	night_ended.emit(completed)


## Applies a mode change to lanterns already in the air (no respawn).
func apply_config(config: ModeConfig, motion_scale: float) -> void:
	for lantern in _lanterns:
		if is_instance_valid(lantern):
			lantern.apply_config(config, motion_scale)


func set_night_amount(amount: float) -> void:
	for lantern in _lanterns:
		if is_instance_valid(lantern):
			lantern.set_night_amount(amount)


func get_remaining() -> Array[Lantern]:
	var result: Array[Lantern] = []
	for lantern in _lanterns:
		if is_instance_valid(lantern) and not lantern.collected:
			result.append(lantern)
	return result


func _on_lantern_interacted(target: Interactable) -> void:
	var lantern := target as Lantern
	if lantern != null:
		lantern_interacted.emit(lantern)


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
