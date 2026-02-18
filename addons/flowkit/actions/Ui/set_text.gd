extends FKAction

func get_description() -> String:
	return "What you'd expect."

func get_id() -> String:
	return "Set Text"

func get_name() -> String:
	return "Set Text"
	
func get_inputs() -> Array:
	return \
	[
		{
			"name": "New Text",
			"type": "String",
			"description": "The text that the target will hold."
		},
	]
	
func get_supported_types() -> Array:
	return ["Label", "RichTextLabel", "Button", "TextEdit", "LineEdit"]

func execute(target_node: Node, inputs: Dictionary, _str := "") -> void:
	var new_text: String = inputs.get("New Text", "")
	var has_text: Variant = target_node
	var prev_text: String = has_text.text
	has_text.text = new_text
	var text_changed: bool = new_text != prev_text
	if !text_changed:
		return
	
	_emit_text_change_signal_as_needed(new_text, prev_text, target_node)

static func _emit_text_change_signal_as_needed(new_text: String, prev_text: String, target_node: Node):
	# Not all text-having Nodes announce their text-changes by default, so...
	var node_class = target_node.get_class()
	var we_should_signal = !auto_signals_own_text_changes.has(node_class)
	if we_should_signal:
		var globals = FlowKitSystem.global_signals
		globals.text_changed.emit(prev_text, new_text, target_node)
	pass

static var auto_signals_own_text_changes: Array = ["LineEdit"]
# ^Technically TextEdit does too, but only in response to user input or core engine code.
# Not when third-party scripts (like this one) change its text propery, hence why
# we're _not_ including it in this list.
