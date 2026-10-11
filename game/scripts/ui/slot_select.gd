extends Control
## "Choose a journey": pick one of three save slots (straight from Start
## Adventure). Continue loads the world exactly as it was saved; a new journey
## starts fresh and first shows the mode card. No research data is stored for
## these sessions (Study Mode has its own flow).

var _list: SlotList


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var box := UiKit.centered_panel(self, 820)
	box.add_child(UiKit.label("Choose a journey", UiTheme.HEADING))
	box.add_child(UiKit.label("Your world is saved automatically when you sleep, travel between places, finish a quest, and every few minutes. Saves stay on this computer and are separate from the optional reflection data.", UiTheme.SUBTLE, true))
	_list = SlotList.new()
	_list.confirm_parent = self
	_list.slot_chosen.connect(_on_slot_chosen)
	box.add_child(_list)
	_list.build()
	var back := UiKit.button("Back to Main Menu", func() -> void:
		SessionState.abandon_session()
		SceneRouter.go_to(SceneRouter.MAIN_MENU))
	box.add_child(back)
	var first := _list.first_button()
	(first if first != null else back).call_deferred("grab_focus")


func _on_slot_chosen(slot: int, new_journey: bool) -> void:
	var mode := AdaptiveComfortEngine.DEFAULT_MODE
	if new_journey:
		SaveManager.delete_slot(slot)
	else:
		mode = StringName(String(SaveManager.load_slot(slot).get("mode", String(mode))))
	start_play_session(mode, new_journey)
	SaveManager.current_slot = slot
	SaveManager.reload_current()
	GameSettings.set_setting("last_slot", slot)
	SceneRouter.go_to(SceneRouter.OVERWORLD)


## A play session without a check-in: no stress score (the engine's "skipped"
## rule), the journey's own mode, and nothing stored for research.
static func start_play_session(mode: StringName, new_journey: bool) -> void:
	if not SessionState.session_active:
		SessionState.begin_session(null, mode, false)
	SessionState.start_cards = {"mode_card": new_journey, "mood_check": true}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and get_children().filter(func(c: Node) -> bool: return c is UiKit.ConfirmLayer).is_empty():
		get_viewport().set_input_as_handled()
		SessionState.abandon_session()
		SceneRouter.go_to(SceneRouter.MAIN_MENU)
