extends Resource
class_name FKEventAction

@export var action_id: String
@export var target_node: NodePath
@export var inputs: Dictionary = {}

# Branch support
@export var is_branch: bool = false
@export var branch_type: String = ""  # Chain position: "if", "elseif", "else"
@export var branch_id: String = ""  # Branch provider ID (e.g., "if_branch", "repeat")
@export var branch_condition: FKEventCondition = null  # For condition-type branches
@export var branch_inputs: Dictionary = {}  # For evaluation-type branches
@export var branch_actions: Array[FKEventAction] = []
