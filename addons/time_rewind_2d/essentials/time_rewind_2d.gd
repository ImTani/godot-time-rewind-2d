@tool
extends EditorPlugin

const AUTOLOAD_NAME = "RewindManager"
const AUTOLOAD_PATH = "res://addons/time_rewind_2d/scripts/RewindManager.gd"

const INSPECTOR_PLUGIN = preload("res://addons/time_rewind_2d/scripts/editor/time_rewind_inspector_plugin.gd")

var inspector_plugin: EditorInspectorPlugin

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	
	inspector_plugin = INSPECTOR_PLUGIN.new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
	
	remove_inspector_plugin(inspector_plugin)
