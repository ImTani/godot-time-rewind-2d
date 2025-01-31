@icon("res://addons/time_rewind_2d/essentials/icon.svg")

#TODO: Add a menu in project settings for default rewind time on script.

# Script responsible for handling time manipulation for a 2D body
extends Node2D
class_name TimeRewind2D

# Nodes group
@export_subgroup("Nodes")
@export var body: Node2D ## The main body of the object to be manipulated
@export var collision_shape: CollisionShape2D ## The collision shape of the object

# Settings group
@export_subgroup("Settings")
@export_range(1, 10, 1, "suffix:sec") var rewind_time: float = 3 ## Duration of time that can be rewound, in seconds

@export var rewindable_properties: Array[String] ## Properties that will be rewound

# On ready variables initialized when the script is ready
@onready var max_values_stored = rewind_time * Engine.physics_ticks_per_second ## Maximum number of values to store for rewind
@onready var rewind_manager: RewindManager = RewindManager ## Reference to the rewind manager

# Internal variables for managing the rewind process
var rewind_values: Dictionary = {} ## Dictionary to store rewind values for properties
var rewind_index: int ## Index to store the current position in the rewind_values array. Used for allowing re-play

# Initialization function
func _ready() -> void:
	if not body:
		push_error("TimeRewind2D: 'body' is not assigned.")
		return
		
	if rewind_time <= 0:
		push_error("TimeRewind2D: 'rewind_time' must be greater than 0.")
		return
	
	if not collision_shape:
		push_warning("TimeRewind2D: 'collision_shape' is not assigned.")

	if rewindable_properties.is_empty():
		push_warning("TimeRewind2D: 'rewindable_properties' is empty. No properties will be rewound.")
		
	for property in rewindable_properties:
		if get_nested_property(body, property) == null:
			push_error("TimeRewind2D: Property '" + property + "' does not exist on the body.")
		# Initialize lists for each rewindable property
		rewind_values[property] = []

	# Connect rewind start signal
	rewind_manager.connect("rewind_stopped", _on_rewind_stopped)
	rewind_manager.connect("rewind_started", _on_rewind_started)

# Called every physics frame
func _physics_process(delta: float) -> void:
	if not rewind_manager.is_rewinding:
		# Store current property values when not rewinding
		_store_current_values()
	else:
		# Rewind properties when rewinding
		_rewind_process(delta)

# Stores the current values of the rewindable properties
func _store_current_values() -> void:
	if rewindable_properties.is_empty():
		return

	# Remove the oldest values if the max limit is reached	
	if rewind_values[rewindable_properties[0]].size() >= max_values_stored:
		for key in rewind_values.keys():
			rewind_values[key].pop_front()

	# Store the current value of the property
	for property in rewindable_properties:
		var value = get_nested_property(body, property)
		if value == null:
			return
		rewind_values[property].append(value)

# Rewinds the properties to previous values
func _rewind_process(delta: float) -> void:
	if rewindable_properties.is_empty():
		return
	
	rewind_index -= sign(delta)
	
	# Stop rewind if there are no values left, clearing the future buffer
	if _is_rewind_exhausted_for_property(rewindable_properties[0]):
		clear_future_buffer()
		rewind_manager.stop_rewind()
		return
	
	# Set the property to a previous value
	for property in rewindable_properties:
		if _is_rewind_exhausted_for_property(property):
			push_warning("TimeRewind2D: No more values to rewind for property '" + property + "'.")
			continue
		
		_set_rewind_property(property)

# Called when rewind starts
func _on_rewind_started():
	# Update the rewind index to point to the latest available value
	rewind_index = len(rewind_values[rewindable_properties[0]])
	
	 # Disable collision during rewind
	if collision_shape:
		collision_shape.set_disabled.call_deferred(true)
	else:
		push_error("TimeRewind2D: 'collision_shape' is not valid when starting rewind.")
	
# Called when rewind stops
func _on_rewind_stopped():
	clear_future_buffer()
	
	# Re-enable collision after rewind
	if collision_shape:
		collision_shape.set_disabled.call_deferred(false)
	else:
		push_error("TimeRewind2D: 'collision_shape' is not valid when stopping rewind.")

# Helper function to get a nested property from an object
func get_nested_property(root: Object, path: String) -> Variant:
	var current = root
	var properties = path.split(".")
	for property in properties:
		if not current:
			push_error("TimeRewind2D: Failed to retrieve property '" + path + "'.")
			return null
		current = current.get(property)
	return current

# Helper function to set a nested property in an object
func set_nested_property(root: Object, path: String, value: Variant) -> void:
	var current = root
	var properties = path.split(".")
	for i in range(properties.size() - 1):
		if not current:
			push_error("TimeRewind2D: Failed to set property '" + path + "'.")
			return
		current = current.get(properties[i])
	current.set(properties[-1], value)

## Clear all items from [member rewind_values] which are equal to, or above
## [member rewind_index].
func clear_future_buffer():
	# Set the property to a previous value
	for property in rewindable_properties:
		rewind_values[property] = rewind_values[property].slice(0, rewind_index)

## Sets the value of [param property]. Prints a warning if no more values
## are available
func _set_rewind_property(property: String):
	if !_is_rewind_exhausted_for_property(property):
		var value = rewind_values[property][rewind_index]
		set_nested_property(body, property, value)
	else:
		push_warning("TimeRewind2D: No more values to rewind for property '" + property + "'.")
		return

## Returns [code]true[/code] if [param property] no longer has values which can be rewinded.
func _is_rewind_exhausted_for_property(property):
	if rewind_values[property].is_empty():
		return true
	
	var buffer_length = len(rewind_values[rewindable_properties[0]])
	
	if rewind_index <= 0 or rewind_index >= buffer_length:
		return true
