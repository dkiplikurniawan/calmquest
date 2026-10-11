class_name LanternPost
extends Node2D
## A wooden lantern post on the village paths (0.4.0). It glows warmly at night.
## Its light is only on at night and near the camera, so the number of lights
## in use stays small (see Overworld.LIGHT_BUDGET).

var _night: float = 0.0
var _light: PointLight2D
var _t: float = 0.0


func _ready() -> void:
	_light = GlowTexture.make_light(Palette.GOLD_SOFT, 1.3, 0.0)
	_light.position = Vector2(0, -58)
	add_child(_light)


func set_night_amount(amount: float) -> void:
	_night = amount
	_update_light()
	queue_redraw()


func _update_light() -> void:
	if _light == null:
		return
	_light.enabled = visible and _night > 0.05 and ViewCull.near(global_position, 200.0)
	_light.energy = 0.5 * _night


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	_update_light()
	if _night > 0.05 and visible and ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	BiomeDecorArt.shadow(self, 10.0)
	draw_rect(Rect2(Vector2(-3, -52), Vector2(6, 52)), Palette.BARK)
	draw_line(Vector2(0, -50), Vector2(12, -50), Palette.BARK_DARK, 3.0, true)
	var swing := sin(_t * 1.2) * 1.5
	var lamp := Vector2(12 + swing, -42)
	draw_line(Vector2(12, -50), lamp + Vector2(0, -6), Palette.INK_SOFT, 1.2)
	var glow := 0.3 + 0.7 * _night
	draw_circle(lamp, 12.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.18 * glow))
	draw_rect(Rect2(lamp + Vector2(-5, -7), Vector2(10, 12)), Palette.with_alpha(Palette.GOLD, 0.45 + 0.55 * glow))
	draw_rect(Rect2(lamp + Vector2(-5, -7), Vector2(10, 12)), Palette.BARK_DARK, false, 1.5)
