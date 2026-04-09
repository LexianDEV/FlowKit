extends RefCounted
class_name FKEvalResult

## Result of an expression evaluation attempt.
## Wraps a success flag and the resulting value to distinguish
## 'evaluation failed' from 'evaluated to null'.

var success: bool
var value: Variant

func _init(p_success: bool = false, p_value: Variant = null) -> void:
	success = p_success
	value = p_value

static func succeeded(p_value: Variant) -> FKEvalResult:
	return FKEvalResult.new(true, p_value)

static func failed() -> FKEvalResult:
	return FKEvalResult.new(false, null)
