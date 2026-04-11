extends RefCounted
class_name FKEvalResult

## Result of an expression evaluation attempt.
## Wraps a success flag and the resulting value to distinguish
## 'evaluation failed' from 'evaluated to null'.

var success: bool
var value: Variant

## Good for providing further details about the evaluation.
var message := ""


func _init(p_success: bool = false, p_value: Variant = null, p_message = "") -> void:
	success = p_success
	value = p_value
	message = p_message

static func succeeded(p_value: Variant, p_message = "") -> FKEvalResult:
	return FKEvalResult.new(true, p_value, p_message)

static func failed(p_message = "") -> FKEvalResult:
	return FKEvalResult.new(false, null, p_message)
