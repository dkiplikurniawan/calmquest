class_name RequestBoardPanel
extends Control
## The village request board: up to three small requests from villagers.
## Requests never expire and there is no penalty for leaving them.

signal closed

var _list: VBoxContainer
var _status: Label


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 820)
	box.add_child(UiKit.label("Village Request Board", UiTheme.HEADING))
	box.add_child(UiKit.label("Small favours for your neighbours. Requests never expire; take your time.", UiTheme.SUBTLE, true))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	box.add_child(_list)
	_status = UiKit.label("", &"", true)
	box.add_child(_status)
	var close := UiKit.button("Close", close_panel)
	box.add_child(close)
	_refresh()
	close.call_deferred("grab_focus")


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var open := VillageDB.open_requests()
	if open.is_empty():
		_list.add_child(UiKit.label("All caught up! New requests come with new friends.", UiTheme.SUBTLE, true))
	for r in open:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var text := L.t("%s\n    from %s") % [L.t(String(r["text"])), VillageDB.display_name(String(r["from"]))]
		if r.has("deliver"):
			var d: Dictionary = r["deliver"]
			text += "  -  %s %d / %d" % [ItemDB.display_name(String(d["item"])), mini(GameState.inventory.count(String(d["item"])), int(d["qty"])), int(d["qty"])]
		var label := UiKit.label(text, &"", true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var ready := VillageDB.request_ready(r)
		var b := UiKit.button("Hand over" if r.has("deliver") else "Report back", func() -> void: _complete(r), UiTheme.PRIMARY_BUTTON if ready else &"")
		b.disabled = not ready
		row.add_child(b)
		_list.add_child(row)
	var done := GameState.counter("requests_done")
	_status.text = L.t("Requests completed: %d of %d") % [done, VillageDB.all_requests().size()] if done > 0 else ""


func _complete(r: Dictionary) -> void:
	var reward := VillageDB.complete_request(r)
	if reward.is_empty() and not VillageDB.request_done(String(r["id"])):
		return
	var parts := PackedStringArray()
	for it: Dictionary in reward.get("items", []):
		parts.append("%d %s" % [int(it.get("qty", 1)), ItemDB.display_name(String(it["item"]))])
	_status.text = L.t("%s says thank you! You receive: %s.") % [VillageDB.display_name(String(r["from"])), ", ".join(parts)]
	AudioManager.play(&"bloom")
	EventBus.progress_changed.emit()
	_refresh()


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
