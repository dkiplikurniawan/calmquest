class_name ItemSlot
extends Button
## One inventory/hotbar slot: item icon, quantity and selection outline.
## A focusable Button, so the inventory works with mouse and keyboard.

var item_id: String = ""
var qty: int = 0
var selected: bool = false
var hotkey: String = ""


func _init(slot_size: float = 56.0) -> void:
	custom_minimum_size = Vector2(slot_size, slot_size)
	text = ""
	clip_text = true


func set_item(id: String, amount: int) -> void:
	item_id = id
	qty = amount
	tooltip_text = "" if id.is_empty() else "%s\n%s" % [ItemDB.display_name(id), ItemDB.description(id)]
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if selected:
		draw_rect(r.grow(-2.0), Palette.with_alpha(Palette.GOLD, 0.35))
		draw_rect(r.grow(-2.0), Palette.GOLD_DEEP, false, 3.0)
	if not item_id.is_empty():
		ItemArt.draw(self, size / 2.0, minf(size.x, size.y) * 0.62, item_id)
		if qty > 1:
			var font := get_theme_default_font()
			var fs := int(get_theme_default_font_size() * 0.8)
			var label := str(qty)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2(size.x - w - 6.0, size.y - 6.0)
			draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Palette.IVORY)
			draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
	if not hotkey.is_empty():
		var font := get_theme_default_font()
		var fs := int(get_theme_default_font_size() * 0.6)
		draw_string(font, Vector2(5, fs + 2), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK_SOFT)
