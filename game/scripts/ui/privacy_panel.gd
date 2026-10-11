class_name PrivacyPanel
extends Control
## "Data & Privacy" overlay: explains what is stored and lets the player
## export, open or delete their local data: research session records
## (SessionStorage), the private mood journal (Wellbeing) and, in Study Mode,
## the study files (StudyMode).

signal closed

const EXPLANATION := [
	["What can be stored", "Only in Study Mode (research sessions), and only if the participant ticks the consent box at the check-in: an anonymous session record with a random session ID, the local start time, your optional 0-10 answers before and after playing, the modes used, play time, hints used, reach-help events, items collected, whether the Heart Tree was restored, your optional game rating, and whether the session was finished. No name, email, account, location or device identifiers."],
	["Why", "So you (or a researcher you choose to share an export with) can look back at your own sessions, and so the project's analysis notebook has real, consented data to work with."],
	["Where", "In a CSV file on this computer, inside the game's user-data folder (shown below). Nothing is sent over the internet: the game contains no network, analytics or tracking code."],
	["Declining", "Leave the consent box unticked (the default). The game works exactly the same and no session record is written."],
	["Journal progress", "Separately, the game remembers journal progress (hidden details found, how often the Heart Tree was restored) in progress.cfg. It never contains your check-in answers. You can reset it below."],
	["World saves", "Your journeys are saved in the saves folder (one file per slot, plus a backup). They hold only the game world: places, items, homes, friends and quests. They never contain check-in or reflection answers, and they can be deleted from the \"Choose a journey\" screen."],
	["Mood check and journal", "The mood check when you start playing and the faces when you leave are optional and are not stored, unless you turn on the private mood journal (Settings > Well-being, off by default). The journal keeps the date and time, the faces you chose, the session length and the short summary in wellbeing_journal.json on this device. It is separate from your journeys and from research data, and you can export or delete it below."],
	["A note on anonymity", "Records contain no direct identifiers, but your answers and timestamps are still personal reflections. Anyone with access to this computer account could read the file, so delete it if you share the device."],
]
const STUDY_EXPLANATION := ["Study Mode", "Study Mode is used by a researcher for a study. With the participant's consent it writes study_sessions.csv (the participant code, language, build, session length and the same 16 columns as above) and study_events.csv (coarse events such as entering a region or starting to fish; no positions or keystrokes). Both stay on this device, separate from your journeys."]

var _status: Label
var _count_label: Label
var _storage := SessionStorage.new()
var _dialog: FileDialog
var _journal_dialog: FileDialog
var _study_dialog: FileDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 760)
	box.add_child(UiKit.label("Data & Privacy", UiTheme.HEADING))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var sections: Array = EXPLANATION.duplicate()
	if StudyMode.is_active() or StudyMode.sessions_store.exists():
		sections.append(STUDY_EXPLANATION)
	for section: Array in sections:
		list.add_child(UiKit.label(section[0], UiTheme.SUBTLE))
		list.add_child(UiKit.label(section[1], &"", true))
	list.add_child(UiKit.label("Data file location", UiTheme.SUBTLE))
	var path_label := UiKit.label(_storage.get_absolute_path(), &"", true)
	list.add_child(path_label)

	_count_label = UiKit.label("", &"", true)
	box.add_child(_count_label)
	var export_button := UiKit.button("Export CSV...", _open_export_dialog)
	var open_button := UiKit.button("Open data folder", _open_folder)
	box.add_child(UiKit.hbox([export_button, open_button]))
	var delete_button := UiKit.button("Delete session records", func() -> void:
		UiKit.confirm(self, "Permanently delete all locally stored session records? This cannot be undone.", "Delete", _delete_records))
	var reset_button := UiKit.button("Reset journal progress", func() -> void:
		UiKit.confirm(self, "Reset journal progress (hidden details found, restoration and lantern counts)? Session records are not affected.", "Reset", _reset_progress))
	box.add_child(UiKit.hbox([delete_button, reset_button]))
	if GameSettings.mood_journal or Wellbeing.journal_exists():
		var export_journal := UiKit.button("Export mood journal...", _open_journal_export)
		var delete_journal := UiKit.button("Delete mood journal", func() -> void:
			UiKit.confirm(self, "Delete your private mood journal? This cannot be undone.", "Delete", _delete_journal))
		box.add_child(UiKit.hbox([export_journal, delete_journal]))
	if StudyMode.is_active():
		var export_study := UiKit.button("Export study data...", _open_study_export)
		var leave := UiKit.button("Leave Study Mode", func() -> void:
			StudyMode.leave()
			_status.text = "Study Mode is off.")
		box.add_child(UiKit.hbox([export_study, leave]))
	_status = UiKit.label("", UiTheme.SUBTLE, true)
	box.add_child(_status)
	var back := UiKit.button("Back", close, UiTheme.PRIMARY_BUTTON)
	box.add_child(back)
	_refresh_count()
	back.call_deferred("grab_focus")


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var dialog_open := false
	for d: FileDialog in [_dialog, _journal_dialog, _study_dialog]:
		if d != null and d.visible:
			dialog_open = true
	if event.is_action_pressed(&"ui_cancel") and not dialog_open:
		get_viewport().set_input_as_handled()
		close()


func _refresh_count() -> void:
	var count := _storage.count_records()
	if count < 0:
		_count_label.text = "The data file exists but could not be read as a CALMQUEST session file. It has not been modified."
	elif count == 0:
		_count_label.text = "Stored session records: none."
	else:
		_count_label.text = L.t("Stored session records: %d.") % count


func _open_export_dialog() -> void:
	if not _storage.exists():
		_status.text = "There are no saved session records to export yet."
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = true
		_dialog.filters = PackedStringArray(["*.csv ; CSV files"])
		_dialog.title = "Export session records"
		_dialog.file_selected.connect(_export_to)
		add_child(_dialog)
	_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_dialog.current_file = SessionStorage.suggested_export_filename()
	_dialog.popup_centered_ratio(0.7)


func _export_to(path: String) -> void:
	var result := _storage.export_to(path)
	_status.text = result["message"]


func _open_folder() -> void:
	var dir := ProjectSettings.globalize_path("user://")
	var err := OS.shell_open(dir)
	_status.text = L.t("Opened %s") % dir if err == OK else L.t("Could not open the folder (%s). Path: %s") % [error_string(err), dir]


func _delete_records() -> void:
	var result := _storage.delete_all()
	_status.text = result["message"]
	_refresh_count()


func _open_journal_export() -> void:
	if not Wellbeing.journal_exists():
		_status.text = "There is no mood journal to export yet."
		return
	if _journal_dialog == null:
		_journal_dialog = _file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export mood journal", ["*.json ; JSON files"])
		_journal_dialog.file_selected.connect(func(path: String) -> void: _status.text = Wellbeing.export_journal(path)["message"])
	_journal_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_journal_dialog.current_file = "calmquest_mood_journal.json"
	_journal_dialog.popup_centered_ratio(0.7)


func _delete_journal() -> void:
	_status.text = "Your mood journal was deleted." if Wellbeing.delete_journal() else Wellbeing.last_error


func _open_study_export() -> void:
	if _study_dialog == null:
		_study_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_DIR, "Export study data", [])
		_study_dialog.dir_selected.connect(func(dir: String) -> void: _status.text = StudyMode.export_to_folder(dir)["message"])
	_study_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_study_dialog.popup_centered_ratio(0.7)


func _file_dialog(mode: FileDialog.FileMode, title: String, filters: Array) -> FileDialog:
	var d := FileDialog.new()
	d.file_mode = mode
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.use_native_dialog = true
	d.filters = PackedStringArray(filters)
	d.title = title
	add_child(d)
	return d


func _reset_progress() -> void:
	if SessionState.progress.reset():
		_status.text = "Journal progress was reset."
	else:
		_status.text = SessionState.progress.last_error
