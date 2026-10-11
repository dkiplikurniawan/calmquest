extends RefCounted
## Minimal assertion helpers for the headless test runner (tests/run_tests.gd).
## Every method whose name starts with "test_" is executed by the runner.

var failures: PackedStringArray = []
var current_test: String = ""


func _fail(message: String) -> void:
	failures.append("%s: %s" % [current_test, message])


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		_fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		_fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	var same_kind := typeof(actual) == typeof(expected) or (numeric.has(typeof(actual)) and numeric.has(typeof(expected)))
	var string_like := [TYPE_STRING, TYPE_STRING_NAME]
	if not same_kind and string_like.has(typeof(actual)) and string_like.has(typeof(expected)):
		same_kind = true
	if not same_kind or actual != expected:
		_fail("%s expected <%s> but got <%s>" % [message, str(expected), str(actual)])


func assert_null(value: Variant, message: String = "expected null") -> void:
	if value != null:
		_fail("%s (got <%s>)" % [message, str(value)])


func assert_not_null(value: Variant, message: String = "expected a value") -> void:
	if value == null:
		_fail(message)
