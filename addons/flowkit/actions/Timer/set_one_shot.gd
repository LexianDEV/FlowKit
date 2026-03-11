extends FKAction

func get_description() -> String:
	return "Sets whether the timer is one-shot."

func get_id() -> String:
	return "set_one_shot"

func get_name() -> String:
	return "Set One Shot"

func get_inputs() -> Array[FKActionInput]:
	return [_one_shot_input]
	
static var _one_shot_input: FKBoolActionInput:
	get:
		return FKBoolActionInput.new("One Shot",
		"If true, the timer will only run once and then stop.")

func get_supported_types() -> Array[String]:
	return ["Timer"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if node and node is Timer:
		var one_shot: bool = _one_shot_input.get_val(inputs)
		node.one_shot = one_shot
