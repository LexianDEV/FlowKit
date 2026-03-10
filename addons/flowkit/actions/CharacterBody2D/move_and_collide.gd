extends FKAction

func get_description() -> String:
	return "Moves the character body by the specified amount and returns collision information."

func get_id() -> String:
	return "move_and_collide"

func get_name() -> String:
	return "Move and Collide"

func get_inputs() -> Array[FKActionInput]:
	return [_x_input, _y_input]

static var _x_input: FKActionInput:
	get:
		return FKActionInput.new("X", "Float",
		"The amount to move the character body along the X axis.")

static var _y_input: FKActionInput:
	get:
		return FKActionInput.new("Y", "Float",
		"The amount to move the character body along the Y axis.")

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	var x: float = float(inputs.get("X", 0))
	var y: float = float(inputs.get("Y", 0))

	body.move_and_collide(Vector2(x, y))
