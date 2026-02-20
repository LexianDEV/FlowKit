@tool
extends EditorPlugin

var action_registry
var editor
var generator
var inspector_plugin
var editor_main_screen

func _enable_plugin() -> void:
	# Add autoloads here if needed later.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here if needed later.
	pass

func _enter_tree() -> void:
	# Load UI
	editor = preload("res://addons/flowkit/ui/main_editor.tscn").instantiate()

	# Load registry
	action_registry = preload("res://addons/flowkit/registry.gd").new()
	action_registry.load_providers()
	
	# Initialize generator
	generator = preload("res://addons/flowkit/generator.gd").new(get_editor_interface())

	# Pass editor interface and registry to the editor UI
	editor.set_editor_interface(get_editor_interface())
	editor.set_registry(action_registry)
	editor.set_generator(generator)

	# Add runtime autoloads
	add_autoload_singleton(
		"FlowKitSystem",
		"res://addons/flowkit/runtime/flowkit_system.gd"
	)
	
	add_autoload_singleton(
		"FlowKit",
		"res://addons/flowkit/runtime/flowkit_engine.gd"
	)

	# Add editor as main screen plugin
	editor_main_screen = get_editor_interface().get_editor_main_screen()
	editor_main_screen.add_child(editor)
	# Hide by default until user clicks the FlowKit button
	_make_visible(false)
	
	# Create and add custom inspector
	inspector_plugin = preload("res://addons/flowkit/ui/inspector/flowkit_inspector_plugin.gd").new()
	inspector_plugin.set_registry(action_registry)
	inspector_plugin.set_editor_interface(get_editor_interface())
	add_inspector_plugin(inspector_plugin)
	
	print("[FlowKit] Plugin loaded")

func _exit_tree() -> void:
	action_registry.free()

	remove_autoload_singleton("FlowKitSystem")
	remove_autoload_singleton("FlowKit")
	
	if editor:
		editor.queue_free()
	
	# Remove inspector plugin
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if editor:
		editor.visible = visible

func _get_plugin_name() -> String:
	return "FlowKit"

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/flowkit/assets/icon.svg")
