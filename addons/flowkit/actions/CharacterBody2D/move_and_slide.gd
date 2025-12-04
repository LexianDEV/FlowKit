extends FKAction

func get_description() -> String:
	return "Moves the character body and handles collisions by sliding along surfaces."

func get_id() -> String:
	return "move_and_slide"

func get_name() -> String:
	return "Move and Slide"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	body.move_and_slide()
