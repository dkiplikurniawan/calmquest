class_name Gatherable
extends Interactable
## A small natural resource lying in the world (a fallen branch, a shell...).
## Walk up and press E to gather it. Generated per chunk by ChunkGenerator;
## when gathered it is recorded as a world delta and grows back after a few
## in-game days (nothing is ever destructive: only fallen or loose things).

var item_id: String = "branch"
var chunk: Vector2i = Vector2i.ZERO
var respawn_days: int = 2
var gathered: bool = false
var _t: float = 0.0


func _ready() -> void:
	_t = float(hash(interactable_id) % 100) * 0.07


func can_interact() -> bool:
	return not gathered and super.can_interact()


func get_prompt() -> String:
	return L.t("Gather %s") % ItemDB.display_name(item_id)


## Small pop and fade, then the node frees itself.
func play_gathered() -> void:
	gathered = true
	set_targeted(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.35, 0.7), 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.08)
	tween.tween_property(self, "position:y", position.y - 18.0, 0.35).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	if is_targeted or show_marker:
		queue_redraw()


func _draw() -> void:
	BiomeDecorArt.shadow(self, 12.0)
	# A faint sparkle marks it as collectable (a shape cue, not only color).
	var glint := 0.35 + 0.25 * sin(_t * 2.2)
	ItemArt.draw(self, Vector2(0, -12), 24.0, item_id)
	draw_circle(Vector2(10, -24), 2.2, Palette.with_alpha(Palette.IVORY, glint))
	draw_interaction_cues(18.0, Vector2(0, -10))
