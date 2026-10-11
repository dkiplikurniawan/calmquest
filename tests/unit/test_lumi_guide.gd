extends "res://tests/test_case.gd"
## Tests for LumiGuide: hint directions and wording.


func test_compass_directions_use_screen_coordinates() -> void:
	var o := Vector2.ZERO
	assert_eq(LumiGuide.compass_word(o, Vector2(100, 0)), "east")
	assert_eq(LumiGuide.compass_word(o, Vector2(-100, 0)), "west")
	assert_eq(LumiGuide.compass_word(o, Vector2(0, -100)), "north", "negative y is up/north")
	assert_eq(LumiGuide.compass_word(o, Vector2(0, 100)), "south")
	assert_eq(LumiGuide.compass_word(o, Vector2(100, -100)), "north-east")
	assert_eq(LumiGuide.compass_word(o, Vector2(-100, 100)), "south-west")


func test_distance_phrases() -> void:
	assert_eq(LumiGuide.distance_phrase(100.0), "very close")
	assert_eq(LumiGuide.distance_phrase(500.0), "a little way off")
	assert_eq(LumiGuide.distance_phrase(2000.0), "further away")


func test_hint_text() -> void:
	assert_true(LumiGuide.hint_for_target(Vector2.ZERO, Vector2(10, 0), "a light").contains("right beside you"))
	assert_eq(LumiGuide.hint_for_target(Vector2.ZERO, Vector2(0, -900), "a light"), "I sense a light to the north, further away.")


func test_gentle_welcome_mentions_guidance() -> void:
	assert_true(LumiGuide.welcome(AdaptiveComfortEngine.MODE_GENTLE, 8).contains("glow toward"))
	assert_false(LumiGuide.welcome(AdaptiveComfortEngine.MODE_PLAYFUL, 8).contains("glow toward"))
	assert_true(LumiGuide.welcome(AdaptiveComfortEngine.MODE_BALANCED, 8).contains("8 lights"))
