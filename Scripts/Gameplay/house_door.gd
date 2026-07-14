class_name HouseDoor
extends Node3D

signal opened
signal closed

@export var requires_property_ownership := false
@export_range(45.0, 135.0, 1.0) var open_angle_degrees := 92.0
@export_range(0.1, 2.0, 0.05) var animation_duration := 0.45
@export var starts_open := false

@onready var hinge := $HingePivot as Node3D
@onready var visual_pivot := $DoorVisualPivot as Node3D
@onready var open_audio := $OpenAudio as AudioStreamPlayer3D
@onready var close_audio := $CloseAudio as AudioStreamPlayer3D
@onready var animation_player := $AnimationPlayer as AnimationPlayer

var is_open := false
var is_moving := false
var _building: PropertyBuilding
var _target_open := false


func _ready() -> void:
	add_to_group(&"interactable")
	_building = _find_property_building()
	is_open = starts_open
	_target_open = starts_open
	animation_player.animation_finished.connect(_on_animation_finished)
	if starts_open:
		animation_player.play(&"Door")
		animation_player.seek(animation_player.current_animation_length, true)
		animation_player.stop(true)
	else:
		animation_player.play(&"RESET")
		animation_player.advance(0.0)
		animation_player.stop(true)


func can_interact(player: CharacterBody3D) -> bool:
	return player != null and not is_moving


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	if _is_locked():
		return "LOCKED - PROPERTY FOR SALE"
	return "E - Close Door" if is_open else "E - Open Door"


func interact(player: CharacterBody3D) -> void:
	if not can_interact(player) or _is_locked():
		return
	_play_door_animation(not is_open)


func _play_door_animation(opening: bool) -> void:
	is_moving = true
	_target_open = opening
	if opening:
		open_audio.play()
		animation_player.play(&"Door")
	else:
		close_audio.play()
		animation_player.play_backwards(&"Door")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"Door":
		return
	is_open = _target_open
	is_moving = false
	if is_open:
		opened.emit()
	else:
		closed.emit()


func _is_locked() -> bool:
	return requires_property_ownership and (
		_building == null or not _building.is_owned()
	)


func _find_property_building() -> PropertyBuilding:
	var current := get_parent()
	while current != null:
		if current is PropertyBuilding:
			return current as PropertyBuilding
		current = current.get_parent()
	return null
