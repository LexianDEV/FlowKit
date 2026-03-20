@tool
class_name FKSerializationManager
# Note: we serialize to Dictionaries (instead of Resources) for the sake of the undo/redo
# system. Of course, we _de_serialize to Resources since that's what we most
# want to use in RAM.

# Serialization #
func capture_state(blocks: Array[Node]) -> Array[Dictionary]:
	"""Capture the state of the passed block Nodes as serialized data."""
	var state: Array[Dictionary] = []

	for block_el in blocks:
		# Double-check the block is still valid and not queued for deletion
		if not is_instance_valid(block_el) or block_el.is_queued_for_deletion():
			continue
		
		var serialized := serialize_block(block_el)
		state.append(serialized)
			
	return state
	
	
func serialize_block(block_node: Node) -> Dictionary:
	var data: FKBaseBlock = null

	if block_node.has_method("get_event_data"):
		data = block_node.get_event_data()
	elif block_node.has_method("get_comment_data"):
		data = block_node.get_comment_data()
	elif block_node.has_method("get_group_data"):
		data = block_node.get_group_data()
	else:
		printerr("serialize_block: Node does not expose block data.")
		return {}

	return data.serialize()


# Deserialization #
func restore_state(state: Array[Dictionary]) -> Array[FKBaseBlock]:
	var result: Array[FKBaseBlock] = []

	for dict in state:
		var block := deserialize_block(dict)
		if block:
			result.append(block)
			
	return result
	
	
func deserialize_block(dict: Dictionary) -> FKBaseBlock:
	var block_type := dict.get("type", "")
	var block := _instantiate_block(block_type)
	if block == null:
		printerr("deserialize_block: Unknown block type '%s'" % block_type)
		return null

	block.deserialize(dict)
	return block

func _instantiate_block(block_type: String) -> FKBaseBlock:
	match block_type:
		"event":
			return FKEventBlock.new()
		"comment":
			return FKCommentBlock.new()
		"group":
			return FKGroupBlock.new()
		_:
			return null


	
