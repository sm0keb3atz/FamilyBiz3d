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
	_refresh_binding_and_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED and is_inside_tree():
		_refresh_binding_and_state()


func _refresh_binding_and_state() -> void:
	_bind_controller()
	_apply_current_state()


func _bind_controller() -> void:
	var controller := (
		get_node_or_null(signal_controller_path) as TrafficSignalController3D
	)
	if controller == null and signal_controller_path.is_empty():
		controller = _find_signal_controller()
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


func _find_signal_controller() -> TrafficSignalController3D:
	var node := get_parent()
	while node != null:
		var controller := _find_signal_controller_recursive(node)
		if controller != null:
			return controller
		node = node.get_parent()
	return null


func _find_signal_controller_recursive(node: Node) -> TrafficSignalController3D:
	for child in node.get_children():
		if child is TrafficSignalController3D:
			return child as TrafficSignalController3D
		var controller := _find_signal_controller_recursive(child)
		if controller != null:
			return controller
	return null


func _on_signal_state_changed(group: StringName, state: int) -> void:
	if group != signal_group:
		return
	_set_state(state)


func _set_state(state: int) -> void:
	_turn_all_lamps_off()
	match state:
		TrafficSignalController3D.SignalState.YELLOW:
			_set_lamp_visible(yellow_lamp_path, &"YellowLamp", true)
		TrafficSignalController3D.SignalState.GREEN:
			_set_lamp_visible(green_lamp_path, &"GreenLamp", true)
		_:
			_set_lamp_visible(red_lamp_path, &"RedLamp", true)
	_set_blocker_enabled(state == TrafficSignalController3D.SignalState.RED)


func _set_no_signal_state() -> void:
	_turn_all_lamps_off()
	_set_blocker_enabled(false)


func _turn_all_lamps_off() -> void:
	_set_lamp_visible(red_lamp_path, &"RedLamp", false)
	_set_lamp_visible(yellow_lamp_path, &"YellowLamp", false)
	_set_lamp_visible(green_lamp_path, &"GreenLamp", false)


func _set_lamp_visible(path: NodePath, fallback_name: StringName, is_visible: bool) -> void:
	var lamp := get_node_or_null(path) as Node3D
	if lamp != null:
		lamp.visible = is_visible
	_set_lamp_visible_by_name(self, fallback_name, is_visible)


func _set_lamp_visible_by_name(node: Node, lamp_name: StringName, is_visible: bool) -> void:
	if node.name == lamp_name and node is Node3D:
		(node as Node3D).visible = is_visible
	for child in node.get_children():
		_set_lamp_visible_by_name(child, lamp_name, is_visible)


func _set_blocker_enabled(enabled: bool) -> void:
	var blocker := get_node_or_null(blocker_shape_path) as CollisionShape3D
	if blocker != null:
		blocker.disabled = not enabled
