class_name RegionFeatures
extends Node
## Content of the wider world beyond Act 1 (V2 M6+): Misty Pinewood and the
## Sunpetal Coast and Isles. Spawns the authored points of interest from
## WorldData (gloom patches, Gloomlings, docks, the lighthouse, the shipwreck
## puzzle, the lost fox kits and their den, ruins and tide pools), owns the
## ambient wildlife spawner and the regional atmosphere, and answers Lumi's
## hints near these places. All progress is written to GameState.

const HINT_RADIUS := 480.0
const GLOOM_HIDE_CHECK := 0.5
const HEARTHSTONE_ITEMS := {
	"pinewood": "hearthstone_pinewood", "coast": "hearthstone_coast", "isles": "hearthstone_isles",
	"caverns": "hearthstone_caverns", "highlands": "hearthstone_highlands",
}

var overworld: Overworld
var wildlife: WildlifeSpawner
var atmosphere: RegionAtmosphere
var patches: Dictionary = {}
var gloomlings: Dictionary = {}
var docks: Dictionary = {}
var sites: Dictionary = {}
var kits: Array[LostKit] = []
var den: FoxDen
var wreck: SignalPuzzle
var fishing_spots: Dictionary = {}
var path_barrier: PathBarrier
var shrine: AuroraShrine
var gardens: Dictionary = {}
var _veils: Node2D
var _mists: Node2D
var _hide_timer: float = 0.0


func build(ow: Overworld) -> void:
	overworld = ow
	var veil_layer := CanvasLayer.new()
	veil_layer.name = "GloomLayer"
	veil_layer.layer = 1
	veil_layer.follow_viewport_enabled = true
	ow.add_child(veil_layer)
	_veils = Node2D.new()
	veil_layer.add_child(_veils)
	_mists = Node2D.new()
	veil_layer.add_child(_mists)
	atmosphere = RegionAtmosphere.new()
	atmosphere.name = "Atmosphere"
	ow.add_child(atmosphere)
	wildlife = WildlifeSpawner.new()
	wildlife.name = "Wildlife"
	add_child(wildlife)
	wildlife.setup(ow)
	var den_poi := ow.world.poi("fox_den")
	for p: Dictionary in ow.world.pois:
		match String(p["kind"]):
			"gloom":
				var patch := GloomPatch.new()
				patch.setup(p, _veils, _mists)
				patch.heart.interacted.connect(func(_t: Interactable) -> void: _on_gloom_heart(patch))
				patch.cleared.connect(_on_gloom_cleared)
				ow.entities.add_child(patch)
				patches[patch.patch_id] = patch
			"gloomling":
				var g := Gloomling.new()
				g.setup(p)
				g.interacted.connect(func(_t: Interactable) -> void: _on_gloomling(g))
				g.calmed.connect(_on_gloomling_calmed)
				ow.entities.add_child(g)
				gloomlings[g.gloomling_id] = g
			"dock":
				var d := BoatDock.new()
				d.setup(p, ow.world.poi(String(p.get("dest", ""))))
				d.interacted.connect(func(_t: Interactable) -> void: _on_dock(d))
				ow.entities.add_child(d)
				docks[d.dock_id] = d
			"site":
				var s := RestorationSite.new()
				s.setup(String(p.get("site", p["id"])), p["pos"])
				s.interacted.connect(func(_t: Interactable) -> void: open_site(s))
				s.completed.connect(_on_site_completed)
				ow.entities.add_child(s)
				sites[s.site_id] = s
			"wreck_puzzle":
				wreck = SignalPuzzle.new()
				wreck.puzzle_id = String(p["id"])
				wreck.position = p["pos"]
				wreck.z_index = -4
				wreck.solved.connect(_on_wreck_solved)
				wreck.changed.connect(func() -> void: AudioManager.play(&"ui_click", 1.2))
				ow.entities.add_child(wreck)
			"lost_kit":
				var k := LostKit.new()
				k.setup(p, den_poi.get("pos", Vector2.ZERO))
				k.interacted.connect(func(_t: Interactable) -> void: _on_kit(k))
				ow.entities.add_child(k)
				kits.append(k)
			"fox_den":
				den = FoxDen.new()
				den.interactable_id = String(p["id"])
				den.position = p["pos"]
				den.interacted.connect(func(_t: Interactable) -> void: _on_den())
				ow.entities.add_child(den)
			"mountain_path":
				path_barrier = PathBarrier.new()
				path_barrier.position = p["pos"]
				ow.entities.add_child(path_barrier)
				var off: Array = p.get("site_offset", [0, 200])
				var ps := RestorationSite.new()
				ps.setup("mountain_path", p["pos"] + Vector2(float(off[0]), float(off[1])))
				ps.interacted.connect(func(_t: Interactable) -> void: open_site(ps))
				ps.completed.connect(_on_site_completed)
				ow.entities.add_child(ps)
				sites[ps.site_id] = ps
			"aurora_shrine":
				shrine = AuroraShrine.new()
				shrine.puzzle_id = String(p["id"])
				shrine.position = p["pos"]
				shrine.z_index = -4
				shrine.solved.connect(_on_shrine_solved)
				ow.entities.add_child(shrine)
			"fishing_spot":
				var spot := FishingSpot.new()
				spot.setup(p)
				spot.interacted.connect(func(_t: Interactable) -> void: ow.open_fishing(spot))
				ow.entities.add_child(spot)
				fishing_spots[spot.interactable_id] = spot
			"withered_garden":
				var garden := WitheredGarden.new()
				garden.setup(p)
				garden.plant.interacted.connect(func(_t: Interactable) -> void: _on_withered_plant(garden))
				garden.chest.interacted.connect(func(_t: Interactable) -> void: _on_garden_chest(garden))
				ow.entities.add_child(garden)
				gardens[garden.garden_id] = garden
			"scenery":
				var piece := SceneryPiece.new()
				piece.style = String(p.get("style", "cabin"))
				piece.variant = int(p.get("variant", 0))
				piece.position = p["pos"]
				ow.entities.add_child(piece)
	if den != null:
		den.total_kits = kits.size()
	_resume_following_kits()


func _resume_following_kits() -> void:
	var index := 0
	for k in kits:
		if k.state() == "following":
			k.leader = overworld.player
			k.follow_index = index
			index += 1
			k.call_deferred("snap_to_leader")


func set_night_amount(amount: float) -> void:
	atmosphere.night = amount
	var tint := overworld.night_tint.color
	for patch: GloomPatch in patches.values():
		if patch.mist != null:
			patch.mist.tint = tint


func _process(delta: float) -> void:
	if overworld == null:
		return
	atmosphere.region = overworld.current_region
	atmosphere.in_sublevel = not overworld.current_sublevel.is_empty()
	atmosphere.weather = Weather.today()
	atmosphere.aurora = GameState.has_flag("aurora_aligned")
	atmosphere.camera_pos = overworld.camera.get_screen_center_position()
	atmosphere.camera_zoom = overworld.camera.zoom.x
	_update_kits()
	_hide_timer += delta
	if _hide_timer >= GLOOM_HIDE_CHECK:
		_hide_timer = 0.0
		_hide_gathered_in_gloom()


## Gloom hides resources: gatherables inside an uncleared patch stay invisible
## (and cannot be gathered) until the gloom is gone.
func _hide_gathered_in_gloom() -> void:
	var pending: Array[GloomPatch] = []
	for patch: GloomPatch in patches.values():
		if not patch.is_cleared:
			pending.append(patch)
	for chunk_node: Node2D in overworld.streamer.loaded.values():
		for c in chunk_node.get_children():
			var g := c as Gatherable
			if g == null:
				continue
			var hidden := false
			for patch in pending:
				if patch.contains(g.global_position):
					hidden = true
					break
			g.visible = not hidden


func _update_kits() -> void:
	if den == null or not overworld.current_sublevel.is_empty():
		return
	for k in kits:
		if k.state() == "following" and overworld.player.global_position.distance_to(den.global_position) < FoxDen.ARRIVE_DISTANCE:
			k.go_home()
			AudioManager.play(&"bloom", 1.3)
			overworld.lumi.react()
			var home := LostKit.kits_home()
			GameState.add_counter("kits_home")
			if home >= kits.size():
				_complete_fox_family()
			else:
				overworld.hud.show_dialogue(L.t("The kit tumbles into its mother's paws. %d of %d kits are home.") % [home, kits.size()], 5.0)
			_reindex_followers()


func _reindex_followers() -> void:
	var index := 0
	for k in kits:
		if k.state() == "following":
			k.follow_index = index
			index += 1


## Called after travel, doorways and sailing: following kits come along.
func on_player_teleported() -> void:
	for k in kits:
		k.snap_to_leader()


## Lumi's hint for something nearby, or "" if nothing here needs one.
func hint_near(pos: Vector2, gentle: bool) -> String:
	if wreck != null and pos.distance_to(wreck.global_position) < 520.0:
		return wreck.next_hint(gentle)
	if shrine != null and pos.distance_to(shrine.global_position) < 560.0:
		return shrine.next_hint(gentle)
	for patch: GloomPatch in patches.values():
		if not patch.is_cleared and pos.distance_to(patch.global_position) < patch.radius + 200.0:
			if GameState.inventory.count("bright_lantern") > 0:
				return "Your Bright Lantern can melt this gloom. Walk to the dark knot at its center and press E."
			if GameState.inventory.count("luma_bloom") > 0:
				return "A Luma Bloom planted at the dark knot in the middle will melt this gloom. Press E there."
			if GameState.has_flag("act1_complete"):
				return "This gloom is too thick for a small lantern. A Bright Lantern (lantern, 3 crystal shards, 1 sea glass, 2 glowcaps at a workbench) can melt it, and so can a Luma Bloom grown from a bulb in your garden."
			return "This gloom is too thick for now. Once the Heart of Lumeria is awake, a brighter lantern will be possible. A Luma Bloom from your garden works too."
	for g: Gloomling in gloomlings.values():
		if not g.is_calm and pos.distance_to(g.global_position) < HINT_RADIUS:
			return "That Gloomling is just sad and shy. Light, a soft song or a little food will comfort it. Any kindness works."
	for garden: WitheredGarden in gardens.values():
		if pos.distance_to(garden.global_position) < HINT_RADIUS and not WitheredGarden.is_revived(garden.garden_id):
			return "The hedges have only one gap, and a thirsty withered plant fills it. A watering can would revive it." if GameState.inventory.count("watering_can") == 0 else "Water the withered plant in the hedge gap (E) and it will open the way."
	for spot: FishingSpot in fishing_spots.values():
		if pos.distance_to(spot.global_position) < 260.0:
			if GameState.inventory.count("fishing_rod") == 0:
				return "Fish rise at these ripples. A fishing rod would let you try; the fisher's notes by the creek explain it."
			if spot.special == "old_whiskers" and not Fishing.legendary_ready() and Fishing.caught("old_whiskers") == 0:
				return "Something big lives here, but it's shy. Catch five different kinds of fish first, then come back."
			return "Press E at the ripples, wait for a bite, then press once. Different fish come by day, at night and in the rain."
	for d: BoatDock in docks.values():
		if pos.distance_to(d.global_position) < 360.0 and GameState.inventory.count("small_boat") == 0:
			return "A boat could sail from here. The shipwright's note by the lighthouse explains how to build one at the cottage workbench."
	for s: RestorationSite in sites.values():
		if pos.distance_to(s.global_position) < HINT_RADIUS and not RestorationSite.is_complete(s.site_id):
			for step: Dictionary in s.steps():
				var id := String(step["id"])
				if not RestorationSite.is_step_done(s.site_id, id):
					var reason := s.check_step(id)
					return L.t("Next: %s. %s") % [L.t(String(step["title"])).to_lower(), reason if not reason.is_empty() else L.t("You have everything for it!")]
	if den != null and pos.distance_to(den.global_position) < HINT_RADIUS and LostKit.kits_home() < kits.size():
		return "The mother fox's kits are lost in the gloom patches of the pinewood. Clear the gloom, then lead each kit back here."
	return ""


# --- Gloom ------------------------------------------------------------------------------

func _on_gloom_heart(patch: GloomPatch) -> void:
	if patch.is_cleared:
		return
	if GameState.inventory.count("bright_lantern") > 0:
		patch.clear_gloom()
		return
	if GameState.inventory.remove("luma_bloom", 1):
		GameState.add_counter("luma_blooms_planted")
		overworld.hud.show_toast("You plant a Luma Bloom in the gloom")
		patch.clear_gloom()
		return
	AudioManager.play(&"soft_deny")
	overworld.hud.show_dialogue(hint_near(patch.global_position, false), 6.0)


func _on_gloom_cleared(patch: GloomPatch) -> void:
	var reward: Array = overworld.world.poi(patch.patch_id).get("reward", [])
	if patch.cleared_silently:
		for r: Dictionary in reward:
			var left := GameState.give_item(String(r["item"]), int(r.get("qty", 1)))
			if left > 0:
				GameState.storage.add(String(r["item"]), left)
		return
	AudioManager.play(&"restore")
	overworld.lumi.react()
	overworld.hud.show_toast("The gloom lifts")
	var got := PackedStringArray()
	for r: Dictionary in reward:
		var left := GameState.give_item(String(r["item"]), int(r.get("qty", 1)))
		if left > 0:
			GameState.storage.add(String(r["item"]), left)
		got.append("%d %s" % [int(r.get("qty", 1)), ItemDB.display_name(String(r["item"]))])
	var text := L.t("Color flows back into the trees, and flowers open where the gloom was.")
	for k in kits:
		if k.hidden_in == patch.patch_id and k.state() == "lost":
			text += L.t(" A little fox kit peeks out, lost and blinking.")
	if not got.is_empty():
		text += L.t(" You find: %s.") % ", ".join(got)
	overworld.hud.show_dialogue(text, 6.0)
	EventBus.progress_changed.emit()


# --- Gloomlings -------------------------------------------------------------------------

func _on_gloomling(g: Gloomling) -> void:
	var food := _food_in_bag()
	var options := [
		["light", "Shine your lantern softly"],
		["song", "Hum a gentle melody"],
		["food", L.t("Offer %s") % ItemDB.display_name(food) if not food.is_empty() else L.t("Offer food (you have none)"), not food.is_empty()],
	]
	overworld.open_choice("A sad little Gloomling", "It hides its face. It doesn't seem dangerous at all, just lonely.", options, func(choice: String) -> void:
		if choice == "food":
			var item := _food_in_bag()
			if item.is_empty() or not GameState.inventory.remove(item, 1):
				return
		g.calm(choice))


## Any dish, or berries, can be shared.
func _food_in_bag() -> String:
	for s in GameState.inventory.slots:
		if not s.is_empty() and ItemDB.category(String(s["id"])) == "food":
			return String(s["id"])
	return "berry" if GameState.inventory.count("berry") > 0 else ""


func _on_gloomling_calmed(g: Gloomling, how: String) -> void:
	AudioManager.play(&"bloom")
	overworld.lumi.react()
	var verb := {"light": "Your lantern's glow", "song": "Your little melody", "food": "Your gift"}
	var text := L.t("%s reaches it. The Gloomling looks up, brightens, and becomes a tiny light spirit!") % L.t(String(verb.get(how, "Your kindness")))
	if how == g.favourite:
		text += L.t(" That was exactly what it needed.")
	if not g.keeps.is_empty():
		text += L.t(" It leaves behind what it was keeping safe: %d %s.") % [int(g.keeps.get("qty", 1)), ItemDB.display_name(String(g.keeps["item"]))]
	overworld.hud.show_dialogue(text, 6.0)
	EventBus.progress_changed.emit()


# --- Forgotten garden -------------------------------------------------------------------

func _on_withered_plant(garden: WitheredGarden) -> void:
	if garden.revive():
		AudioManager.play(&"restore")
		overworld.lumi.react()
		overworld.hud.show_dialogue("The withered plant drinks deeply, stretches, and blooms into a flowering arch. The way into the old garden is open!", 6.0)
		EventBus.progress_changed.emit()
	else:
		AudioManager.play(&"soft_deny")
		overworld.hud.show_dialogue("It looks very thirsty. A watering can would bring it back.", 4.0)


func _on_garden_chest(garden: WitheredGarden) -> void:
	var items := garden.open_chest()
	if items.is_empty():
		return
	var parts := PackedStringArray()
	for r: Dictionary in items:
		parts.append("%d %s" % [int(r.get("qty", 1)), ItemDB.display_name(String(r["item"]))])
	AudioManager.play(&"discover")
	overworld.hud.show_dialogue(L.t("Inside the old chest, wrapped in a gardener's cloth: %s.") % ", ".join(parts), 6.0)
	EventBus.progress_changed.emit()


# --- Boat -------------------------------------------------------------------------------

func _on_dock(d: BoatDock) -> void:
	if GameState.inventory.count("small_boat") > 0:
		sail(d)
		return
	AudioManager.play(&"soft_deny")
	if GameState.storage.count("small_boat") > 0:
		overworld.hud.show_dialogue("Your boat is resting in the cottage chest. Bring it along in your bag to sail.", 5.0)
	else:
		overworld.hud.show_dialogue(L.t("An old dock. %s lies across the water. A Small Boat would get you there; the shipwright's note near the lighthouse has the plans.") % L.t(d.dest_name), 6.0)


func sail(d: BoatDock) -> void:
	var dest: BoatDock = docks.get(d.dest_id)
	if dest == null:
		return
	var first := GameState.counter("boat_trips") == 0
	GameState.add_counter("boat_trips")
	GameState.set_flag("sailed_to:" + dest.dock_id)
	SceneRouter.fade_through(func() -> void:
		overworld.teleport_to(dest.arrival_point())
		on_player_teleported())
	AudioManager.play(&"lantern", 0.8)
	if first:
		overworld.hud.show_dialogue("The sea is calm and the little boat glides along. You can always sail back from the same dock.", 6.0)


# --- Lighthouse and other sites ----------------------------------------------------------

func open_site(s: RestorationSite) -> void:
	overworld.open_site_panel(s)


func _on_site_completed(s: RestorationSite) -> void:
	AudioManager.play(&"restore")
	overworld.lumi.react()
	overworld.hud.show_dialogue(L.t(String(s.data.get("complete_text", "Restored!"))), 7.0)
	if s.site_id == "lighthouse":
		grant_hearthstone("coast")
	if s.site_id == "mountain_path" and path_barrier != null:
		path_barrier.sync()


## For tests and tools: opens the mountain path as if it was restored.
func open_mountain_path() -> void:
	GameState.set_flag("highlands_path_open")
	if path_barrier != null:
		path_barrier.sync()


func _on_shrine_solved(_id: String) -> void:
	GameState.set_flag("aurora_aligned")
	AudioManager.play(&"restore")
	overworld.lumi.react()
	overworld.hud.show_dialogue("The three beams meet, the crystal wakes, and green and violet light ripples across the sky. Inside the crystal, a Hearthstone glows.", 7.0)
	grant_hearthstone("highlands")


# --- Shipwreck --------------------------------------------------------------------------

func _on_wreck_solved(_id: String) -> void:
	GameState.set_flag("wreck_signal_solved")
	AudioManager.play(&"restore")
	overworld.lumi.react()
	overworld.hud.show_dialogue("The hold creaks open. Inside, wrapped in an old sail, a Hearthstone glows like a small sun.", 6.0)
	grant_hearthstone("isles")


# --- Fox family --------------------------------------------------------------------------

func _on_kit(k: LostKit) -> void:
	var index := 0
	for other in kits:
		if other.state() == "following":
			index += 1
	k.start_following(overworld.player, index)
	AudioManager.play(&"discover", 1.3)
	overworld.hud.show_dialogue("The kit sniffs your hand and decides you are safe. It will follow you; lead it to the fox den in the north-west of the pinewood.", 6.0)


func _on_den() -> void:
	GameState.set_flag("fox_den_visited")
	var home := LostKit.kits_home()
	if home >= kits.size():
		overworld.hud.show_dialogue("The whole fox family is curled up together, warm and safe.", 4.0)
	else:
		overworld.hud.show_dialogue(L.t("A mother ember fox waits by the den, watching the fog. %d of %d kits are home. The others are lost somewhere in the gloom.") % [home, kits.size()], 6.0)


func _complete_fox_family() -> void:
	GameState.set_flag("fox_family_home")
	overworld.hud.show_dialogue("All the kits are home! The mother fox nuzzles each one, then nudges something warm out of the den toward you: a Hearthstone.", 7.0)
	grant_hearthstone("pinewood")


func grant_hearthstone(id: String) -> void:
	var flag := "hearthstone_" + id
	if GameState.has_flag(flag):
		return
	GameState.set_flag(flag)
	var item := String(HEARTHSTONE_ITEMS.get(id, ""))
	if not item.is_empty():
		var left := GameState.give_item(item, 1)
		if left > 0:
			GameState.storage.add(item, left)
	GameState.add_counter("hearthstones")
	overworld.hud.show_toast("Hearthstone found!")
	SaveManager.autosave("found a Hearthstone")
