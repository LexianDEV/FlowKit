extends RefCounted
class_name FKDragData

func _init(init_type := DragTargetType.none, init_node: Node = null, init_data: Variant = null):
	type = init_type
	node = init_node
	data = init_data
	
var type: int = DragTargetType.none
var node: Node = null
var data: Variant = null

func to_str() -> String:
	var node_str = "null" if not node else \
	_node_and_data_str_format % [node.name, node.get_class()]
	var data_str = "null" if not data else \
	_node_and_data_str_format % [str(data), data.get_class()]
	
	var result: String = _string_format % [type, node_str, data_str]
	return result

var _node_and_data_str_format = "%s (class: %s)"
var _string_format = "Type: %d\nNode: %s\nData: %s"
