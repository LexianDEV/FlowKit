@tool
extends EditorPlugin

var action_registry: FKRegistry = FKRegistry.new()
var generator: FKGenerator = null
var inspector_plugin
var export_plugin
var editor_main_screen
var editor: FKMainEditor = null
var editor_globals: FKEditorGlobals = FKEditorGlobals.new()
var editor_interface: EditorInterface

func _enable_plugin() -> void:
	# Add autoloads here if needed later.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here if needed later.
	pass

func _enter_tree() -> void:
	_prep_editor_globals()
	_prep_settings_window()
	var project_settings: FKProjectSettings = settings_window.get_project_settings()
	action_registry.set_project_settings(project_settings)
	generator.set_project_settings(project_settings)
	action_registry.load_providers()
	_prep_main_editor()
	_prep_tool_submenu_entries()
	_add_runtime_autoloads()
	_register_as_main_screen_plugin()
	
	# Hide by default until user clicks the FlowKit button
	_make_visible(false)
	
	_create_and_add_custom_inspector()
	_prep_export_plugin()

	print("[FlowKit]: Plugin loaded")

func _prep_editor_globals():
	# Some of its dependencies will be injected by us, 
	# the rest by FKMainEditor later
	action_registry = FKRegistry.new()
	
	editor_interface = get_editor_interface()
	generator = FKGenerator.new(editor_interface)

	editor_globals = FKEditorGlobals.new()
	editor_globals.registry = action_registry
	editor_globals.editor_interface = editor_interface
	editor_globals.generator = generator

func _prep_main_editor():
	const path := FKEditorGlobals.MAIN_EDITOR_SCENE_PATH
	var editor_scene: PackedScene = preload(path)
	editor = editor_scene.instantiate()
	editor.editor_globals = editor_globals
	# ^Very important that we assign this _before_ legitimization. Why? At least
	# 1 of FKMainEditor's submodules will need an FKEditorGlobals object
	# accessible
	editor.legitimize()

func _prep_settings_window():
	const tool_menu_path := FKEditorGlobals.SETTINGS_WINDOW_TOOL_MENU_PATH
	const scene_path := FKEditorGlobals.SETTINGS_WINDOW_SCENE_PATH
	var window_scene: PackedScene = preload(scene_path)
	settings_window = window_scene.instantiate() as FKSettingsWindow
	
	settings_window.visible = false
	settings_window.set_globals(editor_globals)
	editor_globals.base_control.add_child(settings_window)
	settings_window._legitimize()
	
var settings_window: FKSettingsWindow

func _prep_tool_submenu_entries():
	_base_popup = PopupMenu.new()
	_base_popup.add_item("Settings", MENU_ITEM_SETTINGS)
	_base_popup.id_pressed.connect(_on_base_popup_id_pressed)
	add_tool_submenu_item("FlowKit", _base_popup)
	
var _base_popup: PopupMenu

func _on_base_popup_id_pressed(id: int):
	if id == MENU_ITEM_SETTINGS:
		settings_window.popup_centered()

const MENU_ITEM_SETTINGS := 0

func _add_runtime_autoloads():
	add_autoload_singleton(
		"FlowKitSystem",
		"res://addons/flowkit/runtime/flowkit_system.gd"
	)
	
	add_autoload_singleton(
		"FlowKit",
		"res://addons/flowkit/runtime/flowkit_engine.gd"
	)

func _register_as_main_screen_plugin():
	editor_main_screen = editor_interface.get_editor_main_screen()
	editor_main_screen.add_child(editor)
	
func _create_and_add_custom_inspector():
	# Create and add custom inspector
	inspector_plugin = FKEditorInspectorPlugin.new()
	inspector_plugin.set_registry(action_registry)
	inspector_plugin.set_editor_interface(editor_interface)
	add_inspector_plugin(inspector_plugin)

func _prep_export_plugin():
	# We want to make sure it excludes unused providers from builds
	export_plugin = FKExportPlugin.new()
	export_plugin.set_generator(generator)
	add_export_plugin(export_plugin)
	
func _exit_tree() -> void:
	var tool_menu_path := FKEditorGlobals.SETTINGS_WINDOW_TOOL_MENU_PATH
	remove_tool_menu_item(tool_menu_path)
	_base_popup.id_pressed.disconnect(_on_base_popup_id_pressed)
	action_registry.free()
	remove_autoload_singleton("FlowKitSystem")
	remove_autoload_singleton("FlowKit")
	
	if editor:
		editor.queue_free()
	
	# Remove inspector plugin
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null

	# Remove export plugin
	if export_plugin:
		remove_export_plugin(export_plugin)
		export_plugin = null

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if editor:
		editor.visible = visible

func _get_plugin_name() -> String:
	return "FlowKit"

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/flowkit/assets/icon.svg")
