@tool
class_name PropertySelectionWindow
extends Window

signal properties_selected(selected_properties: Array[String])

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

const WINDOW_SCENE: PackedScene = preload("PropertySelectionWindow.tscn")
const NO_TARGET_ERROR_MESSAGE: String = "No target node assigned. Please assign a target node."
const SEARCH_DEBOUNCE_TIME: float = 0.25
const SEARCH_ICON_NAME: String = "Search"
const EDITOR_ICON_CATEGORY: String = "EditorIcons"
const EDITOR_FONT_CATEGORY: String = "EditorFonts"
const FILTER_PROPERTY_USAGE_MASK: int = PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_INTERNAL

# UI Elements
@onready var properties_tree: Tree = %PropertiesTree
@onready var search_field: LineEdit = %SearchField
@onready var search_debounce_timer: Timer = %DebounceTimer
@onready var type_filter_option: OptionButton = %TypeFilterOption

var target: Node
var initially_selected_properties: Array[String] = []
var show_hidden_properties: bool = false
var current_type_filter: int = -1  # -1 means no filter
var _on_properties_selected_callback: Callable

const TYPE_FILTER_OPTIONS = {
	-1: "All Types",
	TYPE_BOOL: "Boolean",
	TYPE_INT: "Integer",
	TYPE_FLOAT: "Float",
	TYPE_STRING: "String",
	TYPE_VECTOR2: "Vector2",
	TYPE_VECTOR3: "Vector3",
	TYPE_COLOR: "Color",
	TYPE_OBJECT: "Object",
}

func create_window(target: Node, initially_selected_properties: Array = [], show_hidden_properties: bool = false, type_filter: int = -1, callback: Callable = Callable()) -> void:
	var window = WINDOW_SCENE.instantiate()
	window.target = target
	window.initially_selected_properties = initially_selected_properties
	window.show_hidden_properties = show_hidden_properties
	window.current_type_filter = type_filter
	window._on_properties_selected_callback = callback
	EditorInterface.popup_dialog_centered(window)

func _ready() -> void:
	_setup_ui()
	_initialize_properties_tree()
	_setup_type_filter()
	_check_target()

func _setup_ui() -> void:
	search_field.right_icon = get_theme_icon(SEARCH_ICON_NAME, EDITOR_ICON_CATEGORY)
	search_debounce_timer.wait_time = SEARCH_DEBOUNCE_TIME

func _initialize_properties_tree() -> void:
	properties_tree.clear()
	properties_tree.set_column_expand(0, true)
	properties_tree.set_column_expand(1, false)

func _setup_type_filter() -> void:
	type_filter_option.clear()  # Clear existing items before populating
	
	for type_value in TYPE_FILTER_OPTIONS:
		type_filter_option.add_item(TYPE_FILTER_OPTIONS[type_value], type_value)
	
	type_filter_option.selected = 0  # "All Types" by default
	type_filter_option.item_selected.connect(_on_type_filter_changed)

func _check_target() -> void:
	if target:
		_populate_tree(target)
	else:
		_display_no_target_warning()

func _display_no_target_warning() -> void:
	var warning_popup := AcceptDialog.new()
	warning_popup.dialog_text = NO_TARGET_ERROR_MESSAGE
	warning_popup.title = "No Target Node"
	warning_popup.confirmed.connect(queue_free)
	warning_popup.canceled.connect(queue_free)
	add_child(warning_popup)
	warning_popup.popup_centered()

func _populate_tree(node: Object, parent_item: TreeItem = null, filter: String = "", property_name: String = "") -> void:
	if not is_instance_valid(node):
		push_error("Invalid node passed to _populate_tree")
		return

	var item := _create_tree_item(node, parent_item, property_name)
	var properties := _get_filtered_properties(node)
	_add_properties_to_tree(properties, node, item, filter)

func _create_tree_item(node: Object, parent_item: TreeItem, property_name: String = "") -> TreeItem:
	var item: TreeItem = parent_item if parent_item != null else properties_tree.create_item()
	
	if property_name:
		item.set_text(0, property_name)
	else:
		item.set_text(0, node.name if node.has_method("get_name") else "Unknown")
	
	item.set_custom_font(0, get_theme_font("bold", EDITOR_FONT_CATEGORY))
	item.set_icon(0, get_theme_icon(node.get_class(), EDITOR_ICON_CATEGORY))

	return item

func _get_filtered_properties(node: Object) -> Array[Dictionary]:
	if not is_instance_valid(node):
		push_error("Invalid node passed to _get_filtered_properties")
		return []

	var properties := node.get_property_list()
	properties = properties.filter(func(p): 
		return _is_property_valid(p) and _passes_type_filter(p))
	properties.sort_custom(_sort_properties_by_name)

	return properties

func _passes_type_filter(property: Dictionary) -> bool:
	if current_type_filter == -1:  # No filter
		return true
	return property.type == current_type_filter

func _add_properties_to_tree(properties: Array[Dictionary], node: Object, item: TreeItem, filter: String) -> void:
	if not is_instance_valid(node) or not is_instance_valid(item):
		push_error("Invalid node or item passed to _add_properties_to_tree")
		return

	for property in properties:
		if _is_property_valid(property):
			var property_name = property.name
			var property_value = _get_property_safely(node, property_name)
			if property_name not in EXCLUDED_PROPERTIES:
				var child_item = _create_property_tree_item(property_name, property_value, item)
				if typeof(property_value) == TYPE_OBJECT and property_value != null:
					child_item.collapsed = true
					_populate_tree(property_value, child_item, filter, property_name)
				if property_name in HIDDEN_PROPERTIES and not show_hidden_properties:
					child_item.visible = false
				_check_initially_selected_property(child_item, property_name)

func _get_property_safely(node: Object, property_name: String) -> Variant:
	if node.has_method("get"):
		return node.get(property_name)
	push_warning("Unable to get property: " + property_name)
	return null

func _create_property_tree_item(property_name: String, property_value: Variant, parent_item: TreeItem) -> TreeItem:
	var child_item = properties_tree.create_item(parent_item)
	var child_type: String = type_string(typeof(property_value))
	var child_icon: Texture2D = get_theme_icon(child_type, EDITOR_ICON_CATEGORY)

	child_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	child_item.set_editable(0, true)
	child_item.set_text(0, property_name)
	child_item.set_tooltip_text(0, _get_full_property_name(child_item))
	child_item.set_icon(0, child_icon)

	return child_item

func _check_initially_selected_property(child_item: TreeItem, property_name: String) -> void:
	var full_property_name = _get_full_property_name(child_item)
	child_item.set_checked(0, full_property_name in initially_selected_properties)

func _get_full_property_name(item: TreeItem) -> String:
	if not is_instance_valid(item):
		push_error("Invalid item passed to _get_full_property_name")
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

func _sort_properties_by_name(a: Dictionary, b: Dictionary) -> bool:
	return a.name.nocasecmp_to(b.name) < 0

func _on_search_text_changed(new_text: String) -> void:
	if not search_debounce_timer.is_stopped():
		search_debounce_timer.stop()

	search_debounce_timer.start()

	await search_debounce_timer.timeout
	var previous_checked_states = _get_current_checked_states()
	_filter_tree(new_text)
	_restore_checked_states(previous_checked_states)

func _filter_tree(filter: String) -> void:
	var root_item = properties_tree.get_root()
	if not is_instance_valid(root_item):
		push_error("Invalid root item in _filter_tree")
		return

	var current_item = root_item.get_first_child()

	while current_item:
		var full_property_name = _get_full_property_name(current_item)
		_update_item_visibility(current_item, full_property_name, filter, root_item)
		current_item = current_item.get_next_in_tree()

func _update_item_visibility(current_item: TreeItem, full_property_name: String, filter: String, root_item: TreeItem) -> void:
	if not is_instance_valid(current_item):
		push_error("Invalid item passed to _update_item_visibility")
		return

	if not show_hidden_properties and current_item.get_text(0) in HIDDEN_PROPERTIES:
		return

	if filter.is_empty() or filter.to_lower() in full_property_name.to_lower():
		_set_item_and_parents_visible(current_item, root_item, true)
	else:
		current_item.collapsed = true
		current_item.visible = false

func _set_item_and_parents_visible(item: TreeItem, root_item: TreeItem, visibility: bool) -> void:
	if not is_instance_valid(item) or not is_instance_valid(root_item):
		push_error("Invalid item or root_item passed to _set_item_and_parents_visible")
		return

	var parent = item.get_parent()
	while parent and parent != root_item:
		parent.set_collapsed(not visibility)
		parent.visible = visibility
		parent = parent.get_parent()
	item.collapsed = not visibility
	item.visible = visibility

func _get_current_checked_states() -> Dictionary:
	var checked_states = {}
	var root_item = properties_tree.get_root()

	if is_instance_valid(root_item):
		var child_item = root_item.get_first_child()
		while child_item:
			if child_item.is_checked(0):
				checked_states[_get_full_property_name(child_item)] = true
			child_item = child_item.get_next_in_tree()

	return checked_states

func _restore_checked_states(checked_states: Dictionary) -> void:
	var root_item = properties_tree.get_root()

	if is_instance_valid(root_item):
		var child_item = root_item.get_first_child()
		while child_item:
			var full_property_name = _get_full_property_name(child_item)
			if full_property_name in checked_states:
				child_item.set_checked(0, true)
			child_item = child_item.get_next_in_tree()

func _on_show_all_toggled(toggled_on: bool) -> void:
	show_hidden_properties = toggled_on

	var root_item = properties_tree.get_root()

	if is_instance_valid(root_item):
		var child_item = root_item.get_first_child()

		while child_item != null:
			if child_item.get_text(0) in HIDDEN_PROPERTIES:
				child_item.visible = show_hidden_properties

			child_item = child_item.get_next_in_tree()

func _on_type_filter_changed(index: int) -> void:
	current_type_filter = type_filter_option.get_item_id(index)
	_repopulate_tree()

func _repopulate_tree() -> void:
	var previous_checked_states = _get_current_checked_states()
	_initialize_properties_tree()
	_populate_tree(target)
	_restore_checked_states(previous_checked_states)

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		queue_free()

func _on_cancel_pressed() -> void:
	queue_free()

func _on_confirm_pressed() -> void:
	var selected_properties = _get_selected_properties()
	properties_selected.emit(selected_properties)
	if _on_properties_selected_callback.is_valid():
		_on_properties_selected_callback.call(selected_properties)
	queue_free()

func _on_close_requested() -> void:
	queue_free()

func _get_selected_properties() -> Array[String]:
	var selected_properties: Array[String] = []
	var root_item = properties_tree.get_root()

	if is_instance_valid(root_item):
		var child_item = root_item.get_first_child()
		while child_item:
			if child_item.is_checked(0):
				selected_properties.append(_get_full_property_name(child_item))
			child_item = child_item.get_next_in_tree()

	return selected_properties

# Public method to set the target node
func set_target(new_target: Node) -> void:
	target = new_target
	_check_target()

# Public method to set initially selected properties
func set_initially_selected_properties(properties: Array[String]) -> void:
	initially_selected_properties = properties
	if properties_tree.get_root():
		_update_initially_selected_properties()

func _update_initially_selected_properties() -> void:
	var root_item = properties_tree.get_root()
	if not is_instance_valid(root_item):
		push_error("Invalid root item in _update_initially_selected_properties")
		return

	var stack: Array[TreeItem] = [root_item]
	while not stack.is_empty():
		var item = stack.pop_back()
		var full_property_name = _get_full_property_name(item)
		item.set_checked(0, full_property_name in initially_selected_properties)
		
		var child = item.get_first_child()
		while child:
			stack.push_back(child)
			child = child.get_next()

# Helper method to safely get theme icon
func _get_theme_icon_safely(icon_name: String, theme_type: String) -> Texture2D:
	var icon = get_theme_icon(icon_name, theme_type)
	if not icon:
		push_warning("Failed to get theme icon: " + icon_name)
		return null
	return icon

# Helper method to safely get theme font
func _get_theme_font_safely(font_name: String, theme_type: String) -> Font:
	var font = get_theme_font(font_name, theme_type)
	if not font:
		push_warning("Failed to get theme font: " + font_name)
		return null
	return font

# Override _notification to handle theme changes
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			_update_theme()

func _update_theme() -> void:
	if is_instance_valid(search_field):
		search_field.right_icon = _get_theme_icon_safely(SEARCH_ICON_NAME, EDITOR_ICON_CATEGORY)
	
	if is_instance_valid(properties_tree):
		_update_tree_icons()

func _update_tree_icons() -> void:
	var root_item = properties_tree.get_root()
	if not is_instance_valid(root_item):
		return

	var stack: Array[TreeItem] = [root_item]
	while not stack.is_empty():
		var item = stack.pop_back()
		var icon_type = type_string(typeof(_get_property_safely(target, item.get_text(0))))
		item.set_icon(0, _get_theme_icon_safely(icon_type, EDITOR_ICON_CATEGORY))
		
		var child = item.get_first_child()
		while child:
			stack.push_back(child)
			child = child.get_next()

# Error handling for tree operations
func _handle_tree_error(message: String) -> void:
	push_error(message)
	# You might want to show an error dialog to the user here
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = "An error occurred: " + message
	add_child(error_dialog)
	error_dialog.popup_centered()

# Optimization: Cache property lists
var _property_cache: Dictionary = {}

func _get_cached_properties(node: Object) -> Array[Dictionary]:
	if node in _property_cache:
		return _property_cache[node]
	var properties = _get_filtered_properties(node)
	_property_cache[node] = properties
	return properties

# Clear cache when necessary
func _clear_property_cache() -> void:
	_property_cache.clear()

# Override _exit_tree to clean up
func _exit_tree() -> void:
	_clear_property_cache()
	# Additional cleanup if necessary