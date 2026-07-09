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
@export_category("NPC Impacts")
@export_range(0.0, 20.0, 0.1) var minimum_fatal_npc_impact_speed := 2.0
@export_range(0.0, 1.0, 0.01) var npc_impact_momentum_retention := 0.96
@export_category("Skid Marks")
@export_range(0.0, 20.0, 0.1) var skid_mark_minimum_speed := 3.0
@export_range(0.0, 10.0, 0.1) var skid_mark_lateral_speed := 1.2
@export_range(0.05, 1.0, 0.01) var skid_mark_width := 0.22
@export_range(0.05, 1.5, 0.01) var skid_mark_length := 0.42
@export_range(1.0, 30.0, 0.5) var skid_mark_lifetime := 10.0
@export_range(0.0, 1.0, 0.01) var skid_mark_opacity := 0.62
@export_range(0.0, 1.0, 0.01) var tire_smoke_opacity := 0.22
@export_range(0.1, 3.0, 0.1) var tire_smoke_lifetime := 1.25

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
@onready var driver_marker := get_node(driver_marker_path) as Marker3D
@onready var tire_component := (
	$Components/TireComponent as VehicleTireComponent
)
@onready var camera_component := (
	$Components/CameraComponent as VehicleCameraComponent
)
@onready var wheel_visual_component := (
	$Components/WheelVisualComponent as VehicleWheelVisualComponent
)
@onready var impact_component := (
	$Components/ImpactComponent as VehicleImpactComponent
)
@onready var audio_component := (
	$Components/AudioComponent as VehicleAudioComponent
)
@onready var interaction_component := (
	$Components/InteractionComponent as VehicleInteractionComponent
)
@onready var effects_component := (
	$Components/EffectsComponent as VehicleEffectsComponent
)
@onready var powertrain_component := (
	$Components/PowertrainComponent as VehiclePowertrainComponent
)
@onready var stability_component := (
	$Components/StabilityComponent as VehicleStabilityComponent
)
@onready var drive_component := (
	$Components/DriveComponent as VehicleDriveComponent
)

var _driver: CharacterBody3D
var _managed_traffic_enabled := false
var _wheel_anchor_positions: Dictionary = {}
var _skid_mark_emitters: Dictionary = {}
var _tire_smoke_emitters: Dictionary = {}
var _tailpipe_idle_exhausts: Array[GPUParticles3D] = []
var _tailpipe_startup_exhausts: Array[GPUParticles3D] = []
var _soft_smoke_texture: GradientTexture2D
var _traffic_detail_enabled := true


func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	set_process_unhandled_input(false)
	if definition == null:
		push_error("%s requires a VehicleDefinition." % name)
		return
	tire_component.setup(self)
	camera_component.setup(self)
	wheel_visual_component.setup(self)
	impact_component.setup(self)
	audio_component.setup(self)
	interaction_component.setup(self)
	powertrain_component.setup(self)
	stability_component.setup(self)
	drive_component.setup(self)
	_cache_wheel_anchors()
	_apply_definition()
	_create_skid_mark_emitters()
	_create_tailpipe_exhaust()
	effects_component.setup(self)


func _on_body_entered(body: Node) -> void:
	impact_component.handle_body_entered(body)


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	impact_component.capture_velocity()
	drive_component.update(delta)
	stability_component.update()
	effects_component.update()
	audio_component.update(delta)
	wheel_visual_component.update(delta)


func _process(delta: float) -> void:
	if definition == null:
		return
	camera_component.update(delta)
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
			interaction_component.recover_upright()
			get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouseMotion
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	):
		camera_component.handle_mouse_motion(event)


func can_interact(player: CharacterBody3D) -> bool:
	if _managed_traffic_enabled:
		return false
	return interaction_component.can_interact(player)


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return interaction_component.get_prompt()


func interact(player: CharacterBody3D) -> void:
	if _managed_traffic_enabled or not can_interact(player):
		return
	var component: Variant = player.get_node_or_null(
		"Components/VehicleComponent"
	)
	if component != null:
		component.call("enter_vehicle", self)


func enter_driver(player: CharacterBody3D) -> bool:
	if _managed_traffic_enabled or _driver != null or not can_interact(player):
		return false
	_driver = player
	powertrain_component.reset()
	audio_component.engine_rpm = definition.idle_rpm
	tire_component.reset()
	drive_component.reset()
	audio_component.engine.pitch_scale = definition.idle_pitch
	sleeping = false
	camera_component.activate()
	set_process_unhandled_input(true)
	audio_component.begin_entry()
	driver_changed.emit(_driver)
	return true


func request_exit(player: CharacterBody3D) -> Vector3:
	if player != _driver:
		return Vector3.INF
	if linear_velocity.length() > maximum_exit_speed:
		exit_denied.emit("Slow down before exiting.")
		return Vector3.INF
	var exit_position := interaction_component.find_safe_exit(player)
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
	powertrain_component.reset()
	effects_component.set_exhaust_running(false)
	audio_component.shutdown()
	drive_component.stop()
	tire_component.reset()
	camera_component.deactivate()
	set_process_unhandled_input(false)
	driver_changed.emit(null)


func has_driver() -> bool:
	return _driver != null


func set_managed_traffic_enabled(enabled: bool) -> void:
	if _managed_traffic_enabled == enabled:
		return
	_managed_traffic_enabled = enabled
	if enabled:
		if _driver != null:
			clear_driver()
		add_to_group("traffic_vehicle")
		_traffic_detail_enabled = true
		audio_component.set_traffic_detail_enabled(true)
		effects_component.set_traffic_detail_enabled(true)
		drive_component.clear_ai_control()
		audio_component.engine_ready = true
		if audio_component.engine.stream != null and not audio_component.engine.playing:
			audio_component.engine.play()
		effects_component.set_exhaust_running(true)
	else:
		remove_from_group("traffic_vehicle")
		_traffic_detail_enabled = true
		audio_component.set_traffic_detail_enabled(true)
		effects_component.set_traffic_detail_enabled(true)
		drive_component.clear_ai_control()
		audio_component.engine_ready = false
		audio_component.engine.stop()
		audio_component.tires.stop()
		effects_component.set_exhaust_running(false)


func is_managed_traffic() -> bool:
	return _managed_traffic_enabled


func set_traffic_detail_enabled(enabled: bool) -> void:
	if _traffic_detail_enabled == enabled:
		return
	_traffic_detail_enabled = enabled
	audio_component.set_traffic_detail_enabled(enabled)
	effects_component.set_traffic_detail_enabled(enabled)


func is_traffic_detail_enabled() -> bool:
	return _traffic_detail_enabled


func get_driver() -> CharacterBody3D:
	return _driver


func get_vehicle_camera() -> Camera3D:
	return camera_component.camera


func get_current_gear() -> int:
	return powertrain_component.current_gear


func get_engine_rpm() -> float:
	return audio_component.engine_rpm


func has_valid_wheel_bones() -> bool:
	return wheel_visual_component.has_valid_bones()


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
	front_left_wheel.use_as_steering = true
	front_right_wheel.use_as_steering = true
	rear_left_wheel.use_as_traction = true
	rear_right_wheel.use_as_traction = true


func _create_skid_mark_emitters() -> void:
	for wheel in [rear_left_wheel, rear_right_wheel]:
		var particles := GPUParticles3D.new()
		particles.name = "%sSkidMarks" % wheel.name
		particles.amount = 300
		particles.lifetime = skid_mark_lifetime
		particles.local_coords = false
		particles.fixed_fps = 30
		particles.interp_to_end = 0.0
		particles.visibility_aabb = AABB(
			Vector3(-100.0, -10.0, -100.0),
			Vector3(200.0, 20.0, 200.0)
		)

		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
		gradient.colors = PackedColorArray([
			Color(0.025, 0.025, 0.022, skid_mark_opacity),
			Color(0.025, 0.025, 0.022, skid_mark_opacity * 0.9),
			Color(0.025, 0.025, 0.022, 0.0),
		])
		var color_ramp := GradientTexture1D.new()
		color_ramp.gradient = gradient

		var process_material := ParticleProcessMaterial.new()
		process_material.emission_shape = (
			ParticleProcessMaterial.EMISSION_SHAPE_POINT
		)
		process_material.gravity = Vector3.ZERO
		process_material.initial_velocity_min = 0.0
		process_material.initial_velocity_max = 0.0
		process_material.color_ramp = color_ramp
		particles.process_material = process_material

		var quad := QuadMesh.new()
		quad.orientation = PlaneMesh.FACE_Y
		quad.size = Vector2(skid_mark_width, skid_mark_length)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color.WHITE
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = material
		particles.draw_pass_1 = quad
		particles.emitting = false
		add_child(particles)
		_skid_mark_emitters[wheel] = particles
		_create_tire_smoke_emitter(wheel)


func _create_tire_smoke_emitter(wheel: VehicleWheel3D) -> void:
	var smoke := GPUParticles3D.new()
	smoke.name = "%sTireSmoke" % wheel.name
	smoke.amount = 65
	smoke.lifetime = tire_smoke_lifetime
	smoke.local_coords = false
	smoke.randomness = 0.78
	smoke.visibility_aabb = AABB(
		Vector3(-100.0, -10.0, -100.0),
		Vector3(200.0, 30.0, 200.0)
	)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.58, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.38, 0.38, 0.36, 0.0),
		Color(0.46, 0.46, 0.43, tire_smoke_opacity),
		Color(0.56, 0.56, 0.52, tire_smoke_opacity * 0.42),
		Color(0.65, 0.65, 0.62, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = (
		ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	)
	process_material.emission_sphere_radius = 0.08
	process_material.direction = Vector3.UP
	process_material.spread = 48.0
	process_material.initial_velocity_min = 0.45
	process_material.initial_velocity_max = 1.15
	process_material.gravity = Vector3(0.0, 0.18, 0.0)
	process_material.damping_min = 0.15
	process_material.damping_max = 0.4
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.angular_velocity_min = -150.0
	process_material.angular_velocity_max = 150.0
	process_material.scale_min = 0.28
	process_material.scale_max = 0.72
	var growth_curve := Curve.new()
	growth_curve.add_point(Vector2(0.0, 0.35))
	growth_curve.add_point(Vector2(0.32, 0.9))
	growth_curve.add_point(Vector2(0.72, 1.2))
	growth_curve.add_point(Vector2(1.0, 1.35))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = growth_curve
	process_material.scale_curve = scale_curve
	process_material.color_ramp = color_ramp
	smoke.process_material = process_material

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.58
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = _get_soft_smoke_texture()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	smoke.draw_pass_1 = quad
	smoke.emitting = false
	add_child(smoke)
	_tire_smoke_emitters[wheel] = smoke


func _get_soft_smoke_texture() -> GradientTexture2D:
	if _soft_smoke_texture != null:
		return _soft_smoke_texture
	var edge_gradient := Gradient.new()
	edge_gradient.offsets = PackedFloat32Array([0.0, 0.48, 0.78, 1.0])
	edge_gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 1.0, 1.0, 0.68),
		Color(1.0, 1.0, 1.0, 0.22),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_soft_smoke_texture = GradientTexture2D.new()
	_soft_smoke_texture.width = 64
	_soft_smoke_texture.height = 64
	_soft_smoke_texture.fill = GradientTexture2D.FILL_RADIAL
	_soft_smoke_texture.fill_from = Vector2(0.5, 0.5)
	_soft_smoke_texture.fill_to = Vector2(1.0, 0.5)
	_soft_smoke_texture.gradient = edge_gradient
	return _soft_smoke_texture


func _create_tailpipe_exhaust() -> void:
	for child in get_children():
		if (
			child is not Marker3D
			or not String(child.name).begins_with("TailpipeExhaust")
		):
			continue
		var marker := child as Marker3D
		var idle_exhaust := _build_tailpipe_particles(
			"IdleExhaust",
			46,
			1.35,
			0.13
		)
		var startup_exhaust := _build_tailpipe_particles(
			"StartupPuff",
			30,
			1.65,
			0.24
		)
		startup_exhaust.one_shot = true
		startup_exhaust.explosiveness = 0.88
		marker.add_child(idle_exhaust)
		marker.add_child(startup_exhaust)
		_tailpipe_idle_exhausts.append(idle_exhaust)
		_tailpipe_startup_exhausts.append(startup_exhaust)


func _build_tailpipe_particles(
	particle_name: String,
	particle_amount: int,
	particle_lifetime: float,
	peak_opacity: float
) -> GPUParticles3D:
	var exhaust := GPUParticles3D.new()
	exhaust.name = particle_name
	exhaust.amount = particle_amount
	exhaust.lifetime = particle_lifetime
	exhaust.local_coords = false
	exhaust.randomness = 0.8
	exhaust.visibility_aabb = AABB(
		Vector3(-30.0, -10.0, -30.0),
		Vector3(60.0, 30.0, 60.0)
	)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.3, 0.31, 0.32, 0.0),
		Color(0.38, 0.39, 0.4, peak_opacity),
		Color(0.52, 0.53, 0.54, peak_opacity * 0.35),
		Color(0.62, 0.63, 0.64, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient

	var growth_curve := Curve.new()
	growth_curve.add_point(Vector2(0.0, 0.28))
	growth_curve.add_point(Vector2(0.35, 0.72))
	growth_curve.add_point(Vector2(1.0, 1.35))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = growth_curve

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = (
		ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	)
	process_material.emission_sphere_radius = 0.035
	process_material.direction = Vector3.FORWARD
	process_material.spread = 18.0
	process_material.initial_velocity_min = 0.45
	process_material.initial_velocity_max = 1.05
	process_material.gravity = Vector3(0.0, 0.24, 0.0)
	process_material.damping_min = 0.1
	process_material.damping_max = 0.3
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.angular_velocity_min = -110.0
	process_material.angular_velocity_max = 110.0
	process_material.scale_min = 0.13
	process_material.scale_max = 0.3
	process_material.scale_curve = scale_curve
	process_material.color_ramp = color_ramp
	exhaust.process_material = process_material

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.34
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = _get_soft_smoke_texture()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	exhaust.draw_pass_1 = quad
	exhaust.emitting = false
	return exhaust


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


func _get_wheels() -> Array[VehicleWheel3D]:
	return [
		front_left_wheel,
		front_right_wheel,
		rear_left_wheel,
		rear_right_wheel,
	]
