class_name VillageController
extends Node
## The spirit village east of the Heart Tree, the Act 2 / Act 3 story beats
## at the Heart Tree, and quest rewards.
## - Villagers arrive as the world is restored (data: "arrives" conditions),
##   first living in a tent until the player helps build their home.
## - A request board offers small, never-expiring requests.
## - The village visibly grows: homes, lanterns, a market stall, a campfire
##   with music notes in the evening.
## - The Hearthstone circle at the Heart Tree: Act 2's intro, placing the
##   five Hearthstones, and the Act 3 finale (the Festival of Light).

signal finale_finished

const ARRIVAL_CHECK := 1.0
const FINALE_SECONDS := 9.0

var overworld: Overworld
var villagers: Dictionary = {}
var homes: Dictionary = {}
var home_sites: Dictionary = {}
var board: RequestBoard
var fire: VillageFire
var stall: Node2D
var circle: HearthCircle
var finale_running: bool = false
var _timer: float = 0.0


func build(ow: Overworld) -> void:
	overworld = ow
	for id in VillageDB.ids():
		var v := VillageDB.villager(id)
		var h: Array = v["home"]["pos"]
		var home_pos := Vector2(float(h[0]), float(h[1]))
		var view := Villager.HomeView.new()
		view.villager_id = id
		view.position = home_pos
		ow.entities.add_child(view)
		homes[id] = view
		var site := RestorationSite.new()
		site.setup(String(v["home"]["site"]), home_pos)
		site.interactable_id = String(v["home"]["site"])
		site.hide_sign_when_complete = true
		site.interacted.connect(func(_t: Interactable) -> void: _on_home(id))
		site.completed.connect(func(_s: RestorationSite) -> void: _on_home_built(id))
		ow.entities.add_child(site)
		home_sites[id] = site
		var npc := Villager.new()
		npc.setup(id)
		npc.interacted.connect(func(_t: Interactable) -> void: open_villager(id))
		ow.entities.add_child(npc)
		villagers[id] = npc
	for p: Dictionary in ow.world.pois:
		match String(p["kind"]):
			"request_board":
				board = RequestBoard.new()
				board.interactable_id = String(p["id"])
				board.position = p["pos"]
				board.interacted.connect(func(_t: Interactable) -> void: ow.open_request_board())
				ow.entities.add_child(board)
			"campfire":
				fire = VillageFire.new()
				fire.position = p["pos"]
				ow.entities.add_child(fire)
			"market_stall":
				stall = MarketStall.new()
				stall.position = p["pos"]
				ow.entities.add_child(stall)
			"hearth_circle":
				circle = HearthCircle.new()
				circle.interactable_id = String(p["id"])
				circle.position = p["pos"]
				circle.interacted.connect(func(_t: Interactable) -> void: _on_circle())
				ow.entities.add_child(circle)
	EventBus.quest_completed.connect(_on_quest_completed)
	_sync_village()


func set_night_amount(amount: float) -> void:
	for view: Villager.HomeView in homes.values():
		view.set_night_amount(amount)
	if fire != null:
		fire.set_night_amount(amount)
	if circle != null:
		circle.night = amount


func _process(delta: float) -> void:
	if overworld == null:
		return
	_timer += delta
	if _timer < ARRIVAL_CHECK:
		return
	_timer = 0.0
	check_arrivals()


## Villagers whose arrival condition is met move in (once).
func check_arrivals() -> Array[String]:
	var arrived: Array[String] = []
	for id in VillageDB.ids():
		if VillageDB.has_arrived(id):
			continue
		var cond: Dictionary = VillageDB.villager(id).get("arrives", {})
		if QuestBook.condition_met(cond, QuestManager.facts):
			GameState.set_flag("villager_arrived:" + id)
			GameState.add_counter("villagers_arrived")
			arrived.append(id)
			if overworld.current_sublevel.is_empty() and not finale_running:
				overworld.hud.show_toast(L.t("%s moved into the village!") % VillageDB.display_name(id))
				overworld.hud.show_dialogue(L.t(String(VillageDB.villager(id).get("arrival_text", ""))), 6.0)
	if not arrived.is_empty():
		_sync_village()
		QuestManager.request_refresh()
	return arrived


func _sync_village() -> void:
	for view: Villager.HomeView in homes.values():
		view.sync()
	for id: String in home_sites:
		(home_sites[id] as RestorationSite).visible = VillageDB.has_arrived(id)
	var built := 0
	for id in VillageDB.ids():
		if VillageDB.home_built(id):
			built += 1
	if board != null:
		board.visible = VillageDB.arrived_count() > 0
		board.lanterns = built
		board.queue_redraw()
	if stall != null:
		stall.visible = built >= 3
	if fire != null:
		fire.visible = VillageDB.arrived_count() > 0
		fire.villagers_home = built


func _on_home(id: String) -> void:
	var site: RestorationSite = home_sites[id]
	if not RestorationSite.is_complete(site.site_id):
		overworld.open_site_panel(site)
		return
	var npc: Villager = villagers[id]
	if npc.is_asleep():
		overworld.hud.show_dialogue(L.t(String((VillageDB.villager(id).get("lines", {}) as Dictionary).get("night", "Zzz..."))), 3.0)
	else:
		overworld.hud.show_dialogue(L.t("%s's home. It looks lived in and very cosy.") % VillageDB.display_name(id), 3.0)


func _on_home_built(id: String) -> void:
	VillageDB.add_points(id, 10)
	AudioManager.play(&"restore")
	overworld.lumi.react()
	overworld.hud.show_dialogue(L.t("%s's new home is finished! \"It's perfect. Thank you, truly.\"") % VillageDB.display_name(id), 5.0)
	_sync_village()
	SaveManager.autosave("built a home")
	QuestManager.request_refresh()


func open_villager(id: String) -> void:
	overworld.open_villager_panel(id)


## Quest rewards ("rewards" in quest data): items, friendship, cosmetics.
func _on_quest_completed(quest_id: String) -> void:
	var q := QuestManager.book.get_quest(quest_id)
	var r: Dictionary = q.get("rewards", {})
	if r.is_empty():
		return
	for it: Dictionary in r.get("items", []):
		var left := GameState.give_item(String(it["item"]), int(it.get("qty", 1)))
		if left > 0:
			GameState.storage.add(String(it["item"]), left)
	var f: Dictionary = r.get("friendship", {})
	if not f.is_empty():
		VillageDB.add_points(String(f["villager"]), int(f.get("points", 0)))
	var cosmetic := String(r.get("cosmetic", ""))
	if not cosmetic.is_empty():
		Cosmetics.unlock(cosmetic)


## Lumi's hint near the village ("" if not near).
func hint_near(pos: Vector2) -> String:
	if board != null and board.visible and pos.distance_to(board.global_position) < 700.0:
		for id in VillageDB.ids():
			if VillageDB.has_arrived(id) and not VillageDB.home_built(id):
				return L.t("%s is still living in a tent. Press E at the tent to see what the new home needs.") % VillageDB.display_name(id)
		return "Villagers love gifts they like, once a day. The request board has small favours, and none of them ever expire."
	if circle != null and pos.distance_to(circle.global_position) < 400.0 and GameState.has_flag("act1_complete") and not GameState.has_flag("act3_complete"):
		return "The stone circle in front of the Heart Tree is waiting for something. Press E there."
	return ""


# --- Act 2 / Act 3 at the Heart Tree ----------------------------------------------------

func hearthstones_found() -> int:
	var n := 0
	for k in ["pinewood", "coast", "isles", "caverns", "highlands"]:
		if GameState.has_flag("hearthstone_" + k):
			n += 1
	return n


func _on_circle() -> void:
	var hud := overworld.hud
	if not GameState.has_flag("act2_heard"):
		GameState.set_flag("act2_heard")
		overworld.lumi.react()
		AudioManager.play(&"discover")
		hud.show_dialogue("The Heart Tree's light only reaches the meadow. Far away, five Hearthstones sleep: in the misty pines, by the dark lighthouse, on a shipwrecked isle, in the singing caves, and under the highland aurora. Together they could carry the light everywhere.", 9.0)
		QuestManager.request_refresh()
		return
	if not GameState.has_flag("hearthstones_placed"):
		var found := hearthstones_found()
		if found < 5:
			hud.show_dialogue(L.t("%d of 5 Hearthstones found. The empty stones in the circle wait patiently.") % found, 5.0)
			return
		GameState.set_flag("hearthstones_placed")
		AudioManager.play(&"restore")
		overworld.lumi.react()
		circle.queue_redraw()
		hud.show_dialogue("One by one, the Hearthstones settle into the circle and begin to hum together. Everyone should see what happens next. Invite your friends to a Festival of Light!", 7.0)
		QuestManager.request_refresh()
		return
	if GameState.has_flag("act3_complete"):
		hud.show_dialogue("The Great Lantern glows above the Heart Tree. Lumeria is bright again.", 4.0)
		return
	var invites := GameState.counter("festival_invites")
	if invites < VillageDB.ids().size():
		hud.show_dialogue(L.t("The Hearthstones are ready. %d of %d friends invited to the festival so far.") % [invites, VillageDB.ids().size()], 5.0)
		return
	play_finale()


## The Festival of Light: everyone gathers, the Hearthstones send their light
## through the Heart Tree, and all of Lumeria brightens. Nothing can go wrong.
func play_finale(fast: bool = false) -> void:
	if finale_running or GameState.has_flag("act3_complete"):
		return
	finale_running = true
	var center := circle.global_position
	var i := 0
	var ids := VillageDB.ids()
	for id in ids:
		var npc: Villager = villagers[id]
		var a := PI + PI * (float(i) + 0.5) / float(ids.size())
		npc.festival_spot = center + Vector2(cos(a) * 230.0, 120.0 + sin(a) * -60.0)
		# A small cutscene: everyone is already gathered when it begins.
		npc.global_position = npc.festival_spot
		i += 1
	overworld.player.block_input(FINALE_SECONDS if not fast else 0.1)
	overworld.fade_night(true)
	AudioManager.play(&"night")
	var hud := overworld.hud
	if not fast:
		hud.show_dialogue("Everyone has gathered around the Heart Tree. Bramble brought flowers, Mossa brought soup, Wren brought songs, Pip brought everyone else, and Fennel begins the oldest story there is...", 4.5)
		await get_tree().create_timer(3.5).timeout
	circle.start_beams()
	AudioManager.play(&"restore")
	if not fast:
		await get_tree().create_timer(3.0).timeout
	overworld.play_world_restoration()
	for patch: GloomPatch in overworld.features.patches.values():
		patch.clear_gloom(true, true)
	GameState.set_flag("act3_complete")
	GameState.set_flag("lumeria_restored")
	overworld.lumi.react()
	hud.show_banner("The Light returns to all of Lumeria")
	if not fast:
		await get_tree().create_timer(2.5).timeout
	for id in ids:
		(villagers[id] as Villager).festival_spot = Vector2.INF
	# The cutscene's night lifts again; from here the clock decides day and night.
	overworld.fade_night(false)
	finale_running = false
	QuestManager.request_refresh()
	SaveManager.autosave("the Festival of Light")
	finale_finished.emit()
	if not fast:
		overworld.show_finale_panel()


## The village notice board with up to three small, never-expiring requests.
class RequestBoard extends Interactable:
	var lanterns: int = 0
	var _t: float = 0.0

	func _ready() -> void:
		reach_bonus = 26.0
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(110, 24)
		col.shape = shape
		col.position = Vector2(0, -8)
		body.add_child(col)
		add_child(body)

	func get_prompt() -> String:
		return L.t("Read the request board (%d open)") % VillageDB.open_requests().size()

	func _process(delta: float) -> void:
		super(delta)
		_t += delta * GameSettings.motion_scale()
		if ViewCull.near(global_position):
			queue_redraw()

	func _draw() -> void:
		BiomeDecorArt.shadow(self, 60.0)
		for x: float in [-46.0, 46.0]:
			draw_rect(Rect2(x - 4, -70, 8, 70), Palette.BARK_DARK)
		draw_rect(Rect2(-58, -96, 116, 54), Palette.BARK)
		draw_rect(Rect2(-52, -90, 104, 42), Color("#e8d6b0"))
		var open := VillageDB.open_requests().size()
		for i in 3:
			var c := Palette.CREAM if i < open else Palette.with_alpha(Palette.CREAM, 0.25)
			draw_rect(Rect2(-44 + i * 32, -84, 24, 30), c)
			if i < open:
				draw_line(Vector2(-40 + i * 32, -76), Vector2(-24 + i * 32, -76), Palette.INK_SOFT, 1.5)
				draw_line(Vector2(-40 + i * 32, -68), Vector2(-28 + i * 32, -68), Palette.INK_SOFT, 1.5)
		# One string of lanterns per finished home: the village grows.
		for i in mini(lanterns * 2, 10):
			var x := -120.0 + i * 26.0
			var y := -118.0 + sin(float(i) * 0.9) * 6.0
			draw_circle(Vector2(x, y), 6.0 + sin(_t * 2.0 + i) * 0.6, [Palette.GOLD, Color("#f7b2c4"), Palette.SKY][i % 3])
		draw_interaction_cues(40.0, Vector2(0, -40))


## The village campfire: lit in the evening, with music notes when friends gather.
class VillageFire extends Node2D:
	var villagers_home: int = 0
	var _light: PointLight2D
	var _t: float = 0.0
	var _night: float = 0.0

	func _ready() -> void:
		_light = GlowTexture.make_light(Palette.GOLD_DEEP, 2.2, 0.0)
		_light.position = Vector2(0, -20)
		add_child(_light)
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 26.0
		col.shape = shape
		body.add_child(col)
		add_child(body)

	func set_night_amount(amount: float) -> void:
		_night = amount
		_light.enabled = visible and amount > 0.05
		_light.energy = 0.8 * amount

	func evening() -> bool:
		var hour := TimeManager.minute_of_day / 60.0
		return hour >= 17.0 and hour < 21.0

	func _process(delta: float) -> void:
		_t += delta * GameSettings.motion_scale()
		if visible and ViewCull.near(global_position):
			queue_redraw()

	func _draw() -> void:
		BiomeDecorArt.shadow(self, 34.0)
		for i in 7:
			var a := TAU * float(i) / 7.0
			draw_circle(Vector2(cos(a) * 28.0, sin(a) * 12.0), 7.0, Palette.STONE_DARK)
		draw_line(Vector2(-16, -2), Vector2(16, -8), Palette.BARK_DARK, 6.0)
		draw_line(Vector2(-16, -8), Vector2(16, -2), Palette.BARK, 6.0)
		var lit := evening() or _night > 0.3
		if lit:
			var f := 1.0 + 0.15 * sin(_t * 8.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-16, -6), Vector2(16, -6), Vector2(0, -6 - 36.0 * f)]), Palette.GOLD_DEEP)
			draw_colored_polygon(PackedVector2Array([Vector2(-8, -6), Vector2(8, -6), Vector2(0, -6 - 22.0 * f)]), Palette.GOLD_SOFT)
			if villagers_home >= 2:
				for i in 3:
					var k := fposmod(_t * 0.3 + i / 3.0, 1.0)
					var p := Vector2(30 + sin(k * TAU) * 14.0, -40 - k * 70.0)
					draw_circle(p, 3.5, Palette.with_alpha(Palette.IVORY, 1.0 - k))
					draw_line(p + Vector2(3, 0), p + Vector2(3, -12), Palette.with_alpha(Palette.IVORY, 1.0 - k), 1.5)


## A small market stall that appears once three homes are built.
class MarketStall extends Node2D:
	func _ready() -> void:
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(120, 30)
		col.shape = shape
		col.position = Vector2(0, -12)
		body.add_child(col)
		add_child(body)

	func _draw() -> void:
		BiomeDecorArt.shadow(self, 70.0)
		draw_rect(Rect2(-60, -40, 120, 34), Palette.BARK)
		for i in 6:
			draw_rect(Rect2(-60 + i * 20, -96, 20, 22), Color("#e9867a") if i % 2 == 0 else Palette.CREAM)
		for x: float in [-56.0, 56.0]:
			draw_rect(Rect2(x - 3, -96, 6, 90), Palette.BARK_DARK)
		for i in 4:
			ItemArt.draw(self, Vector2(-42 + i * 28, -48), 18.0, ["carrot", "pumpkin", "strawberry", "wheat"][i])


## The Hearthstone circle in front of the Heart Tree.
class HearthCircle extends Interactable:
	var night: float = 0.0
	var _t: float = 0.0
	var _beams: float = 0.0

	func _ready() -> void:
		reach_bonus = 30.0

	func can_interact() -> bool:
		return GameState.has_flag("act1_complete") and super.can_interact()

	func get_prompt() -> String:
		if not GameState.has_flag("act2_heard"):
			return "Listen to the Heart Tree"
		if not GameState.has_flag("hearthstones_placed"):
			return "Set the Hearthstones in the circle" if _found() >= 5 else "Look at the Hearthstone circle"
		if not GameState.has_flag("act3_complete"):
			return "Light the Great Lantern"
		return "Admire the Great Lantern"

	func _found() -> int:
		var n := 0
		for k in ["pinewood", "coast", "isles", "caverns", "highlands"]:
			if GameState.has_flag("hearthstone_" + k):
				n += 1
		return n

	func start_beams() -> void:
		create_tween().tween_property(self, "_beams", 1.0, 2.5 * maxf(GameSettings.motion_scale(), 0.4))

	func _process(delta: float) -> void:
		super(delta)
		_t += delta * GameSettings.motion_scale()
		if ViewCull.near(global_position, 500.0):
			queue_redraw()

	func _draw() -> void:
		if not GameState.has_flag("act1_complete"):
			return
		var placed := GameState.has_flag("hearthstones_placed")
		var done := GameState.has_flag("act3_complete")
		var keys := ["pinewood", "coast", "isles", "caverns", "highlands"]
		var tree := Vector2(0, -110)
		for i in 5:
			var a := PI + PI * (float(i) + 0.5) / 5.0
			var p := Vector2(cos(a) * 150.0, 10.0 + sin(a) * -40.0)
			draw_set_transform(p + Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, 16.0, Palette.SHADOW)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_rect(Rect2(p + Vector2(-10, -18), Vector2(20, 18)), Palette.STONE)
			var has := GameState.has_flag("hearthstone_" + String(keys[i]))
			if placed or done:
				ItemArt.draw(self, p + Vector2(0, -28), 20.0, "hearthstone_" + String(keys[i]))
				draw_circle(p + Vector2(0, -28), 14.0 + sin(_t * 2.0 + i) * 2.0, Palette.with_alpha(Palette.GOLD, 0.25))
			elif has:
				draw_circle(p + Vector2(0, -24), 4.0, Palette.with_alpha(Palette.GOLD, 0.7))
			if _beams > 0.0 or done:
				var k := 1.0 if done else _beams
				draw_line(p + Vector2(0, -28), p.lerp(tree, k) + Vector2(0, -28) * (1.0 - k), Palette.with_alpha(Palette.GOLD_SOFT, 0.6 * (0.6 + 0.4 * night)), 4.0)
		if done:
			var pulse := 0.8 + 0.2 * sin(_t * 1.5)
			draw_circle(tree + Vector2(0, -120), 40.0 * pulse, Palette.with_alpha(Palette.GOLD_SOFT, 0.35))
			draw_circle(tree + Vector2(0, -120), 16.0, Palette.with_alpha(Palette.IVORY, 0.9))
		draw_interaction_cues(30.0, Vector2(0, -8))
