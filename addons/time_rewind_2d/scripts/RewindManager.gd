extends Node

signal rewind_started
signal rewind_stopped

var is_rewinding: bool = false
var non_rewindables: Array[Node] = []

func start_rewind() -> void:
	is_rewinding = true
	_pause_non_rewindables(true)
	emit_signal("rewind_started")

func stop_rewind() -> void:
	is_rewinding = false
	_pause_non_rewindables(false)
	emit_signal("rewind_stopped")

func _pause_non_rewindables(pause: bool) -> void:
	for node: Node in non_rewindables:
		if pause:
			node.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			node.process_mode = Node.PROCESS_MODE_INHERIT
