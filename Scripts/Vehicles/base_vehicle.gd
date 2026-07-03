class_name BaseVehicle
extends VehicleBody3D

const VehicleDefinitionResource := preload(
	"res://Scripts/Vehicles/vehicle_definition.gd"
)

signal driver_changed(driver: CharacterBody3D)
signal exit_denied(message: String)

@export var definition: VehicleDefinitionResource
@export_category("Scene References")
@export var visual_root_path := NodePath("VisualRoot")
@export var front_left_wheel_path := NodePath("WheelFL")
@export var front_right_wheel_path := NodePath("WheelFR")
@export var rear_left_wheel_path := NodePath("WheelRL")
@export var rear_right_wheel_path := NodePath("WheelRR")
@export var camera_pivot_path := NodePath("CameraPivot")
@export var spring_arm_path := NodePath("CameraPivot/SpringArm3D")
@export var camera_path := NodePath("CameraPivot/SpringArm3D/Camera3D")
@export var driver_marker_path := NodePath("DriverMarker")
@export var exit_marker_paths: Array[NodePath] = [
	NodePath("ExitLeft"),
	NodePath("ExitRight"),
]
@export_category("Interaction")
@export_range(0.0, 10.0, 0.1) var maximum_exit_speed := 2.0
@export var interact_action := &"interact"
@export var handbrake_action := &"vehicle_handbrake"
@export var reset_action := &"vehicle_reset"

@onready var visual_root := get_node(visual_root_path) as Node3D
@onready var front_left_wheel := (
	get_node(front_left_wheel_path) as VehicleWheel3D
)
@onready var front_right_wheel := (
	get_node(front_right_wheel_path) as VehicleWheel3D
)
@onready var rear_left_wheel := (
	get_node(rear_left_wheel_path) as VehicleWheel3D
)
@onready var rear_right_wheel := (
	get_node(rear_right_wheel_path) as VehicleWheel3D
)
@onready var camera_pivot := get_node(camera_pivot_path) as Node3D
@onready var spring_arm := get_node(spring_arm_path) as SpringArm3D
@onready var vehicle_camera := get_node(camera_path) as Camera3D
@onready var driver_marker := get_node(driver_marker_path) as Marker3D
@onready var door_player := $Audio/DoorPlayer as AudioStreamPlayer3D
@onready var start_player := $Audio/StartPlayer as AudioStreamPlayer3D
@onready var engine_player := $Audio/EnginePlayer as AudioStreamPlayer3D
@onready var stop_player := $Audio/StopPlayer as AudioStreamPlayer3D

var _driver: CharacterBody3D
var _steering_input := 0.0
var _throttle_amount := 0.0
var _camera_pitch := deg_to_rad(-10.0)
var _camera_yaw_offset := 0.0
var _camera_recenter_timer := 0.0
var _camera_turn_lag := 0.0
var _camera_longitudinal_acceleration := 0.0
var _previous_camera_forward_speed := 0.0
var _skeleton: Skeleton3D
var _wheel_bones: Dictionary = {}
var _wheel_spin: Dictionary = {}
var _wheel_anchor_positions: Dictionary = {}
var _current_gear := 1
var _engine_rpm := 850.0
var _shift_timer := 0.0
var _is_service_braking := false
var _audio_sequence_id := 0
var _engine_target_volume_db := 0.0
var _start_target_volume_db := 0.0
var _engine_ready := false
var _rear_grip := 2.9
var _handbrake_amount := 0.0
var _drift_amount := 0.0


func _ready() -> void:
	add_to_group("interactable")
	vehicle_camera.current = false
	set_process_unhandled_input(false)
	if definition == null:
		push_error("%s requires a VehicleDefinition." % name)
		return
	_cache_wheel_anchors()
	_apply_definition()
	_snap_camera_rig()
	call_deferred("_bind_wheel_bones")


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	_update_controls(delta)
	_apply_stability()
	_update_engine_audio(delta)
	_update_wheel_visuals(delta)


func _process(delta: float) -> void:
	_update_camera_rig(delta)
	if _driver != null and is_instance_valid(_driver):
		_driver.global_position = driver_marker.global_position


func _unhandled_input(event: InputEvent) -> void:
	if _driver == null:
		return
	if event.is_action_pressed(interact_action):
		var component := _get_driver_component()
		if component != null:
			component.call("exit_vehicle")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(reset_action):
		if linear_velocity.length() <= 2.0:
			_recover_upright()
			get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouseMotion
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	):
		_camera_yaw_offset -= event.relative.x * definition.camera_sensitivity
		_camera_recenter_timer = definition.camera_recenter_delay
		_camera_pitch = clampf(
			_camera_pitch - event.relative.y * definition.camera_sensitivity,
			deg_to_rad(-35.0),
			deg_to_rad(15.0)
		)


func can_interact(player: CharacterBody3D) -> bool:
	if _driver != null or definition == null:
		return false
	var health := player.get_node_or_null(
		"Components/HealthComponent"
	) as PlayerHealthComponent
	return health != null and health.is_alive()


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	var vehicle_name: String = (
		definition.display_name if definition != null else "vehicle"
	)
	return "E - Drive %s" % vehicle_name


func interact(player: CharacterBody3D) -> void:
	if not can_interact(player):
		return
	var component: Variant = player.get_node_or_null(
		"Components/VehicleComponent"
	)
	if component != null:
		component.call("enter_vehicle", self)


func enter_driver(player: CharacterBody3D) -> bool:
	if _driver != null or not can_interact(player):
		return false
	_driver = player
	_current_gear = 1
	_engine_rpm = definition.idle_rpm
	_shift_timer = 0.0
	_throttle_amount = 0.0
	_is_service_braking = false
	_engine_ready = false
	_handbrake_amount = 0.0
	_drift_amount = 0.0
	_camera_yaw_offset = 0.0
	_camera_recenter_timer = 0.0
	_camera_turn_lag = 0.0
	_camera_longitudinal_acceleration = 0.0
	_previous_camera_forward_speed = linear_velocity.dot(global_basis.z)
	engine_player.pitch_scale = definition.idle_pitch
	sleeping = false
	vehicle_camera.current = true
	_snap_camera_rig()
	set_process_unhandled_input(true)
	_begin_entry_audio_sequence()
	driver_changed.emit(_driver)
	return true


func request_exit(player: CharacterBody3D) -> Vector3:
	if player != _driver:
		return Vector3.INF
	if linear_velocity.length() > maximum_exit_speed:
		exit_denied.emit("Slow down before exiting.")
		return Vector3.INF
	var exit_position := _find_safe_exit_position(player)
	if exit_position == Vector3.INF:
		exit_denied.emit("There is no room to exit.")
		return Vector3.INF
	return exit_position


func set_driver(player: CharacterBody3D) -> void:
	if player == _driver:
		return
	if player == null:
		if _driver != null:
			clear_driver()
		return
	if _driver == null:
		enter_driver(player)


func clear_driver() -> void:
	_driver = null
	_current_gear = 1
	_shift_timer = 0.0
	_throttle_amount = 0.0
	_is_service_braking = false
	_engine_ready = false
	_drift_amount = 0.0
	_cancel_entry_audio_sequence()
	start_player.stop()
	_set_drive_force(0.0)
	_set_brake_force(
		definition.service_brake_force if definition != null else 90.0,
		0.0
	)
	_reset_rear_grip()
	steering = 0.0
	vehicle_camera.current = false
	set_process_unhandled_input(false)
	engine_player.stop()
	stop_player.play()
	door_player.volume_db = definition.exit_door_volume_db
	door_player.play()
	driver_changed.emit(null)


func has_driver() -> bool:
	return _driver != null


func get_driver() -> CharacterBody3D:
	return _driver


func get_vehicle_camera() -> Camera3D:
	return vehicle_camera


func get_current_gear() -> int:
	return _current_gear


func get_engine_rpm() -> float:
	return _engine_rpm


func has_valid_wheel_bones() -> bool:
	return _skeleton != null and _wheel_bones.size() == 4


func _apply_definition() -> void:
	mass = definition.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, definition.center_of_mass_height, 0.0)
	if definition.visual_scene != null and visual_root.get_child_count() == 0:
		var model := definition.visual_scene.instantiate() as Node3D
		if model != null:
			model.name = "VehicleModel"
			model.position = definition.visual_offset
			model.rotation_degrees = definition.visual_rotation_degrees
			visual_root.add_child(model)
	spring_arm.spring_length = definition.camera_distance
	camera_pivot.position.y = definition.camera_height
	for wheel in _get_wheels():
		wheel.wheel_radius = definition.wheel_radius
		wheel.wheel_rest_length = definition.suspension_rest_length
		wheel.suspension_travel = definition.suspension_travel
		wheel.suspension_stiffness = definition.suspension_stiffness
		wheel.damping_compression = definition.damping_compression
		wheel.damping_relaxation = definition.damping_relaxation
		wheel.suspension_max_force = definition.suspension_max_force
		wheel.wheel_roll_influence = definition.wheel_roll_influence
	front_left_wheel.wheel_friction_slip = (
		definition.front_wheel_friction_slip
	)
	front_right_wheel.wheel_friction_slip = (
		definition.front_wheel_friction_slip
	)
	rear_left_wheel.wheel_friction_slip = definition.rear_wheel_friction_slip
	rear_right_wheel.wheel_friction_slip = definition.rear_wheel_friction_slip
	_rear_grip = definition.rear_wheel_friction_slip
	front_left_wheel.use_as_steering = true
	front_right_wheel.use_as_steering = true
	rear_left_wheel.use_as_traction = true
	rear_right_wheel.use_as_traction = true
	door_player.stream = definition.door_stream
	start_player.stream = definition.start_stream
	engine_player.stream = definition.engine_stream
	stop_player.stream = definition.stop_stream
	if engine_player.stream is AudioStreamWAV:
		var looping_stream := engine_player.stream.duplicate() as AudioStreamWAV
		looping_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var final_frame := int(
			looping_stream.get_length() * looping_stream.mix_rate
		)
		looping_stream.loop_begin = clampi(
			definition.engine_loop_begin,
			0,
			maxi(final_frame - 2, 0)
		)
		looping_stream.loop_end = clampi(
			definition.engine_loop_end,
			looping_stream.loop_begin + 1,
			maxi(final_frame - 1, 1)
		)
		engine_player.stream = looping_stream
	engine_player.pitch_scale = definition.idle_pitch
	_engine_target_volume_db = engine_player.volume_db
	_start_target_volume_db = start_player.volume_db


func _update_controls(delta: float) -> void:
	if _driver == null:
		_set_drive_force(0.0)
		_throttle_amount = 0.0
		return
	var forward_speed := linear_velocity.dot(global_basis.z)
	var throttle := Input.get_action_strength("move_forward")
	var reverse := Input.get_action_strength("move_back")
	var steer_axis := Input.get_axis("move_right", "move_left")
	_handbrake_amount = Input.get_action_strength(handbrake_action)
	_update_drift_amount(delta, throttle)
	_update_automatic_transmission(
		delta,
		forward_speed,
		throttle,
		reverse
	)
	var speed_ratio := clampf(
		absf(forward_speed) / definition.max_forward_speed,
		0.0,
		1.0
	)
	var steering_limit := deg_to_rad(
		definition.max_steering_degrees
	) * lerpf(1.0, definition.high_speed_steering_ratio, speed_ratio)
	_steering_input = move_toward(
		_steering_input,
		steer_axis * steering_limit,
		definition.steering_speed * delta
	)
	steering = _steering_input
	var requested_brake_force := 0.0
	var requested_drive_force := 0.0
	_throttle_amount = 0.0
	_is_service_braking = false

	if throttle > 0.0:
		if forward_speed < -0.8:
			requested_brake_force = (
				definition.service_brake_force * throttle
			)
			_is_service_braking = true
		elif forward_speed < definition.max_forward_speed:
			requested_drive_force = (
				definition.engine_force
				* _get_current_gear_force_multiplier()
				* lerpf(
					1.0,
					definition.drift_torque_multiplier,
					_drift_amount
				)
				* throttle
			)
			_throttle_amount = throttle
	elif reverse > 0.0:
		if forward_speed > 0.8:
			requested_brake_force = (
				definition.service_brake_force * reverse
			)
			_is_service_braking = true
		elif forward_speed > -definition.max_reverse_speed:
			requested_drive_force = (
				-definition.reverse_engine_force * reverse
			)
			_throttle_amount = reverse
	else:
		requested_brake_force = 1.5
	if _shift_timer > 0.0:
		requested_drive_force = 0.0
		_throttle_amount = 0.0
	if not _engine_ready:
		requested_drive_force = 0.0
		_throttle_amount = 0.0
	requested_drive_force *= 1.0 - _handbrake_amount
	_set_drive_force(requested_drive_force)

	_update_rear_grip(
		delta,
		throttle,
		_handbrake_amount,
		forward_speed
	)
	_set_brake_force(
		requested_brake_force,
		definition.handbrake_force * _handbrake_amount
	)


func _apply_stability() -> void:
	if linear_velocity.length_squared() <= 0.01:
		return
	_apply_anti_roll(front_left_wheel, front_right_wheel)
	_apply_anti_roll(rear_left_wheel, rear_right_wheel)
	_apply_roll_stabilization()
	_apply_drift_stability()
	var speed_squared := linear_velocity.length_squared()
	if global_basis.y.dot(Vector3.UP) > 0.25:
		var downforce := minf(
			speed_squared * definition.downforce_coefficient,
			definition.max_downforce
		)
		apply_central_force(-global_basis.y * downforce)


func _apply_anti_roll(
	left_wheel: VehicleWheel3D,
	right_wheel: VehicleWheel3D
) -> void:
	if not left_wheel.is_in_contact() or not right_wheel.is_in_contact():
		return
	var left_compression := _get_suspension_compression(left_wheel)
	var right_compression := _get_suspension_compression(right_wheel)
	var force := clampf(
		(
			left_compression - right_compression
		) * definition.anti_roll_stiffness,
		-definition.maximum_anti_roll_force,
		definition.maximum_anti_roll_force
	)
	var up := global_basis.y
	var left_anchor := _get_wheel_anchor_world(left_wheel)
	var right_anchor := _get_wheel_anchor_world(right_wheel)
	# Equal and opposite forces resist the axle's suspension difference.
	apply_force(up * force, left_anchor - global_position)
	apply_force(-up * force, right_anchor - global_position)


func _get_suspension_compression(wheel: VehicleWheel3D) -> float:
	if not wheel.is_in_contact():
		return 0.0
	var anchor := _get_wheel_anchor_world(wheel)
	var distance_along_suspension := (
		anchor - wheel.get_contact_point()
	).dot(global_basis.y.normalized())
	var suspension_length := clampf(
		distance_along_suspension - definition.wheel_radius,
		0.0,
		definition.suspension_rest_length + definition.suspension_travel
	)
	return clampf(
		definition.suspension_rest_length - suspension_length,
		-definition.suspension_travel,
		definition.suspension_travel
	)


func _apply_roll_stabilization() -> void:
	var grounded_wheels := 0
	for wheel in _get_wheels():
		if wheel.is_in_contact():
			grounded_wheels += 1
	if grounded_wheels < 2:
		return
	var forward := global_basis.z.normalized()
	var roll_error := global_basis.x.normalized().dot(Vector3.UP)
	var roll_rate := angular_velocity.dot(forward)
	var corrective_torque := (
		-roll_error * definition.roll_leveling_torque
		- roll_rate * definition.roll_damping_torque
	)
	apply_torque(forward * corrective_torque)


func _apply_drift_stability() -> void:
	var speed := linear_velocity.length()
	if speed < 2.0:
		return
	var side := global_basis.x.normalized()
	var up := global_basis.y.normalized()
	var lateral_speed := linear_velocity.dot(side)
	var assist_scale := 1.0 - _handbrake_amount * 0.75
	apply_central_force(
		-side
		* lateral_speed
		* definition.drift_lateral_assist
		* assist_scale
	)
	var yaw_rate := angular_velocity.dot(up)
	apply_torque(
		-up
		* yaw_rate
		* definition.drift_yaw_damping
		* assist_scale
	)


func _update_engine_audio(delta: float) -> void:
	if _driver == null or not engine_player.playing:
		return
	var forward_speed := linear_velocity.dot(global_basis.z)
	var target_rpm := _calculate_target_rpm(forward_speed)
	if _drift_amount > 0.0 and _throttle_amount > 0.0:
		var drift_rpm := lerpf(
			definition.drift_rpm_floor,
			definition.maximum_rpm,
			_throttle_amount * 0.65
		)
		target_rpm = maxf(
			target_rpm,
			lerpf(target_rpm, drift_rpm, _drift_amount)
		)
	if _is_service_braking:
		target_rpm = minf(target_rpm, _engine_rpm)
	if _shift_timer > 0.0:
		target_rpm = maxf(
			definition.idle_rpm,
			target_rpm * 0.7
		)
	_engine_rpm = move_toward(
		_engine_rpm,
		target_rpm,
		9000.0 * delta
	)
	var rpm_ratio := clampf(
		(_engine_rpm - definition.idle_rpm)
		/ (definition.maximum_rpm - definition.idle_rpm),
		0.0,
		1.0
	)
	var engine_load := clampf(
		rpm_ratio + _throttle_amount * 0.12,
		0.0,
		1.0
	)
	var target_pitch := lerpf(
		definition.idle_pitch,
		definition.maximum_pitch,
		engine_load
	)
	engine_player.pitch_scale = move_toward(
		engine_player.pitch_scale,
		target_pitch,
		4.0 * delta
	)


func _update_automatic_transmission(
	delta: float,
	forward_speed: float,
	throttle: float,
	reverse_input: float
) -> void:
	_shift_timer = maxf(_shift_timer - delta, 0.0)
	if (
		reverse_input > 0.0
		and forward_speed <= 0.8
		and throttle <= 0.0
	):
		_current_gear = -1
		return
	if forward_speed < -0.8:
		_current_gear = -1
		return
	if _current_gear <= 0:
		_current_gear = 1
	if _shift_timer > 0.0:
		return
	if _drift_amount > 0.2:
		return
	var limits := definition.forward_gear_speed_limits
	if limits.is_empty():
		return
	var speed := maxf(forward_speed, 0.0)
	var gear_index := clampi(_current_gear - 1, 0, limits.size() - 1)
	if speed >= limits[gear_index] and _current_gear < limits.size():
		_current_gear += 1
		_shift_timer = definition.shift_duration
	elif _current_gear > 1:
		var previous_limit := limits[_current_gear - 2]
		if speed < previous_limit * 0.72:
			_current_gear -= 1
			_shift_timer = definition.shift_duration


func _get_current_gear_force_multiplier() -> float:
	if _current_gear <= 0:
		return 1.0
	var multipliers := definition.forward_gear_force_multipliers
	if multipliers.is_empty():
		return 1.0
	return multipliers[
		clampi(_current_gear - 1, 0, multipliers.size() - 1)
	]


func _calculate_target_rpm(forward_speed: float) -> float:
	if _current_gear < 0:
		var reverse_ratio := clampf(
			absf(forward_speed) / definition.max_reverse_speed,
			0.0,
			1.0
		)
		return lerpf(
			definition.idle_rpm,
			definition.maximum_rpm,
			maxf(reverse_ratio, _throttle_amount * 0.35)
		)
	var limits := definition.forward_gear_speed_limits
	if limits.is_empty():
		return definition.idle_rpm
	var gear_index := clampi(_current_gear - 1, 0, limits.size() - 1)
	var lower_speed := (
		0.0
		if gear_index == 0
		else limits[gear_index - 1] * 0.72
	)
	var upper_speed := limits[gear_index]
	var speed_ratio := clampf(
		(maxf(forward_speed, 0.0) - lower_speed)
		/ maxf(upper_speed - lower_speed, 0.1),
		0.0,
		1.0
	)
	var minimum_running_rpm := (
		definition.idle_rpm
		if forward_speed < 0.5
		else definition.idle_rpm + 550.0
	)
	return lerpf(
		minimum_running_rpm,
		definition.maximum_rpm,
		maxf(speed_ratio, _throttle_amount * 0.18)
	)


func _update_drift_amount(delta: float, throttle: float) -> void:
	var planar_velocity := Vector3(
		linear_velocity.x,
		0.0,
		linear_velocity.z
	)
	var speed := planar_velocity.length()
	var lateral_speed := absf(
		planar_velocity.dot(global_basis.x.normalized())
	)
	var slip_ratio := lateral_speed / maxf(speed, 0.1)
	var slip_amount := smoothstep(
		definition.drift_slip_start,
		definition.drift_slip_full,
		slip_ratio
	)
	var throttle_amount := inverse_lerp(
		definition.drift_throttle_threshold,
		1.0,
		throttle
	)
	var target_drift := (
		slip_amount * clampf(throttle_amount, 0.0, 1.0)
		if speed > 3.0
		else 0.0
	)
	var response_speed := (
		definition.drift_engagement_speed
		if target_drift > _drift_amount
		else definition.drift_release_speed
	)
	_drift_amount = move_toward(
		_drift_amount,
		target_drift,
		response_speed * delta
	)


func _bind_wheel_bones() -> void:
	_skeleton = _find_skeleton(visual_root)
	if _skeleton == null:
		push_warning("%s could not find its vehicle skeleton." % name)
		return
	var bindings := {
		front_left_wheel: definition.front_left_bone,
		front_right_wheel: definition.front_right_bone,
		rear_left_wheel: definition.rear_left_bone,
		rear_right_wheel: definition.rear_right_bone,
	}
	for wheel in bindings:
		var bone_index := _skeleton.find_bone(bindings[wheel])
		if bone_index < 0:
			push_warning(
				"%s is missing wheel bone %s." % [name, bindings[wheel]]
			)
			continue
		_wheel_bones[wheel] = bone_index
		_wheel_spin[wheel] = 0.0


func _update_wheel_visuals(delta: float) -> void:
	if _skeleton == null or _wheel_bones.is_empty():
		return
	var skeleton_inverse := _skeleton.global_transform.affine_inverse()
	var down := -global_basis.y
	for wheel in _wheel_bones:
		var bone_index := int(_wheel_bones[wheel])
		_wheel_spin[wheel] = float(_wheel_spin[wheel]) + (
			wheel.get_rpm() * TAU / 60.0 * delta
		)
		var center: Vector3 = wheel.global_position + (
			down * definition.suspension_rest_length
		)
		if wheel.is_in_contact():
			center = wheel.get_contact_point() + (
				wheel.get_contact_normal() * definition.wheel_radius
			)
		var rest := _skeleton.get_bone_global_rest(bone_index)
		var steer_angle := (
			_steering_input
			if wheel == front_left_wheel or wheel == front_right_wheel
			else 0.0
		)
		var steer_rotation := Basis(Vector3.UP, steer_angle)
		var spin_rotation := Basis(
			Vector3.FORWARD,
			-float(_wheel_spin[wheel])
		)
		var target := Transform3D(
			rest.basis * steer_rotation * spin_rotation,
			skeleton_inverse * center
		)
		_skeleton.set_bone_global_pose(bone_index, target)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null


func _find_safe_exit_position(player: CharacterBody3D) -> Vector3:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	for marker_path in exit_marker_paths:
		var marker := get_node_or_null(marker_path) as Marker3D
		if marker == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(
			Basis.IDENTITY,
			marker.global_position + Vector3.UP * 0.9
		)
		query.exclude = [player.get_rid()]
		query.collision_mask = player.collision_mask
		var hits := get_world_3d().direct_space_state.intersect_shape(query, 1)
		if hits.is_empty():
			return marker.global_position
	return Vector3.INF


func _recover_upright() -> void:
	var forward := global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	global_basis = Basis.looking_at(forward, Vector3.UP, true)
	global_position += Vector3.UP
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _update_camera_rig(delta: float) -> void:
	if definition == null or delta <= 0.0:
		return
	_camera_recenter_timer = maxf(_camera_recenter_timer - delta, 0.0)
	if _camera_recenter_timer <= 0.0:
		var recenter_weight := 1.0 - exp(
			-definition.camera_recenter_speed * delta
		)
		_camera_yaw_offset = lerp_angle(
			_camera_yaw_offset,
			0.0,
			recenter_weight
		)
	var forward_speed := linear_velocity.dot(global_basis.z)
	var raw_acceleration := clampf(
		(forward_speed - _previous_camera_forward_speed) / delta,
		-15.0,
		15.0
	)
	_previous_camera_forward_speed = forward_speed
	var acceleration_weight := 1.0 - exp(
		-definition.camera_acceleration_response * delta
	)
	_camera_longitudinal_acceleration = lerpf(
		_camera_longitudinal_acceleration,
		raw_acceleration,
		acceleration_weight
	)
	var speed_ratio := clampf(
		linear_velocity.length() / definition.max_forward_speed,
		0.0,
		1.0
	)
	var response_weight := 1.0 - exp(
		-definition.camera_response_speed * delta
	)
	var target_distance := (
		definition.camera_distance
		+ definition.camera_speed_distance_bonus * speed_ratio
		+ maxf(_camera_longitudinal_acceleration, 0.0)
		* definition.camera_acceleration_distance
		- maxf(-_camera_longitudinal_acceleration, 0.0)
		* definition.camera_braking_distance
	)
	target_distance = maxf(target_distance, 2.0)
	spring_arm.spring_length = lerpf(
		spring_arm.spring_length,
		target_distance,
		response_weight
	)
	vehicle_camera.fov = lerpf(
		vehicle_camera.fov,
		definition.camera_base_fov
		+ definition.camera_speed_fov_bonus * speed_ratio,
		response_weight
	)
	camera_pivot.position = camera_pivot.position.lerp(
		Vector3(0.0, definition.camera_height, 0.0),
		response_weight
	)
	var acceleration_pitch := clampf(
		_camera_longitudinal_acceleration
		* definition.camera_acceleration_pitch_degrees,
		-5.0,
		5.0
	)
	camera_pivot.rotation.x = lerp_angle(
		camera_pivot.rotation.x,
		_camera_pitch + deg_to_rad(acceleration_pitch),
		response_weight
	)
	var yaw_rate := angular_velocity.dot(global_basis.y.normalized())
	var turn_speed_scale := clampf(linear_velocity.length() / 8.0, 0.0, 1.0)
	var target_turn_lag := clampf(
		-yaw_rate
		* definition.camera_turn_lag_strength
		* turn_speed_scale,
		-deg_to_rad(definition.camera_max_turn_lag_degrees),
		deg_to_rad(definition.camera_max_turn_lag_degrees)
	)
	var turn_lag_weight := 1.0 - exp(
		-definition.camera_turn_lag_response * delta
	)
	_camera_turn_lag = lerp_angle(
		_camera_turn_lag,
		target_turn_lag,
		turn_lag_weight
	)
	var target_yaw := PI + _camera_yaw_offset + _camera_turn_lag
	camera_pivot.rotation.y = lerp_angle(
		camera_pivot.rotation.y,
		target_yaw,
		response_weight
	)
	camera_pivot.rotation.z = 0.0


func _snap_camera_rig() -> void:
	if definition == null:
		return
	_camera_turn_lag = 0.0
	_camera_longitudinal_acceleration = 0.0
	_previous_camera_forward_speed = linear_velocity.dot(global_basis.z)
	camera_pivot.position = Vector3(0.0, definition.camera_height, 0.0)
	camera_pivot.rotation = Vector3(
		_camera_pitch,
		PI + _camera_yaw_offset,
		0.0
	)
	spring_arm.spring_length = definition.camera_distance
	vehicle_camera.fov = definition.camera_base_fov


func _get_driver_component() -> Node:
	if _driver == null:
		return null
	return _driver.get_node_or_null(
		"Components/VehicleComponent"
	)


func _cache_wheel_anchors() -> void:
	for wheel in _get_wheels():
		_wheel_anchor_positions[wheel] = wheel.position


func _get_wheel_anchor_world(wheel: VehicleWheel3D) -> Vector3:
	var local_anchor: Vector3 = _wheel_anchor_positions.get(
		wheel,
		wheel.position
	)
	return global_transform * local_anchor


func _set_drive_force(force: float) -> void:
	# Per-wheel force is more consistent across the built-in and Jolt backends.
	engine_force = 0.0
	rear_left_wheel.engine_force = force * 0.5
	rear_right_wheel.engine_force = force * 0.5


func _set_brake_force(
	service_force: float,
	handbrake_force: float
) -> void:
	# Explicit wheel forces prevent the rear handbrake values from weakening
	# VehicleBody3D's shared service brake.
	brake = 0.0
	front_left_wheel.brake = service_force
	front_right_wheel.brake = service_force
	rear_left_wheel.brake = maxf(service_force, handbrake_force)
	rear_right_wheel.brake = maxf(service_force, handbrake_force)


func _update_rear_grip(
	delta: float,
	throttle: float,
	handbrake_amount: float,
	forward_speed: float
) -> void:
	var speed_factor := clampf(absf(forward_speed) / 14.0, 0.2, 1.0)
	var power_slip := clampf(
		throttle * definition.power_slide_strength * speed_factor,
		0.0,
		1.0
	)
	var handbrake_slip := clampf(handbrake_amount, 0.0, 1.0)
	var curved_power_slip := smoothstep(0.0, 1.0, power_slip)
	var curved_handbrake_slip := smoothstep(0.0, 1.0, handbrake_slip)
	var target_grip := lerpf(
		definition.rear_wheel_friction_slip,
		definition.power_slide_rear_friction_slip,
		curved_power_slip
	)
	target_grip = lerpf(
		target_grip,
		definition.handbrake_rear_friction_slip,
		curved_handbrake_slip
	)
	var response_speed := (
		definition.traction_loss_speed
		if target_grip < _rear_grip
		else definition.traction_recovery_speed
	)
	_rear_grip = move_toward(
		_rear_grip,
		target_grip,
		response_speed * delta
	)
	rear_left_wheel.wheel_friction_slip = _rear_grip
	rear_right_wheel.wheel_friction_slip = _rear_grip


func _reset_rear_grip() -> void:
	_handbrake_amount = 0.0
	_rear_grip = definition.rear_wheel_friction_slip
	rear_left_wheel.wheel_friction_slip = _rear_grip
	rear_right_wheel.wheel_friction_slip = _rear_grip


func _get_wheels() -> Array[VehicleWheel3D]:
	return [
		front_left_wheel,
		front_right_wheel,
		rear_left_wheel,
		rear_right_wheel,
	]


func _begin_entry_audio_sequence() -> void:
	_cancel_entry_audio_sequence()
	_audio_sequence_id += 1
	_play_entry_audio_sequence(_audio_sequence_id)


func _cancel_entry_audio_sequence() -> void:
	_audio_sequence_id += 1
	door_player.stop()
	start_player.stop()


func _play_entry_audio_sequence(sequence_id: int) -> void:
	engine_player.stop()
	engine_player.volume_db = _engine_target_volume_db
	_engine_ready = false
	if door_player.stream != null:
		door_player.volume_db = definition.entry_door_volume_db
		door_player.play()
	if definition.door_to_ignition_delay > 0.0:
		await get_tree().create_timer(
			definition.door_to_ignition_delay
		).timeout
	if not _is_audio_sequence_valid(sequence_id):
		return
	if start_player.stream == null:
		engine_player.play()
		_engine_ready = true
		return

	start_player.volume_db = _start_target_volume_db
	start_player.play()
	var wait_duration := maxf(
		start_player.stream.get_length()
		- definition.ignition_idle_overlap,
		0.0
	)
	if wait_duration > 0.0:
		await get_tree().create_timer(wait_duration).timeout
	if not _is_audio_sequence_valid(sequence_id):
		return

	engine_player.play()
	_engine_ready = true


func _is_audio_sequence_valid(sequence_id: int) -> bool:
	return sequence_id == _audio_sequence_id and _driver != null
