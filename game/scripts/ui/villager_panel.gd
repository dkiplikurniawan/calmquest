class_name VillagerPanel
extends Control
## Talking with a spirit villager: a line of dialogue, friendship petals, and
## buttons to chat, give a gift, hand over something a quest asks for, or
## invite them to the Festival of Light. Esc or "Goodbye" closes it.

signal closed

var villager_id: String = ""
var _line: Label
var _petals: Label
var _actions: VBoxContainer
var _gifts: HFlowContainer
var _chat_count: int = 0


func setup(id: String) -> void:
	villager_id = id
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var v := VillageDB.villager(id)
	var box := UiKit.centered_panel(self, 760)
	box.add_child(UiKit.label("%s, %s" % [L.t(String(v.get("name", id))), L.t(String(v.get("title", "")))], UiTheme.HEADING))
	_petals = UiKit.label("", UiTheme.SUBTLE)
	box.add_child(_petals)
	_line = UiKit.label("", &"", true)
	_line.custom_minimum_size = Vector2(700, 70)
	box.add_child(_line)
	_actions = VBoxContainer.new()
	box.add_child(_actions)
	_gifts = HFlowContainer.new()
	_gifts.visible = false
	box.add_child(_gifts)
	var reward := VillageDB.talk(id)
	_line.text = "\"%s\"" % VillageDB.line(id, TimeManager.minute_of_day / 60.0, 0)
	_show_reward(reward)
	_refresh()


func _refresh() -> void:
	var p := VillageDB.petals(villager_id)
	_petals.text = L.t("Friendship: %s%s  (%d / %d)") % ["* ".repeat(p), "- ".repeat(VillageDB.MAX_PETALS - p), p, VillageDB.MAX_PETALS]
	for c in _actions.get_children():
		c.queue_free()
	var first: Button = null
	var chat := UiKit.button("Chat", _chat)
	_actions.add_child(chat)
	first = chat
	var gift := UiKit.button(L.t("Give a gift") if VillageDB.can_gift_today(villager_id) else L.t("Give a gift (already today)"), _show_gifts)
	gift.disabled = not VillageDB.can_gift_today(villager_id)
	_actions.add_child(gift)
	for d: Dictionary in VillageDB.deliveries_for(villager_id):
		var item := String(d["item"])
		var qty := int(d["qty"])
		var have := GameState.inventory.count(item)
		var b := UiKit.button(L.t("Hand over %d %s (you have %d)") % [qty, ItemDB.display_name(item), have], func() -> void: _deliver(item, qty), UiTheme.PRIMARY_BUTTON)
		b.disabled = have < qty
		_actions.add_child(b)
	if QuestManager.book.is_active("act3_return") and GameState.has_flag("hearthstones_placed") and not VillageDB.is_invited(villager_id):
		_actions.add_child(UiKit.button("Invite to the Festival of Light", _invite, UiTheme.PRIMARY_BUTTON))
	_actions.add_child(UiKit.button("Goodbye", close_panel))
	first.call_deferred("grab_focus")


func _chat() -> void:
	_chat_count += 1
	_line.text = "\"%s\"" % VillageDB.line(villager_id, TimeManager.minute_of_day / 60.0, _chat_count)
	AudioManager.play(&"ui_click")


func _show_gifts() -> void:
	for c in _gifts.get_children():
		c.queue_free()
	var seen := {}
	for s in GameState.inventory.slots:
		if s.is_empty():
			continue
		var id := String(s["id"])
		if seen.has(id) or not VillageDB.giftable(id):
			continue
		seen[id] = true
		var b := UiKit.button(ItemDB.display_name(id), func() -> void: _give(id))
		_gifts.add_child(b)
	if seen.is_empty():
		_gifts.add_child(UiKit.label("Nothing in your bag can be given right now.", UiTheme.SUBTLE))
	_gifts.visible = true


func _give(item: String) -> void:
	var r := VillageDB.gift(villager_id, item)
	_line.text = "\"%s\"" % String(r["text"]) if bool(r["ok"]) else String(r["text"])
	if bool(r["ok"]):
		AudioManager.play(&"bloom" if r["kind"] != "neutral" else &"ui_click")
		_show_reward(r["reward"])
	_gifts.visible = false
	EventBus.progress_changed.emit()
	_refresh()


func _deliver(item: String, qty: int) -> void:
	if VillageDB.deliver(villager_id, item, qty):
		_line.text = "\"Oh, wonderful! Thank you so much.\""
		AudioManager.play(&"bloom")
		QuestManager.request_refresh()
		EventBus.progress_changed.emit()
	_refresh()


func _invite() -> void:
	if VillageDB.invite(villager_id):
		_line.text = "\"%s\"" % L.t(String((VillageDB.villager(villager_id).get("lines", {}) as Dictionary).get("invite", "I'll be there!")))
		AudioManager.play(&"discover")
		QuestManager.request_refresh()
	_refresh()


func _show_reward(reward: Dictionary) -> void:
	if reward.is_empty():
		return
	var parts := PackedStringArray()
	for it: Dictionary in reward.get("items", []):
		parts.append("%d %s" % [int(it.get("qty", 1)), ItemDB.display_name(String(it["item"]))])
	var cosmetic := String(reward.get("cosmetic", ""))
	if not cosmetic.is_empty():
		var kind := cosmetic.split(":")
		var table: Dictionary = Cosmetics.CLOAKS if kind[0] == "cloak" else Cosmetics.GLOWS
		parts.append(L.t(String((table.get(kind[1], {}) as Dictionary).get("name", cosmetic))))
	_line.text += L.t("\n(Best friends! A thank-you present: %s. Cosmetics can be chosen in the Journal.)") % ", ".join(parts)


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
