@icon("res://addons/time_rewind_2d/essentials/icon.svg")

# Script responsible for handling time manipulation for a 2D body
extends Node2D
class_name TimeRewind2D

# Nodes group
@export_subgroup("Nodes")
@export var body: Node2D # The main body of the object to be manipulated
@export var collision_shape: CollisionShape2D # The collision shape of the object

# Settings group
@export_subgroup("Settings")
@export_range(1, 10, 1, "suffix:sec") var rewind_time: float = 3 # Duration of time that can be rewound, in seconds
@export var rewindable_properties: Array[String] # Properties that will be rewound

# On ready variables initialized when the script is ready
@onready var max_values_stored = rewind_time * Engine.physics_ticks_per_second # Max number of values to store for rewind
@onready var rewind_manager: RewindManager = RewindManager # Reference to the rewind manager

# Internal variables for managing the rewind process
var rewind_values: Dictionary = {} # Dictionary to store rewind values for properties

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
	
	# Initialize rewind values and check properties
	for property in rewindable_properties:
		if get_nested_property(body, property) == null:
			push_error("TimeRewind2D: Property '" + property + "' does not exist on the body.")
			continue
		rewind_values[property] = []

	# Connect rewind signals
	rewind_manager.connect("rewind_stopped", _on_rewind_stopped)
	rewind_manager.connect("rewind_started", _on_rewind_started)

# Called every physics frame
func _physics_process(delta: float) -> void:
	if not rewind_manager.is_rewinding:
		_store_current_values()
	else:
		_rewind_process(delta)

# Stores the current values of the rewindable properties
func _store_current_values() -> void:
	if rewindable_properties.is_empty():
		return

	# Remove the oldest values if the max limit is reached	
	for property in rewindable_properties:
		if rewind_values[property].size() >= max_values_stored:
			rewind_values[property].pop_front()

	# Store the current value of the property
	for property in rewindable_properties:
		var value = get_nested_property(body, property)
		if value != null:
			rewind_values[property].append(value)

# Rewinds the properties to previous values
func _rewind_process(delta: float) -> void:
	if rewindable_properties.is_empty():
		return

	# Stop rewind if there are no values left
	if rewind_values[rewindable_properties[0]].is_empty():
		rewind_manager.stop_rewind()
		return

	# Set the property to a previous value
	for property in rewindable_properties:
		if rewind_values[property].is_empty():
			push_warning("TimeRewind2D: No more values to rewind for property '" + property + "'.")
			continue
		var value = rewind_values[property].pop_back()
		set_nested_property(body, property, value)

# Called when rewind starts
func _on_rewind_started() -> void:
	# Disable collision during rewind
	if collision_shape:
		collision_shape.set_disabled.call_deferred(true)
	else:
		push_error("TimeRewind2D: 'collision_shape' is not valid when starting rewind.")
	
# Called when rewind stops
func _on_rewind_stopped() -> void:
	# Re-enable collision after rewind
	if collision_shape:
		collision_shape.set_disabled.call_deferred(false)
	else:
		push_error("TimeRewind2D: 'collision_shape' is not valid when stopping rewind.")

# Helper function to get a nested property from an object
func get_nested_property(root: Object, path: String) -> Variant:
	var current = root
	for property in path.split("."):
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
