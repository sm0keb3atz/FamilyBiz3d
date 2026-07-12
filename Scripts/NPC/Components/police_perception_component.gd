class_name PolicePerceptionComponent
extends Node

const WANTED_VISION_CONE_SHADER := preload(
	"res://Assets/VFX/Shaders/police_vision_cone.gdshader"
)

static var debug_draw_enabled := false

@export_range(1.0, 100.0, 1.0) var witness_range := 14.0
@export_range(1.0, 150.0, 1.0) var combat_sight_range := 23.0
@export_range(1.0, 200.0, 1.0) var hearing_range := 28.0
@export_range(20.0, 180.0, 1.0) var field_of_view_degrees := 88.0
@export_flags_3d_physics var sight_collision_mask := 3
@export_category("Wanted Vision Cone")
@export var show_wanted_vision_cone := true
@export_range(12, 128, 1) var vision_cone_ray_count := 96
@export_range(0.03, 0.5, 0.01) var vision_cone_update_interval := 0.08
@export_range(0.01, 0.25, 0.01) var vision_cone_ground_offset := 0.06

var npc
var player: CharacterBody3D
var wanted: PlayerWantedComponent
var player_weapon: PlayerWeaponComponent
var _debug_mesh_instance: MeshInstance3D
var _wanted_cone_mesh_instance: MeshInstance3D
var _wanted_cone_material: ShaderMaterial
var _vision_cone_update_remaining := 0.0


func initialize(owner_npc: BaseNPC, target_player: CharacterBody3D) -> void:
	npc = owner_npc
	player = target_player
	wanted = player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	player_weapon = player.get_node(
		"Components/WeaponComponent"
	) as PlayerWeaponComponent
	_ensure_debug_mesh()
	_debug_mesh_instance.visible = debug_draw_enabled
	_ensure_wanted_vision_cone()
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
	var has_visual_contact := (
		wanted != null
		and wanted.wanted_level > 0
		and can_see_player()
	)
	if is_zero_approx(_vision_cone_update_remaining):
		_refresh_wanted_vision_cone(false, has_visual_contact)
		_vision_cone_update_remaining = vision_cone_update_interval
	if has_visual_contact:
		wanted.report_police_visual_contact(player.global_position)
	if player_weapon.get_equipped_weapon() == null:
		return
	if can_witness_position(player.global_position + Vector3.UP):
		wanted.report_visible_weapon_witness()


func can_see_player() -> bool:
	if player == null:
		return false
	return _has_sight(
		player.global_position + Vector3.UP,
		combat_sight_range,
		true
	)


func can_witness_position(world_position: Vector3) -> bool:
	return _has_sight(world_position, witness_range, true)


func can_hear_position(world_position: Vector3) -> bool:
	return (
		npc != null
		and not npc.is_defeated()
		and npc.global_position.distance_squared_to(world_position)
		<= hearing_range * hearing_range
	)


func set_debug_draw_visible(enabled: bool) -> void:
	debug_draw_enabled = enabled
	_ensure_debug_mesh()
	_debug_mesh_instance.visible = enabled


func _has_sight(
	world_position: Vector3,
	maximum_range: float,
	require_fov: bool
) -> bool:
	if npc == null or npc.is_defeated():
		return false
	var origin: Vector3 = npc.global_position + Vector3.UP * 1.35
	var offset := world_position - origin
	if offset.length_squared() > maximum_range * maximum_range:
		return false
	if require_fov:
		var forward: Vector3 = npc.visual.global_basis.z.normalized()
		var flat_offset := Vector3(offset.x, 0.0, offset.z).normalized()
		var minimum_dot := cos(deg_to_rad(field_of_view_degrees * 0.5))
		if forward.dot(flat_offset) < minimum_dot:
			return false
	var query := PhysicsRayQueryParameters3D.create(origin, world_position)
	query.collision_mask = sight_collision_mask
	query.exclude = [npc.get_rid()]
	var hit: Dictionary = (
		npc.get_world_3d().direct_space_state.intersect_ray(query)
	)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	return _is_player_node(collider)


func _is_player_node(node: Node) -> bool:
	var current := node
	while current != null:
		if current == player:
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
	var material := _make_debug_material(Color(1.0, 0.28, 0.12, 0.95))
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var half_angle := deg_to_rad(field_of_view_degrees * 0.5)
	var segments := 32
	var previous := Vector3.ZERO
	for index in segments + 1:
		var angle := lerpf(-half_angle, half_angle, float(index) / segments)
		var point := Vector3(sin(angle), 0.0, cos(angle)) * combat_sight_range
		if index > 0:
			mesh.surface_add_vertex(previous)
			mesh.surface_add_vertex(point)
		previous = point
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(
		Vector3(-sin(half_angle), 0.0, cos(half_angle))
		* combat_sight_range
	)
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(
		Vector3(sin(half_angle), 0.0, cos(half_angle))
		* combat_sight_range
	)
	mesh.surface_end()


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


func _refresh_wanted_vision_cone(
	force := false,
	focused_on_player := false
) -> void:
	_ensure_wanted_vision_cone()
	var should_show: bool = (
		show_wanted_vision_cone
		and wanted != null
		and wanted.wanted_level > 0
		and not npc.is_defeated()
	)
	_wanted_cone_mesh_instance.visible = should_show
	if not should_show:
		return
	if not force and not npc.visible:
		return
	_wanted_cone_material.set_shader_parameter(
		&"alert_level",
		clampf(float(wanted.wanted_level) / 3.0, 0.18, 1.0)
	)
	_wanted_cone_material.set_shader_parameter(
		&"focus_strength",
		1.0 if focused_on_player else 0.0
	)
	var origin: Vector3 = npc.global_position + Vector3.UP * 1.35
	var forward: Vector3 = npc.visual.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	var endpoints: Array[Vector3] = []
	for ray_index in vision_cone_ray_count + 1:
		var blend: float = float(ray_index) / float(
			vision_cone_ray_count
		)
		var angle: float = lerpf(
			-deg_to_rad(field_of_view_degrees * 0.5),
			deg_to_rad(field_of_view_degrees * 0.5),
			blend
		)
		var direction: Vector3 = forward.rotated(Vector3.UP, angle)
		endpoints.append(
			_get_clipped_cone_endpoint(origin, direction)
		)
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _wanted_cone_material)
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
		mesh.surface_set_uv(Vector2(0.5, 0.0))
		mesh.surface_add_vertex(center)
		mesh.surface_set_uv(Vector2(left_u, 1.0))
		mesh.surface_add_vertex(endpoints[segment_index])
		mesh.surface_set_uv(Vector2(right_u, 1.0))
		mesh.surface_add_vertex(endpoints[segment_index + 1])
	mesh.surface_end()
	_wanted_cone_mesh_instance.mesh = mesh


func _get_clipped_cone_endpoint(
	origin: Vector3,
	direction: Vector3
) -> Vector3:
	var destination := origin + direction * combat_sight_range
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = sight_collision_mask
	query.exclude = [npc.get_rid(), player.get_rid()]
	query.collide_with_areas = false
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
