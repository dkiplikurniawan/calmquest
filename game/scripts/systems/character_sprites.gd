class_name CharacterSprites
extends RefCounted
## Optional sprite sheets for the Traveler and Lumi (0.4.0). When an artist
## drops the files below into assets/sprites/, the game draws them instead of
## the procedural art; without them the procedural drawing is used. The
## expected layout is documented in assets/sprites/README.md.
##
##   traveler.png: frames of 64 x 64 px, 6 columns x 4 rows.
##     Rows (facing): 0 down, 1 up, 2 left, 3 right.
##     Columns: 0-3 walk cycle, 4 idle, 5 idle with eyes closed (blink).
##     The feet touch the bottom center of each frame (pixel 32, 60).
##   lumi.png: frames of 48 x 48 px, 4 columns x 1 row (a gentle float loop),
##     body centred in the frame.

const TRAVELER_PATH := "res://assets/sprites/traveler.png"
const LUMI_PATH := "res://assets/sprites/lumi.png"
const TRAVELER_FRAME := Vector2i(64, 64)
const TRAVELER_COLUMNS := 6
const TRAVELER_ROWS := 4
const TRAVELER_FEET := Vector2(32, 60)
const LUMI_FRAME := Vector2i(48, 48)
const LUMI_COLUMNS := 4

static var _cache: Dictionary = {}


## The sheet at `path` if it exists and has the expected size, else null.
static func sheet(path: String, frame: Vector2i, columns: int, rows: int) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
		if tex != null and (tex.get_width() < frame.x * columns or tex.get_height() < frame.y * rows):
			push_warning("CharacterSprites: %s is smaller than %d x %d frames of %s; using the procedural art." % [path, columns, rows, frame])
			tex = null
	_cache[path] = tex
	return tex


static func traveler() -> Texture2D:
	return sheet(TRAVELER_PATH, TRAVELER_FRAME, TRAVELER_COLUMNS, TRAVELER_ROWS)


static func lumi() -> Texture2D:
	return sheet(LUMI_PATH, LUMI_FRAME, LUMI_COLUMNS, 1)


## Forget cached sheets (tests, or after files were added).
static func clear_cache() -> void:
	_cache.clear()


## Row for a facing direction: 0 down, 1 up, 2 left, 3 right.
static func traveler_row(facing: Vector2) -> int:
	if absf(facing.x) > absf(facing.y):
		return 2 if facing.x < 0.0 else 3
	return 1 if facing.y < 0.0 else 0


## Column: the walk cycle while walking, otherwise idle or blinking.
static func traveler_column(t: float, walking: bool, blinking: bool) -> int:
	if walking:
		return int(floor(t * 12.0 / PI)) % 4
	return 5 if blinking else 4


static func draw_traveler(ci: CanvasItem, tex: Texture2D, row: int, column: int, offset_y: float) -> void:
	var src := Rect2(Vector2(column * TRAVELER_FRAME.x, row * TRAVELER_FRAME.y), Vector2(TRAVELER_FRAME))
	ci.draw_texture_rect_region(tex, Rect2(-TRAVELER_FEET + Vector2(0, offset_y), Vector2(TRAVELER_FRAME)), src)


static func draw_lumi(ci: CanvasItem, tex: Texture2D, t: float, center: Vector2) -> void:
	var column := int(floor(t * 4.0)) % LUMI_COLUMNS
	var src := Rect2(Vector2(column * LUMI_FRAME.x, 0), Vector2(LUMI_FRAME))
	ci.draw_texture_rect_region(tex, Rect2(center - Vector2(LUMI_FRAME) / 2.0, Vector2(LUMI_FRAME)), src)
