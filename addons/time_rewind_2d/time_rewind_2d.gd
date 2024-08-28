@tool
extends EditorPlugin

const AUTOLOAD_NAME = "RewindManager"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/time_rewind_2d/scripts/RewindManager.gd")

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
