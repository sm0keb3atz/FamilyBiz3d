class_name CombatVFXManager
extends Node3D

enum SurfaceImpactKind {
	STONE,
	METAL,
}

const BLOOD_POOL_SIZE := 16
const SURFACE_POOL_SIZE := 24
const TRACER_POOL_SIZE := 32
const MUZZLE_SMOKE_POOL_SIZE := 8
const MAX_WOUNDS_PER_CHARACTER := 4
const MAX_BLOOD_MARKS := 48
const MAX_BULLET_HOLES := 96
const MAX_DEATH_POOLS := 12
const MARK_LIFETIME_MSEC := 30000
const DEATH_POOL_LIFETIME_MSEC := 30000

const BLOOD_POOL_TEXTURE := preload("res://Assets/VFX/Blood/BloodSplat1.png")
const BLOOD_SPRAY_TEXTURE := preload("res://Assets/VFX/Blood/BloodSplat5.png")
const BLOOD_WOUND_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/VFX/Blood/BloodSplat2.png"),
	preload("res://Assets/VFX/Blood/BloodSplat3.png"),
	preload("res://Assets/VFX/Blood/BloodSplat4.png"),
]
const BULLET_HOLE_TEXTURE := preload("res://Assets/VFX/Blood/Bullethole.png")
const BLOOD_SPRAY_SHADER := preload("res://Assets/VFX/Blood/blood_spray.gdshader")
const BLOOD_MARK_SHADER := preload("res://Assets/VFX/Blood/blood_mark.gdshader")
const BULLET_HOLE_SHADER := preload("res://Assets/VFX/Blood/bullet_hole.gdshader")
const SOFT_SMOKE_SHADER := preload("res://Assets/VFX/Combat/soft_smoke.gdshader")
const PARTICLE_WARMUP_POSITION := Vector3(0.0, -10000.0, 0.0)

var _blood_pool: Array[Node3D] = []
var _surface_pool: Array[Node3D] = []
var _tracer_pool: Array[MeshInstance3D] = []
var _muzzle_smoke_pool: Array[Node3D] = []
var _bullet_hole_pool: Array[MeshInstance3D] = []
var _blood_cursor := 0
var _surface_cursor := 0
var _tracer_cursor := 0
var _muzzle_smoke_cursor := 0
var _bullet_hole_cursor := 0

var _blood_marks: Array[Dictionary] = []
var _bullet_holes: Array[Dictionary] = []
var _death_pools: Array[Dictionary] = []
var _pending_death_pools: Array[Dictionary] = []

var _blood_mist_mesh: QuadMesh
var _blood_streak_mesh: BoxMesh
var _spark_mesh: BoxMesh
var _debris_mesh: BoxMesh
var _smoke_mesh: QuadMesh
var _tracer_mesh: BoxMesh
var _ribbon_mesh: BoxMesh
var _bullet_hole_mesh: QuadMesh
var _impact_flash_mesh: QuadMesh
var _bullet_hole_material: ShaderMaterial
var _tracer_material: StandardMaterial3D
var _ribbon_material: StandardMaterial3D
var _smoke_fade_texture: GradientTexture1D


static func find(tree: SceneTree) -> CombatVFXManager:
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"combat_vfx_manager") as CombatVFXManager


func _ready() -> void:
	add_to_group(&"combat_vfx_manager")
	_build_shared_resources()
	_prewarm_pools()
	_warm_particle_pools()
	set_process(true)


func _process(delta: float) -> void:
	_update_tracers(delta)
	_update_surface_flashes()
	_update_pending_death_pools()
	_update_death_pools()
	_expire_marks(_blood_marks, MARK_LIFETIME_MSEC)
	_expire_marks(_bullet_holes, MARK_LIFETIME_MSEC)


func spawn_blood_hit(
	hit_position: Vector3,
	hit_normal: Vector3,
	shot_direction: Vector3,
	hit_collider: Node3D,
	fatal_hit: bool,
	spray_multiplier := 1.0
) -> void:
	var direction := shot_direction.normalized()
	if direction.is_zero_approx():
		direction = -hit_normal.normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var slot := _next_blood_slot()
	slot.global_position = hit_position + direction * 0.035
	slot.global_basis = _basis_from_forward(direction)
	var authored_scale := clampf(spray_multiplier, 0.75, 1.35)
	if fatal_hit:
		authored_scale = maxf(authored_scale, 1.25)
	slot.scale = Vector3.ONE * authored_scale
	(slot.get_node("Mist") as GPUParticles3D).restart()
	(slot.get_node("Streaks") as GPUParticles3D).restart()
	_create_wound_mark(hit_position, hit_normal, hit_collider)
	_trace_environment_splats(
		hit_position,
		direction,
		hit_collider,
		3 if fatal_hit else 2
	)
	if fatal_hit:
		_pending_death_pools.append({
			"owner": _find_vfx_owner(hit_collider),
			"due": Time.get_ticks_msec() + 900,
		})


func spawn_surface_hit(
	hit_position: Vector3,
	hit_normal: Vector3,
	hit_collider: Node3D,
	impact_kind := SurfaceImpactKind.STONE
) -> void:
	var normal := hit_normal.normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	var slot := _next_surface_slot()
	slot.global_position = hit_position + normal * 0.012
	slot.global_basis = _basis_from_forward(normal)
	_stop_surface_slot(slot)
	if impact_kind == SurfaceImpactKind.METAL:
		(slot.get_node("Sparks") as GPUParticles3D).restart()
		(slot.get_node("MetalFlecks") as GPUParticles3D).restart()
		(slot.get_node("ImpactSmoke") as GPUParticles3D).restart()
		var flash := slot.get_node("Flash") as MeshInstance3D
		flash.visible = true
		slot.set_meta("flash_until", Time.get_ticks_msec() + 55)
	else:
		(slot.get_node("Dust") as GPUParticles3D).restart()
		(slot.get_node("StoneChips") as GPUParticles3D).restart()
	_create_bullet_hole(hit_position, normal, hit_collider)


func spawn_tracer(
	from: Vector3,
	to: Vector3,
	visible_length := 2.4,
	speed := 900.0,
	lifetime := 0.08
) -> void:
	_spawn_tracer_internal(
		from, to, visible_length, speed, lifetime, false
	)


func spawn_near_miss_ribbon(
	closest_point: Vector3,
	bullet_direction: Vector3,
	strength := 1.0
) -> void:
	var direction := bullet_direction.normalized()
	if direction.is_zero_approx():
		return
	var length := lerpf(0.55, 1.15, clampf(strength, 0.0, 1.0))
	_spawn_tracer_internal(
		closest_point - direction * length * 0.5,
		closest_point + direction * length * 0.5,
		length,
		60.0,
		0.075,
		true
	)


func spawn_muzzle_smoke(position: Vector3, direction: Vector3) -> void:
	var safe_direction: Vector3 = direction.normalized()
	if safe_direction.is_zero_approx():
		safe_direction = Vector3.FORWARD
	var slot: Node3D = _muzzle_smoke_pool[_muzzle_smoke_cursor]
	_muzzle_smoke_cursor = (_muzzle_smoke_cursor + 1) % _muzzle_smoke_pool.size()
	slot.global_position = position
	slot.global_basis = _basis_from_forward(safe_direction)
	(slot.get_node("Smoke") as GPUParticles3D).restart()


func clear_marks_attached_to(owner: Node3D) -> void:
	_clear_owner_records(_blood_marks, owner)
	for index in range(_death_pools.size() - 1, -1, -1):
		var record: Dictionary = _death_pools[index]
		if _get_valid_record_node(record, &"owner") == owner:
			_free_record(record)
			_death_pools.remove_at(index)
	for index in range(_pending_death_pools.size() - 1, -1, -1):
		var pending: Dictionary = _pending_death_pools[index]
		if _get_valid_record_node(pending, &"owner") == owner:
			_pending_death_pools.remove_at(index)


func _build_shared_resources() -> void:
	var mist_material := ShaderMaterial.new()
	mist_material.shader = BLOOD_SPRAY_SHADER
	mist_material.set_shader_parameter("blood_texture", BLOOD_SPRAY_TEXTURE)
	mist_material.set_shader_parameter(
		"blood_tint", Color(0.34, 0.003, 0.006, 0.78)
	)
	_blood_mist_mesh = QuadMesh.new()
	_blood_mist_mesh.size = Vector2(0.32, 0.22)
	_blood_mist_mesh.material = mist_material

	var streak_material := StandardMaterial3D.new()
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.albedo_color = Color(0.32, 0.002, 0.004, 0.82)
	streak_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blood_streak_mesh = BoxMesh.new()
	_blood_streak_mesh.size = Vector3(0.012, 0.012, 0.13)
	_blood_streak_mesh.material = streak_material

	var spark_material := StandardMaterial3D.new()
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1.0, 0.77, 0.2, 0.96)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.44, 0.04)
	spark_material.emission_energy_multiplier = 3.2
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3(0.006, 0.006, 0.082)
	_spark_mesh.material = spark_material

	var debris_material := StandardMaterial3D.new()
	debris_material.albedo_color = Color(0.14, 0.12, 0.1)
	debris_material.roughness = 0.9
	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3.ONE * 0.022
	_debris_mesh.material = debris_material

	var smoke_material := ShaderMaterial.new()
	smoke_material.shader = SOFT_SMOKE_SHADER
	smoke_material.set_shader_parameter(
		"smoke_color", Color(0.55, 0.57, 0.59, 0.3)
	)
	_smoke_mesh = QuadMesh.new()
	_smoke_mesh.size = Vector2(0.34, 0.28)
	_smoke_mesh.orientation = PlaneMesh.FACE_Z
	_smoke_mesh.material = smoke_material

	var smoke_gradient := Gradient.new()
	smoke_gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.58, 1.0])
	smoke_gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.82),
		Color(0.82, 0.84, 0.86, 0.38),
		Color(0.7, 0.72, 0.74, 0.0),
	])
	_smoke_fade_texture = GradientTexture1D.new()
	_smoke_fade_texture.gradient = smoke_gradient

	_bullet_hole_material = ShaderMaterial.new()
	_bullet_hole_material.shader = BULLET_HOLE_SHADER
	_bullet_hole_material.set_shader_parameter("mark_texture", BULLET_HOLE_TEXTURE)
	_bullet_hole_mesh = QuadMesh.new()
	_bullet_hole_mesh.size = Vector2.ONE * 0.105
	_bullet_hole_mesh.material = _bullet_hole_material

	_tracer_material = _new_emissive_material(
		Color(1.0, 0.82, 0.28, 0.72), Color(1.0, 0.55, 0.08), 2.4
	)
	_ribbon_material = _new_emissive_material(
		Color(0.74, 0.88, 1.0, 0.34), Color(0.4, 0.72, 1.0), 1.2
	)
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(0.016, 0.016, 2.4)
	_tracer_mesh.material = _tracer_material
	_ribbon_mesh = BoxMesh.new()
	_ribbon_mesh.size = Vector3(0.008, 0.018, 1.0)
	_ribbon_mesh.material = _ribbon_material
	_impact_flash_mesh = QuadMesh.new()
	_impact_flash_mesh.size = Vector2.ONE * 0.075
	_impact_flash_mesh.material = _new_emissive_material(
		Color(1.0, 0.72, 0.18, 0.5), Color(1.0, 0.38, 0.02), 2.1
	)


func _prewarm_pools() -> void:
	for index in BLOOD_POOL_SIZE:
		var slot := _create_blood_slot(index)
		add_child(slot)
		_blood_pool.append(slot)
	for index in SURFACE_POOL_SIZE:
		var slot := _create_surface_slot(index)
		add_child(slot)
		_surface_pool.append(slot)
	for index in TRACER_POOL_SIZE:
		var tracer := MeshInstance3D.new()
		tracer.name = "PooledTracer%02d" % index
		tracer.top_level = true
		tracer.mesh = _tracer_mesh
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tracer.visible = false
		tracer.set_meta("remaining", 0.0)
		add_child(tracer)
		_tracer_pool.append(tracer)
	for index in MAX_BULLET_HOLES:
		var mark := _create_pooled_bullet_hole(index)
		add_child(mark)
		_bullet_hole_pool.append(mark)
	for index in MUZZLE_SMOKE_POOL_SIZE:
		var slot := Node3D.new()
		slot.name = "MuzzleSmokeSlot%02d" % index
		slot.top_level = true
		var smoke_process := _new_particle_process(
			Vector3.BACK, 31.0, 0.3, 0.72, Vector3(0.0, 0.48, 0.0), 0.32, 0.82
		)
		_configure_smoke_process(smoke_process, -1.8, 1.8)
		var smoke := _new_particles("Smoke", 7, 0.46, smoke_process, _smoke_mesh)
		slot.add_child(smoke)
		add_child(slot)
		_muzzle_smoke_pool.append(slot)


func _create_blood_slot(index: int) -> Node3D:
	var slot := Node3D.new()
	slot.name = "BloodBurstSlot%02d" % index
	slot.top_level = true
	var mist_process := _new_particle_process(
		Vector3.BACK, 29.0, 2.4, 4.6, Vector3(0.0, -0.45, 0.0), 0.7, 1.35
	)
	mist_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mist_process.emission_sphere_radius = 0.035
	var mist := _new_particles("Mist", 12, 0.31, mist_process, _blood_mist_mesh)
	slot.add_child(mist)
	var streak_process := _new_particle_process(
		Vector3.BACK, 20.0, 4.2, 7.2, Vector3(0.0, -2.4, 0.0), 0.55, 1.0
	)
	var streaks := _new_particles(
		"Streaks", 5, 0.22, streak_process, _blood_streak_mesh
	)
	slot.add_child(streaks)
	return slot


func _create_surface_slot(index: int) -> Node3D:
	var slot := Node3D.new()
	slot.name = "SurfaceImpactSlot%02d" % index
	slot.top_level = true
	slot.add_child(_new_particles(
		"Sparks", 14, 0.26,
		_new_particle_process(Vector3.BACK, 43.0, 3.1, 6.2, Vector3(0, -7.8, 0), 0.45, 0.95),
		_spark_mesh
	))
	slot.add_child(_new_particles(
		"MetalFlecks", 5, 0.44,
		_new_particle_process(Vector3.BACK, 52.0, 0.9, 2.5, Vector3(0, -5.5, 0), 0.55, 1.0),
		_debris_mesh
	))
	var impact_smoke_process: ParticleProcessMaterial = _new_particle_process(
		Vector3.BACK, 48.0, 0.35, 0.9, Vector3(0, 0.15, 0), 0.25, 0.5
	)
	_configure_smoke_process(impact_smoke_process, -1.4, 1.4)
	slot.add_child(_new_particles(
		"ImpactSmoke", 6, 0.48,
		impact_smoke_process,
		_smoke_mesh
	))
	var dust_process: ParticleProcessMaterial = _new_particle_process(
		Vector3.BACK, 58.0, 0.35, 1.25, Vector3(0, -0.35, 0), 0.45, 0.95
	)
	_configure_smoke_process(dust_process, -1.1, 1.1)
	slot.add_child(_new_particles(
		"Dust", 10, 0.62,
		dust_process,
		_smoke_mesh
	))
	slot.add_child(_new_particles(
		"StoneChips", 4, 0.5,
		_new_particle_process(Vector3.BACK, 58.0, 0.8, 2.1, Vector3(0, -6.0, 0), 0.5, 1.0),
		_debris_mesh
	))
	var flash := MeshInstance3D.new()
	flash.name = "Flash"
	flash.mesh = _impact_flash_mesh
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	slot.add_child(flash)
	return slot


func _new_particles(
	particle_name: String,
	amount: int,
	lifetime: float,
	process_material: ParticleProcessMaterial,
	draw_mesh: Mesh
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = particle_name
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.65
	particles.local_coords = false
	particles.fixed_fps = 30
	particles.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	particles.process_material = process_material
	particles.draw_pass_1 = draw_mesh
	return particles


func _new_particle_process(
	direction: Vector3,
	spread: float,
	velocity_min: float,
	velocity_max: float,
	gravity: Vector3,
	scale_min: float,
	scale_max: float
) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = direction
	material.spread = spread
	material.initial_velocity_min = velocity_min
	material.initial_velocity_max = velocity_max
	material.gravity = gravity
	material.scale_min = scale_min
	material.scale_max = scale_max
	material.damping_min = 0.15
	material.damping_max = 0.85
	return material


func _configure_smoke_process(
	material: ParticleProcessMaterial,
	angular_velocity_min: float,
	angular_velocity_max: float
) -> void:
	material.color_ramp = _smoke_fade_texture
	material.angular_velocity_min = angular_velocity_min
	material.angular_velocity_max = angular_velocity_max


func _warm_particle_pools() -> void:
	# Allocate the particle buffers during scene setup instead of on the first shot.
	for slot in _blood_pool:
		_warm_particle_slot(slot)
	for slot in _surface_pool:
		_warm_particle_slot(slot)
	for slot in _muzzle_smoke_pool:
		_warm_particle_slot(slot)


func _warm_particle_slot(slot: Node3D) -> void:
	slot.global_position = PARTICLE_WARMUP_POSITION
	for child in slot.get_children():
		if child is GPUParticles3D:
			var particles: GPUParticles3D = child as GPUParticles3D
			particles.restart()


func _new_emissive_material(
	albedo: Color,
	emission: Color,
	energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _next_blood_slot() -> Node3D:
	var slot: Node3D = _blood_pool[_blood_cursor]
	_blood_cursor = (_blood_cursor + 1) % _blood_pool.size()
	return slot


func _next_surface_slot() -> Node3D:
	var slot: Node3D = _surface_pool[_surface_cursor]
	_surface_cursor = (_surface_cursor + 1) % _surface_pool.size()
	return slot


func _stop_surface_slot(slot: Node3D) -> void:
	for child in slot.get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = false
	(slot.get_node("Flash") as MeshInstance3D).visible = false


func _spawn_tracer_internal(
	from: Vector3,
	to: Vector3,
	visible_length: float,
	speed: float,
	lifetime: float,
	is_ribbon: bool
) -> void:
	var segment: Vector3 = to - from
	var length: float = segment.length()
	if length <= 0.05:
		return
	var direction: Vector3 = segment / length
	var shown_length: float = minf(visible_length, length)
	var tracer: MeshInstance3D = _tracer_pool[_tracer_cursor]
	_tracer_cursor = (_tracer_cursor + 1) % _tracer_pool.size()
	tracer.mesh = _ribbon_mesh if is_ribbon else _tracer_mesh
	var source_mesh_length: float = 1.0 if is_ribbon else 2.4
	tracer.scale = Vector3(1.0, 1.0, shown_length / source_mesh_length)
	tracer.global_position = from + direction * shown_length * 0.5
	tracer.global_basis = _basis_from_forward(direction).scaled(tracer.scale)
	tracer.visible = true
	var duration: float = clampf(length / maxf(speed, 1.0), 0.015, lifetime)
	var travel_distance: float = maxf(length - shown_length, 0.0)
	tracer.set_meta("remaining", duration)
	tracer.set_meta("velocity", direction * travel_distance / maxf(duration, 0.001))


func _update_tracers(delta: float) -> void:
	for tracer in _tracer_pool:
		var remaining: float = float(tracer.get_meta("remaining", 0.0))
		if remaining <= 0.0:
			continue
		tracer.global_position += (
			tracer.get_meta("velocity", Vector3.ZERO) as Vector3
		) * delta
		remaining -= delta
		tracer.set_meta("remaining", remaining)
		if remaining <= 0.0:
			tracer.visible = false


func _update_surface_flashes() -> void:
	var now: int = Time.get_ticks_msec()
	for slot in _surface_pool:
		var flash_until: int = int(slot.get_meta("flash_until", 0))
		if flash_until > 0 and now >= flash_until:
			(slot.get_node("Flash") as MeshInstance3D).visible = false
			slot.set_meta("flash_until", 0)


func _create_wound_mark(
	hit_position: Vector3,
	hit_normal: Vector3,
	hit_collider: Node3D
) -> void:
	var owner: Node3D = _find_vfx_owner(hit_collider)
	_remove_excess_owner_wounds(owner)
	var mark: MeshInstance3D = _create_blood_mark(
		BLOOD_WOUND_TEXTURES.pick_random(),
		hit_position,
		hit_normal,
		0.072,
		Color(0.24, 0.0015, 0.003, 0.96)
	)
	mark.name = "PooledWoundMark"
	var host: Node3D = _attach_mark(mark, hit_collider)
	_register_record(_blood_marks, mark, owner, host, MAX_BLOOD_MARKS)


func _trace_environment_splats(
	hit_position: Vector3,
	shot_direction: Vector3,
	hit_collider: Node3D,
	trace_count: int
) -> void:
	var exclusions: Array[RID] = _get_collision_exclusions(hit_collider)
	for index in mini(trace_count, 3):
		var direction: Vector3 = (
			shot_direction
			+ Vector3(
				randf_range(-0.38, 0.38),
				randf_range(-0.32, 0.42),
				randf_range(-0.38, 0.38)
			)
		).normalized()
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			hit_position + direction * 0.08,
			hit_position + direction * randf_range(0.75, 1.8) + Vector3.DOWN * 0.45
		)
		query.exclude = exclusions
		var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var mark: MeshInstance3D = _create_blood_mark(
			BLOOD_WOUND_TEXTURES.pick_random(),
			result.position as Vector3,
			result.normal as Vector3,
			randf_range(0.13, 0.27),
			Color(0.28, 0.002, 0.004, 0.82)
		)
		mark.name = "PooledBloodSplat"
		var target: Node3D = result.collider as Node3D
		var host: Node3D = _attach_mark(mark, target)
		_register_record(_blood_marks, mark, target, host, MAX_BLOOD_MARKS)


func _create_bullet_hole(
	hit_position: Vector3,
	hit_normal: Vector3,
	hit_collider: Node3D
) -> void:
	var pool_index: int = _bullet_hole_cursor
	var mark: MeshInstance3D = _bullet_hole_pool[pool_index]
	_bullet_hole_cursor = (_bullet_hole_cursor + 1) % _bullet_hole_pool.size()
	if not is_instance_valid(mark):
		mark = _create_pooled_bullet_hole(pool_index)
		add_child(mark)
		_bullet_hole_pool[pool_index] = mark
	_release_existing_bullet_hole_record(mark)
	if mark.get_parent() != self:
		mark.reparent(self, true)
	mark.visible = true
	_place_mark(mark, hit_position, hit_normal, 0.004)
	var host: Node3D = _attach_mark(mark, hit_collider)
	_bullet_holes.append({
		"node": mark,
		"owner": hit_collider,
		"host": host,
		"created": Time.get_ticks_msec(),
		"pooled": true,
	})


func _create_pooled_bullet_hole(index: int) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	mark.name = "PooledBulletHole%02d" % index
	mark.mesh = _bullet_hole_mesh
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.visible = false
	mark.set_meta("pooled_bullet_hole", true)
	return mark


func _release_existing_bullet_hole_record(mark: MeshInstance3D) -> void:
	for index in range(_bullet_holes.size() - 1, -1, -1):
		var record: Dictionary = _bullet_holes[index]
		if _get_valid_record_node(record, &"node") == mark:
			_bullet_holes.remove_at(index)
			return


func _create_blood_mark(
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


func _update_pending_death_pools() -> void:
	var now: int = Time.get_ticks_msec()
	for index in range(_pending_death_pools.size() - 1, -1, -1):
		var pending: Dictionary = _pending_death_pools[index]
		if now < int(pending.get("due", 0)):
			continue
		var owner: Node3D = _get_valid_record_node(pending, &"owner")
		if is_instance_valid(owner):
			_create_death_pool(owner)
		_pending_death_pools.remove_at(index)


func _create_death_pool(owner: Node3D) -> void:
	var origin: Vector3 = owner.global_position
	if owner.has_method("get_vfx_pool_origin"):
		origin = owner.call("get_vfx_pool_origin") as Vector3
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin + Vector3.UP * 0.6,
		origin + Vector3.DOWN * 5.0
	)
	query.exclude = _get_collision_exclusions(owner)
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var mark: MeshInstance3D = _create_blood_mark(
		BLOOD_POOL_TEXTURE,
		result.position as Vector3,
		result.normal as Vector3,
		randf_range(1.18, 1.42),
		Color(0.19, 0.001, 0.003, 0.9)
	)
	mark.name = "PooledDeathPool"
	var host: Node3D = _attach_mark(mark, result.collider as Node3D)
	var target_scale: Vector3 = Vector3(randf_range(1.0, 1.3), randf_range(0.72, 0.94), 1.0)
	mark.scale = target_scale * 0.12
	_death_pools.append({
		"node": mark,
		"host": host,
		"owner": owner,
		"created": Time.get_ticks_msec(),
		"target_scale": target_scale,
	})
	while _death_pools.size() > MAX_DEATH_POOLS:
		var expired_record: Dictionary = _death_pools.pop_front() as Dictionary
		_free_record(expired_record)


func _update_death_pools() -> void:
	var now: int = Time.get_ticks_msec()
	for index in range(_death_pools.size() - 1, -1, -1):
		var record: Dictionary = _death_pools[index]
		var mark: Node3D = _get_valid_record_node(record, &"node")
		if not is_instance_valid(mark):
			_free_record(record)
			_death_pools.remove_at(index)
			continue
		var age: int = now - int(record.get("created", now))
		if age >= DEATH_POOL_LIFETIME_MSEC:
			_free_record(record)
			_death_pools.remove_at(index)
			continue
		var growth: float = clampf(float(age) / 1200.0, 0.0, 1.0)
		growth = 1.0 - pow(1.0 - growth, 3.0)
		mark.scale = (record.get("target_scale") as Vector3) * lerpf(0.12, 1.0, growth)


func _register_record(
	records: Array[Dictionary],
	mark: Node3D,
	owner: Node3D,
	host: Node3D,
	maximum: int
) -> void:
	records.append({
		"node": mark,
		"owner": owner,
		"host": host,
		"created": Time.get_ticks_msec(),
	})
	while records.size() > maximum:
		var expired_record: Dictionary = records.pop_front() as Dictionary
		_free_record(expired_record)


func _expire_marks(records: Array[Dictionary], lifetime_msec: int) -> void:
	var now: int = Time.get_ticks_msec()
	for index in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[index]
		var mark: Node3D = _get_valid_record_node(record, &"node")
		if (
			not is_instance_valid(mark)
			or now - int(record.get("created", now)) >= lifetime_msec
		):
			_free_record(record)
			records.remove_at(index)


func _remove_excess_owner_wounds(owner: Node3D) -> void:
	if owner == null:
		return
	var owner_records: Array[Dictionary] = []
	for record in _blood_marks:
		if _get_valid_record_node(record, &"owner") == owner:
			owner_records.append(record)
	while owner_records.size() >= MAX_WOUNDS_PER_CHARACTER:
		var oldest: Dictionary = owner_records.pop_front() as Dictionary
		_free_record(oldest)
		_blood_marks.erase(oldest)


func _clear_owner_records(records: Array[Dictionary], owner: Node3D) -> void:
	for index in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[index]
		if _get_valid_record_node(record, &"owner") == owner:
			_free_record(record)
			records.remove_at(index)


func _free_record(record: Dictionary) -> void:
	var mark: Node3D = _get_valid_record_node(record, &"node")
	var host: Node3D = _get_valid_record_node(record, &"host")
	if is_instance_valid(mark):
		if bool(record.get("pooled", false)):
			if mark.get_parent() != self:
				mark.reparent(self, true)
			mark.visible = false
		else:
			mark.queue_free()
	if is_instance_valid(host) and host.name.begins_with("BloodMark_"):
		host.queue_free()


func _get_valid_record_node(record: Dictionary, key: StringName) -> Node3D:
	var value: Variant = record.get(key)
	if not is_instance_valid(value):
		return null
	return value as Node3D


func _place_mark(
	mark: Node3D,
	position: Vector3,
	normal: Vector3,
	surface_offset: float
) -> void:
	var safe_normal := normal.normalized()
	if safe_normal.is_zero_approx():
		safe_normal = Vector3.UP
	var world_transform: Transform3D = Transform3D(
		_basis_from_forward(safe_normal),
		position + safe_normal * surface_offset
	)
	if mark.is_inside_tree():
		mark.global_transform = world_transform
	else:
		mark.transform = world_transform
	mark.rotate_object_local(Vector3.FORWARD, randf_range(0.0, TAU))


func _attach_mark(mark: Node3D, target: Node3D) -> Node3D:
	var host: Node3D = target
	if host == null:
		host = get_tree().current_scene as Node3D
	var owner: Node3D = _find_vfx_owner(target)
	if owner != null and owner.has_method("create_vfx_attachment"):
		if owner.has_method("snap_vfx_position_to_body"):
			mark.transform.origin = owner.call(
				"snap_vfx_position_to_body", mark.transform.origin
			) as Vector3
		host = owner.call(
			"create_vfx_attachment", mark.transform.origin
		) as Node3D
	if host == null:
		host = self
	var world_transform: Transform3D = (
		mark.global_transform if mark.is_inside_tree() else mark.transform
	)
	if mark.get_parent() == null:
		host.add_child(mark)
	elif mark.get_parent() != host:
		mark.reparent(host, true)
	mark.global_transform = world_transform
	return host


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


func _basis_from_forward(forward: Vector3) -> Basis:
	var safe_forward := forward.normalized()
	if safe_forward.is_zero_approx():
		safe_forward = Vector3.FORWARD
	var up_hint := Vector3.RIGHT if absf(safe_forward.dot(Vector3.UP)) > 0.96 else Vector3.UP
	var right := up_hint.cross(safe_forward).normalized()
	var up := safe_forward.cross(right).normalized()
	return Basis(right, up, safe_forward)
