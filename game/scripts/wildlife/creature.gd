class_name Creature
extends Interactable
## An ambient animal. It idles and wanders near where it appeared, gently
## moves away if someone hurries toward it, and comes a little closer when the
## player stands still. Watching it calmly for a few seconds sketches it into
## the Creature Journal; E greets it or offers a treat it likes.
## Creatures never block the way, never harm, and never take anything.

signal sketched(creature: Creature)

enum State { IDLE, WANDER, FLEE, APPROACH }

const SKETCH_SECONDS := 3.0
const WATCH_DISTANCE := 380.0
## Player speed above walking pace (walk 220, run 352) counts as hurrying.
const HURRY_SPEED := 290.0
const STILL_SPEED := 15.0
const CALM_SECONDS := 1.4
const WANDER_RADIUS := 150.0
const CLOSEST := 95.0

var species: String = ""
var data: Dictionary = {}
var home: Vector2 = Vector2.ZERO
var player: CharacterBody2D
var world: WorldData
var state: State = State.IDLE
var watch_time: float = 0.0
var sketch_sent: bool = false
var _target: Vector2 = Vector2.ZERO
var _timer: float = 1.0
var _flee_dir: Vector2 = Vector2.ZERO
var _still: float = 0.0
var _t: float = 0.0
var _hop: float = 0.0
var _flip: float = 1.0
var _joy: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(id: String, pos: Vector2, p: CharacterBody2D, w: WorldData) -> void:
	species = id
	data = CreatureDB.get_creature(id)
	position = pos
	home = pos
	player = p
	world = w
	interactable_id = "creature_%s_%d" % [id, get_instance_id()]
	reach_bonus = 14.0
	_rng.randomize()
	_t = _rng.randf() * 10.0
	_timer = _rng.randf_range(0.5, 2.0)


func display_name() -> String:
	return L.t(String(data.get("name", species)))


func get_prompt() -> String:
	var item := CreatureDB.liked_item_in_bag(species)
	if CreatureDB.can_offer_today(species) and not item.is_empty():
		return L.t("Offer %s to the %s") % [ItemDB.display_name(item), display_name()]
	return L.t("Greet the %s") % display_name()


func get_interaction_point() -> Vector2:
	return global_position + Vector2(0, -10)


## Gentle: creatures are at ease quickly; Playful: they need a little more calm.
static func mode_shyness() -> float:
	match SessionState.get_config().mode_id:
		&"gentle":
			return 0.5
		&"playful":
			return 1.3
	return 1.0


func speed() -> float:
	return float(data.get("speed", 40.0))


## A happy little bounce (after a greeting or a treat).
func celebrate() -> void:
	_joy = 1.0
	state = State.IDLE
	_timer = 2.5


func _process(delta: float) -> void:
	super(delta)
	var motion := GameSettings.motion_scale()
	_t += delta * maxf(motion, 0.3)
	_joy = maxf(0.0, _joy - delta * 0.8)
	if player != null:
		_think(delta)
	if ViewCull.near(global_position):
		queue_redraw()


func _think(delta: float) -> void:
	var to_player := player.global_position - global_position
	var d := to_player.length()
	var player_speed := player.velocity.length()
	var friendly := ItemConsumer.Buffs.has("creature_friend") or CreatureDB.friendship(species) >= CreatureDB.MAX_FRIENDSHIP
	var mode_k := mode_shyness()
	var shy := float(data.get("shy", 0.5)) * (0.3 if friendly else 1.0) * mode_k
	if d < WATCH_DISTANCE and player_speed < HURRY_SPEED and state != State.FLEE:
		watch_time += delta
		if watch_time >= SKETCH_SECONDS and not sketch_sent:
			sketch_sent = true
			sketched.emit(self)
	_still = _still + delta if player_speed < STILL_SPEED and d < 340.0 else 0.0
	if state != State.FLEE and shy > 0.05 and player_speed > HURRY_SPEED and d < 90.0 + shy * 230.0:
		state = State.FLEE
		_timer = 1.6
		_flee_dir = -to_player.normalized() if d > 1.0 else Vector2.RIGHT
	match state:
		State.FLEE:
			_move(_flee_dir * speed() * 2.2, delta)
			_timer -= delta
			if _timer <= 0.0:
				state = State.IDLE
				_timer = _rng.randf_range(1.0, 2.0)
				home = global_position
		State.APPROACH:
			if _still <= 0.0 or d <= CLOSEST:
				state = State.IDLE
				_timer = 2.0
			else:
				_move(to_player.normalized() * speed() * 0.6, delta)
		State.WANDER:
			var to_target := _target - global_position
			_timer -= delta
			if to_target.length() < 6.0 or _timer <= 0.0:
				state = State.IDLE
				_timer = _rng.randf_range(1.2, 3.5)
			else:
				_move(to_target.normalized() * speed(), delta)
		State.IDLE:
			_timer -= delta
			if _still > CALM_SECONDS * (1.0 + shy) * mode_k and d > CLOSEST + 15.0 and d < 330.0:
				state = State.APPROACH
				_flip = 1.0 if to_player.x >= 0.0 else -1.0
			elif _timer <= 0.0:
				_target = home + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * WANDER_RADIUS
				state = State.WANDER
				_timer = 4.0


func _move(v: Vector2, delta: float) -> void:
	var next := global_position + v * delta
	if world != null and (world.is_blocked_at(next) or not world.world_rect().grow(-40.0).has_point(next)):
		state = State.IDLE
		_timer = _rng.randf_range(0.6, 1.4)
		home = global_position
		return
	global_position = next
	if absf(v.x) > 2.0:
		_flip = 1.0 if v.x > 0.0 else -1.0
	_hop += delta * v.length() / 40.0


func _draw() -> void:
	var col := Color(String(data.get("color", "#c49a6c")))
	var acc := Color(String(data.get("accent", "#fff6e5")))
	var hop := _hop + _joy * 2.0
	CreatureArt.draw(self, String(data.get("shape", "rabbit")), col, acc, _t, hop, _flip)
	if _joy > 0.0:
		for i in 3:
			var a := float(i) * 2.1 + _t * 2.0
			draw_circle(Vector2(cos(a) * 18.0, -36.0 - _joy * 10.0 + sin(a) * 4.0), 2.5, Palette.with_alpha(Palette.GOLD, _joy))
	draw_interaction_cues(20.0, Vector2(0, -10))
