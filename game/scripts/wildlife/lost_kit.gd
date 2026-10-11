class_name LostKit
extends Interactable
## A fox kit lost in a gloom patch of Misty Pinewood. It stays hidden in the
## gloom until the patch is cleared. E coaxes it to follow you; near the den it
## runs home. State per kit ("lost", "following", "home") is kept in
## GameState.systems["fox_kits"], so a kit that was following you is still
## with you after loading.

const STATE_KEY := "fox_kits"
const FOLLOW_GAP := 46.0

var kit_id: String = ""
var hidden_in: String = ""
var den_pos: Vector2 = Vector2.ZERO
var follow_index: int = 0
var leader: Node2D
var _t: float = 0.0
var _flip: float = 1.0
var _hop: float = 0.0


static func kit_state(id: String) -> String:
	return String(GameState.system_state(STATE_KEY).get(id, "lost"))


static func set_kit_state(id: String, s: String) -> void:
	GameState.system_state(STATE_KEY)[id] = s
	GameState.changed.emit("kit:" + id)


static func kits_home() -> int:
	var n := 0
	for v: Variant in GameState.system_state(STATE_KEY).values():
		if String(v) == "home":
			n += 1
	return n


func setup(data: Dictionary, den: Vector2) -> void:
	kit_id = String(data["id"])
	interactable_id = kit_id
	position = data["pos"]
	hidden_in = String(data.get("hidden_in", ""))
	den_pos = den
	reach_bonus = 16.0
	_sync_home_position()


func state() -> String:
	return kit_state(kit_id)


func is_revealed() -> bool:
	return hidden_in.is_empty() or GloomPatch.is_patch_cleared(hidden_in)


func can_interact() -> bool:
	return state() == "lost" and is_revealed() and super.can_interact()


func get_prompt() -> String:
	return "Coax the little fox kit to follow you"


func start_following(p: Node2D, index: int) -> void:
	leader = p
	follow_index = index
	set_kit_state(kit_id, "following")


func go_home() -> void:
	set_kit_state(kit_id, "home")
	leader = null
	var tween := create_tween()
	tween.tween_property(self, "global_position", _home_spot(), 1.2 * maxf(GameSettings.motion_scale(), 0.4))


func _home_spot() -> Vector2:
	var i := int(kit_id.right(1)) if kit_id.right(1).is_valid_int() else 0
	return den_pos + Vector2(-50 + i * 34, 52)


func _sync_home_position() -> void:
	if state() == "home":
		position = _home_spot()


## Snaps a following kit next to its leader (after travel or a doorway).
func snap_to_leader() -> void:
	if leader != null and state() == "following":
		global_position = leader.global_position + Vector2(-FOLLOW_GAP * (follow_index + 1), 12)


func _process(delta: float) -> void:
	super(delta)
	_t += delta * maxf(GameSettings.motion_scale(), 0.3)
	visible = is_revealed() or state() != "lost"
	if state() == "following" and leader != null:
		var target := leader.global_position + (Vector2(-FOLLOW_GAP, 10) if leader.global_position.x >= global_position.x else Vector2(FOLLOW_GAP, 10)) * float(follow_index + 1)
		var to := target - global_position
		if to.length() > 8.0:
			var step := to.normalized() * minf(to.length(), maxf(200.0, to.length() * 3.0) * delta)
			global_position += step
			_hop += delta * 3.0
			if absf(step.x) > 0.5:
				_flip = 1.0 if step.x > 0.0 else -1.0
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	CreatureArt.draw(self, "fox", Color("#f4a259"), Color("#fff6e5"), _t, _hop, _flip, Vector2.ZERO, 0.72)
	if state() == "lost":
		var bob := sin(_t * 2.0) * 2.0
		draw_string(ThemeDB.fallback_font, Vector2(-4, -34 + bob), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.CREAM)
	draw_interaction_cues(18.0, Vector2(0, -8))
