class_name WildlifeSpawner
extends Node
## Keeps a few ambient creatures around the player in the open world. Which
## creatures appear depends on the region, day or night, and the weather.
## Creatures appear a little way off-screen and are removed again when far
## away, so the cost stays small and constant. Nothing spawns in interiors.
## The "creature_friend" food buff lets more (and rarer) creatures appear.

const CHECK_SECONDS := 1.0
const MAX_NEARBY := 5
const SPAWN_MIN := 560.0
const SPAWN_MAX := 980.0
const DESPAWN_DISTANCE := 1750.0
const RARE_BOOST := 4.0

var overworld: Overworld
var enabled: bool = true
var creatures: Array[Creature] = []
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(ow: Overworld) -> void:
	overworld = ow
	_rng.randomize()


static func current_weather() -> String:
	return Weather.world_today()


static func is_day() -> bool:
	return TimeManager.daylight() >= 0.5


func _process(delta: float) -> void:
	if overworld == null:
		return
	_timer += delta
	if _timer < CHECK_SECONDS:
		return
	_timer = 0.0
	if not enabled or not overworld.current_sublevel.is_empty():
		clear_all()
		return
	var center := overworld.player.global_position
	for c in creatures.duplicate():
		if not is_instance_valid(c) or c.global_position.distance_to(center) > DESPAWN_DISTANCE:
			_remove(c)
	var limit := MAX_NEARBY * (2 if ItemConsumer.Buffs.has("creature_friend") else 1)
	if creatures.size() < limit:
		try_spawn_near(center)


## Tries a few random spots around `center`; returns the new creature or null.
func try_spawn_near(center: Vector2) -> Creature:
	var world := overworld.world
	for attempt in 6:
		var pos := center + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		if not world.world_rect().grow(-120.0).has_point(pos) or world.is_blocked_at(pos):
			continue
		var id := pick_species(world.region_at(pos))
		if not id.is_empty():
			return spawn(id, pos)
	return null


## Weighted choice among the creatures that fit this region right now.
func pick_species(region: String) -> String:
	var options := CreatureDB.candidates(region, is_day(), current_weather())
	if options.is_empty():
		return ""
	var boost := ItemConsumer.Buffs.has("creature_friend")
	var total := 0.0
	var weights: Array[float] = []
	for id in options:
		var c := CreatureDB.get_creature(id)
		var w := float(c.get("weight", 1.0)) * (RARE_BOOST if boost and bool(c.get("rare", false)) else 1.0)
		weights.append(w)
		total += w
	var roll := _rng.randf() * total
	for i in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[options.size() - 1]


func spawn(id: String, pos: Vector2) -> Creature:
	var c := Creature.new()
	c.setup(id, pos, overworld.player, overworld.world)
	c.animation_intensity = GameSettings.motion_scale()
	c.interacted.connect(_on_interacted)
	c.sketched.connect(_on_sketched)
	overworld.entities.add_child(c)
	creatures.append(c)
	CreatureDB.mark_seen(id)
	return c


func clear_all() -> void:
	for c in creatures.duplicate():
		_remove(c)


func _remove(c: Creature) -> void:
	creatures.erase(c)
	if is_instance_valid(c):
		c.queue_free()


func _on_sketched(c: Creature) -> void:
	if CreatureDB.sketch(c.species):
		overworld.hud.show_toast(L.t("Sketched in your journal: %s") % c.display_name())
		AudioManager.play(&"discover", 1.1)
		EventBus.progress_changed.emit()


## Greeting sketches the creature; a liked treat raises friendship.
func _on_interacted(target: Interactable) -> void:
	var c := target as Creature
	if c == null:
		return
	var id := c.species
	var hud := overworld.hud
	c.celebrate()
	if CreatureDB.can_offer_today(id) and not CreatureDB.liked_item_in_bag(id).is_empty():
		var r := CreatureDB.offer(id)
		if bool(r["ok"]):
			AudioManager.play(&"bloom", 1.15)
			var text := L.t("The %s happily takes the %s. Friendship %d / %d.") % [c.display_name(), ItemDB.display_name(String(r["item"])), int(r["friendship"]), CreatureDB.MAX_FRIENDSHIP]
			var gift: Dictionary = r["gift"]
			if not gift.is_empty():
				text += L.t(" It brings you a thank-you gift: %d %s!") % [int(gift.get("qty", 1)), ItemDB.display_name(String(gift["item"]))]
				overworld.lumi.react()
			hud.show_dialogue(text, 5.0)
			EventBus.progress_changed.emit()
			return
	var first := CreatureDB.sketch(id)
	AudioManager.play(&"discover" if first else &"ui_click", 1.2)
	var line := L.t(String(c.data.get("desc", "")))
	if first:
		hud.show_dialogue(L.t("You sketch the %s in your journal. %s") % [c.display_name(), line], 6.0)
		EventBus.progress_changed.emit()
		return
	var friendship := CreatureDB.friendship(id)
	if friendship >= CreatureDB.MAX_FRIENDSHIP:
		hud.show_dialogue(L.t("The %s greets you like an old friend.") % c.display_name(), 4.0)
	else:
		var likes := PackedStringArray()
		for l: String in c.data.get("likes", []):
			likes.append(ItemDB.display_name(l))
		var when := "" if CreatureDB.can_offer_today(id) else " It has had a treat today already."
		hud.show_dialogue(L.t("The %s tilts its head at you. It seems to like %s.%s") % [c.display_name(), L.t(" and ").join(likes), when], 5.0)
