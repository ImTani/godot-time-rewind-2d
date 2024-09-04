const HIDDEN_PROPERTIES: Dictionary = {
	key = "time_rewind_2d/configuration/hidden_properties",

	default = [
	"name", "unique_name_in_owner", "scene_file_path",
	"process_mode", "process_priority", "process_physics_priority",
	"process_thread_group", "process_thread_group_order", "process_thread_messages",
	"physics_interpolation_mode", "auto_translate_mode", "editor_description",
	"self_modulate", "show_behind_parent", "top_level",
	"clip_children", "light_mask", "visibility_layer",
	"z_index", "z_as_relative", "y_sort_enabled",
	"texture_filter", "texture_repeat", "material",
	"use_parent_material", "rotation_degrees", "skew",
	"transform", "global_rotation_degrees", "global_skew",
	"global_transform"
	],

	info = {
		"name": "time_rewind_2d/configuration/hidden_properties",
		"type": TYPE_PACKED_STRING_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "4:"
	}
}

const REWIND_TIME: Dictionary = {
	key = "time_rewind_2d/configuration/default_rewind_time",

	default = 3.0,

	info = {
		"name": "time_rewind_2d/configuration/default_rewind_time",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1, 10, 1, suffix:sec"
	}
		
}

func _setup_project_settings() -> void:
	if not ProjectSettings.has_setting(HIDDEN_PROPERTIES.key):
		ProjectSettings.set(HIDDEN_PROPERTIES.key, HIDDEN_PROPERTIES.default)
		ProjectSettings.add_property_info(HIDDEN_PROPERTIES.info)
	
	if not ProjectSettings.has_setting(REWIND_TIME.key):
		ProjectSettings.set(REWIND_TIME.key, REWIND_TIME.default)
		ProjectSettings.add_property_info(REWIND_TIME.info)

