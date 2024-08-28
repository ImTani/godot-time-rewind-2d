# Script responsible for handling time manipulation for a 2D body
extends Node
class_name TimeManipulationComponent

# Nodes group
@export_subgroup("Nodes")
@export var body: Node2D ## The main body of the object to be manipulated
@export var collision_shape: CollisionShape2D ## The collision shape of the object

# Settings group
@export_subgroup("Settings")
@export_range(1, 10, 1, "suffix:sec") var rewind_time: float = 3 ## Duration of time that can be rewound, in seconds
@export var rewindable_properties: Array[String] ## Properties of the body that can be rewound

# On ready variables initialized when the script is ready
@onready var max_values_stored = rewind_time * Engine.physics_ticks_per_second ## Maximum number of values to store for rewind
@onready var rewind_manager: RewindManager = RewindManager ## Reference to the rewind manager

# Internal variables for managing the rewind process
var rewind_values: Dictionary = {} ## Dictionary to store rewind values for properties

# Initialization function
func _ready() -> void:
	for property in rewindable_properties:
		# Initialize lists for each rewindable property
		rewind_values[property] = []

	# Connect rewind start signal
	rewind_manager.connect("rewind_started", _on_rewind_started)
	# Connect rewind stop signal
	rewind_manager.connect("rewind_stopped", _on_rewind_stopped)

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
	
	# Remove the oldest values if the max limit is reached	
	if rewind_values[rewindable_properties[0]].size() >= max_values_stored:
		for key in rewind_values.keys():
			rewind_values[key].pop_front()

	# Store the current value of the property
	for property in rewindable_properties:
		var value = get_nested_property(body, property)
		rewind_values[property].append(value)

# Rewinds the properties to previous values
func _rewind_process(delta: float) -> void:
	# Stop rewind if there are no values left
	if rewind_values[rewindable_properties[0]].is_empty():
		rewind_manager.stop_rewind() 
		return

	# Set the property to a previous value
	for property in rewindable_properties:
		var value = rewind_values[property].pop_back()
		set_nested_property(body, property, value)

# Called when rewind starts
func _on_rewind_started():
	 # Disable collision during rewind
	if collision_shape:
		collision_shape.set_disabled.call_deferred(true)

# Called when rewind stops
func _on_rewind_stopped():
	# Re-enable collision after rewind
	if collision_shape:
		collision_shape.set_disabled.call_deferred(false) 

# Helper function to get a nested property from an object
func get_nested_property(root: Object, path: String) -> Variant:
	var current = root
	var properties = path.split(".")
	for property in properties:
		current = current.get(property)
	return current

# Helper function to set a nested property in an object
func set_nested_property(root: Object, path: String, value: Variant) -> void:
	var current = root
	var properties = path.split(".")
	for i in range(properties.size() - 1):
		current = current.get(properties[i])
	current.set(properties[-1], value)
