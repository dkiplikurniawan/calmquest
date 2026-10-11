class_name LumiGuide
extends RefCounted
## Lumi's words, kept short and optional. Pure functions so hint wording and
## direction logic can be unit tested without a scene.

const CLOSE_DISTANCE := 320.0
const MEDIUM_DISTANCE := 760.0
const DIRECTIONS: PackedStringArray = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]  # i18n


## Compass word for a direction in screen space (y grows downward = south).
static func compass_word(from: Vector2, to: Vector2) -> String:
	var delta := to - from
	if delta.length() < 1.0:
		return L.t("right here")
	var angle := fposmod(delta.angle(), TAU)
	var index := int(roundf(angle / (TAU / 8.0))) % 8
	return L.t(DIRECTIONS[index])


static func distance_phrase(distance: float) -> String:
	if distance < CLOSE_DISTANCE:
		return L.t("very close")
	if distance < MEDIUM_DISTANCE:
		return L.t("a little way off")
	return L.t("further away")


static func hint_for_target(from: Vector2, to: Vector2, what: String) -> String:
	var distance := from.distance_to(to)
	if distance < 90.0:
		return L.t("The %s is right beside you. Press E to reach it.") % what
	return L.t("I sense %s to the %s, %s.") % [what, compass_word(from, to), distance_phrase(distance)]


static func welcome(mode_id: StringName, lights_needed: int) -> String:
	var text := L.t("Hello, traveler! I'm Lumi. The meadow's light has drifted away. Shall we gather %d lights for the Heart Tree? Press H whenever you'd like a hint.") % lights_needed
	if mode_id == AdaptiveComfortEngine.MODE_GENTLE:
		text += L.t(" I'll glow toward the nearest light for you.")
	return text


static func first_light() -> String:
	return "You found one! Each light makes the meadow a little warmer."


static func enough_light() -> String:
	return "We have enough light now! Let's bring it to the Heart Tree in the middle of the meadow."


static func tree_needs_more(missing: int) -> String:
	return L.t("The Heart Tree needs %d more light. Let's keep exploring together, no hurry.") % missing


static func tree_restored() -> String:
	return "The Heart Tree is glowing again! If you like, we can bloom the garden beds, look for hidden details, or visit the Lantern Shrine to the east."


static func bed_needs_light() -> String:
	return "This bed needs 1 light. There are more lights drifting around the meadow."


static func reach_help() -> String:
	return "Step a little closer to the glow, then press E. The golden circle shows how far you can reach."


static func guidance_on() -> String:
	return "I'll glow toward the nearest light to help. You can switch this off in the pause menu."


static func lantern_night_start() -> String:
	return "The night is soft and quiet. Catch the drifting lanterns whenever you're ready. There's no timer, and you can end the night at the shrine anytime."


static func lantern_night_complete() -> String:
	return "The sky is full of lanterns. Thank you for sharing this night with me."


static func lantern_night_ended_early() -> String:
	return "Dawn is coming back. We can light lanterns again whenever you like."


static func nothing_left() -> String:
	return "Every light in the meadow has been gathered. Feel free to wander, or visit the Lantern Shrine."
