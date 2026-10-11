class_name SignalPuzzle
extends Node2D
## The shipwreck's signal lanterns. Four lanterns stand around the broken mast,
## one for each compass direction. Each press of E changes a lantern's color.
## The captain's log on the beach tells which color belongs to which
## direction. When all four match, the hold opens. A lever resets the colors.
## Lumi offers a three-step hint ladder. Progress is saved in GameState.

signal solved(puzzle_id: String)
signal changed

const COLORS: Array[Color] = [Color("#ffd166"), Color("#5cc8c0"), Color("#f7b2c4"), Color("#8fd18a")]
const COLOR_NAMES: PackedStringArray = ["gold", "sea blue", "rose", "leaf green"]  # i18n
const DIRECTIONS: PackedStringArray = ["north", "east", "south", "west"]  # i18n
const OFFSETS: Array[Vector2] = [Vector2(0, -150), Vector2(170, 0), Vector2(0, 150), Vector2(-170, 0)]
## north = leaf green (home), east = gold (sunrise), south = sea blue, west = rose (dusk).
const SOLUTION: Array[int] = [3, 0, 1, 2]
const HINTS := [
	"These lanterns look like a ship's signal. Maybe the captain wrote something down. There was a log on the beach.",
	"Each lantern faces a direction around the mast. The log ties a color to each direction: sunrise, the sea, dusk and home.",
	"North shows leaf green for home, east gold for sunrise, south sea blue, and west rose for dusk. The lever starts over.",
]

var puzzle_id: String = "wreck_signal"
var state: Array[int] = [0, 0, 0, 0]
var is_solved: bool = false
var hint_level: int = 0
var moves: int = 0
var lanterns: Array[SignalLantern] = []
var lever: ResetLever
var _t: float = 0.0
var _open: float = 0.0


func _ready() -> void:
	var saved := GameState.puzzle_state(puzzle_id)
	if not saved.is_empty():
		var s: Array = saved.get("state", [0, 0, 0, 0])
		for i in mini(4, s.size()):
			state[i] = int(s[i]) % COLORS.size()
		is_solved = bool(saved.get("solved", false))
		_open = 1.0 if is_solved else 0.0
	for i in 4:
		var l := SignalLantern.new()
		l.index = i
		l.puzzle = self
		l.interactable_id = "%s_lantern_%d" % [puzzle_id, i]
		l.position = OFFSETS[i]
		add_child(l)
		lanterns.append(l)
	lever = ResetLever.new()
	lever.interactable_id = puzzle_id + "_lever"
	lever.position = Vector2(-150, 120)
	lever.puzzle = self
	lever.prompt = "Reset the signal lanterns"
	add_child(lever)


func cycle(index: int) -> void:
	if is_solved:
		return
	state[index] = (state[index] + 1) % COLORS.size()
	moves += 1
	_after_change()
	if state == SOLUTION:
		is_solved = true
		_save()
		var tween := create_tween()
		tween.tween_property(self, "_open", 1.0, 1.4 * maxf(GameSettings.motion_scale(), 0.5))
		var par := 0
		for v in SOLUTION:
			par += v
		PuzzleBonus.report(puzzle_id, moves, par)
		solved.emit(puzzle_id)


## Called by the reset lever.
func reset_puzzle() -> void:
	if is_solved:
		return
	state = [0, 0, 0, 0]
	moves = 0
	hint_level = 0
	_after_change()


func next_hint(gentle: bool) -> String:
	if is_solved:
		return L.t("The hold is open. The captain's signal is shining again!")
	var text: String = L.t(HINTS[mini(hint_level, HINTS.size() - 1)])
	if hint_level >= HINTS.size() - 1 and gentle:
		for i in 4:
			lanterns[i].hinted = state[i] != SOLUTION[i]
		text += L.t(" The lanterns that still need a change are shimmering.")
	hint_level = mini(hint_level + 1, HINTS.size() - 1)
	return text


func _after_change() -> void:
	_save()
	for l in lanterns:
		l.hinted = false
		l.queue_redraw()
	changed.emit()


func _save() -> void:
	GameState.set_puzzle_state(puzzle_id, {"state": state.duplicate(), "solved": is_solved})


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position, 400.0):
		queue_redraw()


func _draw() -> void:
	# The tilted deck of the wreck, a compass rose and the broken mast.
	var deck := PackedVector2Array([Vector2(-260, -60), Vector2(-150, -200), Vector2(180, -190), Vector2(280, -40), Vector2(230, 190), Vector2(-210, 200)])
	draw_colored_polygon(deck, Color("#9c7b62"))
	for i in 9:
		var y := -180.0 + i * 42.0
		draw_line(Vector2(-240, y), Vector2(250, y + 10), Palette.with_alpha(Palette.BARK_DARK, 0.5), 2.0)
	draw_circle(Vector2.ZERO, 60.0, Palette.with_alpha(Palette.CREAM, 0.35))
	for i in 4:
		draw_line(Vector2.ZERO, OFFSETS[i] * 0.42, Palette.with_alpha(Palette.CREAM, 0.7), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-5, -68), L.t("N"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.CREAM)
	draw_rect(Rect2(-10, -60, 20, 60), Palette.BARK_DARK)
	draw_line(Vector2(0, -60), Vector2(40, -120), Palette.BARK_DARK, 8.0)
	# The hold hatch opens when solved.
	var hatch := Rect2(60, 60, 80, 56)
	draw_rect(hatch, Palette.BARK_DARK)
	if _open > 0.0:
		draw_rect(Rect2(hatch.position, Vector2(hatch.size.x, hatch.size.y * (1.0 - _open))), Palette.BARK)
		draw_circle(hatch.get_center(), 30.0 * _open, Palette.with_alpha(Palette.GOLD, 0.35 * _open))
	else:
		draw_rect(hatch, Palette.BARK)
		draw_line(hatch.position + Vector2(0, 28), hatch.end - Vector2(0, 28), Palette.BARK_DARK, 2.0)


## One signal lantern on the deck.
class SignalLantern extends Interactable:
	var index: int = 0
	var puzzle: SignalPuzzle
	var hinted: bool = false
	var _t: float = 0.0

	func _ready() -> void:
		reach_bonus = 10.0

	func can_interact() -> bool:
		return not puzzle.is_solved and super.can_interact()

	func get_prompt() -> String:
		return L.t("Change the %s lantern (now %s)") % [L.t(SignalPuzzle.DIRECTIONS[index]), L.t(SignalPuzzle.COLOR_NAMES[puzzle.state[index]])]

	func interact() -> void:
		if can_interact():
			puzzle.cycle(index)
			interacted.emit(self)

	func _process(delta: float) -> void:
		super(delta)
		_t += delta * GameSettings.motion_scale()
		if ViewCull.near(global_position):
			queue_redraw()

	func _draw() -> void:
		var col: Color = SignalPuzzle.COLORS[puzzle.state[index]]
		BiomeDecorArt.shadow(self, 16.0)
		draw_rect(Rect2(-3, -40, 6, 40), Palette.BARK_DARK)
		draw_rect(Rect2(-12, -62, 24, 24), Palette.INK_SOFT)
		draw_rect(Rect2(-9, -59, 18, 18), col)
		var glow := 0.3 + (0.2 * sin(_t * 2.0) if puzzle.is_solved else 0.0)
		draw_circle(Vector2(0, -50), 26.0, Palette.with_alpha(col, glow))
		if hinted:
			draw_arc(Vector2(0, -50), 30.0 + sin(_t * 4.0) * 3.0, 0.0, TAU, 32, Palette.with_alpha(Palette.IVORY, 0.9), 2.0)
		# Shape cue per color so color is never the only signal.
		match puzzle.state[index]:
			0:
				draw_circle(Vector2(0, -50), 4.0, Palette.INK)
			1:
				draw_line(Vector2(-5, -50), Vector2(5, -50), Palette.INK, 2.5)
			2:
				draw_colored_polygon(PackedVector2Array([Vector2(0, -55), Vector2(5, -46), Vector2(-5, -46)]), Palette.INK)
			3:
				draw_rect(Rect2(-4, -54, 8, 8), Palette.INK)
		draw_interaction_cues(22.0, Vector2(0, -50))
