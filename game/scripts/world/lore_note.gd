class_name LoreNote
extends Interactable
## A page from a forgotten journal resting on a little stone. Reading it adds
## lore to the Journal and teaches the recipes listed in the recipe data
## (discovery key "note:<id>"). Optional, never required.

const NOTES_PATH := "res://game/data/lore/notes.json"

static var _notes: Dictionary = {}

var note_id: String = ""
## Optional flag: the note only appears once it is set (e.g. the epilogue).
var requires_flag: String = ""
var _t: float = 0.0


static func all_note_ids() -> PackedStringArray:
	note_data("")
	return PackedStringArray(_notes.keys())


static func note_data(id: String) -> Dictionary:
	if _notes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NOTES_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			for n: Dictionary in (parsed as Dictionary).get("notes", []):
				_notes[String(n["id"])] = n
		else:
			push_error("LoreNote: could not read %s" % NOTES_PATH)
	return _notes.get(id, {})


func can_interact() -> bool:
	return (requires_flag.is_empty() or GameState.has_flag(requires_flag)) and super.can_interact()


func get_prompt() -> String:
	return "Read the old note" if not GameState.lore_read.has(note_id) else L.t("Reread: %s") % L.t(String(note_data(note_id).get("title", "note")))


func _process(delta: float) -> void:
	super(delta)
	visible = requires_flag.is_empty() or GameState.has_flag(requires_flag)
	_t += delta
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	BiomeDecorArt.shadow(self, 18.0)
	draw_circle(Vector2(0, -6), 14.0, Palette.STONE)
	var unread := not GameState.lore_read.has(note_id)
	draw_set_transform(Vector2(0, -18), -0.15, Vector2.ONE)
	draw_rect(Rect2(-10, -8, 20, 14), Palette.CREAM)
	draw_line(Vector2(-6, -3), Vector2(6, -3), Palette.BARK, 1.2)
	draw_line(Vector2(-6, 1), Vector2(4, 1), Palette.BARK, 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if unread:
		draw_circle(Vector2(12, -30), 3.0 + sin(_t * 3.0), Palette.with_alpha(Palette.GOLD, 0.8))
	draw_interaction_cues(20.0, Vector2(0, -12))
