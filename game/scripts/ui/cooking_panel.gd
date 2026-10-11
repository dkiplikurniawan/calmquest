class_name CookingPanel
extends Control
## Cooking at the cottage pot. Left: dishes you know, with what they need.
## Right: experiment by choosing ingredients; a matching combination teaches a
## new dish. Experimenting never uses anything up. Food gives only optional,
## gentle, temporary buffs; there are no hunger meters.

signal closed

const MAX_INGREDIENTS := 3

var use_storage: bool = false
var _list: VBoxContainer
var _info: Label
var _cook: Button
var _selected: String = ""
var _ingredients: Dictionary = {}
var _ingredient_box: HFlowContainer
var _status: Label


func setup(storage: bool) -> void:
	use_storage = storage
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 1060)
	box.add_child(UiKit.label("Cooking pot", UiTheme.HEADING))
	box.add_child(UiKit.label("Food gives a gentle, optional boost for a little while. There is no hunger, and not eating is always fine.", UiTheme.SUBTLE, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 470
	left.add_child(UiKit.label("Dishes you know", UiTheme.SUBTLE))
	_list = VBoxContainer.new()
	left.add_child(_list)
	_info = UiKit.label("", &"", true)
	left.add_child(_info)
	_cook = UiKit.button("Cook", _do_cook, UiTheme.PRIMARY_BUTTON)
	left.add_child(_cook)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 470
	right.add_child(UiKit.label("Experiment", UiTheme.SUBTLE))
	right.add_child(UiKit.label("Pick up to three ingredients you carry and try them together. If they make a dish, you'll learn it. Nothing is used up.", &"", true))
	_ingredient_box = HFlowContainer.new()
	right.add_child(_ingredient_box)
	right.add_child(UiKit.button("Try this combination", _try))
	row.add_child(left)
	row.add_child(right)
	box.add_child(row)
	_status = UiKit.label("", UiTheme.SUBTLE, true)
	box.add_child(_status)
	var close := UiKit.button("Close", close_panel)
	box.add_child(close)
	_refresh()
	close.call_deferred("grab_focus")


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func _stock() -> Array:
	return [GameState.inventory, GameState.storage] if use_storage else [GameState.inventory]


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var book := GameState.crafting
	for id in book.order:
		if not book.is_cooking(id) or not GameState.known_recipes.has(id):
			continue
		if _selected.is_empty():
			_selected = id
		var ok: bool = book.check(id, _stock(), CraftingBook.COOKING_TIER, GameState.known_recipes)["ok"]
		var b := UiKit.button("%s%s" % [ItemDB.display_name(String(book.get_recipe(id)["output"]["item"])), L.t("  (ready)") if ok else ""], func() -> void: _select(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(b)
	for c in _ingredient_box.get_children():
		c.queue_free()
	var seen := {}
	for s in GameState.inventory.slots:
		if s.is_empty():
			continue
		var id := String(s["id"])
		if seen.has(id) or not ["resource", "crop", "fish", "magic"].has(ItemDB.category(id)):
			continue
		seen[id] = true
		var t := Button.new()
		t.toggle_mode = true
		t.text = ItemDB.display_name(id)
		t.button_pressed = _ingredients.has(id)
		t.toggled.connect(func(on: bool) -> void: _toggle_ingredient(id, on, t))
		UiKit.wire_feedback(t)
		_ingredient_box.add_child(t)
	if not _selected.is_empty():
		_select(_selected)
	else:
		_cook.disabled = true


func _select(id: String) -> void:
	_selected = id
	var book := GameState.crafting
	var r := book.get_recipe(id)
	var out_id := String(r["output"]["item"])
	var lines := PackedStringArray([ItemDB.display_name(out_id), ItemDB.uses(out_id)])
	for part: Dictionary in r.get("inputs", []):
		var have := 0
		for inv: Inventory in _stock():
			have += inv.count(String(part["item"]))
		lines.append("  %s %s: %d / %d" % ["[ok]" if have >= int(part["qty"]) else "[  ]", ItemDB.display_name(String(part["item"])), have, int(part["qty"])])
	_info.text = "\n".join(lines)
	_cook.disabled = not book.check(id, _stock(), CraftingBook.COOKING_TIER, GameState.known_recipes)["ok"]


func _toggle_ingredient(id: String, on: bool, button: Button) -> void:
	if on and _ingredients.size() >= MAX_INGREDIENTS:
		button.set_pressed_no_signal(false)
		_status.text = "Three ingredients at most."
		return
	if on:
		_ingredients[id] = true
	else:
		_ingredients.erase(id)


func _try() -> void:
	if _ingredients.is_empty():
		_status.text = "Choose one to three ingredients first."
		return
	var found := GameState.try_experiment(_ingredients.keys())
	if found.is_empty():
		_status.text = "Hmm, that didn't become a dish. Nothing was used up; try another mix!"
		AudioManager.play(&"soft_deny")
	else:
		var dish := ItemDB.display_name(String(GameState.crafting.get_recipe(found)["output"]["item"]))
		_status.text = L.t("You discovered a new dish: %s!") % dish
		AudioManager.play(&"discover")
		_ingredients.clear()
		_selected = found
	_refresh()


func _do_cook() -> void:
	if _selected.is_empty():
		return
	if GameState.craft(_selected, CraftingBook.COOKING_TIER, 1, use_storage):
		_status.text = L.t("Cooked %s. Eat it with F from the hotbar whenever you like.") % ItemDB.display_name(String(GameState.crafting.get_recipe(_selected)["output"]["item"]))
		AudioManager.play(&"cook")
		EventBus.progress_changed.emit()
	else:
		_status.text = "Not possible right now (missing ingredients, or no room in the bag)."
	_refresh()
