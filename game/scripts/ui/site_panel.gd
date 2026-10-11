class_name SitePanel
extends Control
## Restoration checklist for a RestorationSite (e.g. the lighthouse): each
## step shows what it needs (have / need) and a button to do it.

signal closed

var site: RestorationSite
var _list: VBoxContainer
var _status: Label


func setup(s: RestorationSite) -> void:
	site = s
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 760)
	box.add_child(UiKit.label(L.t(String(site.data.get("title", "Restoration"))), UiTheme.HEADING))
	box.add_child(UiKit.label(L.t(String(site.data.get("intro", ""))), UiTheme.SUBTLE, true))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
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
	for s: Dictionary in site.steps():
		var id := String(s["id"])
		var done := RestorationSite.is_step_done(site.site_id, id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var parts := PackedStringArray()
		for part: Dictionary in s.get("inputs", []):
			var have := GameState.inventory.count(String(part["item"]))
			parts.append("%s %d/%d" % [ItemDB.display_name(String(part["item"])), mini(have, int(part["qty"])), int(part["qty"])])
		var text := "%s %s" % [L.t("[done]") if done else "[    ]", L.t(String(s["title"]))]
		if not done:
			text += "\n    " + ", ".join(parts)
		var label := UiKit.label(text, &"", true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if not done:
			var reason := site.check_step(id)
			var b := UiKit.button("Repair", func() -> void: _restore(id), UiTheme.PRIMARY_BUTTON if reason.is_empty() else &"")
			b.disabled = not reason.is_empty()
			b.tooltip_text = reason
			row.add_child(b)
		_list.add_child(row)


func _restore(step_id: String) -> void:
	var reason := site.restore_step(step_id)
	if reason.is_empty():
		_status.text = L.t(String(site.step(step_id).get("done_text", "Done!")))
		AudioManager.play(&"restore")
	else:
		_status.text = reason
		AudioManager.play(&"soft_deny")
	_refresh()


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
