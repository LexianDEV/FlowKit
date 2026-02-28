extends FKBranch

## Built-in "If" branch provider.
## Classic if / else-if / else conditional control flow.
## Uses a condition (FKCondition) to decide whether to execute.

func get_description() -> String:
	return "Execute actions if a condition is true. Supports else-if and else chains."

func get_id() -> String:
	return "if_branch"

func get_name() -> String:
	return "If"

func get_type() -> String:
	return "chain"

func get_color() -> Color:
	return Color(0.3, 0.8, 0.5, 1)  # Green

func get_input_type() -> String:
	return "condition"

func should_execute(condition_result: bool, inputs: Dictionary, block_id: String = "") -> bool:
	return condition_result

func get_execution_count(inputs: Dictionary, block_id: String = "") -> int:
	return 1
