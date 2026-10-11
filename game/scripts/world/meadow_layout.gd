class_name MeadowLayout
extends RefCounted
## Hand-placed content of the Whispering Meadow region (the V1 meadow).
##
## Positions are LOCAL to the region; ORIGIN places the region inside the V2
## overworld (see game/data/world/overworld.json). Paths, ground and world
## boundaries now come from the overworld data, not from this file.
## The integration tests check that every object here is reachable.

## Top-left of the meadow region in overworld pixels.
const ORIGIN := Vector2(3328, 1792)
## Area that the hand-placed meadow content occupies (local coordinates).
const CONTENT_RECT := Rect2(120, 130, 2320, 1350)
const PLAYER_SPAWN := Vector2(1280, 1130)

const HEART_TREE := Vector2(1280, 720)
const GARDEN_BEDS := {
	"bed_west": Vector2(1120, 860),
	"bed_south": Vector2(1280, 905),
	"bed_east": Vector2(1440, 860),
}
const COTTAGE := Vector2(520, 420)
const POND_CENTER := Vector2(1960, 430)
const POND_RADII := Vector2(190, 105)

## Twelve light motes. Eight are needed for the Heart Tree; the rest can bloom
## the garden beds, so no single light is ever required.
const LIGHTS := {
	"light_01": Vector2(860, 560),
	"light_02": Vector2(330, 640),
	"light_03": Vector2(700, 900),
	"light_04": Vector2(420, 1300),
	"light_05": Vector2(960, 1360),
	"light_06": Vector2(1560, 1340),
	"light_07": Vector2(1700, 950),
	"light_08": Vector2(2300, 1350),
	"light_09": Vector2(2340, 820),
	"light_10": Vector2(1690, 520),
	"light_11": Vector2(1250, 300),
	"light_12": Vector2(2200, 260),
}

## Optional bonus objects, only shown in Playful mode.
const PRISMS := {
	"prism_01": Vector2(250, 1000),
	"prism_02": Vector2(1500, 230),
	"prism_03": Vector2(2390, 1080),
}

## Hidden environmental details: [kind, position].
const DISCOVERIES := {
	"moss_sprite": [0, Vector2(690, 330)],
	"star_stone": [1, Vector2(1700, 400)],
	"fairy_ring": [2, Vector2(2150, 700)],
}

## Lantern Catch anchor points, as offsets from the Lantern Shrine (now in
## Firefly Grove). The shrine's clearing keeps this area free of trees.
const LANTERN_OFFSETS: Array[Vector2] = [
	Vector2(-180, -130), Vector2(140, -130), Vector2(220, 110), Vector2(-220, 150),
	Vector2(-420, 30), Vector2(-60, -270), Vector2(-500, -170), Vector2(60, 230),
	Vector2(-600, 70), Vector2(-300, -330), Vector2(270, -200), Vector2(-160, 270),
]

## Decorations with collision or visual weight: [kind, position, size].
## Kinds match Decoration.Kind (0 tree, 1 pine, 2 bush, 4 stone, 5 mushroom, 7 cottage, 8 fence).
const LANDMARKS: Array = [
	[7, COTTAGE, 1.0],
	[8, Vector2(380, 520), 1.0], [8, Vector2(660, 520), 1.0],
	[0, Vector2(260, 330), 1.1], [0, Vector2(980, 330), 1.0], [1, Vector2(1080, 420), 0.9],
	[0, Vector2(560, 760), 0.95], [2, Vector2(660, 340), 1.0], [2, Vector2(820, 380), 0.8],
	[0, Vector2(1500, 560), 0.9], [1, Vector2(1580, 300), 1.0],
	[0, Vector2(2360, 520), 1.1], [1, Vector2(2240, 420), 0.9],
	[4, Vector2(1640, 420), 1.2], [4, Vector2(1760, 360), 0.8],
	[0, Vector2(300, 860), 1.0], [2, Vector2(470, 1060), 1.0], [1, Vector2(200, 1180), 1.0],
	[4, Vector2(860, 1240), 1.1], [4, Vector2(920, 1210), 0.7], [4, Vector2(820, 1290), 0.6],
	[0, Vector2(1080, 1300), 1.0], [2, Vector2(1480, 1420), 0.9],
	[0, Vector2(1880, 760), 0.95], [2, Vector2(2180, 640), 1.0],
	[1, Vector2(2380, 1180), 1.0], [0, Vector2(1640, 1430), 1.0],
	[2, Vector2(1000, 1020), 0.8], [2, Vector2(1560, 1020), 0.8],
	[5, Vector2(400, 1180), 1.0], [5, Vector2(1960, 1260), 0.9], [5, Vector2(1150, 380), 0.8],
]


## Converts a meadow-local position to overworld pixels.
static func to_world(local: Vector2) -> Vector2:
	return ORIGIN + local
