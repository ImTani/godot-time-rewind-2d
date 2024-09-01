@tool
extends Node

@export var target: Node:
	set(value):
		target = value
		update_property_list()

var _selected_property: String = ""
var _search_query: String = "":
	set(value):
		_search_query = value.to_lower()
		update_property_list()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_property_list()

# This function is called whenever the script needs to update its property list.
func _get_property_list() -> Array:
	var property_list = []
	
	if target == self:
		push_error("Target can't be self.")
		return []
	
	if target:
		var properties = target.get_property_list()
		var property_names = []
		
		# Extract property names.
		for prop in properties:
			if not (prop.usage & PROPERTY_USAGE_CATEGORY) and not (prop.usage & PROPERTY_USAGE_SUBGROUP) and not (prop.usage & PROPERTY_USAGE_GROUP) and not (prop.usage & PROPERTY_USAGE_INTERNAL):
				if _search_query == "" or _search_query in prop.name.to_lower():  # Filter by search query
					property_names.append(prop.name)
		
		property_names.sort()
		
			# Add a search field to filter properties.
		property_list.append({
			"name": "_search_query",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint_string": "Search properties"
		})
		
		# Add the dropdown (enum) to select the property.
		property_list.append({
			"name": "_selected_property",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(property_names),
			"usage": PROPERTY_USAGE_DEFAULT
		})

	return property_list

# Update the property list to reflect any changes
func update_property_list() -> void:
	notify_property_list_changed()
