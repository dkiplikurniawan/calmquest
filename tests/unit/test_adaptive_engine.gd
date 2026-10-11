extends "res://tests/test_case.gd"
## Tests for AdaptiveComfortEngine: recommendations, overrides, switching, bounds.



func test_every_valid_score_gets_a_recommendation() -> void:
	for score in range(0, 11):
		var rec := AdaptiveComfortEngine.recommend(score)
		assert_true(AdaptiveComfortEngine.is_valid_mode(rec["mode"]), "score %d produced invalid mode" % score)
		assert_eq(rec["source"], "score", "score %d source" % score)


func test_high_scores_recommend_gentle() -> void:
	for score in [7, 8, 9, 10]:
		var rec := AdaptiveComfortEngine.recommend(score)
		assert_eq(rec["mode"], AdaptiveComfortEngine.MODE_GENTLE, "score %d" % score)
		assert_false(rec["ask_preference"], "score %d should not ask" % score)


func test_middle_scores_recommend_balanced() -> void:
	for score in [4, 5, 6]:
		var rec := AdaptiveComfortEngine.recommend(score)
		assert_eq(rec["mode"], AdaptiveComfortEngine.MODE_BALANCED, "score %d" % score)
		assert_false(rec["ask_preference"])


func test_low_scores_ask_balanced_or_playful_without_assuming() -> void:
	for score in [0, 1, 2, 3]:
		var rec := AdaptiveComfortEngine.recommend(score)
		assert_eq(rec["mode"], AdaptiveComfortEngine.MODE_BALANCED, "default stays Balanced for score %d" % score)
		assert_true(rec["ask_preference"], "score %d should ask the player" % score)
		var choices: Array = rec["choices"]
		assert_true(choices.has(AdaptiveComfortEngine.MODE_BALANCED) and choices.has(AdaptiveComfortEngine.MODE_PLAYFUL), "choices for score %d" % score)


func test_skipped_check_in_defaults_to_balanced() -> void:
	var rec := AdaptiveComfortEngine.recommend(null)
	assert_eq(rec["mode"], AdaptiveComfortEngine.MODE_BALANCED)
	assert_eq(rec["source"], "skipped")
	assert_eq((rec["choices"] as Array).size(), 3, "all modes remain selectable")


func test_invalid_scores_are_rejected_not_rounded() -> void:
	for bad in [-1, 11, 100, 4.5, "5", true, NAN, INF]:
		assert_false(AdaptiveComfortEngine.is_valid_score(bad), "should reject %s" % str(bad))
		assert_null(AdaptiveComfortEngine.parse_score(bad), "parse should return null for %s" % str(bad))
		assert_eq(AdaptiveComfortEngine.recommend(bad)["source"], "invalid", "recommend source for %s" % str(bad))
		assert_eq(AdaptiveComfortEngine.recommend(bad)["mode"], AdaptiveComfortEngine.MODE_BALANCED)


func test_whole_number_floats_are_accepted() -> void:
	assert_true(AdaptiveComfortEngine.is_valid_score(7.0))
	assert_eq(AdaptiveComfortEngine.parse_score(7.0), 7)
	assert_eq(AdaptiveComfortEngine.parse_score(0), 0, "zero is a valid score, not missing")


func test_explicit_player_override() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_GENTLE)
	assert_eq(engine.get_mode_id(), AdaptiveComfortEngine.MODE_GENTLE)
	assert_true(engine.select_mode(AdaptiveComfortEngine.MODE_PLAYFUL, AdaptiveComfortEngine.REASON_PLAYER_CHOICE))
	assert_eq(engine.get_mode_id(), AdaptiveComfortEngine.MODE_PLAYFUL)


func test_switching_to_same_mode_is_a_no_op() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_BALANCED)
	var emitted := [0]
	engine.mode_changed.connect(func(_c, _r): emitted[0] += 1)
	assert_false(engine.select_mode(AdaptiveComfortEngine.MODE_BALANCED))
	assert_eq(emitted[0], 0, "no signal for unchanged mode")
	assert_true(engine.select_mode(AdaptiveComfortEngine.MODE_GENTLE))
	assert_eq(emitted[0], 1, "one signal per real change")


func test_unknown_mode_is_ignored() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_BALANCED)
	assert_false(engine.select_mode(&"turbo"))
	assert_eq(engine.get_mode_id(), AdaptiveComfortEngine.MODE_BALANCED)
	var fallback := AdaptiveComfortEngine.new(&"nonsense")
	assert_eq(fallback.get_mode_id(), AdaptiveComfortEngine.MODE_BALANCED, "constructor falls back to Balanced")


func test_calmer_and_livelier_requests() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_BALANCED)
	assert_true(engine.request_calmer())
	assert_eq(engine.get_mode_id(), AdaptiveComfortEngine.MODE_GENTLE)
	assert_true(engine.request_livelier())
	assert_eq(engine.get_mode_id(), AdaptiveComfortEngine.MODE_PLAYFUL)
	assert_eq(engine.get_mode_history().size(), 3)


func test_mode_switch_keeps_session_counters() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_BALANCED)
	engine.register_hint_request()
	engine.register_hint_request()
	engine.select_mode(AdaptiveComfortEngine.MODE_PLAYFUL)
	assert_eq(engine.hints_used, 2, "switching modes must not reset counters")


func test_modes_have_meaningful_differences() -> void:
	var g := AdaptiveComfortEngine.build_preset(AdaptiveComfortEngine.MODE_GENTLE)
	var b := AdaptiveComfortEngine.build_preset(AdaptiveComfortEngine.MODE_BALANCED)
	var p := AdaptiveComfortEngine.build_preset(AdaptiveComfortEngine.MODE_PLAYFUL)
	assert_true(g.interaction_radius > b.interaction_radius, "Gentle reach is more generous")
	assert_true(g.collectible_activity < b.collectible_activity, "Gentle lights move less")
	assert_true(p.collectible_activity > b.collectible_activity, "Playful lights move more")
	assert_true(g.lantern_drift_speed < b.lantern_drift_speed and b.lantern_drift_speed < p.lantern_drift_speed)
	assert_true(p.bonus_object_count > 0 and b.bonus_object_count == 0, "only Playful has bonus objects")
	assert_true(g.guidance_arrow_default and not b.guidance_arrow_default)
	assert_true(g.show_nearby_markers, "Gentle shows more visible prompts")


func test_all_presets_within_bounds() -> void:
	for mode in AdaptiveComfortEngine.ALL_MODES:
		var c := AdaptiveComfortEngine.build_preset(mode)
		assert_true(AdaptiveComfortEngine.is_config_within_bounds(c), "%s preset out of bounds" % mode)
		assert_true(c.lantern_drift_speed < 220.0 * 0.25, "%s lanterns must stay far slower than the player" % mode)


func test_clamp_config_forces_bounds() -> void:
	var c := ModeConfig.new()
	c.interaction_radius = 9999.0
	c.collectible_activity = -5.0
	c.lantern_drift_speed = 500.0
	c.lantern_count = 0
	c.bonus_object_count = 99
	c.animation_intensity = 10.0
	AdaptiveComfortEngine.clamp_config(c)
	assert_true(AdaptiveComfortEngine.is_config_within_bounds(c))
	assert_eq(c.interaction_radius, AdaptiveComfortEngine.INTERACTION_RADIUS_MAX)
	assert_eq(c.lantern_count, AdaptiveComfortEngine.LANTERN_COUNT_MIN)


func test_repeated_hints_enable_guidance() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_BALANCED)
	assert_false(engine.guidance_enabled)
	for i in AdaptiveComfortEngine.HINT_GUIDANCE_THRESHOLD - 1:
		assert_false(engine.register_hint_request()["guidance_enabled_now"])
	var result := engine.register_hint_request()
	assert_true(result["guidance_enabled_now"], "guidance turns on at threshold")
	assert_true(engine.guidance_enabled)
	assert_eq(engine.hints_used, AdaptiveComfortEngine.HINT_GUIDANCE_THRESHOLD)


func test_player_choice_beats_automatic_guidance() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_BALANCED)
	engine.set_guidance_enabled(false)
	for i in AdaptiveComfortEngine.HINT_GUIDANCE_THRESHOLD + 2:
		engine.register_hint_request()
	assert_false(engine.guidance_enabled, "explicit 'off' must be respected")


func test_auto_assist_can_be_disabled() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_BALANCED)
	engine.set_auto_assist_enabled(false)
	for i in AdaptiveComfortEngine.HINT_GUIDANCE_THRESHOLD + 1:
		engine.register_hint_request()
	assert_false(engine.guidance_enabled)
	for i in AdaptiveComfortEngine.OUT_OF_RANGE_HELP_THRESHOLD + 1:
		assert_false(engine.register_interaction_attempt(false, 80.0)["show_help"])
	assert_eq(engine.interaction_help_events, 0)


func test_out_of_range_attempts_trigger_help() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_BALANCED)
	var radius := engine.get_config().interaction_radius
	var near_miss := radius * 1.5
	for i in AdaptiveComfortEngine.OUT_OF_RANGE_HELP_THRESHOLD - 1:
		assert_false(engine.register_interaction_attempt(false, near_miss)["show_help"])
	assert_true(engine.register_interaction_attempt(false, near_miss)["show_help"])
	assert_eq(engine.interaction_help_events, 1)


func test_far_or_successful_attempts_do_not_count() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_BALANCED)
	var far := engine.get_config().interaction_radius * (AdaptiveComfortEngine.NEAR_MISS_RADIUS_FACTOR + 1.0)
	for i in 10:
		assert_false(engine.register_interaction_attempt(false, far)["show_help"])
		assert_false(engine.register_interaction_attempt(false, -1.0)["show_help"])
	engine.register_interaction_attempt(false, 80.0)
	engine.register_interaction_attempt(true, 10.0)
	assert_false(engine.register_interaction_attempt(false, 80.0)["show_help"], "success resets the streak")
	assert_eq(engine.interaction_help_events, 0)


func test_reset_session_counters() -> void:
	var engine := AdaptiveComfortEngine.new(AdaptiveComfortEngine.MODE_GENTLE)
	engine.register_hint_request()
	engine.set_guidance_enabled(false)
	engine.reset_session_counters()
	assert_eq(engine.hints_used, 0)
	assert_true(engine.guidance_enabled, "Gentle default guidance restored")
	assert_eq(engine.get_mode_id(), AdaptiveComfortEngine.MODE_GENTLE, "mode kept")
