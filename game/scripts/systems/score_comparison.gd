class_name ScoreComparison
extends RefCounted
## Single source of truth for comparing pre- and post-session self-reports.
##
## Sign convention (used everywhere, including the Python analysis):
##     score_delta = post_stress_score - pre_stress_score
## Negative -> the later self-reported score was lower.
## Positive -> the later self-reported score was higher.
## Zero     -> no numerical change.
## Missing scores stay missing (null); they are never replaced with zero.
##
## All wording is neutral and descriptive. A change between two self-reports
## does not show that the game caused it.

const OUTCOME_DECREASED := &"decreased"
const OUTCOME_UNCHANGED := &"unchanged"
const OUTCOME_INCREASED := &"increased"
const OUTCOME_INCOMPLETE := &"incomplete"

const CAVEAT := "This compares two answers you gave about yourself. It is not a measurement or a diagnosis, and many things can influence how you feel."


## Returns post - pre as an int, or null if either score is missing or invalid.
static func compute_delta(pre: Variant, post: Variant) -> Variant:
	var p: Variant = AdaptiveComfortEngine.parse_score(pre)
	var q: Variant = AdaptiveComfortEngine.parse_score(post)
	if p == null or q == null:
		return null
	return int(q) - int(p)


static func classify(pre: Variant, post: Variant) -> StringName:
	var delta: Variant = compute_delta(pre, post)
	if delta == null:
		return OUTCOME_INCOMPLETE
	if int(delta) < 0:
		return OUTCOME_DECREASED
	if int(delta) > 0:
		return OUTCOME_INCREASED
	return OUTCOME_UNCHANGED


static func format_score(score: Variant) -> String:
	var s: Variant = AdaptiveComfortEngine.parse_score(score)
	if s == null:
		return "Not answered"
	return "%d / 10" % int(s)


## Signed delta text such as "-3 points", "0 points" or "+2 points".
static func format_delta(pre: Variant, post: Variant) -> String:
	var delta: Variant = compute_delta(pre, post)
	if delta == null:
		return "Not available"
	var d := int(delta)
	var unit := L.t("point") if absi(d) == 1 else L.t("points")
	if d > 0:
		return "+%d %s" % [d, unit]
	return "%d %s" % [d, unit]


## Neutral one-sentence summary for the results screen.
static func describe(pre: Variant, post: Variant) -> String:
	var outcome := classify(pre, post)
	if outcome == OUTCOME_INCOMPLETE:
		var have_pre := AdaptiveComfortEngine.parse_score(pre) != null
		var have_post := AdaptiveComfortEngine.parse_score(post) != null
		if not have_pre and not have_post:
			return "A comparison isn't available because both reflection questions were skipped. That's completely fine."
		if not have_pre:
			return "A full comparison isn't available because the check-in before playing was skipped."
		return "A full comparison isn't available because the reflection after playing was skipped."
	var d := int(compute_delta(pre, post))
	var magnitude := absi(d)
	var unit := L.t("point") if magnitude == 1 else L.t("points")
	match outcome:
		OUTCOME_DECREASED:
			return L.t("Your reported stress score decreased by %d %s during this session.") % [magnitude, unit]
		OUTCOME_INCREASED:
			return L.t("Your reported stress score increased by %d %s during this session. Thank you for answering honestly; every answer is welcome.") % [magnitude, unit]
		_:
			return "Your reported stress score stayed the same during this session."
