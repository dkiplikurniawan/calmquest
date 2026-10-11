class_name GlowTexture
extends RefCounted
## Cached soft radial texture used by PointLight2D glows (night lighting).

static var _cache: GradientTexture2D


static func radial() -> GradientTexture2D:
	if _cache != null:
		return _cache
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.45, Color(1, 1, 1, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_cache = tex
	return tex


## Creates a disabled PointLight2D configured for gentle glows.
static func make_light(color: Color, scale: float, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = radial()
	light.color = color
	light.texture_scale = scale
	light.energy = energy
	light.enabled = false
	return light
