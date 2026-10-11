class_name PuzzleBonus
extends RefCounted
## Playful mode's optional bonus challenge for puzzles: solve in the fewest
## moves ("par"). It is only ever praise; there is no penalty, no timer and no
## failure, and Gentle/Balanced modes never see it. Best results are kept in
## GameState.systems["puzzle_bonus"].


static func is_active() -> bool:
	return SessionState.get_config().mode_id == &"playful"


## Called when a puzzle is solved. Returns the line shown (or "").
static func report(puzzle_id: String, moves: int, par: int) -> String:
	if not is_active() or moves <= 0:
		return ""
	var best := GameState.system_state("puzzle_bonus")
	var prev := int(best.get(puzzle_id, 0))
	if prev == 0 or moves < prev:
		best[puzzle_id] = moves
	var text := ""
	if moves <= par:
		GameState.add_counter("bonus_puzzles")
		text = L.t("Bonus challenge: a perfect solve in %d moves!") % moves
	else:
		text = L.t("Solved in %d moves. (Bonus challenge: it can be done in %d.)") % [moves, par]
	EventBus.toast_requested.emit(text)
	return text
