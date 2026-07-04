class_name PlayerArrestComponent
extends Node

signal arrest_progress_changed(progress: float)
signal arrest_started
signal arrest_cancelled
signal arrested

@export var wanted_component_path := NodePath("../WantedComponent")
@export var respawn_component_path := NodePath("../RespawnComponent")
@export var vehicle_component_path := NodePath("../VehicleComponent")
@export_range(0.5, 10.0, 0.1) var arrest_duration := 3.0
@export_range(1.0, 10.0, 0.1) var progress_drain_multiplier := 2.0
@export_range(0.05, 1.0, 0.05) var contact_grace := 0.25

@onready var wanted_component := (
	get_node(wanted_component_path) as PlayerWantedComponent
)
@onready var respawn_component := (
	get_node(respawn_component_path) as PlayerRespawnComponent
)
@onready var vehicle_component: Variant = get_node(vehicle_component_path)

var progress: float:
	get:
		return _progress

var _progress := 0.0
var _contact_remaining := 0.0


func _ready() -> void:
	wanted_component.wanted_level_changed.connect(_on_wanted_level_changed)


func _process(delta: float) -> void:
	_contact_remaining = maxf(_contact_remaining - delta, 0.0)
	var can_progress := (
		wanted_component.wanted_level == 1
		and _contact_remaining > 0.0
	)
	var previous := _progress
	if can_progress:
		_progress = minf(
			_progress + delta / maxf(arrest_duration, 0.01),
			1.0
		)
	else:
		_progress = maxf(
			_progress
			- delta
			* progress_drain_multiplier
			/ maxf(arrest_duration, 0.01),
			0.0
		)
	if is_zero_approx(previous) and _progress > 0.0:
		arrest_started.emit()
	if not is_equal_approx(previous, _progress):
		arrest_progress_changed.emit(_progress)
	if previous > 0.0 and is_zero_approx(_progress):
		arrest_cancelled.emit()
	if _progress >= 1.0:
		_complete_arrest()


func report_police_contact() -> void:
	if wanted_component.wanted_level == 1:
		_contact_remaining = contact_grace


func reset_progress() -> void:
	_contact_remaining = 0.0
	if is_zero_approx(_progress):
		return
	_progress = 0.0
	arrest_progress_changed.emit(_progress)
	arrest_cancelled.emit()


func _complete_arrest() -> void:
	_progress = 0.0
	_contact_remaining = 0.0
	wanted_component.resolve_arrest()
	if vehicle_component.is_driving():
		vehicle_component.exit_vehicle(true)
	respawn_component.respawn_after_arrest()
	arrest_progress_changed.emit(0.0)
	arrested.emit()


func _on_wanted_level_changed(_previous: int, current: int) -> void:
	if current != 1:
		reset_progress()
