class_name AdaptiveComfortEngine
extends RefCounted
## Transparent, rule-based adaptation for CALMQUEST.
##
## The engine never infers a player's psychological state. It only uses:
##   * an optional self-reported score (0-10) to *suggest* a mode,
##   * the mode the player explicitly selects,
##   * explicit hint requests and interaction attempts made outside the reach radius,
##   * explicit "calmer" / "livelier" requests.
## Every rule is a named constant below so the behavior can be audited and tuned.
## The class has no scene-tree dependencies, so it can be unit tested headlessly.

signal mode_changed(config: ModeConfig, reason: StringName)
signal assistance_changed(assistance: Dictionary)

const MODE_GENTLE := &"gentle"
const MODE_BALANCED := &"balanced"
const MODE_PLAYFUL := &"playful"
const ALL_MODES: Array[StringName] = [MODE_GENTLE, MODE_BALANCED, MODE_PLAYFUL]
const DEFAULT_MODE := MODE_BALANCED

# --- Recommendation policy (inclusive score bands) ---------------------------
const SCORE_MIN := 0
const SCORE_MAX := 10
## Scores 7-10 -> Gentle is suggested.
const GENTLE_MIN_SCORE := 7
## Scores 4-6 -> Balanced is suggested. Scores 0-3 -> ask Balanced or Playful.
const BALANCED_MIN_SCORE := 4

# --- In-session assistance rules ---------------------------------------------
## After this many explicit hint requests, the guiding arrow is switched on
## (unless the player turned it off themselves or disabled adaptive assistance).
const HINT_GUIDANCE_THRESHOLD := 3
## After this many interaction attempts just outside the reach radius,
## the game explains the control and briefly shows the reach circle.
const OUT_OF_RANGE_HELP_THRESHOLD := 2
## An attempt counts as "just outside" when the nearest object is within
## radius * NEAR_MISS_RADIUS_FACTOR. Pressing E in empty space is ignored.
const NEAR_MISS_RADIUS_FACTOR := 2.5

# --- Parameter bounds: every preset and adjustment must stay inside these ----
const INTERACTION_RADIUS_MIN := 40.0
const INTERACTION_RADIUS_MAX := 140.0
const ACTIVITY_MIN := 0.0
const ACTIVITY_MAX := 2.0
const ANIMATION_INTENSITY_MIN := 0.0
const ANIMATION_INTENSITY_MAX := 1.5
## Lanterns always move far slower than the player (220 px/s), so no fast reactions are needed.
const LANTERN_SPEED_MIN := 0.0
const LANTERN_SPEED_MAX := 40.0
const LANTERN_WANDER_MIN := 0.0
const LANTERN_WANDER_MAX := 140.0
const LANTERN_COUNT_MIN := 3
const LANTERN_COUNT_MAX := 12
const BONUS_COUNT_MIN := 0
const BONUS_COUNT_MAX := 3

# --- Reason codes reported with mode changes ----------------------------------
const REASON_RECOMMENDATION := &"recommendation"
const REASON_PLAYER_CHOICE := &"player_choice"
const REASON_CALMER_REQUEST := &"calmer_request"
const REASON_LIVELIER_REQUEST := &"livelier_request"
const REASON_SKIPPED_DEFAULT := &"skipped_default"
const REASON_RESET := &"reset"

var hints_used: int = 0
var interaction_help_events: int = 0
var guidance_enabled: bool = false
## When false, the engine only reacts to explicit requests (no automatic assistance).
var auto_assist_enabled: bool = true

var _config: ModeConfig
var _out_of_range_streak: int = 0
var _guidance_set_by_player: bool = false
var _guidance_auto_enabled: bool = false
var _mode_history: Array[StringName] = []


func _init(initial_mode: StringName = DEFAULT_MODE) -> void:
	if not is_valid_mode(initial_mode):
		push_warning("AdaptiveComfortEngine: unknown mode '%s', using Balanced." % initial_mode)
		initial_mode = DEFAULT_MODE
	_config = build_preset(initial_mode)
	guidance_enabled = _config.guidance_arrow_default
	_mode_history.append(initial_mode)


# =============================================================================
# Static helpers: validation, recommendation, presets
# =============================================================================

static func is_valid_mode(mode_id: Variant) -> bool:
	if typeof(mode_id) != TYPE_STRING_NAME and typeof(mode_id) != TYPE_STRING:
		return false
	return ALL_MODES.has(StringName(mode_id))


## True only for whole numbers in [SCORE_MIN, SCORE_MAX]. Booleans, strings,
## NaN and fractional values are rejected rather than silently rounded.
static func is_valid_score(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return value >= SCORE_MIN and value <= SCORE_MAX
		TYPE_FLOAT:
			var f: float = value
			if is_nan(f) or is_inf(f) or f != floorf(f):
				return false
			return f >= SCORE_MIN and f <= SCORE_MAX
		_:
			return false


## Returns the score as an int, or null when the value is missing or invalid.
static func parse_score(value: Variant) -> Variant:
	if not is_valid_score(value):
		return null
	return int(value)


## Transparent recommendation policy. The result is a suggestion only;
## the player can always pick any mode.
static func recommend(score: Variant) -> Dictionary:
	if score == null:
		return {
			"mode": DEFAULT_MODE,
			"ask_preference": false,
			"choices": ALL_MODES.duplicate(),
			"source": "skipped",
			"message": "No check-in today, so Balanced is selected. You can pick any mode.",
		}
	if not is_valid_score(score):
		return {
			"mode": DEFAULT_MODE,
			"ask_preference": false,
			"choices": ALL_MODES.duplicate(),
			"source": "invalid",
			"message": "That answer was outside 0-10, so Balanced is selected. You can pick any mode.",
		}
	var s := int(score)
	if s >= GENTLE_MIN_SCORE:
		return {
			"mode": MODE_GENTLE,
			"ask_preference": false,
			"choices": [MODE_GENTLE],
			"source": "score",
			"message": "Suggested: Gentle mode, for a slower and softer pace. Any mode is welcome.",
		}
	if s >= BALANCED_MIN_SCORE:
		return {
			"mode": MODE_BALANCED,
			"ask_preference": false,
			"choices": [MODE_BALANCED],
			"source": "score",
			"message": "Suggested: Balanced mode, the standard cozy pace. Any mode is welcome.",
		}
	return {
		"mode": MODE_BALANCED,
		"ask_preference": true,
		"choices": [MODE_BALANCED, MODE_PLAYFUL],
		"source": "score",
		"message": "Would you like Balanced or a livelier Playful meadow? Either is a great choice.",
	}


static func build_preset(mode_id: StringName) -> ModeConfig:
	var c := ModeConfig.new()
	match mode_id:
		MODE_GENTLE:
			c.mode_id = MODE_GENTLE
			c.display_name = "Gentle"
			c.description = "A slower, softer pace. Lights barely drift, your reach is generous, and Lumi's guiding glow is on."
			c.collectible_activity = 0.35
			c.interaction_radius = 104.0
			c.show_nearby_markers = true
			c.guidance_arrow_default = true
			c.bonus_object_count = 0
			c.animation_intensity = 0.6
			c.lantern_count = 6
			c.bonus_lantern_count = 0
			c.lantern_drift_speed = 6.0
			c.lantern_wander_radius = 14.0
		MODE_PLAYFUL:
			c.mode_id = MODE_PLAYFUL
			c.display_name = "Playful"
			c.description = "A livelier meadow. Lights wander a little more and bonus Prism Motes appear. Still no timers and no failure."
			c.collectible_activity = 1.5
			c.interaction_radius = 64.0
			c.show_nearby_markers = false
			c.guidance_arrow_default = false
			c.bonus_object_count = 3
			c.animation_intensity = 1.2
			c.lantern_count = 10
			c.bonus_lantern_count = 2
			c.lantern_drift_speed = 30.0
			c.lantern_wander_radius = 110.0
		_:
			c.mode_id = MODE_BALANCED
			c.display_name = "Balanced"
			c.description = "The standard cozy experience. Lights drift gently and Lumi helps whenever you ask."
			c.collectible_activity = 1.0
			c.interaction_radius = 72.0
			c.show_nearby_markers = false
			c.guidance_arrow_default = false
			c.bonus_object_count = 0
			c.animation_intensity = 1.0
			c.lantern_count = 8
			c.bonus_lantern_count = 0
			c.lantern_drift_speed = 18.0
			c.lantern_wander_radius = 60.0
	return clamp_config(c)


## Forces every parameter into its documented bounds (in place) and returns the config.
static func clamp_config(c: ModeConfig) -> ModeConfig:
	c.collectible_activity = clampf(c.collectible_activity, ACTIVITY_MIN, ACTIVITY_MAX)
	c.interaction_radius = clampf(c.interaction_radius, INTERACTION_RADIUS_MIN, INTERACTION_RADIUS_MAX)
	c.animation_intensity = clampf(c.animation_intensity, ANIMATION_INTENSITY_MIN, ANIMATION_INTENSITY_MAX)
	c.bonus_object_count = clampi(c.bonus_object_count, BONUS_COUNT_MIN, BONUS_COUNT_MAX)
	c.lantern_count = clampi(c.lantern_count, LANTERN_COUNT_MIN, LANTERN_COUNT_MAX)
	c.bonus_lantern_count = clampi(c.bonus_lantern_count, BONUS_COUNT_MIN, BONUS_COUNT_MAX)
	c.lantern_drift_speed = clampf(c.lantern_drift_speed, LANTERN_SPEED_MIN, LANTERN_SPEED_MAX)
	c.lantern_wander_radius = clampf(c.lantern_wander_radius, LANTERN_WANDER_MIN, LANTERN_WANDER_MAX)
	return c


static func is_config_within_bounds(c: ModeConfig) -> bool:
	return (
		c.collectible_activity >= ACTIVITY_MIN and c.collectible_activity <= ACTIVITY_MAX
		and c.interaction_radius >= INTERACTION_RADIUS_MIN and c.interaction_radius <= INTERACTION_RADIUS_MAX
		and c.animation_intensity >= ANIMATION_INTENSITY_MIN and c.animation_intensity <= ANIMATION_INTENSITY_MAX
		and c.bonus_object_count >= BONUS_COUNT_MIN and c.bonus_object_count <= BONUS_COUNT_MAX
		and c.lantern_count >= LANTERN_COUNT_MIN and c.lantern_count <= LANTERN_COUNT_MAX
		and c.bonus_lantern_count >= BONUS_COUNT_MIN and c.bonus_lantern_count <= BONUS_COUNT_MAX
		and c.lantern_drift_speed >= LANTERN_SPEED_MIN and c.lantern_drift_speed <= LANTERN_SPEED_MAX
		and c.lantern_wander_radius >= LANTERN_WANDER_MIN and c.lantern_wander_radius <= LANTERN_WANDER_MAX
	)


# =============================================================================
# Instance API
# =============================================================================

## The active configuration. Treat it as read-only; use select_mode() to change it.
func get_config() -> ModeConfig:
	return _config


func get_mode_id() -> StringName:
	return _config.mode_id


func get_mode_history() -> Array[StringName]:
	return _mode_history.duplicate()


## Switches mode. Returns true if the mode actually changed.
## Session counters and collected progress are deliberately left untouched.
func select_mode(mode_id: StringName, reason: StringName = REASON_PLAYER_CHOICE) -> bool:
	if not is_valid_mode(mode_id):
		push_warning("AdaptiveComfortEngine: ignoring unknown mode '%s'." % mode_id)
		return false
	if mode_id == _config.mode_id:
		return false
	_config = build_preset(mode_id)
	_mode_history.append(mode_id)
	if not _guidance_set_by_player:
		guidance_enabled = _config.guidance_arrow_default or _guidance_auto_enabled
	mode_changed.emit(_config, reason)
	assistance_changed.emit(get_assistance())
	return true


## Explicit player request for a calmer experience.
func request_calmer() -> bool:
	return select_mode(MODE_GENTLE, REASON_CALMER_REQUEST)


## Explicit player request for a livelier experience. Never triggered automatically.
func request_livelier() -> bool:
	return select_mode(MODE_PLAYFUL, REASON_LIVELIER_REQUEST)


## Call when the player explicitly asks Lumi for a hint.
## Returns {"show_hint": bool, "guidance_enabled_now": bool}.
func register_hint_request() -> Dictionary:
	hints_used += 1
	var result := {"show_hint": true, "guidance_enabled_now": false}
	if (auto_assist_enabled
			and not guidance_enabled
			and not _guidance_set_by_player
			and hints_used >= HINT_GUIDANCE_THRESHOLD):
		guidance_enabled = true
		_guidance_auto_enabled = true
		result["guidance_enabled_now"] = true
		assistance_changed.emit(get_assistance())
	return result


## Call when the player presses the interact key.
## had_target: an object was inside the reach radius (the interaction succeeded).
## nearest_distance: distance to the nearest interactable, or a negative value if none exist.
## Returns {"show_help": bool}.
func register_interaction_attempt(had_target: bool, nearest_distance: float) -> Dictionary:
	if had_target:
		_out_of_range_streak = 0
		return {"show_help": false}
	var near_miss_limit := _config.interaction_radius * NEAR_MISS_RADIUS_FACTOR
	if nearest_distance < 0.0 or nearest_distance > near_miss_limit:
		return {"show_help": false}
	_out_of_range_streak += 1
	if auto_assist_enabled and _out_of_range_streak >= OUT_OF_RANGE_HELP_THRESHOLD:
		_out_of_range_streak = 0
		interaction_help_events += 1
		return {"show_help": true}
	return {"show_help": false}


## Explicit player toggle (pause menu / settings). Player choices always win over rules.
func set_guidance_enabled(enabled: bool) -> void:
	_guidance_set_by_player = true
	if guidance_enabled == enabled:
		return
	guidance_enabled = enabled
	assistance_changed.emit(get_assistance())


func set_auto_assist_enabled(enabled: bool) -> void:
	auto_assist_enabled = enabled


func get_assistance() -> Dictionary:
	return {
		"guidance_enabled": guidance_enabled,
		"auto_assist_enabled": auto_assist_enabled,
		"hints_used": hints_used,
		"interaction_help_events": interaction_help_events,
	}


## Clears per-session counters (used by Restart Session). Keeps the current mode.
func reset_session_counters() -> void:
	hints_used = 0
	interaction_help_events = 0
	_out_of_range_streak = 0
	_guidance_set_by_player = false
	_guidance_auto_enabled = false
	guidance_enabled = _config.guidance_arrow_default
	assistance_changed.emit(get_assistance())
