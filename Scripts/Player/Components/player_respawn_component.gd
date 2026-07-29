class_name PlayerRespawnComponent
extends Node

@export var health_component_path := NodePath("../HealthComponent")
@export var movement_component_path := NodePath("../MovementComponent")
@export var body_path := NodePath("../..")
@export var legal_component_path := NodePath("../LegalComponent")
@export var damage_feedback_path := NodePath("../DamageFeedbackComponent")
@export var hospital_spawn_path := NodePath(
	"../../../../SpawnPoints/Hospital"
)
@export var police_station_spawn_path := NodePath(
	"../../../../SpawnPoints/PoliceStation"
)
@export_range(0.0, 10.0, 0.1) var death_scene_duration := 3.0
@export_range(0.0, 10.0, 0.1) var arrest_scene_duration := 2.5

@onready var health_component := (
	get_node(health_component_path) as PlayerHealthComponent
)
@onready var movement_component := (
	get_node(movement_component_path) as PlayerMovementComponent
)
@onready var body := get_node(body_path) as CharacterBody3D
@onready var legal_component := get_node(legal_component_path) as PlayerLegalComponent
@onready var damage_feedback := (
	get_node(damage_feedback_path) as PlayerDamageFeedbackComponent
)

var _spawn_transform := Transform3D.IDENTITY
var _sequence_id := 0


func _ready() -> void:
	_spawn_transform = body.global_transform
	health_component.downed.connect(_on_downed)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_R
	):
		if respawn():
			get_viewport().set_input_as_handled()


func respawn() -> bool:
	if not health_component.begin_respawn():
		return false

	_sequence_id += 1
	_complete_respawn_at(_get_spawn_transform(hospital_spawn_path))
	return true


func respawn_after_arrest() -> bool:
	if not health_component.begin_forced_respawn():
		return false
	_sequence_id += 1
	var current_sequence := _sequence_id
	movement_component.set_physics_process(false)
	body.velocity = Vector3.ZERO
	_finish_arrest_sequence(current_sequence)
	return true


func _on_downed() -> void:
	var police_custody := damage_feedback.was_last_damage_from_police()
	if police_custody:
		legal_component.begin_police_custody()
	_sequence_id += 1
	var current_sequence := _sequence_id
	if police_custody:
		_finish_arrest_sequence(current_sequence)
	else:
		_finish_death_sequence(current_sequence)


func _finish_death_sequence(current_sequence: int) -> void:
	if death_scene_duration > 0.0:
		get_tree().create_timer(death_scene_duration).timeout.connect(
			_complete_death_sequence.bind(current_sequence)
		)
	else:
		_complete_death_sequence.call_deferred(current_sequence)


func _complete_death_sequence(current_sequence: int) -> void:
	if (
		current_sequence != _sequence_id
		or not health_component.begin_respawn()
	):
		return
	_complete_respawn_at(_get_spawn_transform(hospital_spawn_path))


func _finish_arrest_sequence(current_sequence: int) -> void:
	if arrest_scene_duration > 0.0:
		get_tree().create_timer(arrest_scene_duration).timeout.connect(
			_complete_arrest_sequence.bind(current_sequence)
		)
	else:
		_complete_arrest_sequence.call_deferred(current_sequence)


func _complete_arrest_sequence(current_sequence: int) -> void:
	if current_sequence != _sequence_id:
		return
	_complete_respawn_at(_get_spawn_transform(police_station_spawn_path))


func _complete_respawn_at(target: Transform3D) -> void:
	body.global_transform = target
	body.velocity = Vector3.ZERO
	health_component.complete_respawn()
	movement_component.set_physics_process(true)


func _get_spawn_transform(path: NodePath) -> Transform3D:
	var marker := get_node_or_null(path) as Node3D
	if marker != null:
		return marker.global_transform
	push_warning(
		"Respawn marker '%s' was not found; using the initial player spawn."
		% path
	)
	return _spawn_transform
