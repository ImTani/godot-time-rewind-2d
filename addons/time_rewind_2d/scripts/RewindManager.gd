extends Node

signal rewind_started
signal rewind_stopped

signal rewind_limit_reached

## True if the rewind has reached the end (or forward) of
## an object's history 
var is_limit_reached = false:
	set=_set_is_limit_reached

## Controls how fast frames are re-wound. Values below [code]0[/code] re-wind time, while
## values above [code]0[/code] re-play recorded history
var rewind_speed: float = -1.0:
	set=_set_rewind_speed

## True if the rewind manager is currently winding time
var is_rewinding: bool = false
var non_rewindables: Array[Node] = []

func _set_rewind_speed(value):
	rewind_speed = value
	is_limit_reached = false

func _set_is_limit_reached(value):
	is_limit_reached = value
	if is_limit_reached:
		rewind_limit_reached.emit()

## Start rewinding time. An optional [param speed] value can be passed which
## controls how fast time is rewound. See [member rewind_speed]
func start_rewind(speed: float = -1.0) -> void:
	is_limit_reached = false
	# Pause the scene so objects do not process their physics while a rewind
	# is in progress
	get_tree().paused = true
	
	rewind_speed = speed
	is_rewinding = true
	_pause_non_rewindables(true)
	rewind_started.emit()

func stop_rewind() -> void:
	self.is_limit_reached = false
	
	## Un-pause the scene so objects can process their physics again
	get_tree().paused = false
	
	is_rewinding = false
	_pause_non_rewindables(false)
	rewind_stopped.emit()

func _pause_non_rewindables(pause: bool) -> void:
	for node: Node in non_rewindables:
		if is_instance_valid(node):
			if pause:
				node.process_mode = Node.PROCESS_MODE_DISABLED
			else:
				node.process_mode = Node.PROCESS_MODE_INHERIT
