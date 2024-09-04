@tool
extends Window

# Constants
const EXCLUDED_PROPERTIES: Array[String] = [
	"owner", "multiplayer", "script"
]

const HIDDEN_PROPERTIES: Array[String] = [
	"name", "unique_name_in_owner", "scene_file_path",
	"process_mode", "process_priority", "process_physics_priority",
	"process_thread_group", "process_thread_group_order", "process_thread_messages",
	"physics_interpolation_mode", "auto_translate_mode", "editor_description",
	"self_modulate", "show_behind_parent", "top_level",
	"clip_children", "light_mask", "visibility_layer",
	"z_index", "z_as_relative", "y_sort_enabled",
	"texture_filter", "texture_repeat", "material",
	"use_parent_material", "rotation_degrees", "skew",
	"transform", "global_rotation_degrees", "global_skew",
	"global_transform"]

const NO_TARGET_ERROR_MESSAGE: String = "No target node assigned. Please assign a target node."
const SEARCH_ICON_NAME: String = "Search"
const EDITOR_ICON_CATEGORY: String = "EditorIcons"
const EDITOR_FONT_CATEGORY: String = "EditorFonts"
const FILTER_PROPERTY_USAGE_MASK: int = PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_INTERNAL

# UI Elements
@onready var properties_tree: Tree = %PropertiesTree
@onready var search_field: LineEdit = %SearchField

var parent_time_rewind_2d: TimeRewind2D

@export var target: Node:
	set(value):
		target = value

var show_hidden_properties: bool = false

# Initialization
func _ready():

	_setup_ui()
	_initialize_properties_tree()
	_check_target()

func _setup_ui():
	search_field.right_icon = EditorInterface.get_editor_theme().get_icon(SEARCH_ICON_NAME, EDITOR_ICON_CATEGORY)

func _initialize_properties_tree():
	properties_tree.clear()
	properties_tree.set_column_expand(0, true)
	properties_tree.set_column_expand(1, false)

func _check_target():
	if target:
		_populate_tree(target)
	else:
		_display_no_target_warning()

func _display_no_target_warning():
	if parent_time_rewind_2d:
		var warning_popup := AcceptDialog.new()
		warning_popup.dialog_text = NO_TARGET_ERROR_MESSAGE
		warning_popup.title = "No Target Node"
		warning_popup.get_ok_button().pressed.connect(warning_popup.queue_free)
		warning_popup.popup_centered()

# Tree Population and Filtering
func _populate_tree(node: Object, parent_item: TreeItem = null, filter: String = "", property_name: String = ""):
	var item := _create_tree_item(node, parent_item, property_name)
	var properties := _get_filtered_properties(node)
	_add_properties_to_tree(properties, node, item, filter)

func _create_tree_item(node: Object, parent_item: TreeItem, property_name: String = "") -> TreeItem:
	var item: TreeItem = parent_item if parent_item != null else properties_tree.create_item()
	
	if property_name:
		item.set_text(0, property_name)
	else:
		item.set_text(0, node.name)
	
	item.set_custom_font(0, get_theme_font("bold", EDITOR_FONT_CATEGORY))
	item.set_icon(0, EditorInterface.get_editor_theme().get_icon(node.get_class(), EDITOR_ICON_CATEGORY))

	return item

func _get_filtered_properties(node: Object) -> Array[Dictionary]:
	if not node:
		return []

	var properties := node.get_property_list()
	var object_properties: Array[Dictionary] = []

	for property in properties:
		if property.type == TYPE_OBJECT:
			object_properties.append(property)

	properties = properties.filter(func(p):
		return not object_properties.has(p)
	)

	properties.sort_custom(_sort_properties_by_name)
	properties.append_array(object_properties)

	return properties

func _add_properties_to_tree(properties: Array[Dictionary], node: Object, item: TreeItem, filter: String):
	if not node or not item:
		return

	var rewindable_properties = parent_time_rewind_2d.rewindable_properties

	for property in properties:
		if _is_property_valid(property):
			var property_name = property.name
			var property_value = node.get(property_name)
			if property_name not in EXCLUDED_PROPERTIES:
				var child_item = _create_property_tree_item(property_name, property_value, item)
				if typeof(property_value) == TYPE_OBJECT and property_value != null and property_value != parent_time_rewind_2d.owner:
					child_item.collapsed = true
					_populate_tree(property_value, child_item, filter, property_name)
				if property_name in HIDDEN_PROPERTIES and not show_hidden_properties:
					child_item.visible = false
				_check_rewindable_property(child_item, property_name, rewindable_properties)

func _create_property_tree_item(property_name: String, property_value: Variant, parent_item: TreeItem) -> TreeItem:
	var child_item = properties_tree.create_item(parent_item)
	var child_type: String = type_string(typeof(property_value))
	var child_icon: Texture2D = EditorInterface.get_editor_theme().get_icon(child_type, EDITOR_ICON_CATEGORY)

	child_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	child_item.set_editable(0, true)
	child_item.set_text(0, property_name)
	child_item.set_tooltip_text(0, _get_full_property_name(child_item))
	child_item.set_icon(0, child_icon)

	return child_item

func _check_rewindable_property(child_item: TreeItem, property_name: String, rewindable_properties: Array):
	var full_property_name = _get_full_property_name(child_item)
	child_item.set_checked(0, full_property_name in rewindable_properties)

# Property and Tree Utility Functions
func _get_full_property_name(item: TreeItem) -> String:
	if not item:
		return ""
	
	var names = []
	var current_item = item

	while current_item:
		if current_item.get_text(0) == properties_tree.get_root().get_text(0):
			break
		names.insert(0, current_item.get_text(0))
		current_item = current_item.get_parent()

	return ".".join(names)

func _is_property_valid(property: Dictionary) -> bool:
	return not (property.usage & FILTER_PROPERTY_USAGE_MASK)

func _sort_properties_by_name(a, b):
	return a.name < b.name

# Search and Filter Functionality
func _on_search_text_changed(new_text: String):
	var previous_checked_states = _get_current_checked_states()
	_filter_tree(new_text)
	_restore_checked_states(previous_checked_states)

func _filter_tree(filter: String) -> void:
	var root_item = properties_tree.get_root()
	var current_item = root_item.get_first_child() if root_item else null

	while current_item:
		var full_property_name = _get_full_property_name(current_item)
		_update_item_visibility(current_item, full_property_name, filter, root_item)
		current_item = current_item.get_next_in_tree()

func _update_item_visibility(current_item: TreeItem, full_property_name: String, filter: String, root_item: TreeItem):
	if filter in full_property_name or filter == "":
		_set_item_and_parents_visible(current_item, root_item, true)
	else:
		current_item.collapsed = true
		current_item.visible = false

func _set_item_and_parents_visible(item: TreeItem, root_item: TreeItem, visibility: bool):
	var parent = item.get_parent()
	while parent and parent != root_item:
		parent.set_collapsed(not visibility)
		parent.visible = visibility
		parent = parent.get_parent()
	item.collapsed = not visibility
	item.visible = visibility

# State Management
func _get_current_checked_states() -> Dictionary:
	var checked_states = {}
	var root_item = properties_tree.get_root()

	if root_item:
		var child_item = root_item.get_first_child()
		while child_item:
			if child_item.is_checked(0):
				checked_states[_get_full_property_name(child_item)] = true
			child_item = child_item.get_next_in_tree()

	return checked_states

func _restore_checked_states(checked_states: Dictionary):
	var root_item = properties_tree.get_root()

	if root_item:
		var child_item = root_item.get_first_child()
		while child_item:
			var full_property_name = _get_full_property_name(child_item)
			if full_property_name in checked_states:
				child_item.set_checked(0, true)
			child_item = child_item.get_next_in_tree()

func _on_show_all_toggled(toggled_on:bool) -> void:
	show_hidden_properties = toggled_on

	var root_item = properties_tree.get_root()

	if root_item:
		var child_item = root_item.get_first_child()

		while child_item != null:
			if child_item.get_text(0) in HIDDEN_PROPERTIES:
				child_item.visible = show_hidden_properties

			child_item = child_item.get_next_in_tree()

# User Input and Confirmation
func _input(event: InputEvent):
	if Input.is_action_just_pressed("ui_cancel"):
		queue_free()

func _on_cancel_pressed():
	queue_free()

func _on_confirm_pressed():
	_update_rewindable_properties()
	queue_free()

func _on_close_requested():
	queue_free()

# Rewindable Properties Update
func _update_rewindable_properties():
	var rewindable_properties = []
	var root_item = properties_tree.get_root()

	if root_item:
		var child_item = root_item.get_first_child()
		while child_item:
			if child_item.is_checked(0):
				rewindable_properties.append(_get_full_property_name(child_item))
			child_item = child_item.get_next_in_tree()

	parent_time_rewind_2d.rewindable_properties = rewindable_properties