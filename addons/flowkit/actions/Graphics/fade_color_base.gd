extends FKAction
class_name FadeColorBase

func requires_multi_frames() -> bool:
	return true
	
func get_inputs() -> Array:
	return [
		{
			"name": "Target Color",
			"type": "String",
			"description": "The color in RGB coordinates. For example, \"(255, 255, 255)\" (include the quotes) for white. If empty, defaults to that color."
		},
		{
			"name": "Alpha",
			"type": "float",
			"description": "How transparent the color should be. 0 for completely transparent, 100 for opaque. Default: " + str(default_alpha) + "."
		},
		{
			"name": "Alpha Only",
			"type": "bool",
			"description": "If true, only the transparency will be changed. Default: " + str(default_alpha_only)
		},
		{
			"name": "Duration",
			"type": "float",
			"description": "How long (in seconds) the fade should take. Defaults to " + str(default_duration) + "."
		},
		{
			"name": "Wait For Finish",
			"type": "bool",
			"description": "Whether or not this pauses the Action list until the fade's done running. Default: " + str(default_wait_for_finish)
		}
	]

var default_color_raw := "\"(255, 255, 255)\""
var default_alpha := 100
var default_alpha_only := false
var default_duration := 1.0
var default_wait_for_finish := true

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
		print(log_message)
		targetNode.set(prop, target_color)
	else:
		tween = targetNode.create_tween()
		tween.tween_property(targetNode, prop, target_color, duration)
		if wait_for_finish:
			await tween.finished
	
	exec_completed.emit()

func parse_inputs(targetNode: Node, inputs: Dictionary) -> void:
	duration = float(inputs.get("Duration", default_duration))
	
	var base_alpha_only = inputs.get("Alpha Only", default_alpha_only)
	var use_default := base_alpha_only is String
	if use_default:
		alpha_only = default_alpha_only
	else:
		alpha_only = base_alpha_only
		
	alpha = inputs.get("Alpha", default_alpha) / 100.0
	
	var base_wait := inputs.get("Wait For Finish", default_wait_for_finish)
	use_default = base_wait is String
	if use_default:
		wait_for_finish = default_wait_for_finish
	else:
		wait_for_finish = base_wait

	var prop := decide_color_prop_name_for(targetNode)

	if alpha_only:
		target_color = targetNode.get(prop)
	else:
		var raw = inputs.get("Target Color", default_color_raw)
		var hex := rgb_to_hex(raw)
		target_color = Color.html(hex)

	target_color.a = alpha

var duration := 0.0
var alpha_only := false
var alpha := 0.0
var target_color := Color(1, 1, 1)
var wait_for_finish := true

# Subclasses override this
func decide_color_prop_name_for(_targetNode: Node) -> String:
	return "color"

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
