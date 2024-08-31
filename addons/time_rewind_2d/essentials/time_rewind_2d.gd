@tool
extends EditorPlugin

const AUTOLOAD_NAME = "RewindManager"

var properties_dock: Window

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/time_rewind_2d/scripts/RewindManager.gd")
	
	# Create an instance of your editor window
	properties_dock = preload("res://tree_holder.tscn").instantiate()
	
	#EditorInterface.popup_dialog_centered(properties_dock)


func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
	properties_dock.queue_free()
