extends FadeColorBase

func get_description() -> String:
	return "Fades the main color of a Node."

func get_id() -> String:
	return "Fade Color"

func get_name() -> String:
	return "Fade Color"

func get_supported_types() -> Array:
	return ["ColorRect", "Light2D", "Light3D"]

func decide_color_prop_name_for(node: Node) -> String:
	var result := "color"
	if node is Light3D:
		result = "light_color"
	return result
