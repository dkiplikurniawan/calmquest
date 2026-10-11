class_name SlotList
extends VBoxContainer
## Three save-slot rows (used by the slot screen and by Load in the pause menu).
## Each row shows a short summary and offers Continue / New journey / Delete.
## Destructive choices always ask for confirmation.

signal slot_chosen(slot: int, new_journey: bool)

var allow_new: bool = true
var confirm_parent: Node = null
var _first_button: Button = null


func build() -> void:
	for c in get_children():
		c.queue_free()
	_first_button = null
	add_theme_constant_override("separation", 10)
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		add_child(_row(slot))


func first_button() -> Button:
	return _first_button


func _row(slot: int) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.HUD_PANEL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(L.t("Journey %d") % slot, UiTheme.HUD))
	var summary := SaveManager.slot_summary(slot)
	var exists := SaveManager.slot_exists(slot)
	var text := "Empty"
	if not summary.is_empty():
		text = L.t("Day %d - %s - Act 1: %d/4 - explored %d%% - %d min played\nLast saved %s") % [
			int(summary.get("day", 1)), L.t(String(summary.get("region", ""))), int(summary.get("act1_quests", 0)),
			int(summary.get("explored_percent", 0)), int(summary.get("playtime_minutes", 0)), String(summary.get("saved_at", "")).replace("T", " ")]
	elif exists:
		text = "This save could not be read (its backup could not be read either). You can start over or delete it."
	info.add_child(UiKit.label(text, UiTheme.SUBTLE, true))
	row.add_child(info)
	var buttons := VBoxContainer.new()
	if not summary.is_empty():
		var cont := UiKit.button("Continue", func() -> void: slot_chosen.emit(slot, false), UiTheme.PRIMARY_BUTTON)
		buttons.add_child(cont)
		_remember_first(cont, slot)
		if allow_new:
			buttons.add_child(UiKit.button("Start over", func() -> void:
				UiKit.confirm(_confirm_parent(), L.t("Start a new journey in slot %d? The current journey in this slot will be replaced.") % slot, L.t("Start over"), func() -> void: slot_chosen.emit(slot, true))))
		buttons.add_child(UiKit.button("Delete", func() -> void:
			UiKit.confirm(_confirm_parent(), L.t("Delete the journey in slot %d? This cannot be undone.") % slot, L.t("Delete"), func() -> void:
				SaveManager.delete_slot(slot)
				build())))
	elif allow_new:
		var new_b := UiKit.button("Begin a new journey", func() -> void: slot_chosen.emit(slot, true), UiTheme.PRIMARY_BUTTON)
		buttons.add_child(new_b)
		_remember_first(new_b, slot)
		if exists:
			buttons.add_child(UiKit.button("Delete", func() -> void:
				SaveManager.delete_slot(slot)
				build()))
	row.add_child(buttons)
	return panel


func _remember_first(b: Button, slot: int) -> void:
	if _first_button == null or slot == GameSettings.last_slot:
		_first_button = b


func _confirm_parent() -> Node:
	return confirm_parent if confirm_parent != null else get_parent()
