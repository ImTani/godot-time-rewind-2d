@tool
# WORK IN PROGRESS, USE AT YOUR OWN DISCRETION!
# This is going to be a trouble to work with without heavy modification for now, not modular at all.

extends Area2D

var area_shape: CollisionShape2D

@export_subgroup("Settings")
@export var time_scale: float = 1
@export var tween_duration: float = 0.5
@export var tween_ease_type: int = Tween.TRANS_LINEAR
@export_range(20, 200, .5, "or_greater") var area_radius: float = 150

func _enter_tree() -> void:
	if not area_shape:
		area_shape = CollisionShape2D.new()
		area_shape.shape = CircleShape2D.new()
		area_shape.shape.radius = area_radius
		add_child(area_shape)

func _process(delta: float) -> void:
	if Engine.is_editor_hint and area_shape:
		area_shape.shape.radius = area_radius

func _change_time_scale(target_scale: float) -> void:
	var time_scale_tween: Tween = create_tween()
	time_scale_tween.set_ease(tween_ease_type)
	
	time_scale_tween.tween_property(Engine, "time_scale", target_scale, tween_duration)

func _on_time_manipulation_area_body_entered(body: Node2D) -> void:
	pass

func _on_time_manipulation_area_body_exited(body: Node2D) -> void:
	pass

# Reset time scale when the node is removed from the scene
func _exit_tree() -> void:
	_change_time_scale(1)
