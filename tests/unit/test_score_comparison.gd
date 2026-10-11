extends "res://tests/test_case.gd"
## Tests for ScoreComparison: sign convention, missing data and neutral wording.



func test_delta_sign_convention_is_post_minus_pre() -> void:
	assert_eq(ScoreComparison.compute_delta(7, 4), -3, "lower afterwards -> negative")
	assert_eq(ScoreComparison.compute_delta(3, 5), 2, "higher afterwards -> positive")
	assert_eq(ScoreComparison.compute_delta(5, 5), 0)
	assert_eq(ScoreComparison.compute_delta(0, 0), 0, "zero scores are valid")
	assert_eq(ScoreComparison.compute_delta(10, 0), -10)


func test_missing_scores_never_become_zero() -> void:
	assert_null(ScoreComparison.compute_delta(null, 4))
	assert_null(ScoreComparison.compute_delta(6, null))
	assert_null(ScoreComparison.compute_delta(null, null))
	assert_null(ScoreComparison.compute_delta(12, 4), "invalid pre score is not used")
	assert_eq(ScoreComparison.classify(null, 4), ScoreComparison.OUTCOME_INCOMPLETE)


func test_classification() -> void:
	assert_eq(ScoreComparison.classify(7, 4), ScoreComparison.OUTCOME_DECREASED)
	assert_eq(ScoreComparison.classify(4, 7), ScoreComparison.OUTCOME_INCREASED)
	assert_eq(ScoreComparison.classify(4, 4), ScoreComparison.OUTCOME_UNCHANGED)


func test_neutral_descriptions() -> void:
	assert_eq(ScoreComparison.describe(7, 4), "Your reported stress score decreased by 3 points during this session.")
	assert_eq(ScoreComparison.describe(5, 5), "Your reported stress score stayed the same during this session.")
	assert_true(ScoreComparison.describe(4, 6).begins_with("Your reported stress score increased by 2 points"))
	assert_true(ScoreComparison.describe(4, 5).contains("by 1 point "), "singular unit")


func test_incomplete_descriptions_explain_what_is_missing() -> void:
	assert_true(ScoreComparison.describe(null, 4).contains("before playing was skipped"))
	assert_true(ScoreComparison.describe(4, null).contains("after playing was skipped"))
	assert_true(ScoreComparison.describe(null, null).contains("both reflection questions were skipped"))


func test_no_causal_or_clinical_language() -> void:
	var banned := ["cured", "diagnos", "reduced your", "anxiety", "the game made", "treat"]
	for pair in [[7, 4], [4, 7], [5, 5], [null, 3], [3, null]]:
		var text := ScoreComparison.describe(pair[0], pair[1]).to_lower()
		for word in banned:
			assert_false(text.contains(word), "'%s' found in: %s" % [word, text])
	assert_true(ScoreComparison.CAVEAT.contains("not a measurement or a diagnosis"))


func test_formatting() -> void:
	assert_eq(ScoreComparison.format_delta(7, 4), "-3 points")
	assert_eq(ScoreComparison.format_delta(4, 5), "+1 point")
	assert_eq(ScoreComparison.format_delta(5, 5), "0 points")
	assert_eq(ScoreComparison.format_delta(null, 5), "Not available")
	assert_eq(ScoreComparison.format_score(0), "0 / 10")
	assert_eq(ScoreComparison.format_score(null), "Not answered")
