extends Node2D

@onready var property_selector_window = $"Property Selector"

func _ready() -> void:
	property_selector_window.target = $Player
