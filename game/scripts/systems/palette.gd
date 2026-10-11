class_name Palette
extends RefCounted
## Shared color language for the whole game (world, characters, UI).
## Keeping every color here makes the art direction consistent and easy to tune.

const MINT := Color("#a8e6cf")
const SAGE := Color("#8fb996")
const SAGE_DARK := Color("#5e8c6a")
const FOREST := Color("#3f6b55")
const GRASS := Color("#a3d39c")
const GRASS_LIGHT := Color("#c2e5b5")
const GRASS_DARK := Color("#7fb98a")
const PATH := Color("#efe0c0")
const PATH_EDGE := Color("#dcc79d")

const CREAM := Color("#fff6e5")
const IVORY := Color("#fffbf2")
const LAVENDER := Color("#c3b1e1")
const VIOLET := Color("#8e7cc3")
const VIOLET_DARK := Color("#5d4f8a")
const SKY := Color("#a7d8f0")
const TURQUOISE := Color("#5cc8c0")
const WATER := Color("#7cc6d6")
const WATER_DEEP := Color("#5aa8c0")

const GOLD := Color("#ffd166")
const GOLD_SOFT := Color("#ffe8a3")
const GOLD_DEEP := Color("#f4a259")

const NIGHT := Color("#2b3655")
const NIGHT_DEEP := Color("#1d2540")
## Text ink: dark desaturated blue, high contrast against CREAM/IVORY.
const INK := Color("#26324d")
const INK_SOFT := Color("#4a5675")

const BARK := Color("#8a6f5e")
const BARK_DARK := Color("#6b5446")
const STONE := Color("#b9b6c9")
const STONE_DARK := Color("#8f8ca3")
const ROOF := Color("#b98bb0")

const SHADOW := Color(0.12, 0.16, 0.25, 0.20)

## Night tint applied with CanvasModulate during Lantern Catch.
const NIGHT_TINT := Color(0.36, 0.42, 0.66)
const DAY_TINT := Color(1, 1, 1)


static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
