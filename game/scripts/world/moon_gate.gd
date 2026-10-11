class_name MoonGate
extends Interactable
## A soft veil of sleeping moonlight across the entrance of Moonlit Sanctuary.
## It blocks the way (gently, no damage) until Crystal Creek is awakened, then
## dissolves. Interacting before that only explains what wakes it.

const LOCKED_HINT := "The moonlight here is asleep. Perhaps the crystals of Crystal Creek can wake it."

var size: Vector2 = Vector2(1536, 64)
var is_open: bool = false
var _t: float = 0.0
var _fade: float = 1.0
var _body: StaticBody2D


func _ready() -> void:
	reach_bonus = 60.0
	_body = StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	_body.add_child(col)
	add_child(_body)


func can_interact() -> bool:
	return not is_open and super.can_interact()


func get_prompt() -> String:
	return "Touch the moonlit veil"


func open_gate(instant: bool = false) -> void:
	if is_open:
		return
	is_open = true
	set_targeted(false)
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	_body.get_child(0).set_deferred("disabled", true)
	if instant:
		_fade = 0.0
		queue_redraw()
		return
	var tween := create_tween()
	tween.tween_property(self, "_fade", 0.0, 2.5 * maxf(GameSettings.motion_scale(), 0.5))


func _process(delta: float) -> void:
	super(delta)
	_t += delta * GameSettings.motion_scale()
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.01:
		return
	var half := size / 2.0
	var steps := int(size.x / 48.0)
	for i in steps + 1:
		var x := -half.x + i * 48.0
		var wave := sin(_t * 0.9 + i * 0.6) * 10.0
		var a := (0.28 + 0.12 * sin(_t * 1.3 + i)) * _fade
		draw_circle(Vector2(x, wave), 40.0, Palette.with_alpha(Palette.LAVENDER, a))
		draw_circle(Vector2(x + 20, wave - 26), 22.0, Palette.with_alpha(Color("#e7defa"), a * 0.8))
	for k in 5:
		var x := -half.x + fposmod(_t * 40.0 + k * 300.0, size.x)
		draw_circle(Vector2(x, -18), 4.0, Palette.with_alpha(Palette.IVORY, 0.8 * _fade))
	if not is_open:
		draw_interaction_cues(30.0, Vector2.ZERO)
