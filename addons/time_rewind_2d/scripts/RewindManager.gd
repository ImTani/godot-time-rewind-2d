extends Node

signal rewind_started
signal rewind_stopped

var is_rewinding: bool = false
var non_rewindables: Array[Node] = []

func start_rewind() -> void:
	is_rewinding = true
	_pause_non_rewindables(true)
	rewind_started.emit()

func stop_rewind() -> void:
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
