extends FadeColorBase

func get_description() -> String:
	return "Changes the Modulate property/color of a Node over time."

func get_id() -> String:
	return "Fade Modulate Color"

func get_name() -> String:
	return "Fade Modulate Color"

func get_supported_types() -> Array:
	return ["CanvasItem"]

func decide_color_prop_name_for(_node: Node) -> String:
	return "modulate"