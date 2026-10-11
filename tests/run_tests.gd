extends SceneTree
## Headless unit-test runner for deterministic game logic.
##
## Usage (from the project folder):
##   godot --headless --path . --import
##   godot --headless --path . --script res://tests/run_tests.gd
## Exit code 0 = all tests passed, 1 = at least one failure.

const TEST_SCRIPTS: PackedStringArray = [
	"res://tests/unit/test_adaptive_engine.gd",
	"res://tests/unit/test_score_comparison.gd",
	"res://tests/unit/test_data_layer.gd",
	"res://tests/unit/test_lumi_guide.gd",
	"res://tests/unit/test_world.gd",
	"res://tests/unit/test_quests_and_puzzle.gd",
	"res://tests/unit/test_items.gd",
	"res://tests/unit/test_saves.gd",
	"res://tests/unit/test_wider_world.gd",
	"res://tests/unit/test_homeland.gd",
	"res://tests/unit/test_caverns.gd",
	"res://tests/unit/test_village.gd",
	"res://tests/unit/test_highlands.gd",
	"res://tests/unit/test_audio_input.gd",
	"res://tests/unit/test_localization.gd",
	"res://tests/unit/test_wellbeing.gd",
	"res://tests/unit/test_study_mode.gd",
	"res://tests/unit/test_audio_polish.gd",
	"res://tests/unit/test_visual_polish.gd",
	"res://tests/unit/test_rest_and_breathe.gd",
]


## Counts engine/script errors so a test that crashes mid-way is reported as
## failed instead of silently passing (Logger is available since Godot 4.5).
class ErrorCounter extends Logger:
	var count: int = 0
	var last: String = ""

	func _log_error(function: String, file: String, line: int, _code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		count += 1
		last = "%s (%s:%d %s)" % [rationale, file.get_file(), line, function]

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _started: bool = false


## Autoloads finish their _ready() after _initialize(), so the tests start on
## the first processed frame instead.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_all()
	return false


func _run_all() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	# Assertions compare English text; the player's chosen language must not change them.
	L.set_language("en")
	var total := 0
	var failed := 0
	var messages := PackedStringArray()
	for script_path in TEST_SCRIPTS:
		var script: GDScript = load(script_path)
		if script == null or not script.can_instantiate():
			messages.append("FAIL could not load or parse %s" % script_path)
			failed += 1
			total += 1
			continue
		var suite: RefCounted = script.new()
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			suite.set("current_test", "%s::%s" % [script_path.get_file(), method_name])
			var before: int = (suite.get("failures") as PackedStringArray).size()
			var errors_before := errors.count
			suite.call(method_name)
			var after_failures: PackedStringArray = suite.get("failures")
			if errors.count > errors_before:
				after_failures.append("%s::%s: script error: %s" % [script_path.get_file(), method_name, errors.last])
				suite.set("failures", after_failures)
			if after_failures.size() > before:
				failed += 1
				for i in range(before, after_failures.size()):
					messages.append("FAIL " + after_failures[i])
			else:
				print("  ok   %s::%s" % [script_path.get_file(), method_name])
	for m in messages:
		printerr(m)
	print("")
	print("Unit tests: %d run, %d passed, %d failed" % [total, total - failed, failed])
	quit(0 if failed == 0 else 1)
