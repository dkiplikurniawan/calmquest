class_name Workbench
extends Interactable
## A crafting station. Standing near it raises the crafting tier for the
## inventory/crafting panel (tier 1 = simple workbench, tier 2 = restored
## cottage workbench). Pressing E opens crafting directly.

const NEAR_DISTANCE := 220.0

var tier: int = 1


func _ready() -> void:
	reach_bonus = 20.0
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(84, 22)
	col.shape = shape
	col.position = Vector2(0, -10)
	body.add_child(col)
	add_child(body)
	add_to_group(&"crafting_stations")


func get_prompt() -> String:
	return "Craft at the workbench" if tier < 2 else "Craft at the cottage workbench"


func _draw() -> void:
	BiomeDecorArt.shadow(self, 50.0)
	for leg: float in [-36.0, 32.0]:
		draw_rect(Rect2(leg, -30, 6, 30), Palette.BARK_DARK)
	draw_rect(Rect2(-44, -40, 88, 14), Palette.BARK)
	draw_line(Vector2(-44, -40), Vector2(44, -40), Palette.with_alpha(Palette.IVORY, 0.5), 2.0)
	# Tools resting on top: a shape cue for "crafting".
	draw_line(Vector2(-26, -46), Vector2(-6, -52), Palette.STONE_DARK, 4.0, true)
	draw_rect(Rect2(6, -52, 22, 10), Palette.PATH_EDGE)
	if tier >= 2:
		draw_circle(Vector2(34, -50), 5.0, Palette.GOLD)
	draw_interaction_cues(34.0, Vector2(0, -20))
