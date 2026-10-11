extends Node
## In-game clock (autoload "TimeManager").
##
## A full day lasts `GameSettings.day_length_minutes` real minutes (15-24).
## Night is always safe. Players can keep it day or night permanently, and in
## Gentle mode the clock can run slowly or pause (Settings). Sleeping in the
## cottage bed skips to morning. The clock only runs while the overworld is
## active and the game is not paused.

signal day_started(day: int)
signal phase_changed(phase: String)

const MINUTES_PER_DAY := 1440.0
const START_MINUTE := 8.0 * 60.0
const WAKE_MINUTE := 6.5 * 60.0
const MODE_NORMAL := 0
const MODE_ALWAYS_DAY := 1
const MODE_ALWAYS_NIGHT := 2
const FIXED_DAY_MINUTE := 11.0 * 60.0
const FIXED_NIGHT_MINUTE := 23.0 * 60.0
## Gentle clock options: 0 normal speed, 1 half speed, 2 paused.
const GENTLE_SLOW_FACTOR := 0.5

var day: int = 1
var minute_of_day: float = START_MINUTE
var running: bool = false
var _phase: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_phase = phase()


func _process(delta: float) -> void:
	if not running:
		return
	advance(delta * minutes_per_second())


## In-game minutes that pass per real second, after settings and mode.
func minutes_per_second() -> float:
	if GameSettings.time_mode != MODE_NORMAL:
		return 0.0
	var rate := MINUTES_PER_DAY / (maxf(1.0, float(GameSettings.day_length_minutes)) * 60.0)
	if SessionState.get_config().mode_id == AdaptiveComfortEngine.MODE_GENTLE:
		match GameSettings.gentle_clock:
			1:
				rate *= GENTLE_SLOW_FACTOR
			2:
				rate = 0.0
	return rate


func advance(minutes: float) -> void:
	if minutes <= 0.0:
		return
	minute_of_day += minutes
	while minute_of_day >= MINUTES_PER_DAY:
		minute_of_day -= MINUTES_PER_DAY
		day += 1
		day_started.emit(day)
	_check_phase()


## Sleeping: the next morning, as a new day.
func sleep_until_morning() -> void:
	day += 1
	minute_of_day = WAKE_MINUTE
	day_started.emit(day)
	_check_phase()


## The minute used for visuals (respects "keep it day/night").
func visual_minute() -> float:
	match GameSettings.time_mode:
		MODE_ALWAYS_DAY:
			return FIXED_DAY_MINUTE
		MODE_ALWAYS_NIGHT:
			return FIXED_NIGHT_MINUTE
	return minute_of_day


## 1.0 in full daylight, 0.0 at night, smooth at dawn (5-7h) and dusk (18-20h).
func daylight() -> float:
	var h := visual_minute() / 60.0
	if h < 5.0 or h >= 20.0:
		return 0.0
	if h < 7.0:
		return smoothstep(5.0, 7.0, h)
	if h < 18.0:
		return 1.0
	return 1.0 - smoothstep(18.0, 20.0, h)


## 0..1 strength of warm dusk/dawn colors.
func twilight() -> float:
	var h := visual_minute() / 60.0
	var dawn := 1.0 - absf(h - 6.0) / 1.5
	var dusk := 1.0 - absf(h - 18.75) / 1.5
	return clampf(maxf(dawn, dusk), 0.0, 1.0)


func is_night() -> bool:
	return daylight() < 0.35


func phase() -> String:
	var h := visual_minute() / 60.0
	if h >= 5.0 and h < 8.0:
		return "dawn"
	if h >= 8.0 and h < 18.0:
		return "day"
	if h >= 18.0 and h < 20.5:
		return "dusk"
	return "night"


func clock_text() -> String:
	var m := int(visual_minute())
	return L.t("Day %d  %02d:%02d") % [day, m / 60, m % 60]


func _check_phase() -> void:
	var p := phase()
	if p != _phase:
		_phase = p
		phase_changed.emit(p)


func reset_clock() -> void:
	day = 1
	minute_of_day = START_MINUTE
	_phase = phase()


func to_state() -> Dictionary:
	return {"day": day, "minute": minute_of_day}


func load_state(state: Dictionary) -> void:
	day = maxi(1, int(state.get("day", 1)))
	minute_of_day = clampf(float(state.get("minute", START_MINUTE)), 0.0, MINUTES_PER_DAY - 0.01)
	_phase = phase()
