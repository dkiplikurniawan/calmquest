class_name FarmPlot
extends Interactable
## A placed Garden Plot on the homestead. E plants a seed (choose one if you
## carry several), waters with the watering can, or harvests when ripe.
## Growth rules are in Farming; this node only shows the state.

var plot_key: String = ""
var cell_size: float = 64.0
var _t: float = 0.0


func setup(key: String, pos: Vector2, size: float) -> void:
	plot_key = key
	interactable_id = "plot_" + key
	position = pos
	cell_size = size
	reach_bonus = 8.0
	z_index = -3


func get_prompt() -> String:
	if not Farming.has_crop(plot_key):
		return "Plant seeds" if not Farming.seeds_in_bag().is_empty() else "An empty garden plot"
	if Farming.is_ripe(plot_key):
		return L.t("Harvest %s") % ItemDB.display_name(String(Farming.crop_data(String(Farming.plot(plot_key)["seed"]))["grows"]))
	if Farming.is_watered_today(plot_key):
		return "Watered today. It's growing"
	return "Water the sprouts" if GameState.inventory.count("watering_can") > 0 else "Needs water (watering can)"


func get_interaction_point() -> Vector2:
	return global_position + Vector2(0, -cell_size * 0.4)


func _process(delta: float) -> void:
	super(delta)
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	var half := cell_size * 0.44
	var base := Vector2(0, -cell_size * 0.4)
	var watered := Farming.has_crop(plot_key) and Farming.is_watered_today(plot_key)
	draw_rect(Rect2(base - Vector2(half, half), Vector2(half, half) * 2.0), Palette.BARK)
	var soil := Color("#7a5a45") if watered else Color("#9c7558")
	draw_rect(Rect2(base - Vector2(half - 4, half - 4), Vector2(half - 4, half - 4) * 2.0), soil)
	for i in 3:
		var y := base.y - half * 0.5 + i * half * 0.5
		draw_line(Vector2(-half + 8, y), Vector2(half - 8, y), soil.darkened(0.2), 2.0)
	if watered:
		draw_circle(base + Vector2(half * 0.5, half * 0.5), 3.0, Palette.with_alpha(Palette.SKY, 0.8))
	var st := Farming.stage(plot_key)
	if st < 0:
		draw_interaction_cues(half, base)
		return
	var c := Farming.crop_data(String(Farming.plot(plot_key)["seed"]))
	var leaf := Color(String(c.get("leaf", "#5e8c6a")))
	var fruit := Color(String(c.get("fruit", "#f4a259")))
	var sway := sin(_t * 1.5) * 1.5
	for k in 3:
		var x := (-0.5 + k * 0.5) * half
		var p := base + Vector2(x, 4)
		match st:
			0:
				draw_circle(p, 2.5, Palette.BARK_DARK)
			1:
				draw_line(p, p + Vector2(sway, -8), leaf, 2.0)
				draw_circle(p + Vector2(sway - 2, -8), 3.0, leaf)
				draw_circle(p + Vector2(sway + 2, -9), 3.0, leaf)
			2:
				draw_line(p, p + Vector2(sway, -16), leaf, 2.5)
				for s: float in [-1.0, 1.0]:
					draw_circle(p + Vector2(sway + s * 4, -12), 4.0, leaf)
			3:
				draw_line(p, p + Vector2(sway, -18), leaf, 2.5)
				for s: float in [-1.0, 1.0]:
					draw_circle(p + Vector2(sway + s * 5, -12), 4.5, leaf)
				ItemArt.draw(self, p + Vector2(sway, -20), 16.0, String(c.get("grows", "carrot")))
	if st == 3:
		var glow := 0.4 + 0.3 * sin(_t * 3.0)
		draw_circle(base + Vector2(half * 0.7, -half * 0.7), 4.0, Palette.with_alpha(Palette.GOLD, glow))
	draw_interaction_cues(half, base)
