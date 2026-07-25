class_name StreetLight
extends Node3D

@export var night_lighting_path := NodePath("NightLighting")

@onready var _night_lighting := get_node_or_null(night_lighting_path) as Node3D

var _world_time: WorldTimeComponent


func _ready() -> void:
	if _night_lighting != null:
		_night_lighting.visible = false
	call_deferred("_connect_world_time")


func _connect_world_time() -> void:
	_world_time = get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if _world_time == null:
		push_warning("StreetLight could not find the WorldTimeComponent.")
		return
	if not _world_time.time_changed.is_connected(_on_time_changed):
		_world_time.time_changed.connect(_on_time_changed)
	_update_light()


func _on_time_changed(_date_text: String, _time_text: String) -> void:
	_update_light()


func _update_light() -> void:
	if _night_lighting != null and _world_time != null:
		_night_lighting.visible = _world_time.is_nighttime()
