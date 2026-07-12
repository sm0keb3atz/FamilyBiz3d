class_name TrafficSignalVisual3D
extends Node3D

@export var signal_controller_path: NodePath
@export var signal_group: StringName = &"north_south"
@export var red_lamp_path := NodePath("Lamps/RedLamp")
@export var yellow_lamp_path := NodePath("Lamps/YellowLamp")
@export var green_lamp_path := NodePath("Lamps/GreenLamp")
@export var blocker_shape_path := NodePath("RedSignalBlocker/CollisionShape3D")

var _controller: TrafficSignalController3D


func _ready() -> void:
	_bind_controller()
	_apply_current_state()
	call_deferred("_refresh_binding_and_state")
	set_process(true)


func _process(_delta: float) -> void:
	# Keep the visible lamp exclusive even if another scene/tool touches visibility.
	_apply_current_state()


func _refresh_binding_and_state() -> void:
	_bind_controller()
	_apply_current_state()


func _bind_controller() -> void:
	var controller := get_signal_controller()
	if _controller == controller:
		return
	if _controller != null and _controller.signal_state_changed.is_connected(
		_on_signal_state_changed
	):
		_controller.signal_state_changed.disconnect(_on_signal_state_changed)
	_controller = controller
	if _controller != null and not _controller.signal_state_changed.is_connected(
		_on_signal_state_changed
	):
		_controller.signal_state_changed.connect(_on_signal_state_changed)


func _apply_current_state() -> void:
	if _controller == null:
		_set_no_signal_state()
		return
	_set_state(_controller.get_signal_state(signal_group))


func _on_signal_state_changed(group: StringName, state: int) -> void:
	if group != signal_group:
		return
	_set_state(state)


func _set_state(state: int) -> void:
	_set_lamp_visible(red_lamp_path, false)
	_set_lamp_visible(yellow_lamp_path, false)
	_set_lamp_visible(green_lamp_path, false)
	match state:
		TrafficSignalController3D.SignalState.YELLOW:
			_set_lamp_visible(yellow_lamp_path, true)
		TrafficSignalController3D.SignalState.GREEN:
			_set_lamp_visible(green_lamp_path, true)
		_:
			_set_lamp_visible(red_lamp_path, true)
	_set_blocker_enabled(state == TrafficSignalController3D.SignalState.RED)


func _set_no_signal_state() -> void:
	_set_lamp_visible(red_lamp_path, false)
	_set_lamp_visible(yellow_lamp_path, false)
	_set_lamp_visible(green_lamp_path, false)
	_set_blocker_enabled(false)


func _set_lamp_visible(path: NodePath, is_visible: bool) -> void:
	var lamp := get_node_or_null(path) as MeshInstance3D
	if lamp != null:
		lamp.visible = is_visible


func _set_blocker_enabled(enabled: bool) -> void:
	var blocker := get_node_or_null(blocker_shape_path) as CollisionShape3D
	if blocker != null:
		blocker.disabled = not enabled


func get_signal_controller() -> TrafficSignalController3D:
	if signal_controller_path.is_empty():
		return null
	return get_node_or_null(signal_controller_path) as TrafficSignalController3D


func get_active_state() -> int:
	return (
		_controller.get_signal_state(signal_group)
		if _controller != null
		else -1
	)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if signal_controller_path.is_empty():
		warnings.append("Traffic light needs an explicit signal controller path.")
	if signal_group == &"":
		warnings.append("Traffic light needs a signal group.")
	return warnings
