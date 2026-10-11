class_name AuroraShrine
extends Node2D
## The aurora shrine of the Frostbloom Highlands. Three ice prisms stand around
## a sleeping crystal; each prism sends a soft beam in the direction it faces
## and turns a quarter with E. When all three beams meet at the crystal, the
## aurora wakes. Reset lever and a three-step hint ladder; progress is saved.

signal solved(puzzle_id: String)

const DIRS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const DIR_NAMES: PackedStringArray = ["north", "east", "south", "west"]  # i18n
## Prism offsets from the center, the facing that points at the center, and the start facing.
const PRISMS := [[Vector2(-210, 0), 1, 0], [Vector2(210, 0), 3, 2], [Vector2(0, 170), 0, 1]]
const HINTS := [
	"The three ice prisms each send a little beam of light. Where do you think the light wants to go?",
	"The crystal in the middle is sleeping. Turn each prism (E) until its beam points at it.",
	"The west prism should face east, the east prism west, and the south prism north. The lever starts over.",
]

var puzzle_id: String = "aurora_shrine"
var facings: Array[int] = [0, 2, 1]
var is_solved: bool = false
var hint_level: int = 0
var moves: int = 0
var prisms: Array[AuroraPrism] = []
var lever: ResetLever
var _t: float = 0.0
var _glow: float = 0.0


func _ready() -> void:
	for i in PRISMS.size():
		facings[i] = int(PRISMS[i][2])
	var saved := GameState.puzzle_state(puzzle_id)
	if not saved.is_empty():
		var f: Array = saved.get("facings", [])
		for i in mini(f.size(), facings.size()):
			facings[i] = int(f[i]) % 4
		is_solved = bool(saved.get("solved", false))
		_glow = 1.0 if is_solved else 0.0
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	col.shape = shape
	col.position = Vector2(0, -10)
	body.add_child(col)
	add_child(body)
	for i in PRISMS.size():
		var p := AuroraPrism.new()
		p.shrine = self
		p.index = i
		p.interactable_id = "%s_prism_%d" % [puzzle_id, i]
		p.position = PRISMS[i][0]
		add_child(p)
		prisms.append(p)
	lever = ResetLever.new()
	lever.puzzle = self
	lever.prompt = "Turn the prisms back to the start"
	lever.interactable_id = puzzle_id + "_lever"
	lever.position = Vector2(-150, 170)
	add_child(lever)


func correct(i: int) -> bool:
	return facings[i] == int(PRISMS[i][1])


func turn(i: int) -> void:
	if is_solved:
		return
	facings[i] = (facings[i] + 1) % 4
	moves += 1
	for p in prisms:
		p.hinted = false
	AudioManager.play(&"ui_click", 1.4)
	var all_ok := true
	for k in prisms.size():
		all_ok = all_ok and correct(k)
	if all_ok:
		is_solved = true
		create_tween().tween_property(self, "_glow", 1.0, 2.0 * maxf(GameSettings.motion_scale(), 0.4))
	_save()
	if is_solved:
		var par := 0
		for spec: Array in PRISMS:
			par += posmod(int(spec[1]) - int(spec[2]), 4)
		PuzzleBonus.report(puzzle_id, moves, par)
		solved.emit(puzzle_id)


func reset_puzzle() -> void:
	if is_solved:
		return
	for i in PRISMS.size():
		facings[i] = int(PRISMS[i][2])
	moves = 0
	hint_level = 0
	_save()


func next_hint(gentle: bool) -> String:
	if is_solved:
		return L.t("The aurora is awake. Look up at night!")
	var text: String = L.t(HINTS[mini(hint_level, HINTS.size() - 1)])
	if hint_level >= HINTS.size() - 1 and gentle:
		for i in prisms.size():
			prisms[i].hinted = not correct(i)
		text += L.t(" The prisms that still need turning are shimmering.")
	hint_level = mini(hint_level + 1, HINTS.size() - 1)
	return text


func _save() -> void:
	GameState.set_puzzle_state(puzzle_id, {"facings": facings.duplicate(), "solved": is_solved})


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position, 500.0):
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 290.0, Color(0.85, 0.9, 0.98, 0.5))
	draw_arc(Vector2.ZERO, 290.0, 0.0, TAU, 64, Color("#b8c6dd"), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Beams from each prism in the direction it faces.
	for i in prisms.size():
		var start: Vector2 = PRISMS[i][0] + Vector2(0, -30)
		var dir := DIRS[facings[i]]
		var length := (start - Vector2(0, -30)).length() if correct(i) else 120.0
		draw_line(start, start + dir * length, Palette.with_alpha(Color("#b8f0d8"), 0.7), 4.0)
	# The sleeping crystal at the center wakes with the aurora.
	var g := _glow
	draw_circle(Vector2(0, -30), 40.0 + 30.0 * g, Palette.with_alpha(Color("#b8f0d8"), 0.15 + 0.3 * g))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(10, -60), Vector2(0, -78), Vector2(-10, -60)]), Color("#cfe6ff").lerp(Color("#b8f0d8"), g))
	if g > 0.0:
		for k in 3:
			var col: Color = [Color("#8ff0c0"), Color("#9fd8ff"), Color("#c9a8ff")][k]
			draw_arc(Vector2(0, -260), 160.0 + k * 34.0 + sin(_t * 0.7 + k) * 8.0, PI * 1.1, PI * 1.9, 40, Palette.with_alpha(col, 0.35 * g), 14.0)


## One ice prism of the shrine.
class AuroraPrism extends Interactable:
	var shrine: AuroraShrine
	var index: int = 0
	var hinted: bool = false

	func _ready() -> void:
		reach_bonus = 12.0
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 18.0
		col.shape = shape
		col.position = Vector2(0, -6)
		body.add_child(col)
		add_child(body)

	func can_interact() -> bool:
		return not shrine.is_solved and super.can_interact()

	func get_prompt() -> String:
		return L.t("Turn the ice prism (now facing %s)") % L.t(AuroraShrine.DIR_NAMES[shrine.facings[index]])

	func interact() -> void:
		if can_interact():
			shrine.turn(index)
			interacted.emit(self)

	func _process(delta: float) -> void:
		super(delta)
		if ViewCull.near(global_position) and (is_targeted or hinted):
			queue_redraw()

	func _draw() -> void:
		BiomeDecorArt.shadow(self, 18.0)
		var pts := PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(10, -46), Vector2(0, -60), Vector2(-10, -46)])
		draw_colored_polygon(pts, Color("#dbe8f7"))
		var d := AuroraShrine.DIRS[shrine.facings[index]]
		draw_line(Vector2(0, -30), Vector2(0, -30) + d * 14.0, Palette.INK_SOFT, 3.0)
		draw_circle(Vector2(0, -30) + d * 14.0, 3.5, Palette.INK_SOFT)
		if hinted:
			draw_arc(Vector2(0, -30), 28.0 + sin(_ring_time * 4.0) * 3.0, 0.0, TAU, 28, Palette.with_alpha(Palette.IVORY, 0.9), 2.0)
		draw_interaction_cues(24.0, Vector2(0, -28))
