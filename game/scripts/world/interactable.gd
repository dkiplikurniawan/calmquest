class_name Interactable
extends Node2D
## Base class for anything the player can interact with using E.
## The Player finds the nearest interactable within its reach radius; the world
## script listens to `interacted` and decides what happens (collection, restoration...).

signal interacted(target: Interactable)

const GROUP := &"interactables"
const TARGET_RING_COLOR := Color("#fff3c4")

## Stable identifier (used to prevent double counting across scene reloads).
@export var interactable_id: String = ""
## Extra reach for large objects, added on top of the mode's interaction radius.
@export var reach_bonus: float = 0.0

var is_targeted: bool = false
var show_marker: bool = false
var animation_intensity: float = 1.0
var _ring_time: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func can_interact() -> bool:
	return visible and is_inside_tree()


## Short verb phrase shown in the HUD prompt, e.g. "Collect light".
func get_prompt() -> String:
	return "Interact"


func get_interaction_point() -> Vector2:
	return global_position


func interact() -> void:
	if can_interact():
		interacted.emit(self)


func set_targeted(value: bool) -> void:
	if is_targeted == value:
		return
	is_targeted = value
	queue_redraw()


func set_marker_visible(value: bool) -> void:
	if show_marker == value:
		return
	show_marker = value
	queue_redraw()


## Draws the selection ring (shape cue) and the optional Gentle-mode marker.
func draw_interaction_cues(radius: float, center: Vector2 = Vector2.ZERO) -> void:
	if is_targeted:
		var pulse := 0.5 + 0.5 * sin(_ring_time * 3.0)
		draw_arc(center, radius + 4.0 + pulse * 3.0, 0.0, TAU, 40, Palette.with_alpha(TARGET_RING_COLOR, 0.95), 3.0, true)
		draw_arc(center, radius + 9.0 + pulse * 3.0, 0.0, TAU, 40, Palette.with_alpha(Palette.GOLD_DEEP, 0.55), 2.0, true)
	elif show_marker:
		draw_arc(center, radius + 6.0, 0.0, TAU, 32, Palette.with_alpha(Palette.CREAM, 0.6), 2.0, true)


func _process(delta: float) -> void:
	_ring_time += delta
	if is_targeted:
		queue_redraw()
