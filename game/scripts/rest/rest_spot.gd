class_name RestSpot
extends Interactable
## A quiet place to sit (0.4.0): a bench, a log, a stump, a flat stone, a
## piece of driftwood or a crystal pool. "[E] Sit and rest". It has no
## collision, so it never blocks a path. The seat is drawn just behind the
## player, who sits on it while resting (see RestController).

const GROUP_NAME := &"rest_spots"
const SEAT_OFFSET := Vector2(0, 3)

var spot_id: String = ""
var kind: String = "bench"
## Direction of the view the camera drifts toward while resting.
var view_dir: Vector2 = Vector2.UP
var _t: float = 0.0


func setup(data: Dictionary) -> void:
	spot_id = String(data["id"])
	interactable_id = spot_id
	kind = String(data.get("kind", "bench"))
	var v: Array = data.get("view", [0, -1])
	view_dir = Vector2(float(v[0]), float(v[1])).normalized()
	reach_bonus = 18.0


func _ready() -> void:
	add_to_group(GROUP_NAME)
	interacted.connect(func(_t2: Interactable) -> void: EventBus.rest_requested.emit(self))


func get_prompt() -> String:
	return "Sit and rest"


func display_name() -> String:
	return RestSpots.display_name(spot_id)


## Where the player sits (just in front of the seat, so the player is drawn on top).
func seat_point() -> Vector2:
	return global_position + SEAT_OFFSET


## Where Lumi curls up, beside the seat.
func lumi_point() -> Vector2:
	return global_position + Vector2(40, 8)


func get_interaction_point() -> Vector2:
	return global_position + Vector2(0, -8)


func _process(delta: float) -> void:
	super(delta)
	if kind == "crystal_pool" and ViewCull.near(global_position):
		_t += delta * GameSettings.motion_scale()
		queue_redraw()


func _draw() -> void:
	draw_interaction_cues(30.0, Vector2(0, -8))
	BiomeDecorArt.shadow(self, 26.0)
	match kind:
		"bench":
			_bench(Palette.BARK, Palette.BARK_DARK)
		"moon_bench":
			_bench(Color("#cfd3e6"), Color("#8f93b0"))
		"log":
			_log()
		"stump":
			draw_rect(Rect2(Vector2(-20, -14), Vector2(40, 14)), Palette.BARK)
			draw_set_transform(Vector2(0, -14), 0.0, Vector2(1.0, 0.4))
			draw_circle(Vector2.ZERO, 20.0, Color("#d9b98a"))
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 20, Color("#b8925f"), 2.0, true)
			draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 14, Color("#b8925f"), 2.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"stone":
			_flat_stone(Palette.STONE, Palette.STONE_DARK)
		"hill":
			draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, 46.0, Color("#8cc49a"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_flat_stone(Palette.STONE, Palette.STONE_DARK)
			for x in [-34.0, 30.0]:
				draw_circle(Vector2(x, -6), 3.0, Color("#ffd166"))
		"driftwood":
			var pts := PackedVector2Array([Vector2(-34, -4), Vector2(-12, -10), Vector2(14, -9), Vector2(36, -3)])
			draw_polyline(pts, Color("#d8cbb3"), 12.0, true)
			draw_polyline(pts, Color("#b8a88c"), 2.0, true)
			draw_line(Vector2(14, -9), Vector2(22, -20), Color("#d8cbb3"), 5.0, true)
		"crystal_pool":
			draw_set_transform(Vector2(-6, 14), 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, 38.0, Color("#2c4a6e"))
			draw_circle(Vector2.ZERO, 30.0, Color("#3f6f9c"))
			var shimmer := 0.5 + 0.5 * sin(_t * 1.2)
			draw_circle(Vector2(-8, -6), 10.0, Palette.with_alpha(Color("#a7d8f0"), 0.25 + 0.2 * shimmer))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for c: Array in [[Vector2(-40, 4), 16.0], [Vector2(30, 6), 12.0], [Vector2(-28, 10), 9.0]]:
				var p: Vector2 = c[0]
				var h := float(c[1])
				draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(0, -h), p + Vector2(4, 0)]), Color("#b9a8ff"))
				draw_line(p + Vector2(0, -h), p + Vector2(1, -2), Color("#e6dcff"), 1.5, true)
			_flat_stone(Color("#8a8fa8"), Color("#6a6f88"))
		_:
			_bench(Palette.BARK, Palette.BARK_DARK)


func _bench(wood: Color, dark: Color) -> void:
	# Backrest and legs, then the seat plank.
	draw_rect(Rect2(Vector2(-30, -30), Vector2(60, 7)), wood)
	draw_rect(Rect2(Vector2(-30, -30), Vector2(60, 7)), dark, false, 1.5)
	for x in [-24.0, 20.0]:
		draw_rect(Rect2(Vector2(x, -24), Vector2(4, 24)), dark)
	draw_rect(Rect2(Vector2(-32, -12), Vector2(64, 7)), wood)
	draw_rect(Rect2(Vector2(-32, -12), Vector2(64, 7)), dark, false, 1.5)


func _log() -> void:
	draw_rect(Rect2(Vector2(-34, -16), Vector2(68, 16)), Palette.BARK)
	draw_line(Vector2(-30, -10), Vector2(28, -10), Palette.BARK_DARK, 1.5)
	draw_set_transform(Vector2(34, -8), 0.0, Vector2(0.45, 1.0))
	draw_circle(Vector2.ZERO, 8.0, Color("#d9b98a"))
	draw_arc(Vector2.ZERO, 4.0, 0.0, TAU, 12, Color("#b8925f"), 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(-14, -18), 3.0, Color("#7fb98a"))


func _flat_stone(fill: Color, edge: Color) -> void:
	draw_set_transform(Vector2(0, -6), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 24.0, edge)
	draw_circle(Vector2(0, -3), 22.0, fill)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
