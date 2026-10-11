class_name ViewCull
extends RefCounted
## Off-screen objects don't need to redraw their idle animations. The
## overworld stores the camera's view here every frame; animated objects call
## near() before queue_redraw(). Until a view is set (menus, tests without a
## camera), everything counts as near, so nothing is ever skipped by mistake.

const DEFAULT_MARGIN := 320.0

static var view: Rect2 = Rect2(-1.0e9, -1.0e9, 2.0e9, 2.0e9)


static func near(pos: Vector2, margin: float = DEFAULT_MARGIN) -> bool:
	return view.grow(margin).has_point(pos)


static func reset() -> void:
	view = Rect2(-1.0e9, -1.0e9, 2.0e9, 2.0e9)
