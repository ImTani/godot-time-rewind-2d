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

var excluded_properties: Array[String] = ["owner", "multiplayer"]

@export var target: Node:
	set(value):
		target = value
		_set_target()

var selected_item: String

func _ready():
	# Clear the tree before populating
	properties_tree.clear()

	properties_tree.item_activated.connect(_on_item_activated)
	
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
	else:
		item = properties_tree.create_item(parent_item)
		if node.has_method("get_name") and node.get_class() != "GDScript":
			item.set_text(0, node.name)
		else:
			item.set_text(0, "ProblemChild")
			
	var properties = node.get_property_list()
	
	for prop in properties:
		if not (prop.usage & PROPERTY_USAGE_CATEGORY) and not (prop.usage & PROPERTY_USAGE_SUBGROUP) and not (prop.usage & PROPERTY_USAGE_GROUP) and not (prop.usage & PROPERTY_USAGE_INTERNAL):
			
			var prop_name = prop.name
			var prop_value = node.get(prop_name)

			if prop_name not in excluded_properties:
				
				if filter == "" or prop_name.to_lower().find(filter.to_lower()) != -1:
					
					var child_item = properties_tree.create_item(item)
					var child_class: String = type_string(typeof(prop_value))
					
					child_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
					child_item.set_editable(0, true)
					child_item.set_checked(0, false)
					
					child_item.set_text(0, prop_name)
					child_item.set_tooltip_text(0, child_class)
					
					if typeof(prop_value) == TYPE_OBJECT and prop_value != null:
						populate_tree(prop_value, child_item, filter)

func _on_item_activated() -> void:
	var item: TreeItem = properties_tree.get_selected()
	
	if item:
		selected_item = item.get_text(0)
	else:
		selected_item = ""
	
	print(selected_item)

func _set_target():
	if is_inside_tree():
		populate_tree(target)
		popup_centered()

func _on_cancel_pressed() -> void:
	queue_free()

func _on_close_requested() -> void:
	queue_free()
