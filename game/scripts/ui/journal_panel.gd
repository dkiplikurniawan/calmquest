class_name JournalPanel
extends Control
## The Traveler's Journal (J): tabs for quests, the map, creatures, fish,
## recipes, lore, collections and villagers. Read-only views of GameState,
## QuestManager and SessionState; tabs fill in as the world is explored.
## Tabs switch with the mouse, or with Q / E (and [ / ]) on the keyboard.

signal closed

const TAB_KEYS_PREV := [KEY_Q, KEY_BRACKETLEFT]
const TAB_KEYS_NEXT := [KEY_E, KEY_BRACKETRIGHT]

var tabs: TabContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 940)
	box.add_child(UiKit.label("Traveler's Journal", UiTheme.HEADING))
	box.add_child(UiKit.label("Q / E switch pages.", UiTheme.SUBTLE))
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(900, 430)
	box.add_child(tabs)
	_add_tab("Quests", _quests_tab())
	_add_tab("Map", _map_tab())
	_add_tab("Creatures", _creatures_tab())
	_add_tab("Fish", _fish_tab())
	_add_tab("Recipes", _recipes_tab())
	_add_tab("Lore", _lore_tab())
	_add_tab("Collections", _collections_tab())
	_add_tab("Villagers", _villagers_tab())
	var close_button := UiKit.button("Close", close, UiTheme.PRIMARY_BUTTON)
	box.add_child(close_button)
	close_button.call_deferred("grab_focus")


func _add_tab(title: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	tabs.add_child(scroll)


func _vbox() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	return v


func _line(parent: Container, text: String, variation: StringName = &"") -> void:
	parent.add_child(UiKit.label(text, variation, true))


# --- Tabs ------------------------------------------------------------------------------

func _quests_tab() -> Control:
	var v := _vbox()
	var book := QuestManager.book
	var active := book.quests_with_status(QuestBook.ACTIVE)
	if active.is_empty():
		_line(v, "No open quests right now. Wander wherever you like.", UiTheme.SUBTLE)
	for q in active:
		var id := String(q["id"])
		var row := HBoxContainer.new()
		var text := "%s%s\n    %s" % [L.t(String(q["title"])), L.t("  (followed)") if id == QuestManager.tracked_id else "", book.step_text(id, QuestManager.facts)]
		var label := UiKit.label(text, &"", true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if id != QuestManager.tracked_id:
			var follow := UiKit.button("Follow", func() -> void:
				QuestManager.track(id)
				close())
			row.add_child(follow)
		v.add_child(row)
	var done := book.quests_with_status(QuestBook.COMPLETED)
	if not done.is_empty():
		v.add_child(HSeparator.new())
		_line(v, "Completed", UiTheme.SUBTLE)
		for q in done:
			_line(v, "  %s" % L.t(String(q["title"])))
	return v


func _map_tab() -> Control:
	var v := _vbox()
	_line(v, L.t("Map explored: %d%%   (open the full map with M)") % int(round(GameState.revealed_fraction() * 100.0)))
	_line(v, L.t("Waystones relit: %d") % GameState.restored_waystones().size())
	_line(v, L.t("Landmarks seen: %d") % GameState.seen_landmarks.size())
	v.add_child(HSeparator.new())
	_line(v, "Places visited", UiTheme.SUBTLE)
	var world := WorldData.load_from()
	for region: String in world.regions:
		var info: Dictionary = world.regions[region]
		if String(info.get("status", "")) == "boundary":
			continue
		if GameState.has_visited(region):
			_line(v, "  %s - %s" % [L.t(String(info.get("name", region))), L.t(String(info.get("subtitle", "")))])
		else:
			_line(v, "  ??? - somewhere not yet visited", UiTheme.SUBTLE)
	return v


func _creatures_tab() -> Control:
	var v := _vbox()
	var ids := CreatureDB.all_ids()
	_line(v, L.t("Sketched: %d of %d. Creatures come closer when you stand still; watching calmly for a few seconds sketches them.") % [CreatureDB.sketched_count(), ids.size()], UiTheme.SUBTLE)
	var world := WorldData.load_from()
	for id in ids:
		var c := CreatureDB.get_creature(id)
		var where := PackedStringArray()
		for r: String in c.get("regions", []):
			where.append(world.region_display(r))
		var when := L.t(String({"day": "by day", "night": "at night", "any": "day or night"}.get(String(c.get("time", "any")), "")))
		var weather: Array = c.get("weather", [])
		if not weather.is_empty():
			when += L.t(", in the %s") % ", ".join(L.each(weather))
		if CreatureDB.is_sketched(id):
			var f := CreatureDB.friendship(id)
			var petals := "*".repeat(f) + "-".repeat(CreatureDB.MAX_FRIENDSHIP - f)
			_line(v, L.t("%s   [friendship %s]\n    %s\n    Seen in %s, %s.") % [L.t(String(c["name"])), petals, L.t(String(c.get("desc", ""))), ", ".join(where), when])
		elif CreatureDB.is_seen(id):
			_line(v, L.t("%s - glimpsed. Watch it quietly to sketch it.") % L.t(String(c["name"])))
		else:
			_line(v, L.t("??? - lives in %s, %s.") % [", ".join(where), when], UiTheme.SUBTLE)
	return v


func _fish_tab() -> Control:
	var v := _vbox()
	var ids := Fishing.all_fish()
	_line(v, L.t("Kinds caught: %d of %d. Fish change with the water (creek, pond, sea), the time of day and the weather.") % [Fishing.species_caught(), ids.size()], UiTheme.SUBTLE)
	for id in ids:
		var f := Fishing.fish_data(id)
		var waters := ", ".join(L.each(f.get("waters", [])))
		var when := L.t(String({"day": "by day", "night": "at night", "any": "any time"}.get(String(f.get("time", "any")), "")))
		var weather: Array = f.get("weather", [])
		if not weather.is_empty():
			when += L.t(", in the %s") % L.t(" or ").join(L.each(weather))
		if Fishing.caught(id) > 0:
			_line(v, L.t("%s  - caught %d, biggest %d cm\n    %s\n    %s, %s.") % [ItemDB.display_name(id), Fishing.caught(id), Fishing.biggest(id), ItemDB.description(id), waters.capitalize(), when])
		elif bool(f.get("legendary", false)):
			_line(v, "??? - a legend of the creek. Catch five kinds of fish first.", UiTheme.SUBTLE)
		else:
			_line(v, L.t("??? - %s, %s.") % [waters, when], UiTheme.SUBTLE)
	return v


func _villagers_tab() -> Control:
	var v := _vbox()
	var any := false
	for id in VillageDB.ids():
		if not VillageDB.has_arrived(id):
			continue
		any = true
		var d := VillageDB.villager(id)
		var p := VillageDB.petals(id)
		var loves := PackedStringArray()
		for it: String in d.get("loves", []):
			loves.append(ItemDB.display_name(it))
		var home := L.t("home built") if VillageDB.home_built(id) else L.t("living in a tent (help build a home!)")
		_line(v, L.t("%s, %s   [%s%s]\n    %s\n    Loves: %s. %s.") % [L.t(String(d["name"])), L.t(String(d.get("title", ""))), "*".repeat(p), "-".repeat(VillageDB.MAX_PETALS - p), L.t(String(d.get("personality", ""))), ", ".join(loves), home.capitalize()])
	if not any:
		_line(v, "Spirit villagers move into the meadow as the world is restored. The first one arrives when the Heart Tree glows again.", UiTheme.SUBTLE)
	var waiting := VillageDB.ids().size() - VillageDB.arrived_count()
	if any and waiting > 0:
		_line(v, L.t("%d more may arrive as you restore the world.") % waiting, UiTheme.SUBTLE)
	return v


func _recipes_tab() -> Control:
	var v := _vbox()
	var book := GameState.crafting
	var crafting := PackedStringArray()
	var cooking := PackedStringArray()
	var unknown := 0
	for id in book.order:
		var r := book.get_recipe(id)
		var out := ItemDB.display_name(String(r["output"]["item"]))
		if not GameState.known_recipes.has(id):
			unknown += 1
			continue
		var parts := PackedStringArray()
		for part: Dictionary in r.get("inputs", []):
			parts.append("%d %s" % [int(part["qty"]), ItemDB.display_name(String(part["item"]))])
		var line := "  %s: %s" % [out, ", ".join(parts)]
		if book.is_cooking(id):
			cooking.append(line)
		else:
			crafting.append(line)
	_line(v, L.t("Crafting (%d)") % crafting.size(), UiTheme.SUBTLE)
	_line(v, "\n".join(crafting) if not crafting.is_empty() else "  None yet.")
	_line(v, L.t("Cooking (%d)") % cooking.size(), UiTheme.SUBTLE)
	_line(v, "\n".join(cooking) if not cooking.is_empty() else "  None yet.")
	_line(v, L.t("Recipes still to discover: %d (from notes, restoring places, and experimenting at the pot).") % unknown, UiTheme.SUBTLE)
	return v


func _lore_tab() -> Control:
	var v := _vbox()
	if GameState.lore_read.is_empty():
		_line(v, "Old notes you read will be kept here. They are optional, but some teach recipes.", UiTheme.SUBTLE)
	for id: String in GameState.lore_read:
		var note := LoreNote.note_data(id)
		_line(v, L.t(String(note.get("title", id))), UiTheme.SUBTLE)
		_line(v, L.t(String(note.get("text", ""))))
	return v


func _collections_tab() -> Control:
	var v := _vbox()
	_line(v, "Collections", UiTheme.SUBTLE)
	var creatures := CreatureDB.all_ids().size()
	var fish := Fishing.all_fish().size()
	var notes := LoreNote.all_note_ids().size()
	var recipes := GameState.crafting.order.size()
	var decor := ItemDB.ids_in_category("decor").size()
	var decor_owned := 0
	for id in ItemDB.ids_in_category("decor"):
		if GameState.counter("obtained:" + id) > 0 or GameState.counter("placed:" + id) > 0:
			decor_owned += 1
	var rows := [["Creatures sketched", CreatureDB.sketched_count(), creatures], ["Fish caught", Fishing.species_caught(), fish], ["Recipes known", GameState.known_recipes.size(), recipes], ["Notes read", GameState.lore_read.size(), notes], ["Decorations found", decor_owned, decor], ["Best friends", GameState.counter("villager_best_friends"), VillageDB.ids().size()]]
	for r: Array in rows:
		_line(v, L.t("  %s: %d of %d  (%d%%)") % [L.t(String(r[0])), r[1], r[2], int(round(100.0 * float(r[1]) / maxf(1.0, float(r[2]))))])
	v.add_child(HSeparator.new())
	_line(v, "Wardrobe (purely cosmetic)", UiTheme.SUBTLE)
	var cloaks := HFlowContainer.new()
	for key: String in Cosmetics.CLOAKS:
		var unlocked := Cosmetics.is_unlocked("cloak:" + key)
		var label := L.t(String(Cosmetics.CLOAKS[key]["name"])) if unlocked else L.t("??? (a friend's gift)")
		var b := UiKit.button(("> " if Cosmetics.current("cloak") == key else "") + label, func() -> void: _wear("cloak:" + key))
		b.disabled = not unlocked
		cloaks.add_child(b)
	v.add_child(cloaks)
	var glows := HFlowContainer.new()
	for key: String in Cosmetics.GLOWS:
		var unlocked := Cosmetics.is_unlocked("glow:" + key)
		var label := L.t(String(Cosmetics.GLOWS[key]["name"])) if unlocked else L.t("??? (a friend's gift)")
		var b := UiKit.button(("> " if Cosmetics.current("glow") == key else "") + label, func() -> void: _wear("glow:" + key))
		b.disabled = not unlocked
		glows.add_child(b)
	v.add_child(glows)
	v.add_child(HSeparator.new())
	var stones := 0
	for item in ["hearthstone_pinewood", "hearthstone_coast", "hearthstone_isles", "hearthstone_caverns", "hearthstone_highlands"]:
		if GameState.has_flag(item):
			stones += 1
	_line(v, L.t("Hearthstones found: %d of 5") % stones)
	_line(v, L.t("Gloom cleared: %d    Gloomlings comforted: %d") % [GameState.counter("gloom_cleared"), GameState.counter("gloomlings_calmed")])
	_line(v, L.t("Creature friends: %d    Boat trips: %d") % [GameState.counter("creature_friends"), GameState.counter("boat_trips")])
	v.add_child(HSeparator.new())
	_line(v, "This session", UiTheme.SUBTLE)
	var s := SessionState
	var lines := PackedStringArray()
	lines.append(L.t("Light motes gathered: %d of %d") % [s.lights_collected, SessionState.TOTAL_MEADOW_LIGHTS])
	if s.bonus_collected > 0:
		lines.append(L.t("Prism Motes (Playful bonus): %d") % s.bonus_collected)
	lines.append(L.t("Light you are carrying: %d") % s.light_balance)
	lines.append(L.t("Heart Tree: %s") % (L.t("restored") if s.heart_tree_restored else L.t("dim")))
	lines.append(L.t("Garden beds in bloom: %d of %d") % [s.bloomed_beds.size(), SessionState.GARDEN_BED_COUNT])
	lines.append(L.t("Lanterns released: %d") % s.lanterns_collected)
	_line(v, "\n".join(lines))
	_line(v, "Hidden details", UiTheme.SUBTLE)
	var details := PackedStringArray()
	for id: String in MeadowLayout.DISCOVERIES:
		var kind: int = MeadowLayout.DISCOVERIES[id][0]
		var title: String = HiddenDetail.TITLES[kind]
		if s.discoveries_this_session.has(id):
			details.append(L.t("%s - found this session") % L.t(title))
		elif s.progress.discoveries.has(id):
			details.append(L.t("%s - found on an earlier visit") % L.t(title))
		else:
			details.append(L.t("??? - something is hidden in the meadow"))
	_line(v, "\n".join(details))
	_line(v, L.t("Across all visits: Heart Tree restored %d time(s), Lantern Nights completed %d.") % [s.progress.heart_tree_restorations, s.progress.lantern_nights_completed], UiTheme.SUBTLE)
	return v


func _wear(key: String) -> void:
	Cosmetics.select(key)
	AudioManager.play(&"ui_click")
	var current := tabs.current_tab
	for c in tabs.get_children():
		if c.name == "Collections":
			var content := (c as ScrollContainer).get_child(0)
			content.queue_free()
			var fresh := _collections_tab()
			fresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.add_child(fresh)
	tabs.current_tab = current


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputSetup.JOURNAL):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(InputSetup.HOTBAR_PREV) or event.is_action_pressed(InputSetup.HOTBAR_NEXT):
		var step := 1 if event.is_action_pressed(InputSetup.HOTBAR_NEXT) else -1
		tabs.current_tab = posmod(tabs.current_tab + step, tabs.get_tab_count())
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key := (event as InputEventKey).physical_keycode
		if key in TAB_KEYS_PREV:
			tabs.current_tab = posmod(tabs.current_tab - 1, tabs.get_tab_count())
			get_viewport().set_input_as_handled()
		elif key in TAB_KEYS_NEXT:
			tabs.current_tab = posmod(tabs.current_tab + 1, tabs.get_tab_count())
			get_viewport().set_input_as_handled()
