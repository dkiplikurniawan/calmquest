class_name Weather
extends RefCounted
## Gentle daily weather: clear, cloudy, rain or mist. Each in-game day's
## weather is rolled once (deterministic per journey and day) and remembered
## in GameState.systems["weather"], so rainy days stay rainy after loading.
## Rain waters every planted crop. Weather never harms or blocks anything.
## The first two days are always clear, so a new journey starts sunny.

const KINDS: PackedStringArray = ["clear", "cloudy", "rain", "mist"]
## Chance weights for clear, cloudy, rain, mist.
const WEIGHTS: Array[int] = [50, 20, 20, 10]
const STATE_KEY := "weather"
const CALM_DAYS := 2
## Settings value: weather may be turned to "always clear" (it still never matters for safety).
static var always_clear: bool = false


static func _state() -> Dictionary:
	return GameState.system_state(STATE_KEY)


## Today's weather (rolls it the first time a day is asked about).
static func today() -> String:
	var s := _state()
	if int(s.get("day", -1)) != TimeManager.day:
		s["day"] = TimeManager.day
		s["today"] = roll(TimeManager.day, GameState.bound_session_id)
		if s["today"] == "rain":
			if not s.has("rain_days"):
				s["rain_days"] = {}
			(s["rain_days"] as Dictionary)[str(TimeManager.day)] = true
	if always_clear:
		return "clear"
	return String(s.get("today", "clear"))


## Weather the world actually behaves by (rain still waters crops even when
## the "always clear" visual setting is on, so nothing is lost by choosing it).
static func world_today() -> String:
	today()
	return String(_state().get("today", "clear"))


static func is_raining() -> bool:
	return world_today() == "rain"


static func rained_on(day: int) -> bool:
	today()
	return (_state().get("rain_days", {}) as Dictionary).has(str(day))


static func roll(day: int, journey: String) -> String:
	if day <= CALM_DAYS:
		return "clear"
	var total := 0
	for w in WEIGHTS:
		total += w
	var r := absi(hash([journey, day, "weather"])) % total
	for i in KINDS.size():
		r -= WEIGHTS[i]
		if r < 0:
			return KINDS[i]
	return "clear"


## For tests and tools: sets today's weather explicitly.
static func force(kind: String) -> void:
	today()
	var s := _state()
	s["today"] = kind
	if not s.has("rain_days"):
		s["rain_days"] = {}
	if kind == "rain":
		(s["rain_days"] as Dictionary)[str(TimeManager.day)] = true
	else:
		(s["rain_days"] as Dictionary).erase(str(TimeManager.day))


static func describe(kind: String) -> String:
	return L.t(String({"clear": "Clear skies", "cloudy": "Soft clouds", "rain": "Gentle rain", "mist": "Morning mist"}.get(kind, kind)))
