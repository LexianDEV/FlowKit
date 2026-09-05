extends FKProvider

## Base class for FlowKit branch providers.
## Branches define control-flow constructs (if, repeat, etc.) that wrap actions.
## Extend this class to create custom branch types that appear in the "Add..." menu.
class_name FKBranch

func get_provider_kind() -> String:
	return KIND_BRANCH

func get_type() -> String:
	## Returns "single" or "chain".
	## "single" — the branch stands alone; no else-if / else units can follow.
	## "chain" — else-if / else units can be appended after this branch.
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

func should_execute(condition_result: bool, inputs: Dictionary, unit_id: int = -1) -> bool:
	## Determines whether the branch body should run.
	## For "condition" type: condition_result is the FKCondition check (negation already applied).
	## For "evaluation" type: inputs holds the evaluated expression values;
	##   condition_result is always false and should be ignored.
	return condition_result

func get_execution_count(inputs: Dictionary, unit_id: int = -1) -> int:
	## How many times the branch body executes when should_execute() is true.
	## Default is 1 (standard if-style). Override for repeat-style branches.
	return 1

func get_class() -> String:
	return "FKBranch"
