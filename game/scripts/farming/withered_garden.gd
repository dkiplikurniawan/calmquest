class_name WitheredGarden
extends Node2D
## A forgotten garden ringed by old hedges. Its only gap is blocked by a
## withered plant. Watering it with the watering can revives it into a
## flowering arch that lets you through, and the old chest inside holds seeds.
## Shows that the watering can opens paths, not only farms.
## State: GameState.systems["withered"][id] = {"revived": bool, "opened": bool}.

signal revived(garden: WitheredGarden)
signal chest_opened(garden: WitheredGarden, items: Array)

const STATE_KEY := "withered"

var garden_id: String = ""
## Hedge segments in world coordinates: [[x1, y1, x2, y2], ...].
var hedges: Array = []
var gap: Vector2 = Vector2.ZERO
var chest_pos: Vector2 = Vector2.ZERO
var rewards: Array = []
var plant: WitheredPlant
var chest: GardenChest
var _bloom: float = 0.0


static func state_of(id: String) -> Dictionary:
	var all := GameState.system_state(STATE_KEY)
	if not all.has(id):
		all[id] = {"revived": false, "opened": false}
	return all[id]


static func is_revived(id: String) -> bool:
	return GameState.system_state(STATE_KEY).has(id) and bool(state_of(id)["revived"])


func setup(data: Dictionary) -> void:
	garden_id = String(data["id"])
	position = data["pos"]
	hedges = data.get("hedges", [])
	var g: Array = data.get("gap", [0, 0])
	gap = Vector2(float(g[0]), float(g[1]))
	var c: Array = data.get("chest", [0, 0])
	chest_pos = Vector2(float(c[0]), float(c[1]))
	rewards = data.get("rewards", [])
	_bloom = 1.0 if is_revived(garden_id) else 0.0
	for seg: Array in hedges:
		var a := Vector2(float(seg[0]), float(seg[1])) - position
		var b := Vector2(float(seg[2]), float(seg[3])) - position
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(a.distance_to(b) + 30.0, 34.0)
		col.shape = rect
		col.position = (a + b) / 2.0
		col.rotation = (b - a).angle()
		body.add_child(col)
		add_child(body)
	plant = WitheredPlant.new()
	plant.garden = self
	plant.interactable_id = garden_id + "_plant"
	plant.position = gap - position
	add_child(plant)
	chest = GardenChest.new()
	chest.garden = self
	chest.interactable_id = garden_id + "_chest"
	chest.position = chest_pos - position
	add_child(chest)


## Waters the withered plant. Returns false if already revived or no can.
func revive(instant: bool = false) -> bool:
	if is_revived(garden_id) or GameState.inventory.count("watering_can") == 0:
		return false
	state_of(garden_id)["revived"] = true
	GameState.set_flag("withered_revived:" + garden_id)
	plant.set_open(true)
	if instant:
		_bloom = 1.0
	else:
		create_tween().tween_property(self, "_bloom", 1.0, 1.6 * maxf(GameSettings.motion_scale(), 0.5))
	revived.emit(self)
	return true


func open_chest() -> Array:
	var s := state_of(garden_id)
	if bool(s["opened"]) or not bool(s["revived"]):
		return []
	s["opened"] = true
	GameState.set_flag("garden_chest_opened:" + garden_id)
	for r: Dictionary in rewards:
		var left := GameState.give_item(String(r["item"]), int(r.get("qty", 1)))
		if left > 0:
			GameState.storage.add(String(r["item"]), left)
	chest_opened.emit(self, rewards)
	return rewards


func _draw() -> void:
	for seg: Array in hedges:
		var a := Vector2(float(seg[0]), float(seg[1])) - position
		var b := Vector2(float(seg[2]), float(seg[3])) - position
		var n := maxi(2, int(a.distance_to(b) / 28.0))
		for i in n + 1:
			var p := a.lerp(b, float(i) / float(n))
			draw_circle(p + Vector2(0, -12), 19.0, Color("#4f7d5f"))
			draw_circle(p + Vector2(-6, -20), 11.0, Color("#5e8c6a"))
			if _bloom > 0.0 and i % 2 == 0:
				draw_circle(p + Vector2(5, -22), 4.0 * _bloom, Color("#f7b2c4"))


## The withered plant in the hedge gap; it blocks the way until watered.
class WitheredPlant extends Interactable:
	var garden: WitheredGarden
	var _body: StaticBody2D
	var _t: float = 0.0

	func _ready() -> void:
		reach_bonus = 26.0
		_body = StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 40.0
		col.shape = shape
		col.position = Vector2(0, -10)
		_body.add_child(col)
		add_child(_body)
		set_open(WitheredGarden.is_revived(garden.garden_id))

	func set_open(open: bool) -> void:
		for c in _body.get_children():
			(c as CollisionShape2D).set_deferred("disabled", open)
		queue_redraw()

	func can_interact() -> bool:
		return not WitheredGarden.is_revived(garden.garden_id) and super.can_interact()

	func get_prompt() -> String:
		return "Water the withered plant" if GameState.inventory.count("watering_can") > 0 else "A withered plant blocks the way"

	func _process(delta: float) -> void:
		super(delta)
		_t += delta * GameSettings.motion_scale()
		if ViewCull.near(global_position):
			queue_redraw()

	func _draw() -> void:
		if WitheredGarden.is_revived(garden.garden_id):
			# A flowering arch over the open gap.
			draw_arc(Vector2(0, -20), 44.0, PI, TAU, 24, Color("#5e8c6a"), 8.0, true)
			for i in 7:
				var a := PI + PI * float(i) / 6.0
				draw_circle(Vector2(0, -20) + Vector2(cos(a), sin(a)) * 44.0, 6.0, [Color("#f7b2c4"), Palette.GOLD, Palette.LAVENDER][i % 3])
			return
		BiomeDecorArt.shadow(self, 36.0)
		for k in 6:
			var a := -PI * 0.9 + k * 0.32
			var tip := Vector2(cos(a), sin(a)) * (34.0 + (k % 2) * 8.0) + Vector2(0, -6)
			draw_line(Vector2(0, -4), tip, Color("#8a7a5e"), 4.0, true)
			draw_circle(tip, 4.0, Color("#a39070"))
		draw_circle(Vector2(0, -6), 10.0, Color("#7a6a50"))
		draw_interaction_cues(34.0, Vector2(0, -14))


## The old chest inside the forgotten garden.
class GardenChest extends Interactable:
	var garden: WitheredGarden

	func _ready() -> void:
		reach_bonus = 14.0

	func can_interact() -> bool:
		return WitheredGarden.is_revived(garden.garden_id) and not bool(WitheredGarden.state_of(garden.garden_id)["opened"]) and super.can_interact()

	func get_prompt() -> String:
		return "Open the old chest"

	func _process(delta: float) -> void:
		super(delta)

	func _draw() -> void:
		var opened := bool(WitheredGarden.state_of(garden.garden_id)["opened"])
		BiomeDecorArt.shadow(self, 24.0)
		draw_rect(Rect2(-22, -26, 44, 26), Palette.BARK)
		draw_rect(Rect2(-22, -26, 44, 26), Palette.BARK_DARK, false, 2.0)
		if opened:
			draw_rect(Rect2(-22, -40, 44, 10), Palette.BARK_DARK)
		else:
			draw_rect(Rect2(-22, -34, 44, 10), Palette.BARK.lightened(0.1))
			draw_rect(Rect2(-4, -28, 8, 8), Palette.GOLD)
		draw_interaction_cues(24.0, Vector2(0, -14))
