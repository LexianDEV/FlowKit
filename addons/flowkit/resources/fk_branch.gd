extends Resource
class_name FKBranch

## Base class for FlowKit branch providers.
## Branches define control-flow constructs (if, repeat, etc.) that wrap actions.
## Extend this class to create custom branch types that appear in the "Add..." menu.

func get_description() -> String:
	return "No description provided."

func get_id() -> String:
	return ""

func get_name() -> String:
	return ""

func get_type() -> String:
	## Returns "single" or "chain".
	## "single" — the branch stands alone; no else-if / else blocks can follow.
	## "chain" — else-if / else blocks can be appended after this branch.
	return "single"

func get_color() -> Color:
	## The accent color used for this branch in the editor UI (type label, icon, body).
	## Override to customise per-provider.
	return Color(0.3, 0.8, 0.5, 1)  # Default green

func get_input_type() -> String:
	## Returns "condition" or "evaluation".
	## "condition" — uses the FKCondition pipeline (node selector > condition > expression modal).
	##   The branch condition can be negated.
	## "evaluation" — uses the expression evaluator directly (expression modal, no node selector).
	return "condition"

func get_inputs() -> Array[Dictionary]:
	## For "evaluation" type branches, returns input definitions.
	## Each dictionary: {"name": String, "type": String}
	## These appear as fields in the expression editor modal.
	return []

func should_execute(condition_result: bool, inputs: Dictionary, block_id: String = "") -> bool:
	## Determines whether the branch body should run.
	## For "condition" type: condition_result is the FKCondition check (negation already applied).
	## For "evaluation" type: inputs holds the evaluated expression values;
	##   condition_result is always false and should be ignored.
	return condition_result

func get_execution_count(inputs: Dictionary, block_id: String = "") -> int:
	## How many times the branch body executes when should_execute() is true.
	## Default is 1 (standard if-style). Override for repeat-style branches.
	return 1
