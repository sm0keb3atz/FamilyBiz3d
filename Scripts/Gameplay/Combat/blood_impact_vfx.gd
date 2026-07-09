class_name BloodImpactVFX
extends Node3D

enum SurfaceImpactKind {
	STONE,
	METAL,
}

const BLOOD_SPRAY_TEXTURE := preload(
	"res://Assets/VFX/Blood/BloodSplat5.png"
)
const BLOOD_POOL_TEXTURE := preload(
	"res://Assets/VFX/Blood/BloodSplat1.png"
)
const BLOOD_WOUND_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/VFX/Blood/BloodSplat2.png"),
	preload("res://Assets/VFX/Blood/BloodSplat3.png"),
	preload("res://Assets/VFX/Blood/BloodSplat4.png"),
]
const BULLET_HOLE_TEXTURE := preload(
	"res://Assets/VFX/Blood/Bullethole.png"
)
const BULLET_HOLE_SHADER := preload(
	"res://Assets/VFX/Blood/bullet_hole.gdshader"
)
const BLOOD_MARK_SHADER := preload(
	"res://Assets/VFX/Blood/blood_mark.gdshader"
)
const BLOOD_SPRAY_SHADER := preload(
	"res://Assets/VFX/Blood/blood_spray.gdshader"
)

@export_range(1, 64, 1) var spray_particle_count := 22
@export_range(0.1, 5.0, 0.05) var spray_lifetime := 0.78
@export_range(0.1, 15.0, 0.1) var visual_spray_speed := 5.8
@export_range(0.1, 10.0, 0.1) var spray_speed := 4.0
@export_range(0.05, 3.0, 0.01) var wound_size := 0.12
@export_range(0.1, 4.0, 0.05) var pool_size := 1.15
@export_range(0.1, 5.0, 0.05) var pool_growth_time := 1.2
@export_range(1.0, 120.0, 1.0) var effect_lifetime := 45.0

var _pool: MeshInstance3D
var _pool_target_scale := Vector3.ONE
var _pool_growth_elapsed := 0.0
var _life_elapsed := 0.0
var _persistent_marks: Array[Node3D] = []
var _temporary_hosts: Array[Node3D] = []
var _pending_landing_splats: Array[Dictionary] = []
var _death_pool_target: Node3D
var _death_pool_due_time := -1.0

static var _shared_spray_process_material: ParticleProcessMaterial
static var _shared_spray_mesh: QuadMesh
static var _shared_bullet_hole_material: ShaderMaterial
static var _shared_spark_mesh: BoxMesh
static var _shared_debris_mesh: BoxMesh
static var _shared_smoke_mesh: QuadMesh
static var _shared_soft_smoke_texture: GradientTexture2D


static func prewarm_resources() -> void:
	if _shared_bullet_hole_material == null:
		_shared_bullet_hole_material = ShaderMaterial.new()
		_shared_bullet_hole_material.shader = BULLET_HOLE_SHADER
		_shared_bullet_hole_material.set_shader_parameter(
			"mark_texture",
			BULLET_HOLE_TEXTURE
		)
	if _shared_spray_process_material == null:
		_shared_spray_process_material = ParticleProcessMaterial.new()
		_shared_spray_process_material.direction = Vector3.FORWARD
		_shared_spray_process_material.spread = 17.0
		_shared_spray_process_material.initial_velocity_min = 4.3
		_shared_spray_process_material.initial_velocity_max = 7.2
		_shared_spray_process_material.gravity = Vector3(0.0, -5.7, 0.0)
		_shared_spray_process_material.scale_min = 0.025
		_shared_spray_process_material.scale_max = 0.075
		_shared_spray_process_material.damping_min = 0.1
		_shared_spray_process_material.damping_max = 0.55
	if _shared_spray_mesh == null:
		_shared_spray_mesh = QuadMesh.new()
		_shared_spray_mesh.size = Vector2(0.38, 0.18)
		_shared_spray_mesh.orientation = PlaneMesh.FACE_Z
		var spray_material := ShaderMaterial.new()
		spray_material.shader = BLOOD_SPRAY_SHADER
		spray_material.set_shader_parameter(
			"blood_texture",
			BLOOD_SPRAY_TEXTURE
		)
		spray_material.set_shader_parameter(
			"blood_tint",
			Color(0.38, 0.003, 0.006, 0.92)
		)
		_shared_spray_mesh.material = spray_material
	if _shared_spark_mesh == null:
		_shared_spark_mesh = BoxMesh.new()
		_shared_spark_mesh.size = Vector3(0.007, 0.007, 0.075)
		var spark_material := StandardMaterial3D.new()
		spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_material.albedo_color = Color(1.0, 0.76, 0.22, 0.95)
		spark_material.emission_enabled = true
		spark_material.emission = Color(1.0, 0.48, 0.06)
		spark_material.emission_energy_multiplier = 2.6
		spark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shared_spark_mesh.material = spark_material
	if _shared_debris_mesh == null:
		_shared_debris_mesh = BoxMesh.new()
		_shared_debris_mesh.size = Vector3(0.025, 0.025, 0.025)
		var debris_material := StandardMaterial3D.new()
		debris_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		debris_material.albedo_color = Color(0.12, 0.1, 0.085, 1.0)
		_shared_debris_mesh.material = debris_material
	if _shared_smoke_mesh == null:
		_shared_smoke_mesh = QuadMesh.new()
		_shared_smoke_mesh.size = Vector2.ONE * 0.48
		var smoke_material := StandardMaterial3D.new()
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke_material.vertex_color_use_as_albedo = true
		smoke_material.albedo_color = Color.WHITE
		smoke_material.albedo_texture = _get_soft_smoke_texture()
		smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		smoke_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shared_smoke_mesh.material = smoke_material


func prewarm_runtime() -> void:
	prewarm_resources()

	var particles := GPUParticles3D.new()
	particles.amount = 1
	particles.lifetime = 0.12
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.visibility_aabb = AABB(
		Vector3(-1.0, -1.0, -1.0),
		Vector3(2.0, 2.0, 2.0)
	)
	particles.process_material = _shared_spray_process_material
	particles.draw_pass_1 = _shared_spray_mesh
	add_child(particles)
	particles.restart()

	var bullet_quad := QuadMesh.new()
	bullet_quad.size = Vector2.ONE * 0.02
	bullet_quad.material = _shared_bullet_hole_material
	var bullet_mark := MeshInstance3D.new()
	bullet_mark.mesh = bullet_quad
	add_child(bullet_mark)

	var blood_material := ShaderMaterial.new()
	blood_material.shader = BLOOD_MARK_SHADER
	blood_material.set_shader_parameter(
		"blood_texture",
		BLOOD_WOUND_TEXTURES[0]
	)
	blood_material.set_shader_parameter(
		"blood_tint",
		Color(0.3, 0.003, 0.006, 0.9)
	)
	var blood_quad := QuadMesh.new()
	blood_quad.size = Vector2.ONE * 0.02
	blood_quad.material = blood_material
	var blood_mark := MeshInstance3D.new()
	blood_mark.mesh = blood_quad
	blood_mark.position.x = 0.025
	add_child(blood_mark)


func setup_blood_hit(
	hit_position: Vector3,
	hit_normal: Vector3,
	shot_direction: Vector3,
	hit_collider: Node3D,
	fatal_hit: bool
) -> void:
	global_position = hit_position
	_create_spray(shot_direction)
	_trace_landing_splats(hit_position, shot_direction, hit_collider)
	_create_wound_mark(hit_position, hit_normal, hit_collider)
	if fatal_hit:
		_death_pool_target = _find_vfx_owner(hit_collider)
		_death_pool_due_time = 1.0


func setup_surface_hit(
	hit_position: Vector3,
	hit_normal: Vector3,
	hit_collider: Node3D,
	impact_kind := SurfaceImpactKind.STONE
) -> void:
	global_position = hit_position
	_create_bullet_hole(hit_position, hit_normal, hit_collider, 0.13)
	if impact_kind == SurfaceImpactKind.METAL:
		_create_metal_sparks(hit_normal)
		_create_metal_debris(hit_normal)
		_create_metal_flash(hit_position, hit_normal)
	else:
		_create_smoke_puff(hit_normal)


func clear_marks_attached_to(owner: Node3D) -> void:
	if owner == null:
		return
	for index in range(_persistent_marks.size() - 1, -1, -1):
		var mark := _persistent_marks[index]
		if not is_instance_valid(mark):
			_persistent_marks.remove_at(index)
			continue
		if mark == owner or owner.is_ancestor_of(mark):
			mark.queue_free()
			_persistent_marks.remove_at(index)
	for index in range(_temporary_hosts.size() - 1, -1, -1):
		var host := _temporary_hosts[index]
		if not is_instance_valid(host):
			_temporary_hosts.remove_at(index)
			continue
		if host == owner or owner.is_ancestor_of(host):
			host.queue_free()
			_temporary_hosts.remove_at(index)


func _process(delta: float) -> void:
	_life_elapsed += delta
	_update_landing_splats()
	_update_death_pool()
	if _pool != null and _pool_growth_elapsed < pool_growth_time:
		_pool_growth_elapsed = minf(
			_pool_growth_elapsed + delta,
			pool_growth_time
		)
		var progress := _pool_growth_elapsed / pool_growth_time
		var eased_progress := 1.0 - pow(1.0 - progress, 3.0)
		_pool.scale = _pool_target_scale * lerpf(0.12, 1.0, eased_progress)
	if _life_elapsed >= effect_lifetime:
		for mark in _persistent_marks:
			if is_instance_valid(mark):
				mark.queue_free()
		for host in _temporary_hosts:
			if is_instance_valid(host):
				host.queue_free()
		queue_free()


func _update_landing_splats() -> void:
	for index in range(_pending_landing_splats.size() - 1, -1, -1):
		var landing := _pending_landing_splats[index]
		if _life_elapsed < landing.time as float:
			continue
		var splat := _create_textured_mark(
			BLOOD_WOUND_TEXTURES.pick_random(),
			landing.position as Vector3,
			landing.normal as Vector3,
			landing.size as float,
			Color(0.3, 0.003, 0.006, 0.9)
		)
		splat.name = "BloodDropletSplat"
		_attach_mark(splat, landing.collider as Node3D)
		_pending_landing_splats.remove_at(index)


func _update_death_pool() -> void:
	if (
		_death_pool_due_time < 0.0
		or _life_elapsed < _death_pool_due_time
	):
		return
	_death_pool_due_time = -1.0
	if not is_instance_valid(_death_pool_target):
		return
	var pool_origin := _death_pool_target.global_position
	if _death_pool_target.has_method("get_vfx_pool_origin"):
		pool_origin = _death_pool_target.call(
			"get_vfx_pool_origin"
		) as Vector3
	_create_floor_pool(pool_origin, _death_pool_target)


func _create_spray(shot_direction: Vector3) -> void:
	prewarm_resources()
	var particles := GPUParticles3D.new()
	particles.name = "BloodSpray"
	particles.amount = spray_particle_count
	particles.lifetime = spray_lifetime
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.randomness = 0.45
	particles.visibility_aabb = AABB(
		Vector3(-7.0, -5.0, -7.0),
		Vector3(14.0, 10.0, 14.0)
	)

	var spray_direction := shot_direction.normalized()
	if spray_direction.is_zero_approx():
		spray_direction = Vector3.FORWARD
	var process_material := (
		_shared_spray_process_material.duplicate() as ParticleProcessMaterial
	)
	process_material.direction = spray_direction
	process_material.initial_velocity_min = visual_spray_speed * 0.75
	process_material.initial_velocity_max = visual_spray_speed * 1.25
	particles.process_material = process_material
	particles.draw_pass_1 = _shared_spray_mesh
	add_child(particles)
	particles.restart()


func _create_metal_sparks(hit_normal: Vector3) -> void:
	prewarm_resources()
	var normal := hit_normal.normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	var particles := GPUParticles3D.new()
	particles.name = "MetalSparks"
	particles.amount = 34
	particles.lifetime = 0.24
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.52
	particles.visibility_aabb = AABB(
		Vector3(-3.0, -3.0, -3.0),
		Vector3(6.0, 6.0, 6.0)
	)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = (
		ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	)
	process_material.emission_sphere_radius = 0.025
	process_material.direction = (normal + Vector3.UP * 0.18).normalized()
	process_material.spread = 44.0
	process_material.initial_velocity_min = 2.8
	process_material.initial_velocity_max = 5.6
	process_material.gravity = Vector3(0.0, -7.8, 0.0)
	process_material.scale_min = 0.45
	process_material.scale_max = 0.95
	process_material.damping_min = 0.6
	process_material.damping_max = 1.9
	particles.process_material = process_material
	particles.draw_pass_1 = _shared_spark_mesh
	add_child(particles)
	particles.restart()


func _create_metal_debris(hit_normal: Vector3) -> void:
	prewarm_resources()
	var normal := hit_normal.normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	var particles := GPUParticles3D.new()
	particles.name = "MetalImpactFlecks"
	particles.amount = 10
	particles.lifetime = 0.46
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.72
	particles.visibility_aabb = AABB(
		Vector3(-2.0, -2.0, -2.0),
		Vector3(4.0, 4.0, 4.0)
	)
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = normal
	process_material.spread = 50.0
	process_material.initial_velocity_min = 0.9
	process_material.initial_velocity_max = 2.4
	process_material.gravity = Vector3(0.0, -5.5, 0.0)
	process_material.scale_min = 0.5
	process_material.scale_max = 1.1
	process_material.damping_min = 0.35
	process_material.damping_max = 1.1
	particles.process_material = process_material
	particles.draw_pass_1 = _shared_debris_mesh
	add_child(particles)
	particles.restart()


func _create_metal_flash(hit_position: Vector3, hit_normal: Vector3) -> void:
	var flash := MeshInstance3D.new()
	flash.name = "MetalImpactFlash"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * randf_range(0.055, 0.09)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.7, 0.16, 0.38)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.05)
	material.emission_energy_multiplier = 1.15
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	flash.mesh = quad
	_place_mark(flash, hit_position, hit_normal, 0.01)
	var world_transform := flash.transform
	add_child(flash)
	flash.global_transform = world_transform
	get_tree().create_timer(0.06).timeout.connect(
		func() -> void:
			if is_instance_valid(flash):
				flash.queue_free()
	)


func _create_smoke_puff(hit_normal: Vector3) -> void:
	prewarm_resources()
	var normal := hit_normal.normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	var particles := GPUParticles3D.new()
	particles.name = "SurfaceSmokePuff"
	particles.amount = 18
	particles.lifetime = 0.82
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.randomness = 0.78
	particles.visibility_aabb = AABB(
		Vector3(-3.0, -3.0, -3.0),
		Vector3(6.0, 6.0, 6.0)
	)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.58, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.33, 0.32, 0.29, 0.0),
		Color(0.48, 0.46, 0.4, 0.26),
		Color(0.62, 0.6, 0.54, 0.11),
		Color(0.72, 0.7, 0.64, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient

	var growth_curve := Curve.new()
	growth_curve.add_point(Vector2(0.0, 0.28))
	growth_curve.add_point(Vector2(0.28, 0.85))
	growth_curve.add_point(Vector2(0.72, 1.18))
	growth_curve.add_point(Vector2(1.0, 1.42))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = growth_curve

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = (
		ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	)
	process_material.emission_sphere_radius = 0.045
	process_material.direction = (normal + Vector3.UP * 0.45).normalized()
	process_material.spread = 54.0
	process_material.initial_velocity_min = 0.42
	process_material.initial_velocity_max = 1.25
	process_material.gravity = Vector3(0.0, 0.2, 0.0)
	process_material.damping_min = 0.35
	process_material.damping_max = 0.85
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.angular_velocity_min = -120.0
	process_material.angular_velocity_max = 120.0
	process_material.scale_min = 0.28
	process_material.scale_max = 0.62
	process_material.scale_curve = scale_curve
	process_material.color_ramp = color_ramp
	particles.process_material = process_material
	particles.draw_pass_1 = _shared_smoke_mesh
	add_child(particles)
	particles.restart()


static func _get_soft_smoke_texture() -> GradientTexture2D:
	if _shared_soft_smoke_texture != null:
		return _shared_soft_smoke_texture
	var edge_gradient := Gradient.new()
	edge_gradient.offsets = PackedFloat32Array([0.0, 0.48, 0.78, 1.0])
	edge_gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 1.0, 1.0, 0.68),
		Color(1.0, 1.0, 1.0, 0.22),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_shared_soft_smoke_texture = GradientTexture2D.new()
	_shared_soft_smoke_texture.width = 64
	_shared_soft_smoke_texture.height = 64
	_shared_soft_smoke_texture.fill = GradientTexture2D.FILL_RADIAL
	_shared_soft_smoke_texture.fill_from = Vector2(0.5, 0.5)
	_shared_soft_smoke_texture.fill_to = Vector2(1.0, 0.5)
	_shared_soft_smoke_texture.gradient = edge_gradient
	return _shared_soft_smoke_texture


func _trace_landing_splats(
	hit_position: Vector3,
	shot_direction: Vector3,
	hit_collider: Node3D
) -> void:
	var forward := shot_direction.normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	var exclusion: Array[RID] = []
	if hit_collider is CollisionObject3D:
		exclusion.append((hit_collider as CollisionObject3D).get_rid())

	for droplet_index in 14:
		var velocity := (
			forward * randf_range(spray_speed * 0.5, spray_speed * 1.0)
			+ Vector3(
				randf_range(-0.65, 0.65),
				randf_range(-0.15, 0.8),
				randf_range(-0.65, 0.65)
			)
		)
		var previous_position := hit_position + forward * 0.08
		var flight_time := 0.0
		for step_index in 20:
			var step_duration := 0.075
			flight_time += step_duration
			var next_position := (
				previous_position
				+ velocity * step_duration
				+ Vector3.DOWN * 3.5 * step_duration * step_duration
			)
			velocity += Vector3.DOWN * 8.5 * step_duration
			var query := PhysicsRayQueryParameters3D.create(
				previous_position,
				next_position
			)
			query.exclude = exclusion
			var landing := (
				get_world_3d().direct_space_state.intersect_ray(query)
			)
			if not landing.is_empty():
				_pending_landing_splats.append({
					"time": _life_elapsed + flight_time,
					"position": landing.position as Vector3,
					"normal": landing.normal as Vector3,
					"collider": landing.collider as Node3D,
					"size": randf_range(0.22, 0.48),
				})
				break
			previous_position = next_position


func _create_wound_mark(
	hit_position: Vector3,
	hit_normal: Vector3,
	hit_collider: Node3D
) -> void:
	var wound := _create_textured_mark(
		BLOOD_WOUND_TEXTURES.pick_random(),
		hit_position,
		hit_normal,
		wound_size * randf_range(0.85, 1.2),
		Color(0.38, 0.008, 0.01, 0.96)
	)
	_attach_mark(wound, hit_collider)
	_create_bullet_hole(
		hit_position + hit_normal.normalized() * 0.002,
		hit_normal,
		hit_collider,
		wound_size * 0.32
	)


func _create_bullet_hole(
	hit_position: Vector3,
	hit_normal: Vector3,
	hit_collider: Node3D,
	size: float
) -> void:
	var mark := MeshInstance3D.new()
	mark.name = "BulletHole"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	prewarm_resources()
	quad.material = _shared_bullet_hole_material
	mark.mesh = quad
	_place_mark(mark, hit_position, hit_normal, 0.004)
	_attach_mark(mark, hit_collider)


func _create_floor_pool(
	hit_position: Vector3,
	hit_collider: Node3D
) -> void:
	var from := hit_position + Vector3.UP * 0.6
	var to := hit_position + Vector3.DOWN * 5.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _get_collision_exclusions(hit_collider)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(query)
	if floor_hit.is_empty():
		return

	var floor_position := floor_hit.position as Vector3
	var floor_normal := floor_hit.normal as Vector3
	_pool = _create_textured_mark(
		BLOOD_POOL_TEXTURE,
		floor_position,
		floor_normal,
		pool_size * randf_range(1.15, 1.45),
		Color(0.2, 0.001, 0.003, 0.94)
	)
	_pool.name = "BloodPool"
	_pool_target_scale = Vector3(
		randf_range(1.0, 1.35),
		randf_range(0.72, 0.95),
		1.0
	)
	_pool_growth_elapsed = 0.0
	_pool.scale = _pool_target_scale * 0.12
	_attach_mark(_pool, floor_hit.collider as Node3D)


func _create_textured_mark(
	texture: Texture2D,
	position: Vector3,
	normal: Vector3,
	size: float,
	color: Color
) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var material := ShaderMaterial.new()
	material.shader = BLOOD_MARK_SHADER
	material.set_shader_parameter("blood_texture", texture)
	material.set_shader_parameter("blood_tint", color)
	quad.material = material
	mark.mesh = quad
	_place_mark(mark, position, normal, 0.006)
	return mark


func _place_mark(
	mark: Node3D,
	position: Vector3,
	normal: Vector3,
	surface_offset: float
) -> void:
	var safe_normal := normal.normalized()
	if safe_normal.is_zero_approx():
		safe_normal = Vector3.UP
	var up_hint := (
		Vector3.FORWARD
		if absf(safe_normal.dot(Vector3.UP)) > 0.96
		else Vector3.UP
	)
	var right := up_hint.cross(safe_normal).normalized()
	var up := safe_normal.cross(right).normalized()
	mark.transform = Transform3D(
		Basis(right, up, safe_normal),
		position + safe_normal * surface_offset
	)
	mark.rotate_object_local(Vector3.FORWARD, randf_range(0.0, TAU))


func _attach_mark(mark: Node3D, target: Node3D) -> void:
	var host := target if target != null else get_tree().current_scene
	var vfx_owner := _find_vfx_owner(target)
	if (
		vfx_owner != null
		and vfx_owner.has_method("create_vfx_attachment")
	):
		if vfx_owner.has_method("snap_vfx_position_to_body"):
			mark.transform.origin = vfx_owner.call(
				"snap_vfx_position_to_body",
				mark.transform.origin
			) as Vector3
		host = vfx_owner.call(
			"create_vfx_attachment",
			mark.transform.origin
		) as Node3D
		if host != vfx_owner:
			_temporary_hosts.append(host)
	var world_transform := mark.transform
	host.add_child(mark)
	mark.global_transform = world_transform
	_persistent_marks.append(mark)


func _find_vfx_owner(target: Node3D) -> Node3D:
	var current := target
	while current != null:
		if current.has_method("create_vfx_attachment"):
			return current
		current = current.get_parent() as Node3D
	return target


func _get_collision_exclusions(target: Node3D) -> Array[RID]:
	var owner := _find_vfx_owner(target)
	if owner != null and owner.has_method("get_vfx_collision_exclusions"):
		return owner.call("get_vfx_collision_exclusions") as Array[RID]
	var exclusions: Array[RID] = []
	if target is CollisionObject3D:
		exclusions.append((target as CollisionObject3D).get_rid())
	return exclusions
