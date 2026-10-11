class_name BoatDock
extends Interactable
## An old wooden dock. With a Small Boat in the bag, E sails to the paired dock
## (a short fade; the sea of Lumeria is always calm). Without one, the dock
## explains what is needed, so the isles are clearly reachable "later".

const SAIL_OFFSET := 70.0

var dock_id: String = ""
var dest_id: String = ""
var place_name: String = ""
var dest_name: String = ""
## Direction of the water from the dock: 1 = south (mainland), -1 = north (isles).
var water_dir: float = 1.0
var _t: float = 0.0


func setup(data: Dictionary, dest: Dictionary) -> void:
	dock_id = String(data["id"])
	interactable_id = dock_id
	position = data["pos"]
	dest_id = String(data.get("dest", ""))
	place_name = String(data.get("name", "the dock"))
	dest_name = String(dest.get("name", "the other shore"))
	water_dir = float(data.get("water", 1.0))
	reach_bonus = 26.0


static func has_boat() -> bool:
	return GameState.inventory.count("small_boat") > 0 or GameState.storage.count("small_boat") > 0


func get_prompt() -> String:
	return L.t("Sail to %s") % L.t(dest_name) if GameState.inventory.count("small_boat") > 0 else L.t("Look at the old dock")


## Where the player stands after arriving here.
func arrival_point() -> Vector2:
	return global_position + Vector2(0, -SAIL_OFFSET * water_dir)


func _process(delta: float) -> void:
	super(delta)
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	var dir := water_dir
	for i in 5:
		var y := (10.0 + i * 26.0) * dir
		draw_rect(Rect2(-34, y - 11, 68, 22), Palette.BARK if i % 2 == 0 else Palette.BARK.lightened(0.08))
		draw_line(Vector2(-34, y + 11), Vector2(34, y + 11), Palette.BARK_DARK, 2.0)
	for x: float in [-38.0, 38.0]:
		draw_rect(Rect2(x - 4, 0 if dir > 0 else -140, 8, 140), Palette.BARK_DARK)
	if GameState.inventory.count("small_boat") > 0:
		var bob := sin(_t * 1.4) * 2.0
		var c := Vector2(66, 90 * dir + bob)
		var hull := PackedVector2Array([c + Vector2(-34, -8), c + Vector2(34, -8), c + Vector2(24, 10), c + Vector2(-24, 10)])
		draw_colored_polygon(hull, Color("#cdbfa8"))
		draw_line(c + Vector2(-34, -8), c + Vector2(34, -8), Palette.TURQUOISE, 3.0)
		draw_line(c + Vector2(0, -8), c + Vector2(0, -44), Palette.BARK_DARK, 3.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(2, -42), c + Vector2(24, -14), c + Vector2(2, -14)]), Palette.CREAM)
	draw_interaction_cues(30.0, Vector2(0, 0))
