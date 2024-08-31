@tool
extends Window

# The Tree node in the scene
@export var properties_tree: Tree
@export var search_field: LineEdit
@export var target: Node:
	set(value):
		target = value
		_set_target()

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
			
	# Get the properties of the node
	var properties = node.get_property_list()
	
	for prop in properties:
		# Filter out categories, subgroups, groups, and internal properties
		if not (prop.usage & PROPERTY_USAGE_CATEGORY) and not (prop.usage & PROPERTY_USAGE_SUBGROUP) and not (prop.usage & PROPERTY_USAGE_GROUP) and not (prop.usage & PROPERTY_USAGE_INTERNAL):
			
			var prop_name = prop.name
			var prop_value = node.get(prop_name)
			
			# Add property name to the tree without its value
			if filter == "" or prop_name.to_lower().find(filter.to_lower()) != -1:
				var child_item = properties_tree.create_item(item)
				child_item.set_text(0, prop_name)
				
				child_item.set_tooltip_text(0, type_string(typeof(prop_value)))
				
				# If the property is an object and not a built-in type, recurse
				if typeof(prop_value) == TYPE_OBJECT and prop_value != null:
					populate_tree(prop_value, child_item, filter)

# Function to handle item activation
func _on_item_activated():
	var item: TreeItem = properties_tree.get_selected()
	
	if item:
		print("Activated item: ", item.get_text(0))

func _set_target():
	if is_inside_tree():
		populate_tree(target)
		popup_centered()
