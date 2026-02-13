extends FKEvent

func get_description() -> String:
	return "Executes a block of Actions in response to a button-press."

func get_id() -> String:
	return "On Button Pressed"

func get_name() -> String:
	return "On Button Pressed"
	
func get_supported_types() -> Array:
	return ["Button"]

func is_signal_event() -> bool:
	return true

func setup(target_node: Node, trigger_callback: Callable, instance_id: String = "") -> void:
	button = target_node
	button.pressed.connect(_on_button_pressed)
	exec_actions = trigger_callback 

var button: Button = null
var exec_actions: Callable 

func _on_button_pressed() -> void:
	exec_actions.call() 

func teardown(target_node: Node, instance_id: String = "") -> void:
	# Insert signal-DISconnection code here
	button.pressed.disconnect(_on_button_pressed)
	exec_actions = Callable() 
	pass
