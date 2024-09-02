@tool
extends Window

@export var summon_me: bool = false:
	set(value):
		if value:
			if Engine.is_editor_hint():
				var new_window = load("res://addons/time_rewind_2d/scripts/editor/PropertySelectorWindow.tscn").instantiate()
				new_window.target = target
				EditorInterface.popup_dialog_centered(new_window)

			summon_me = false

@onready var properties_tree: Tree = %PropertiesTree
@onready var search_field: LineEdit = %SearchField

var excluded_properties: Array[String] = ["owner", "multiplayer", "script"]

var parent_time_rewind_2d: TimeRewind2D

@export var target: Node:
	set(value):
		target = value
		_set_target()

var selected_item: String

func _ready():

	popup_window = false
	# Clear the tree before populating
	properties_tree.clear()
	
	if target:
		populate_tree(target)

func _on_search_text_changed(new_text: String):
	properties_tree.clear()
	var root_node = target
	populate_tree(root_node, null, new_text)

# Function to populate the tree
func populate_tree(node: Object, parent_item: TreeItem = null, filter: String = ""):
	var item: TreeItem
	
	# If parent_item is null, it means we are adding the root item
	if parent_item == null:
		item = properties_tree.create_item()
		item.set_text(0, node.name)
		item.set_custom_font(0, get_theme_font("bold", "EditorFonts"))

		item.set_icon(0, EditorInterface.get_editor_theme().get_icon(node.get_class(), "EditorIcons"))
	else:
		item = parent_item

	var properties = node.get_property_list()
	properties.sort_custom(_sort_properties_by_name)

	var rewindable_properties = parent_time_rewind_2d.rewindable_properties
	
	for property in properties:
		if _is_property_valid(property):
			
			var property_name = property.name
			var property_value = node.get(property_name)

			if property_name not in excluded_properties:
				
				if filter == "" or property_name.to_lower().find(filter.to_lower()) != -1:

					var child_item = properties_tree.create_item(item)
					var child_type: String = type_string(typeof(property_value))

					var child_icon: Texture2D = EditorInterface.get_editor_theme().get_icon(child_type, "EditorIcons")					

					child_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
					child_item.set_editable(0, true)
					
					child_item.set_text(0, property_name)
					child_item.set_tooltip_text(0, child_type)
					child_item.set_icon(0, child_icon)
					
					if child_item.get_text(0) in rewindable_properties:
						child_item.set_checked(0, true)
					else:
						child_item.set_checked(0, false)
					
					if typeof(property_value) == TYPE_OBJECT and property_value != null:
						child_type = property_value.get_class()
						child_item.set_text(0, property_name + " (" + child_type + ")")
						child_item.set_custom_font(0, get_theme_font("bold", "EditorFonts"))
						child_item.set_icon(0, EditorInterface.get_editor_theme().get_icon(child_type, "EditorIcons"))

						child_item.collapsed = true
						
						populate_tree(property_value, child_item, filter)


func _update_rewindable_properties() -> void:
	var rewindable_properties = []

	# Start iterating from the root item
	var root_item: TreeItem = properties_tree.get_root()

	if root_item:
		_collect_checked_items(root_item, rewindable_properties)

	parent_time_rewind_2d.rewindable_properties = rewindable_properties

func _collect_checked_items(item: TreeItem, rewindable_properties: Array) -> void:
	while item:
		# Check if the current item is checked
		if item.is_checked(0) and item.get_text(0) not in rewindable_properties:
			rewindable_properties.append(item.get_text(0))

		# Recursively collect checked items from children
		var child_item: TreeItem = item.get_first_child()
		while child_item:
			_collect_checked_items(child_item, rewindable_properties)
			child_item = child_item.get_next()

		# Move to the next sibling
		item = item.get_next()

func _set_target():
	if is_inside_tree():
		populate_tree(target)
		popup_centered()

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		queue_free()

func _on_cancel_pressed() -> void:
	queue_free()

func _on_confirm_pressed() -> void:
	_update_rewindable_properties()
	queue_free()

func _on_close_requested() -> void:
	queue_free()

func _reset_properties() -> void:
	parent_time_rewind_2d.rewindable_properties = []
	var root_item: TreeItem = properties_tree.get_root()
	if root_item:
		var child_item: TreeItem = root_item.get_first_child()
		while child_item:
			child_item.set_checked(0, false)
			child_item = child_item.get_next()

func _is_property_valid(property: Dictionary) -> bool:
	return not (property.usage & PROPERTY_USAGE_CATEGORY) and not (property.usage & PROPERTY_USAGE_SUBGROUP) and not (property.usage & PROPERTY_USAGE_GROUP) and not (property.usage & PROPERTY_USAGE_INTERNAL)

func _sort_properties_by_name(a, b):
	return a.name < b.name
