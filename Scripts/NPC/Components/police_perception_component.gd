class_name PolicePerceptionComponent
extends Node

const WANTED_VISION_CONE_SHADER := preload(
	"res://Assets/VFX/Shaders/police_vision_cone.gdshader"
)

static var debug_draw_enabled := false

@export_range(1.0, 100.0, 1.0) var witness_range := 14.0
@export_range(1.0, 150.0, 1.0) var combat_sight_range := 35.0
@export_range(1.0, 250.0, 1.0) var hearing_range := 150.0
@export_range(20.0, 180.0, 1.0) var field_of_view_degrees := 100.0
@export_range(1.0, 10.0, 0.5) var near_awareness_range := 3.5
@export_range(1.0, 40.0, 0.5) var peripheral_range := 12.0
@export_range(90.0, 180.0, 1.0) var peripheral_fov_degrees := 150.0
@export_flags_3d_physics var sight_collision_mask := 3
@export_range(0.05, 0.5, 0.01) var perception_update_interval := 0.1
@export_category("Wanted Vision Cone")
@export var show_wanted_vision_cone := false
@export_range(8, 64, 1) var vision_cone_ray_count := 16
@export_range(0.1, 1.0, 0.01) var vision_cone_update_interval := 0.25
@export_range(0.01, 0.25, 0.01) var vision_cone_ground_offset := 0.06
@export_range(10.0, 100.0, 1.0) var vision_cone_render_distance := 45.0

var npc: BaseNPC
var player: CharacterBody3D
var wanted: PlayerWantedComponent
var player_weapon: PlayerWeaponComponent
var player_vehicle: PlayerVehicleComponent
var coordinator: Node
var _debug_mesh_instance: MeshInstance3D
var _wanted_cone_mesh_instance: MeshInstance3D
var _wanted_cone_material: ShaderMaterial
var _wanted_cone_mesh: ImmediateMesh
var _vision_cone_update_remaining := 0.0
var _perception_update_remaining := 0.0
var _cached_can_see_player := false
var _raycast_count := 0


func initialize(owner_npc: BaseNPC, target_player: CharacterBody3D) -> void:
	npc = owner_npc
	player = target_player
	wanted = player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	player_weapon = player.get_node(
		"Components/WeaponComponent"
	) as PlayerWeaponComponent
	player_vehicle = player.get_node_or_null("Components/VehicleComponent") as PlayerVehicleComponent
	coordinator = player.get_tree().get_first_node_in_group(&"police_coordinator")
	_ensure_debug_mesh()
	_debug_mesh_instance.visible = debug_draw_enabled
	_ensure_wanted_vision_cone()
	_cached_can_see_player = _sample_can_see_player()
	var stagger: float = float(owner_npc.get_instance_id() % 10) / 10.0
	_perception_update_remaining = perception_update_interval * stagger
	_vision_cone_update_remaining = vision_cone_update_interval * stagger
	_refresh_wanted_vision_cone(true)


func _process(delta: float) -> void:
	if (
		npc == null
		or player == null
		or npc.is_defeated()
	):
		if _wanted_cone_mesh_instance != null:
			_wanted_cone_mesh_instance.visible = false
		return
	_vision_cone_update_remaining = maxf(
		_vision_cone_update_remaining - delta,
		0.0
	)
	_perception_update_remaining = maxf(
		_perception_update_remaining - delta,
		0.0
	)
	var sampled: bool = false
	if is_zero_approx(_perception_update_remaining):
		var needs_player_sight: bool = (
			wanted != null
			and wanted.wanted_level > 0
		) or (
			player_weapon != null
			and player_weapon.get_equipped_weapon() != null
		)
		_cached_can_see_player = (
			_sample_can_see_player()
			if needs_player_sight
			else false
		)
		_perception_update_remaining = perception_update_interval
		sampled = true
	var has_visual_contact: bool = (
		wanted != null
		and wanted.wanted_level > 0
		and _cached_can_see_player
	)
	var should_render_cone: bool = _should_render_wanted_cone()
	if not should_render_cone and _wanted_cone_mesh_instance != null:
		_wanted_cone_mesh_instance.visible = false
	elif is_zero_approx(_vision_cone_update_remaining):
		_refresh_wanted_vision_cone(false, has_visual_contact)
		_vision_cone_update_remaining = vision_cone_update_interval
	if has_visual_contact:
		if coordinator != null:
			coordinator.report_visual_contact(npc, player.global_position)
		else:
			wanted.report_police_visual_contact(player.global_position)
	if (
		not sampled
		or player_weapon == null
		or player_weapon.get_equipped_weapon() == null
	):
		return
	if can_witness_position(player.global_position + Vector3.UP):
		wanted.report_visible_weapon_witness()


func can_see_player() -> bool:
	return _cached_can_see_player


func _sample_can_see_player() -> bool:
	if player == null:
		return false
	var position := player_vehicle.get_effective_position() if player_vehicle != null else player.global_position
	var distance: float = npc.global_position.distance_to(position)
	var targets: Array[Vector3] = [
		position + Vector3.UP * 0.9,
		position + Vector3.UP * 1.55,
	]
	for target: Vector3 in targets:
		if distance <= near_awareness_range and _has_sight(
			target, near_awareness_range, false
		):
			return true
		if distance <= peripheral_range and _has_sight(
			target, peripheral_range, true, peripheral_fov_degrees
		):
			return true
		if _has_sight(target, combat_sight_range, true, field_of_view_degrees):
			return true
	return false


func get_raycast_count() -> int:
	return _raycast_count


func can_witness_position(world_position: Vector3) -> bool:
	return _has_sight(world_position, witness_range, true, field_of_view_degrees)


func can_hear_position(world_position: Vector3) -> bool:
	return get_hearing_confidence(world_position) >= 0.12


func get_hearing_confidence(world_position: Vector3) -> float:
	if npc == null or npc.is_defeated():
		return 0.0
	var origin: Vector3 = npc.global_position + Vector3.UP * 1.35
	var distance: float = origin.distance_to(world_position)
	if distance > hearing_range:
		return 0.0
	var confidence: float = clampf(1.0 - distance / maxf(hearing_range, 0.01), 0.1, 1.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, world_position)
	query.collision_mask = sight_collision_mask
	query.exclude = [npc.get_rid()]
	var hit: Dictionary = npc.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		# Walls and large obstacles reduce useful range and certainty, but do not
		# turn a nearby firearm into a completely silent event.
		confidence *= 0.55
	return confidence


func has_unobstructed_line_to(
	world_position: Vector3,
	maximum_range: float
) -> bool:
	# Pursuit uses this without an FOV requirement. An officer who already knows
	# where the suspect is should not turn away merely because the sidewalk
	# navigation route starts in the opposite direction.
	return _has_sight(world_position, maximum_range, false)


func set_debug_draw_visible(enabled: bool) -> void:
	debug_draw_enabled = enabled
	_ensure_debug_mesh()
	_debug_mesh_instance.visible = enabled
	show_wanted_vision_cone = enabled
	_refresh_wanted_vision_cone(true)


func _has_sight(
	world_position: Vector3,
	maximum_range: float,
	require_fov: bool,
	fov_degrees: float = -1.0
) -> bool:
	if npc == null or npc.is_defeated():
		return false
	var origin: Vector3 = npc.global_position + Vector3.UP * 1.35
	var offset: Vector3 = world_position - origin
	if offset.length_squared() > maximum_range * maximum_range:
		return false
	if require_fov:
		var forward: Vector3 = npc.visual.global_basis.z.normalized()
		var flat_offset: Vector3 = Vector3(offset.x, 0.0, offset.z).normalized()
		var effective_fov: float = field_of_view_degrees if fov_degrees < 0.0 else fov_degrees
		var minimum_dot: float = cos(deg_to_rad(effective_fov * 0.5))
		if forward.dot(flat_offset) < minimum_dot:
			return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, world_position)
	query.collision_mask = sight_collision_mask
	query.exclude = [npc.get_rid()]
	_raycast_count += 1
	var hit: Dictionary = (
		npc.get_world_3d().direct_space_state.intersect_ray(query)
	)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	return _is_player_node(collider)


func _is_player_node(node: Node) -> bool:
	var vehicle: Node3D = player_vehicle.get_current_vehicle() if player_vehicle != null else null
	var current: Node = node
	while current != null:
		if current == player or (vehicle != null and current == vehicle):
			return true
		current = current.get_parent()
	return false


func _ensure_debug_mesh() -> void:
	if _debug_mesh_instance != null:
		return
	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.name = "PoliceDetectionDebug"
	_debug_mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	npc.visual.add_child(_debug_mesh_instance)
	_debug_mesh_instance.position.y = 0.08
	var mesh := ImmediateMesh.new()
	_add_sight_cone(mesh)
	_add_radius_circle(
		mesh,
		witness_range,
		Color(0.2, 0.85, 1.0, 0.9)
	)
	_add_radius_circle(
		mesh,
		hearing_range,
		Color(0.25, 0.45, 1.0, 0.72)
	)
	_debug_mesh_instance.mesh = mesh


func _add_sight_cone(mesh: ImmediateMesh) -> void:
	_add_radius_circle(
		mesh,
		combat_sight_range,
		Color(1.0, 0.28, 0.12, 0.95)
	)


func _add_radius_circle(
	mesh: ImmediateMesh,
	radius: float,
	color: Color
) -> void:
	var material := _make_debug_material(color)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var segments := 64
	for index in segments:
		var angle_a := TAU * float(index) / segments
		var angle_b := TAU * float(index + 1) / segments
		mesh.surface_add_vertex(
			Vector3(sin(angle_a), 0.0, cos(angle_a)) * radius
		)
		mesh.surface_add_vertex(
			Vector3(sin(angle_b), 0.0, cos(angle_b)) * radius
		)
	mesh.surface_end()


func _make_debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	return material


func _ensure_wanted_vision_cone() -> void:
	if _wanted_cone_mesh_instance != null:
		return
	_wanted_cone_material = ShaderMaterial.new()
	_wanted_cone_material.shader = WANTED_VISION_CONE_SHADER
	_wanted_cone_mesh_instance = MeshInstance3D.new()
	_wanted_cone_mesh_instance.name = "WantedVisionCone"
	_wanted_cone_mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	_wanted_cone_mesh_instance.extra_cull_margin = combat_sight_range
	npc.add_child(_wanted_cone_mesh_instance)
	_wanted_cone_mesh = ImmediateMesh.new()
	_wanted_cone_mesh_instance.mesh = _wanted_cone_mesh


func _should_render_wanted_cone() -> bool:
	if (
		not debug_draw_enabled
		or not show_wanted_vision_cone
		or wanted == null
		or wanted.wanted_level <= 0
		or player == null
	):
		return false
	if npc.global_position.distance_squared_to(player.global_position) > (
		vision_cone_render_distance * vision_cone_render_distance
	):
		return false
	var camera: Camera3D = npc.get_viewport().get_camera_3d()
	return (
		camera == null
		or camera.is_position_in_frustum(npc.global_position + Vector3.UP)
	)


func _refresh_wanted_vision_cone(
	force := false,
	focused_on_player := false
) -> void:
	_ensure_wanted_vision_cone()
	var should_show: bool = (
		debug_draw_enabled
		and show_wanted_vision_cone
		and wanted != null
		and wanted.wanted_level > 0
		and not npc.is_defeated()
	)
	_wanted_cone_mesh_instance.visible = should_show
	if not should_show:
		return
	if not force and not _should_render_wanted_cone():
		return
	_wanted_cone_material.set_shader_parameter(
		&"alert_level",
		clampf(float(wanted.wanted_level) / 6.0, 0.18, 1.0)
	)
	_wanted_cone_material.set_shader_parameter(
		&"focus_strength",
		1.0 if focused_on_player else 0.0
	)
	var origin: Vector3 = npc.global_position + Vector3.UP * 1.35
	var endpoints: Array[Vector3] = []
	var forward: Vector3 = npc.visual.global_basis.z.normalized()
	var start_angle: float = -deg_to_rad(field_of_view_degrees * 0.5)
	var angle_step: float = deg_to_rad(field_of_view_degrees) / float(vision_cone_ray_count)
	for ray_index in vision_cone_ray_count + 1:
		var angle: float = start_angle + angle_step * float(ray_index)
		var direction: Vector3 = forward.rotated(Vector3.UP, angle)
		endpoints.append(
			_get_clipped_cone_endpoint(origin, direction)
		)
	_wanted_cone_mesh.clear_surfaces()
	_wanted_cone_mesh.surface_begin(
		Mesh.PRIMITIVE_TRIANGLES,
		_wanted_cone_material
	)
	var center: Vector3 = Vector3(
		0.0,
		vision_cone_ground_offset,
		0.0
	)
	for segment_index in vision_cone_ray_count:
		var left_u: float = float(segment_index) / float(
			vision_cone_ray_count
		)
		var right_u: float = float(segment_index + 1) / float(
			vision_cone_ray_count
		)
		_wanted_cone_mesh.surface_set_uv(Vector2(0.5, 0.0))
		_wanted_cone_mesh.surface_add_vertex(center)
		_wanted_cone_mesh.surface_set_uv(Vector2(left_u, 1.0))
		_wanted_cone_mesh.surface_add_vertex(endpoints[segment_index])
		_wanted_cone_mesh.surface_set_uv(Vector2(right_u, 1.0))
		_wanted_cone_mesh.surface_add_vertex(endpoints[segment_index + 1])
	_wanted_cone_mesh.surface_end()


func _get_clipped_cone_endpoint(
	origin: Vector3,
	direction: Vector3
) -> Vector3:
	var destination: Vector3 = origin + direction * combat_sight_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = sight_collision_mask
	query.exclude = [npc.get_rid(), player.get_rid()]
	query.collide_with_areas = false
	_raycast_count += 1
	var hit: Dictionary = (
		npc.get_world_3d().direct_space_state.intersect_ray(query)
	)
	var distance: float = combat_sight_range
	if not hit.is_empty():
		var hit_position := hit.get("position", destination) as Vector3
		distance = origin.distance_to(hit_position)
	var endpoint_world: Vector3 = (
		npc.global_position
		+ direction * maxf(distance - 0.08, 0.0)
		+ Vector3.UP * vision_cone_ground_offset
	)
	return npc.to_local(endpoint_world)
