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

func serialize() -> Variant:
	var result = {
		"action_id": self.action_id,
		"target_node": str(self.target_node),
		"inputs": self.inputs.duplicate(),
		"is_branch": self.is_branch,
		"branch_type": self.branch_type,
		"branch_id": self.branch_id,
		"branch_inputs": self.branch_inputs.duplicate()
	}
	
	if is_branch:
		if branch_condition:
			result["branch_condition"] = branch_condition.serialize()
		var copied_actions: Array = []
		for act in self.branch_actions:
			var serialized := act.serialize()
			copied_actions.append(serialized)
		result["branch_actions"] = copied_actions
	
	return result
