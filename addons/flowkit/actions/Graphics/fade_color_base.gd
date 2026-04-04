extends FKAction
class_name FadeColorBase

func requires_multi_frames() -> bool:
	return true
	
func get_inputs() -> Array[FKActionInput]:
	return [_targ_color_input, _alpha_input, _alpha_only_input, \
	_duration_input, _wait_for_finish_input]
	
static var _targ_color_input: FKActionInput:
	get:
		return FKActionInput.new("Target Color", "String",
		"The color in RGB coordinates. For example, \"(255, 255, 255)\" (include the quotes) " + \
		"for white. If empty, defaults to that color.",
		default_color_raw)

static var _alpha_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("Alpha", 
		"How transparent the color should be. 0 for completely transparent, 100 for opaque. " +\
		"Default: " + str(default_alpha) + ".",
		default_alpha)

static var _alpha_only_input: FKBoolActionInput:
	get:
		return FKBoolActionInput.new("Alpha Only",
		"If true, only the transparency will be changed. Default: " + str(default_alpha_only),
		default_alpha_only)

static var _duration_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("Duration",
		"How long (in seconds) the fade should take. Defaults to " + str(default_duration) + ".",
		default_duration)

static var _wait_for_finish_input: FKBoolActionInput:
	get:
		return FKBoolActionInput.new("Wait For Finish", 
		"Whether or not this pauses the Action list until the fade's done running. Default: " \
		+ str(default_wait_for_finish),
		default_wait_for_finish
)

static var default_color_raw := "\"(255, 255, 255)\""
static var default_alpha := 100
static var default_alpha_only := false
static var default_duration := 1.0
static var default_wait_for_finish := true

var tween: Tween = null

func execute(targetNode: Node, inputs: Dictionary, _str := "") -> void:
	parse_inputs(targetNode, inputs)
	if tween:
		tween.cancel_free()

	var prop := decide_color_prop_name_for(targetNode)

	var apply_right_away = duration <= 0
	if apply_right_away:
		var log_message := "[FlowKit] Duration is 0. Setting " + targetNode.name + "'s " + prop
		log_message += " prop to " + to_rgb_coords(target_color) + " right away."
		#print(log_message)
		targetNode.set(prop, target_color)
	else:
		tween = targetNode.create_tween()
		tween.tween_property(targetNode, prop, target_color, duration)
		if wait_for_finish:
			await tween.finished
	
	exec_completed.emit()

func parse_inputs(target_node: Node, inputs: Dictionary) -> void:
	duration = _duration_input.get_val(inputs)
	alpha_only = _alpha_only_input.get_val(inputs)
	alpha = _alpha_input.get_val(inputs) / 100.0 
	wait_for_finish = _wait_for_finish_input.get_val(inputs)
	target_color = _parse_color_input(target_node, inputs)
	
var duration := 0.0
var alpha_only := false
var alpha := 0.0
var target_color := Color(1, 1, 1)
var wait_for_finish := true

# Subclasses override this
func decide_color_prop_name_for(_targetNode: Node) -> String:
	return "color"

func _parse_color_input(target_node: Node, inputs: Dictionary) -> Color:
	var prop: String = decide_color_prop_name_for(target_node)
	var result: Color 
	
	if alpha_only:
		result = target_node.get(prop)
	else:
		var raw = _targ_color_input.get_val(inputs)
		var hex := rgb_to_hex(raw)
		result = Color.html(hex)

	result.a = alpha
	return result
	
func rgb_to_hex(rgb_string: String) -> String:
	var cleaned := rgb_string.replace("\"", "")
	cleaned = cleaned.replace("(", "")
	cleaned = cleaned.replace(")", "")

	var parts := cleaned.split(",")
	var r := int(parts[0])
	var g := int(parts[1])
	var b := int(parts[2])
	var result := hex_format % [r, g, b]
	return result

var hex_format := "#%02x%02x%02x"

func to_rgb_coords(color: Color) -> String:
	var r := int(color.r * 255)
	var g := int(color.g * 255)
	var b := int(color.b * 255)
	var a := int(color.a * 100)
	var result := rgb_format % [r, g, b, a]
	return result

var rgb_format := "(%d, %d, %d, %d)"
