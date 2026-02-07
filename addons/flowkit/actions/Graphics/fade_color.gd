extends FKAction

func get_description() -> String:
	var result: String = "Fades the main color of a Node."
	return result

func get_id() -> String:
	return "Fade Color"

func get_name() -> String:
	return "Fade Color"

func get_supported_types() -> Array:
	return [
		"ColorRect",
		"Label",
		"RichTextLabel"
	]

func get_inputs() -> Array:
	return [
		{
			"name": "Target Color",
			"type": "String",
			"description": "The color in RGB coordinates. For example, \"255, 255, 255\" for white."
		},
		{
			"name": "Alpha",
			"type": "float",
			"description": "How transparent the color should be. 0 for completely transparent, 100 for opaque. Default: " + str(default_alpha) + "."
		},
		{
			"name": "Alpha Only",
			"type": "bool",
			"description": "If true, only the alpha channel will be changed. Default: false."
		},
		{
			"name": "Duration",
			"type": "float",
			"description": "How long (in seconds) the fade should take. Defaults to " + str(default_duration) + "."
		},
	]

func execute(_node: Node, inputs: Dictionary, _str: String = "") -> void:
	decide_arg_vals(_node, inputs)
	if tween != null:
		tween.cancel_free()
	tween = _node.create_tween()
	var color_prop_name: String = decide_color_prop_name_for(_node)
	tween.tween_property(_node, color_prop_name, target_color, duration)

func decide_arg_vals(_node: Node, inputs: Dictionary) -> void:
	duration = inputs.get("duration", default_duration)
	alpha_only = inputs.get("Alpha Only", false)
	alpha = inputs.get("Alpha", default_alpha) / 100.0

	var color_prop_name: String = decide_color_prop_name_for(_node)
	if alpha_only:
		target_color = _node.get(color_prop_name)
	else:
		var target_color_raw: String = inputs.get("target color", default_color_raw)
		var color_hex: String = rgb_to_hex(target_color_raw)
		target_color = Color.html(color_hex)

	target_color.a = alpha

var default_color_raw: String = "255, 255, 255"
var default_alpha: float = 100
var default_duration: float = 1

# Args
var duration: float = 0
var alpha_only: bool = false
var alpha: float = 0
var target_color: Color = Color(255, 255, 255)

func rgb_to_hex(rgb_string: String) -> String:
	# We assume a format of "num,num,num" with values between 0 and 255.
	# Remove quote marks if available
	var cleaned = rgb_string.replace("\"", "")

	# Split into parts
	var parts = cleaned.split(",")

	# Parse values
	var r = int(parts[0])
	var g = int(parts[1])
	var b = int(parts[2])

	# Convert to hex with padding
	return "#" + "%02x" % r + "%02x" % g + "%02x" % b

var tween: Tween = null

func decide_color_prop_name_for(node: Node) -> String:
	# Later on, we might support node types that don't have their main color
	# properties simply named "color". Hence the need for this func.
	if (node.get_class() == "ColorRect"):
		return "color"
	else:
		return "color"
