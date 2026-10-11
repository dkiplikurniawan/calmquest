class_name HowToPlayPanel
extends Control
## "How to Play" overlay opened from the main menu.

signal closed

const SECTIONS := [
	["Controls", "Move: WASD or arrow keys (hold Shift to run; there is no stamina)
Interact: E (when a golden ring appears around an object)
Bag and crafting: I or Tab    Use or eat: F    Hotbar: 1-8
Build mode: B (at your cottage or homestead)
Ask Lumi for a hint: H    Journal: J    World map: M (P places a pin)
Pause: Escape. A gamepad works too, and keys can be changed in Settings."],
	["Exploring Lumeria", "The world is much bigger than one screen. Follow the paths between regions, relight Lantern Waystones and travel between them for free, from a waystone or by clicking it on the map. Tools you craft open new places: a Bright Lantern for gloom and caves, a boat for the isles, a climbing rope for the highland pass."],
	["Gather light", "Glowing lights float around Whispering Meadow. Walk close until a ring appears, then press E. You only need 8 of the 12 lights, and there is no timer."],
	["Restore the Heart Tree", "Bring 8 light to the great tree in the middle of the meadow and press E. Afterwards you can bloom three garden beds and look for hidden details. All of this is optional."],
	["Gather, craft and make a home", "Branches, stones, flowers and more lie everywhere and grow back after a while. Craft at a workbench (I opens your bag and recipes). Restore the old cottage, decorate it, plant seeds in garden plots, fish at rippling water and cook at the pot. Crops never die, fish never get away for good, and nothing is ever lost."],
	["Friends and the story", "Spirit villagers move in as the world brightens. Chat, bring gifts and help with their small requests; nothing ever expires. After the Heart of Lumeria wakes, five Hearthstones wait across the world, in any order you like."],
	["Lantern Catch", "Visit the Lantern Shrine in Firefly Grove to begin a quiet night. Catch the slowly drifting lanterns with E. There are no lives and no countdown, and you can end the night at the shrine at any time."],
	["Saving", "Your journey saves itself when you sleep, go through doors, finish quests and every few minutes. You can also save from the pause menu. Saves are separate from the optional reflection data."],
	["Check-in and reflection", "Before playing you may rate how stressed you feel from 0 to 10, and again when you finish. Both are optional and can be skipped. They are a personal reflection, not a test or a diagnosis. The results screen simply compares your two answers."],
	["Gameplay modes", "Gentle: generous reach, guiding glow, automatic fishing, easy-going creatures, more hints.
Balanced: the standard cozy pace.
Playful: livelier lights, lanterns and fish, plus optional bonus challenges.
The check-in can suggest a mode, but you always choose. Change it any time from the pause menu."],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 720)
	box.add_child(UiKit.label("How to Play", UiTheme.HEADING))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for section: Array in SECTIONS:
		list.add_child(UiKit.label(section[0], UiTheme.SUBTLE))
		list.add_child(UiKit.label(section[1], &"", true))
		list.add_child(UiKit.spacer(6))
	var back := UiKit.button("Back", close, UiTheme.PRIMARY_BUTTON)
	box.add_child(back)
	back.call_deferred("grab_focus")


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
