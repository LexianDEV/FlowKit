extends FKBranch

## Built-in "Repeat" branch provider.
## Repeats the branch body a specified number of times.
## Uses an evaluation input for the repeat count.

func get_description() -> String:
	return "Repeat the enclosed actions a given number of times."

func get_id() -> String:
	return "repeat"

func get_name() -> String:
	return "Repeat"

func get_type() -> String:
	return "single"

func get_color() -> Color:
	return Color(0.4, 0.6, 0.9, 1)

func get_input_type() -> String:
	return "evaluation"

func get_inputs() -> Array[Dictionary]:
	return [{"name": "times", "type": "int"}]

func should_execute(condition_result: bool, inputs: Dictionary, block_id: String = "") -> bool:
	var times = inputs.get("times", 0)
	if times is String:
		times = int(times)
	return times > 0

func get_execution_count(inputs: Dictionary, block_id: String = "") -> int:
	var times = inputs.get("times", 1)
	if times is String:
		times = int(times)
	return max(times, 0)
