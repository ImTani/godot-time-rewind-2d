@tool
extends EditorInspectorPlugin

var property_selector: PropertySelectionWindow

func _can_handle(object: Object) -> bool:
	return object.get_script() and object.get_script().get_path().ends_with("TimeRewind.gd")

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if name == "rewindable_properties":
		var property_editor = EditorProperty.new()
		
		var button = Button.new()
		button.text = "Edit Rewinding Properties"
		property_editor.add_child(button)

		button.pressed.connect(_open_property_selector_window.bind(object))
		
		add_property_editor(name, property_editor, true)
	
		return true
	
	return false

func _open_property_selector_window(time_rewind: Node2D) -> void:

	if not is_instance_valid(time_rewind):
		push_error("TimeRewind2D: 'time_rewind' is not a valid instance.")
		return
	
	if not is_instance_valid(time_rewind.body):
		push_error("TimeRewind2D: Cannot open property selection window. Body is not valid.")
		return

	property_selector = PropertySelectionWindow.new()
	
	var rewindable_properties = time_rewind.get("rewindable_properties")
	if rewindable_properties == null:
		rewindable_properties = []

	property_selector.create_window(time_rewind.body, rewindable_properties, false, -1, 
		func(selected_properties: Array[String]):
			time_rewind.set("rewindable_properties", selected_properties)
	)
