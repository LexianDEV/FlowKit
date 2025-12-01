extends FKBehavior

## Platformer Movement Behavior
## A simple platformer character controller for CharacterBody2D nodes
## Supports horizontal movement and jumping with configurable input actions

func get_description() -> String:
    return "Basic platformer movement controller. Handles left/right movement and jumping for CharacterBody2D."

func get_id() -> String:
    return "platformer_movement"

func get_name() -> String:
    return "Platformer Movement"

func get_inputs() -> Array[Dictionary]:
    return [
        {"name": "move_left", "type": "String", "default": "ui_left"},
        {"name": "move_right", "type": "String", "default": "ui_right"},
        {"name": "jump", "type": "String", "default": "ui_accept"},
        {"name": "speed", "type": "float", "default": 200.0},
        {"name": "jump_force", "type": "float", "default": 350.0},
        {"name": "gravity", "type": "float", "default": 900.0}
    ]

func get_supported_types() -> Array[String]:
    return ["CharacterBody2D"]

func apply(node: Node, inputs: Dictionary) -> void:
    node.set_meta("flowkit_behavior_" + get_id(), inputs)

func remove(node: Node) -> void:
    var meta_key: String = "flowkit_behavior_" + get_id()
    if node.has_meta(meta_key):
        node.remove_meta(meta_key)

func physics_process(node: Node, delta: float, inputs: Dictionary) -> void:
    if not node is CharacterBody2D:
        return

    var body: CharacterBody2D = node as CharacterBody2D

    var left_action: String = inputs.get("move_left", "ui_left")
    var right_action: String = inputs.get("move_right", "ui_right")
    var jump_action: String = inputs.get("jump", "ui_accept")
    var speed: float = float(inputs.get("speed", 200.0))
    var jump_force: float = float(inputs.get("jump_force", 350.0))
    var gravity: float = float(inputs.get("gravity", 900.0))

    # Horizontal movement
    var direction: float = 0.0
    if Input.is_action_pressed(left_action):
        direction -= 1
    if Input.is_action_pressed(right_action):
        direction += 1

    body.velocity.x = direction * speed

    # Gravity
    body.velocity.y += gravity * delta

    # Jump
    if Input.is_action_just_pressed(jump_action) and body.is_on_floor():
        body.velocity.y = -jump_force

    body.move_and_slide()