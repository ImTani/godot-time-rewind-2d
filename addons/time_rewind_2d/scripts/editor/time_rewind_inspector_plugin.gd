extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
	return object is TimeRewind2D

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	
	object = object as TimeRewind2D
	
	if name == "rewind_time":

		var property_editor = EditorProperty.new()
		
		var button = Button.new()
		button.text = "Edit Rewindable Properties"
		property_editor.add_child(button)

		button.pressed.connect(_open_property_selector_window.bind(object))
		
		add_property_editor(name, property_editor, true, "Rewindable Properties")
	
	return false

func _open_property_selector_window(object: Object) -> void:
	var property_selector = load("res://addons/time_rewind_2d/scripts/editor/PropertySelectorWindow.tscn").instantiate()

	property_selector.parent_time_rewind_2d = object
	property_selector.target = object.body

	EditorInterface.popup_dialog_centered(property_selector)