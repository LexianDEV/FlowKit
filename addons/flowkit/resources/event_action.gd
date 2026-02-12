extends Resource
class_name FKEventAction

@export var action_id: String
@export var target_node: NodePath
@export var inputs: Dictionary = {}

# Branch support (if/elseif/else)
@export var is_branch: bool = false
@export var branch_type: String = ""  # "if", "elseif", "else"
@export var branch_condition: FKEventCondition = null
@export var branch_actions: Array[FKEventAction] = []
