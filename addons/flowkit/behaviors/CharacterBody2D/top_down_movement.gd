extends FKBehavior

## Top-Down Movement Behavior
## A simple top-down character controller for CharacterBody2D nodes
## Allows movement in 4 or 8 directions using configurable input actions

func get_description() -> String:
	return "Simple top-down movement controller. Handles directional input and movement automatically."

func get_id() -> String:
	return "top_down_movement"

func get_name() -> String:
	return "Top-Down Movement"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "move_up", "type": "String", "default": "ui_up"},
		{"name": "move_down", "type": "String", "default": "ui_down"},
		{"name": "move_left", "type": "String", "default": "ui_left"},
		{"name": "move_right", "type": "String", "default": "ui_right"},
		{"name": "speed", "type": "float", "default": 200.0}
	]

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func apply(node: Node, inputs: Dictionary) -> void:
	# Store the behavior data in node metadata using the behavior ID
	node.set_meta("flowkit_behavior_" + get_id(), inputs)

func remove(node: Node) -> void:
	# Remove the behavior metadata
	var meta_key: String = "flowkit_behavior_" + get_id()
	if node.has_meta(meta_key):
		node.remove_meta(meta_key)

func physics_process(node: Node, delta: float, inputs: Dictionary) -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	
	# Get input action names from inputs dictionary
	var up_action: String = inputs.get("move_up", "ui_up")
	var down_action: String = inputs.get("move_down", "ui_down")
	var left_action: String = inputs.get("move_left", "ui_left")
	var right_action: String = inputs.get("move_right", "ui_right")
	var speed: float = float(inputs.get("speed", 200.0))
	
	# Calculate movement direction
	var direction: Vector2 = Vector2.ZERO
	
	if Input.is_action_pressed(up_action):
		direction.y -= 1
	if Input.is_action_pressed(down_action):
		direction.y += 1
	if Input.is_action_pressed(left_action):
		direction.x -= 1
	if Input.is_action_pressed(right_action):
		direction.x += 1
	
	# Normalize for consistent diagonal speed
	if direction.length() > 0:
		direction = direction.normalized()
	
	# Apply movement
	body.velocity = direction * speed
	body.move_and_slide()
