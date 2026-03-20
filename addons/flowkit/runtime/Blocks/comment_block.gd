extends FKBaseBlock
class_name FKCommentBlock

@export var text: String = ""

func _init() -> void:
	block_type = "comment"

func serialize() -> Dictionary:
	return {
		"type": block_type,
		"text": text,
	}

func deserialize(dict: Dictionary) -> void:
	text = dict.get("text", "")
