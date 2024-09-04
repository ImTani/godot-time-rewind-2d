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
const BAD_TARGET_ERROR_MESSAGE: String = "Assigned target node can't be self. Please assign a different target node."
const SEARCH_DEBOUNCE_TIME: float = 0.25
const SEARCH_ICON_NAME: String = "Search"
const EDITOR_ICON_CATEGORY: String = "EditorIcons"
const EDITOR_FONT_CATEGORY: String = "EditorFonts"
const FILTER_PROPERTY_USAGE_MASK: int = PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_INTERNAL

# UI Elements
@onready var properties_tree: Tree = %PropertiesTree
@onready var search_field: LineEdit = %SearchField
@onready var search_debounce_timer: Timer = %DebounceTimer

var parent_time_rewind_2d: TimeRewind2D
var target: Node

var show_hidden_properties: bool = false

## Called when the node is added to the scene. Initializes the UI and checks for the target node.
func _ready():
	_setup_ui()
	_initialize_properties_tree()
	_check_target()

## Sets up the UI elements, including the search field icon and debounce timer settings.
func _setup_ui():
	search_field.right_icon = EditorInterface.get_editor_theme().get_icon(SEARCH_ICON_NAME, EDITOR_ICON_CATEGORY)
	search_debounce_timer.wait_time = SEARCH_DEBOUNCE_TIME

## Initializes the properties tree by clearing it and setting column properties.
func _initialize_properties_tree():
	properties_tree.clear()
	properties_tree.set_column_expand(0, true)
	properties_tree.set_column_expand(1, false)

## Checks if a target node is assigned. If so, populates the properties tree; otherwise, displays a warning.
func _check_target():
	if target:
		if target == parent_time_rewind_2d:
			_display_bad_target_warning()
			return
		_populate_tree(target)
	else:
		_display_no_target_warning()

## Displays a warning dialog if no target node is assigned.
func _display_no_target_warning():
	if parent_time_rewind_2d:
		var warning_popup := AcceptDialog.new()
		warning_popup.dialog_text = NO_TARGET_ERROR_MESSAGE
		warning_popup.title = "No Target Node"
		warning_popup.confirmed.connect(queue_free)
		warning_popup.canceled.connect(queue_free)
		EditorInterface.popup_dialog_centered(warning_popup)

## Displays a warning dialog if assigned target node is the parent TimeRewind2D.
func _display_bad_target_warning():
	if parent_time_rewind_2d:
		var warning_popup := AcceptDialog.new()
		warning_popup.dialog_text = BAD_TARGET_ERROR_MESSAGE
		warning_popup.title = "Bad Target Node"
		warning_popup.confirmed.connect(queue_free)
		warning_popup.canceled.connect(queue_free)
		EditorInterface.popup_dialog_centered(warning_popup)

## Populates the properties tree with the properties of the given node, optionally filtered by a search string.
func _populate_tree(node: Object, parent_item: TreeItem = null, filter: String = "", property_name: String = ""):
	var item := _create_tree_item(node, parent_item, property_name)
	var properties := _get_filtered_properties(node)
	_add_properties_to_tree(properties, node, item, filter)

## Creates a tree item for the given node or property, optionally setting a parent item and property name.
func _create_tree_item(node: Object, parent_item: TreeItem, property_name: String = "") -> TreeItem:
	var item: TreeItem = parent_item if parent_item != null else properties_tree.create_item()
	
	if property_name:
		item.set_text(0, property_name)
	else:
		item.set_text(0, node.name)
	
	item.set_custom_font(0, get_theme_font("bold", EDITOR_FONT_CATEGORY))
	item.set_icon(0, EditorInterface.get_editor_theme().get_icon(node.get_class(), EDITOR_ICON_CATEGORY))

	return item

## Retrieves and filters the properties of the given node, excluding certain property types.
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

## Adds the filtered properties to the tree, creating tree items and handling nested objects.
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

## Creates a tree item for a specific property, setting the property name, value, and other display options.
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

## Checks if a property is marked as rewindable and updates the tree item accordingly.
func _check_rewindable_property(child_item: TreeItem, property_name: String, rewindable_properties: Array):
	var full_property_name = _get_full_property_name(child_item)
	child_item.set_checked(0, full_property_name in rewindable_properties)

## Retrieves the full property name by traversing the tree from the item up to the root.
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

## Determines if a property is valid based on its usage flags, excluding certain properties.
func _is_property_valid(property: Dictionary) -> bool:
	return not (property.usage & FILTER_PROPERTY_USAGE_MASK)

## Sorts properties by their names. Used for ordering the properties in the tree.
func _sort_properties_by_name(a, b):
	return a.name < b.name

## Handles the text change event in the search field, filtering the tree based on the search text.
func _on_search_text_changed(new_text: String):
	if not search_debounce_timer.is_stopped():
		search_debounce_timer.stop()

	search_debounce_timer.start()

	await search_debounce_timer.timeout
	var previous_checked_states = _get_current_checked_states()
	_filter_tree(new_text)
	_restore_checked_states(previous_checked_states)

## Filters the tree items based on the provided filter text, updating their visibility.
func _filter_tree(filter: String):
	var root_item = properties_tree.get_root()
	var current_item = root_item.get_first_child() if root_item else null

	while current_item:
		var full_property_name = _get_full_property_name(current_item)
		_update_item_visibility(current_item, full_property_name, filter, root_item)
		current_item = current_item.get_next_in_tree()

## Updates the visibility of a tree item and its parents based on the filter criteria.
func _update_item_visibility(current_item: TreeItem, full_property_name: String, filter: String, root_item: TreeItem):
	if not show_hidden_properties and current_item.get_text(0) in HIDDEN_PROPERTIES:
		return

	if filter in full_property_name or filter == "":
		_set_item_and_parents_visible(current_item, root_item, true)
	else:
		current_item.collapsed = true
		current_item.visible = false

## Sets the visibility of a tree item and its parent items.
func _set_item_and_parents_visible(item: TreeItem, root_item: TreeItem, visibility: bool):
	var parent = item.get_parent()
	while parent and parent != root_item:
		parent.set_collapsed(not visibility)
		parent.visible = visibility
		parent = parent.get_parent()
	item.collapsed = not visibility
	item.visible = visibility

## Retrieves the current checked states of the tree items, storing them in a dictionary.
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

## Restores the checked states of the tree items based on the provided dictionary.
func _restore_checked_states(checked_states: Dictionary):
	var root_item = properties_tree.get_root()

	if root_item:
		var child_item = root_item.get_first_child()
		while child_item:
			var full_property_name = _get_full_property_name(child_item)
			if full_property_name in checked_states:
				child_item.set_checked(0, true)
			child_item = child_item.get_next_in_tree()

## Toggles the visibility of hidden properties based on the user's input.
func _on_show_all_toggled(toggled_on:bool):
	show_hidden_properties = toggled_on

	var root_item = properties_tree.get_root()

	if root_item:
		var child_item = root_item.get_first_child()

		while child_item != null:
			if child_item.get_text(0) in HIDDEN_PROPERTIES:
				child_item.visible = show_hidden_properties

			child_item = child_item.get_next_in_tree()

## Handles user input events, closing the window if the cancel action is triggered.
func _input(event: InputEvent):
	if Input.is_action_just_pressed("ui_cancel"):
		queue_free()

## Closes the window when the cancel button is pressed.
func _on_cancel_pressed():
	queue_free()

## Updates the rewindable properties and closes the window when the confirm button is pressed.
func _on_confirm_pressed():
	_update_rewindable_properties()
	queue_free()

## Closes the window when a close request is received.
func _on_close_requested():
	queue_free()

## Updates the list of rewindable properties based on the currently checked items in the tree.
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
