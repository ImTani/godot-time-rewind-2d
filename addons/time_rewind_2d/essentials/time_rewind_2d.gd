@tool
extends EditorPlugin

const AUTOLOAD_NAME = "RewindManager"
const INSPECTOR_PLUGIN = preload("res://addons/time_rewind_2d/scripts/editor/property_selector/time_rewind_inspector_plugin.gd")
const PROJECT_SETTINGS_HANDLER = preload("res://addons/time_rewind_2d/scripts/editor/project_settings_handler.gd")

var inspector_plugin: EditorInspectorPlugin
var project_settings_handler

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/time_rewind_2d/scripts/RewindManager.gd")

	inspector_plugin = INSPECTOR_PLUGIN.new()
	add_inspector_plugin(inspector_plugin)

	project_settings_handler = PROJECT_SETTINGS_HANDLER.new()
	project_settings_handler._setup_project_settings()

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
	remove_inspector_plugin(inspector_plugin)
