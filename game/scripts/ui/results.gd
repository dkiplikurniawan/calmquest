extends Control
## Results: neutral comparison of the player's own before/after answers (only
## real answers from this session, never example values), a short session
## summary and the honest outcome of the storage step.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 760
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var s := SessionState
	box.add_child(UiKit.label("Session reflection", UiTheme.HEADING))
	if s.session_id.is_empty():
		box.add_child(UiKit.label("No session has been played yet, so there is nothing to compare.", &"", true))
	else:
		var pre: Variant = s.pre_stress_score
		var post: Variant = s.post_stress_score
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 24)
		for pair: Array in [["Before", ScoreComparison.format_score(pre)], ["After", ScoreComparison.format_score(post)], ["Change", ScoreComparison.format_delta(pre, post)]]:
			var cell := VBoxContainer.new()
			cell.add_child(UiKit.label(pair[0], UiTheme.SUBTLE))
			cell.add_child(UiKit.label(pair[1], UiTheme.HEADING))
			grid.add_child(cell)
		box.add_child(grid)
		box.add_child(UiKit.label(ScoreComparison.describe(pre, post), &"", true))
		box.add_child(UiKit.label(ScoreComparison.CAVEAT, UiTheme.SUBTLE, true))
		box.add_child(HSeparator.new())
		box.add_child(UiKit.label(_summary(), &"", true))
		box.add_child(HSeparator.new())
		box.add_child(UiKit.label(_storage_text(), UiTheme.SUBTLE, true))

	var again := UiKit.button("Play Again", func() -> void: SceneRouter.go_to(SceneRouter.CHECK_IN), UiTheme.PRIMARY_BUTTON)
	var menu := UiKit.button("Main Menu", func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU))
	box.add_child(UiKit.hbox([again, menu]))
	again.call_deferred("grab_focus")
	# The outcome is shown here; don't repeat it on the main menu.
	s.last_save_result = {}


func _summary() -> String:
	var s := SessionState
	var lines := PackedStringArray()
	var final_mode := L.t(AdaptiveComfortEngine.build_preset(s.engine.get_mode_id()).display_name)
	var start_mode := L.t(AdaptiveComfortEngine.build_preset(StringName(s.selected_mode)).display_name)
	lines.append(L.t("Mode: %s") % (final_mode if final_mode == start_mode else L.t("%s, then %s") % [start_mode, final_mode]))
	lines.append(L.t("Time played: %s") % Overworld.format_duration(s.get_duration_seconds()))
	lines.append(L.t("Items collected: %d   Heart Tree: %s   Garden restoration: %d%%") % [
		s.get_items_collected(),
		L.t("restored") if s.heart_tree_restored else L.t("not restored this time"),
		int(round(s.get_restoration_progress() * 100.0)),
	])
	if s.experience_rating != null:
		lines.append(L.t("How the game felt: %d / 5") % int(s.experience_rating))
	return "\n".join(lines)


func _storage_text() -> String:
	var result: Dictionary = SessionState.last_save_result
	if result.is_empty():
		return "No storage step was run for this session."
	if result.get("saved", false):
		return "Saved as an anonymous record on this device. You can export or delete it in Data & Privacy."
	return str(result.get("message", ""))
