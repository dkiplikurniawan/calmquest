class_name ResetLever
extends Interactable
## A reset lever for any puzzle node that has `is_solved` and `reset_puzzle()`.
## Restores the starting arrangement. Never needed, always available.

var puzzle: Node
var prompt: String = "Pull the reset lever"
var _pull: float = 0.0


func can_interact() -> bool:
	return puzzle != null and not bool(puzzle.get("is_solved")) and super.can_interact()


func get_prompt() -> String:
	return prompt


func interact() -> void:
	if can_interact():
		_pull = 1.0
		puzzle.call("reset_puzzle")
		interacted.emit(self)


func _process(delta: float) -> void:
	super(delta)
	if _pull > 0.0:
		_pull = maxf(0.0, _pull - delta * 2.0)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-14, -8, 28, 10), Palette.STONE_DARK)
	var angle := -0.6 + _pull * 1.2
	var tip := Vector2(0, -6) + Vector2(0, -34).rotated(angle)
	draw_line(Vector2(0, -6), tip, Palette.BARK_DARK, 5.0, true)
	draw_circle(tip, 7.0, Palette.GOLD)
	draw_interaction_cues(20.0, Vector2(0, -14))
