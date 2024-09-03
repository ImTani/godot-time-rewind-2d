@tool
extends Window

# !WARNING: This script only reads exposed properties, fix.
# !WARNING: some object references are fucking up, fixing.

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

var excluded_properties: Array[String] = [
	"owner",
	"multiplayer",
	"script"
]

var advanced_properties: Array[String] = [
    "auto_translate_mode",
    "clip_children",
    "collision_layer",
    "collision_mask",
    "collision_priority",
    "disable_mode",
    "editor_description",
    "floor_block_on_wall",
    "floor_constant_speed",
    "floor_max_angle",
    "floor_snap_length",
    "floor_stop_on_slope",
    "global_rotation_degrees",
    "global_scale",
    "global_skew",
    "global_transform",
    "input_pickable",
    "light_mask",
    "max_slides",
    "motion_mode",
    "name",
    "physics_interpolation_mode",
    "platform_floor_layers",
    "platform_on_leave",
    "platform_wall_layers",
    "process_mode",
    "process_physics_priority",
    "process_priority",
    "process_thread_group",
    "process_thread_group_order",
    "process_thread_messages",
    "rotation_degrees",
    "safe_margin",
    "scene_file_path",
    "scale",
    "show_behind_parent",
    "skew",
    "slide_on_ceiling",
    "texture_filter",
    "texture_repeat",
    "top_level",
    "unique_name_in_owner",
    "up_direction",
    "use_parent_material",
    "visibility_layer",
    "wall_min_slide_angle",
    "y_sort_enabled",
    "z_as_relative",
    "z_index"
]

var parent_time_rewind_2d: TimeRewind2D
var show_advanced_properties: bool = false

@export var target: Node:
	set(value):
		target = value
		_set_target()

var selected_item: String

func _ready():

	popup_window = false

	search_field.right_icon = EditorInterface.get_editor_theme().get_icon("Search", "EditorIcons")

	properties_tree.clear()
	properties_tree.set_column_expand(0, true)
	properties_tree.set_column_expand(1, false)
	
	if target:
		populate_tree(target)
	else:
		var warning_popup := AcceptDialog.new()
		warning_popup.dialog_text = "No target node assigned. Please assign a target node."
		warning_popup.title = "No Target Node"
		warning_popup.get_ok_button().pressed.connect(queue_free)
		EditorInterface.popup_dialog_centered(warning_popup)

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

	var object_properties: Array[Dictionary] = []

	for property in properties:
		if property.type == TYPE_OBJECT:
			object_properties.append(property)

	for property in object_properties:
		if property in properties:
			properties.erase(property)

	properties.sort_custom(_sort_properties_by_name)

	properties.append_array(object_properties)

	object_properties.clear()

	var rewindable_properties = parent_time_rewind_2d.rewindable_properties

	for property in properties:

		if not show_advanced_properties and property.name in advanced_properties:
			continue

		if _is_property_valid(property):
			var property_name = property.name
			var property_value = node.get(property_name)

			if property_name not in excluded_properties:
					var child_item = properties_tree.create_item(item)
					var child_type: String = type_string(typeof(property_value))
					var child_icon: Texture2D = EditorInterface.get_editor_theme().get_icon(child_type, "EditorIcons")

					child_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
					child_item.set_editable(0, true)
					child_item.set_text(0, property_name)
					child_item.set_tooltip_text(0, child_type)
					child_item.set_icon(0, child_icon)

					if typeof(property_value) == TYPE_OBJECT and property_value != null:
						if property_value == parent_time_rewind_2d.owner:
							break

						child_type = property_value.get_class()
						child_item.set_text(0, property_name)
						child_item.set_tooltip_text(0, child_type)
						child_item.set_custom_font(0, get_theme_font("bold", "EditorFonts"))
						child_item.set_icon(0, EditorInterface.get_editor_theme().get_icon(child_type, "EditorIcons"))

						child_item.collapsed = true

						populate_tree(property_value, child_item, filter)

					var full_property_name = _get_full_property_name(child_item)

					if full_property_name in rewindable_properties:
						child_item.set_checked(0, true)
					else:
						child_item.set_checked(0, false)

func _filter_tree(filter: String) -> void:
	var root_item: TreeItem = properties_tree.get_root()
	var current_item: TreeItem = root_item.get_first_child()

	while current_item != null:
		var full_property_name = _get_full_property_name(current_item)

		if filter in full_property_name or filter == "":
			var parent = current_item.get_parent()
			while parent.get_text(0) != root_item.get_text(0):
				parent.set_collapsed(false)
				parent.visible = true

				parent = parent.get_parent()

			current_item.collapsed = false
			current_item.visible = true

		else:
			current_item.collapsed = true
			current_item.visible = false
		
		current_item = current_item.get_next_in_tree()

func _update_rewindable_properties() -> void:
	var rewindable_properties = []

	var root_item: TreeItem = properties_tree.get_root()

	if root_item:
		var child_item: TreeItem = root_item.get_first_child()
		while child_item:
			if child_item.is_checked(0):
				rewindable_properties.append(_get_full_property_name(child_item))

			child_item = child_item.get_next_in_tree()

	parent_time_rewind_2d.rewindable_properties = rewindable_properties

func _reset_properties() -> void:
	parent_time_rewind_2d.rewindable_properties = []
	var root_item: TreeItem = properties_tree.get_root()
	if root_item:
		var child_item: TreeItem = root_item.get_first_child()
		while child_item:
			child_item.set_checked(0, false)
			child_item = child_item.get_next()

func _get_full_property_name(item: TreeItem) -> String:
	var names = []
	var current_item = item

	while current_item != null:
		if current_item.get_text(0) == properties_tree.get_root().get_text(0):
			break
		names.insert(0, current_item.get_text(0))
		current_item = current_item.get_parent()

	return ".".join(names)

func _is_property_valid(property: Dictionary) -> bool:
	return not (property.usage & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_INTERNAL))

func _sort_properties_by_name(a, b):
	return a.name < b.name

func _on_search_text_changed(new_text: String):
	# Save current checked states before filtering
	var previous_checked_states = _get_current_checked_states()

	_filter_tree(new_text)

	# Restore checked states after filtering
	_restore_checked_states(previous_checked_states)

# Function to get the current checked states
func _get_current_checked_states() -> Dictionary:
	var checked_states = {}
	var root_item: TreeItem = properties_tree.get_root()

	if root_item:
		var child_item: TreeItem = root_item.get_first_child()
		while child_item:
			if child_item.is_checked(0):
				checked_states[_get_full_property_name(child_item)] = true
			child_item = child_item.get_next_in_tree()

	return checked_states

# Function to restore the checked states
func _restore_checked_states(checked_states: Dictionary) -> void:
	var root_item: TreeItem = properties_tree.get_root()

	if root_item:
		var child_item: TreeItem = root_item.get_first_child()
		while child_item:
			var full_property_name = _get_full_property_name(child_item)
			if full_property_name in checked_states:
				child_item.set_checked(0, true)
			child_item = child_item.get_next_in_tree()

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
