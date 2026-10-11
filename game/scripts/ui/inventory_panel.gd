class_name InventoryPanel
extends Control
## Inventory and crafting overlay (I / Tab, or E at a workbench).
## Left: the bag. Click a slot to see details; click two slots to swap them
## (the first 8 slots are the hotbar). Right: known recipes, what each needs
## (have / need), the station required, and Craft buttons.

signal closed
signal crafted(recipe_id: String)

const COLUMNS := 8

var station_tier: int = 0
## True when standing near the storage chest: crafting may use its contents.
var use_storage: bool = false
var _grid: GridContainer
var _details: Label
var _recipe_list: VBoxContainer
var _recipe_info: Label
var _craft_one: Button
var _craft_five: Button
var _station_label: Label
var _status: Label
var _selected_slot: int = -1
var _selected_recipe: String = ""
var _slot_buttons: Array[ItemSlot] = []


func setup(tier: int) -> void:
	station_tier = tier
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 1120)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)

	var left := VBoxContainer.new()
	left.add_child(UiKit.label("Bag", UiTheme.HEADING))
	left.add_child(UiKit.label("The first row is your hotbar (keys 1-8). Click two slots to swap them.", UiTheme.SUBTLE, true))
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(_grid)
	_details = UiKit.label("", &"", true)
	_details.custom_minimum_size = Vector2(480, 72)
	left.add_child(_details)
	var sort := UiKit.button("Sort", func() -> void:
		GameState.inventory.sort_items()
		_refresh())
	left.add_child(UiKit.hbox([sort], BoxContainer.ALIGNMENT_BEGIN))
	columns.add_child(left)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 520
	right.add_child(UiKit.label("Crafting", UiTheme.HEADING))
	_station_label = UiKit.label("", UiTheme.SUBTLE, true)
	right.add_child(_station_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipe_list)
	right.add_child(scroll)
	_recipe_info = UiKit.label("Choose a recipe to see what it needs.", &"", true)
	right.add_child(_recipe_info)
	_craft_one = UiKit.button("Craft", func() -> void: _craft(1), UiTheme.PRIMARY_BUTTON)
	_craft_five = UiKit.button("Craft x5", func() -> void: _craft(5))
	right.add_child(UiKit.hbox([_craft_one, _craft_five], BoxContainer.ALIGNMENT_BEGIN))
	_status = UiKit.label("", UiTheme.SUBTLE, true)
	right.add_child(_status)
	columns.add_child(right)

	var close := UiKit.button("Close (I)", close_panel)
	box.add_child(close)
	GameState.inventory.changed.connect(_refresh)
	_refresh()
	if not _slot_buttons.is_empty():
		_slot_buttons[0].call_deferred("grab_focus")


func close_panel() -> void:
	if GameState.inventory.changed.is_connected(_refresh):
		GameState.inventory.changed.disconnect(_refresh)
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputSetup.INVENTORY):
		get_viewport().set_input_as_handled()
		close_panel()


func _refresh() -> void:
	var inv := GameState.inventory
	while _slot_buttons.size() < inv.capacity():
		var slot := ItemSlot.new(52)
		var index := _slot_buttons.size()
		slot.pressed.connect(func() -> void: _on_slot_pressed(index))
		slot.focus_entered.connect(func() -> void: _show_details(index))
		slot.mouse_entered.connect(func() -> void: _show_details(index))
		if index < Inventory.HOTBAR_SIZE:
			slot.hotkey = str(index + 1)
		_grid.add_child(slot)
		_slot_buttons.append(slot)
	for i in _slot_buttons.size():
		var s: Dictionary = inv.slots[i] if i < inv.slots.size() else {}
		_slot_buttons[i].set_item(String(s.get("id", "")), int(s.get("qty", 0)))
		_slot_buttons[i].selected = i == _selected_slot
	var station_name := L.t("your hands")
	if station_tier >= 2:
		station_name = L.t("the cottage workbench")
	elif station_tier == 1:
		station_name = L.t("the workbench")
	_station_label.text = L.t("Crafting with %s. Some recipes need a workbench nearby.") % station_name
	if use_storage:
		_station_label.text += L.t(" Materials in your storage chest count too.")
	_rebuild_recipes()


func _on_slot_pressed(index: int) -> void:
	if _selected_slot < 0:
		_selected_slot = index
	elif _selected_slot == index:
		_selected_slot = -1
	else:
		GameState.inventory.swap(_selected_slot, index)
		_selected_slot = -1
	_refresh()
	_show_details(index)


func _show_details(index: int) -> void:
	var inv := GameState.inventory
	if index >= inv.slots.size() or inv.slots[index].is_empty():
		_details.text = "Empty slot."
		return
	var id := String(inv.slots[index]["id"])
	var text := "%s  x%d\n%s" % [ItemDB.display_name(id), int(inv.slots[index]["qty"]), ItemDB.description(id)]
	if not ItemDB.uses(id).is_empty():
		text += "\n" + L.t("Used for:") + " " + ItemDB.uses(id)
	if ItemDB.is_unique(id):
		text += "\n" + L.t("(Keepsake: this can never be lost.)")
	_details.text = text


func _rebuild_recipes() -> void:
	for c in _recipe_list.get_children():
		c.queue_free()
	var book := GameState.crafting
	var any := false
	for id in book.order:
		if not GameState.known_recipes.has(id) or book.is_cooking(id):
			continue
		any = true
		var check := book.check(id, _stock(), station_tier, GameState.known_recipes)
		var out: Dictionary = book.get_recipe(id)["output"]
		var label := "%s%s" % [ItemDB.display_name(String(out["item"])), L.t("  (ready)") if check["ok"] else ""]
		var b := UiKit.button(label, func() -> void: _select_recipe(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		_recipe_list.add_child(b)
	if not any:
		_recipe_list.add_child(UiKit.label("No recipes yet.", UiTheme.SUBTLE))
	if not _selected_recipe.is_empty():
		_select_recipe(_selected_recipe)
	else:
		_craft_one.disabled = true
		_craft_five.disabled = true


func _select_recipe(id: String) -> void:
	_selected_recipe = id
	var book := GameState.crafting
	var r := book.get_recipe(id)
	var lines := PackedStringArray()
	var out: Dictionary = r["output"]
	lines.append("%s x%d  (%s)" % [ItemDB.display_name(String(out["item"])), int(out["qty"]), L.t(String(r.get("station", "hand")).replace("_2", " (cottage)").replace("_", " "))])
	for part: Dictionary in r.get("inputs", []):
		var have := GameState.inventory.count(String(part["item"])) + (GameState.storage.count(String(part["item"])) if use_storage else 0)
		var need := int(part["qty"])
		lines.append("  %s %s: %d / %d" % ["[ok]" if have >= need else "[  ]", ItemDB.display_name(String(part["item"])), have, need])
	var check := book.check(id, _stock(), station_tier, GameState.known_recipes)
	if not check["ok"]:
		lines.append(L.t(String(check["reason"])))
	_recipe_info.text = "\n".join(lines)
	_craft_one.disabled = not check["ok"]
	_craft_five.disabled = not book.check(id, _stock(), station_tier, GameState.known_recipes, 5)["ok"]


func _craft(qty: int) -> void:
	if _selected_recipe.is_empty():
		return
	if GameState.craft(_selected_recipe, station_tier, qty, use_storage):
		var out: Dictionary = GameState.crafting.get_recipe(_selected_recipe)["output"]
		_status.text = L.t("Crafted %s x%d.") % [ItemDB.display_name(String(out["item"])), int(out["qty"]) * qty]
		AudioManager.play(&"bloom")
		crafted.emit(_selected_recipe)
	else:
		_status.text = "Not possible right now. There may be no room in your bag for the result."
		AudioManager.play(&"soft_deny")
	_refresh()


func _stock() -> Array:
	return [GameState.inventory, GameState.storage] if use_storage else [GameState.inventory]
