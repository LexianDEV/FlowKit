extends FKAction

func get_description() -> String:
	return "Opens a URL in the default web browser."

func get_id() -> String:
	return "open_url"

func get_name() -> String:
	return "Open URL"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_url_input]

static var _url_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("URL", "The URL to open in the web browser.")

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var url: String = _url_input.get_val(inputs)
	if not url.is_empty():
		OS.shell_open(url)
