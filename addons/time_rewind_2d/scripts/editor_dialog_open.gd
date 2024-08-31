@tool
extends Node

@onready var target = $Player

#func _ready():
	#if Engine.is_editor_hint():
		#EditorInterface.popup_property_selector(target, _on_property_selected, [TYPE_INT])

func _on_property_selected(property_path):
	if property_path.is_empty():
		print("property selection canceled")
	else:
		print("selected ", property_path)
