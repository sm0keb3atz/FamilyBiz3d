class_name NPCCombatComponent
extends Node

signal fired(hit_position: Vector3)
signal reload_started
signal reload_completed

@export var weapon_definition: WeaponDefinition
@export var weapon_model_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton/WeaponSocket/EquippedWeapon"
)
@export var muzzle_particles_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton/WeaponSocket/"
	+ "EquippedWeapon/Mesh/MuzzleFlash/MuzzlePlanes"
)
@export var gunshot_sound: AudioStream
@export var reload_sound: AudioStream
@export_range(-30.0, 6.0, 0.5) var gunshot_volume_db := 0.0
@export_range(-30.0, 6.0, 0.5) var reload_volume_db := -14.0
@export_range(0.0, 6.0, 0.1) var bullet_whiz_radius := 2.0
@export_range(0.02, 0.3, 0.01) var tracer_lifetime := 0.08

var npc
var _weapon_model: Node3D
var _muzzle_particles: GPUParticles3D
var _gunshot_player: AudioStreamPlayer3D
var _reload_player: AudioStreamPlayer3D
var _tracer_material: StandardMaterial3D
var _magazine := 0
var _reserve := 0
var _cooldown_remaining := 0.0
var _reload_remaining := 0.0
var _equipped := false
var _fully_automatic := false
var _fire_interval_override := -1.0
var _weapon_socket: Node3D
var _weapon_visual_transform := Transform3D.IDENTITY


func initialize(owner_npc: BaseNPC) -> void:
	npc = owner_npc
	_weapon_model = get_node_or_null(weapon_model_path) as Node3D
	if _weapon_model != null:
		_weapon_socket = _weapon_model.get_parent() as Node3D
		_weapon_visual_transform = _weapon_model.transform
	_muzzle_particles = get_node_or_null(
		muzzle_particles_path
	) as GPUParticles3D
	_gunshot_player = AudioStreamPlayer3D.new()
	_gunshot_player.name = "PoliceGunshotPlayer"
	_gunshot_player.bus = &"Gunshots"
	_gunshot_player.max_distance = 90.0
	_gunshot_player.max_polyphony = 4
	add_child(_gunshot_player)
	_reload_player = AudioStreamPlayer3D.new()
	_reload_player.name = "PoliceReloadPlayer"
	_reload_player.max_distance = 25.0
	add_child(_reload_player)
	if weapon_definition != null:
		_magazine = weapon_definition.magazine_capacity
		_reserve = weapon_definition.starting_reserve_ammo
	set_equipped(false)


func configure_weapon(
	definition: WeaponDefinition,
	fully_automatic := false,
	fire_interval_override := -1.0
) -> void:
	var was_equipped := _equipped
	weapon_definition = definition
	_fully_automatic = fully_automatic and definition != null and definition.supports_full_auto
	_fire_interval_override = fire_interval_override
	_magazine = definition.magazine_capacity if definition != null else 0
	_reserve = definition.starting_reserve_ammo if definition != null else 0
	_cooldown_remaining = 0.0
	_reload_remaining = 0.0
	_replace_weapon_visual()
	set_equipped(was_equipped)


func get_weapon_definition() -> WeaponDefinition:
	return weapon_definition


func is_fully_automatic() -> bool:
	return _fully_automatic


func get_fire_interval() -> float:
	if weapon_definition == null:
		return 0.0
	if _fire_interval_override > 0.0:
		return _fire_interval_override
	return (
		weapon_definition.full_auto_fire_interval
		if _fully_automatic
		else weapon_definition.fire_interval
	)


func get_effective_gunshot_sound() -> AudioStream:
	if gunshot_sound != null:
		return gunshot_sound
	if weapon_definition != null:
		return weapon_definition.gunshot_sound
	return null


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _reload_remaining <= 0.0:
		return
	_reload_remaining = maxf(_reload_remaining - delta, 0.0)
	if is_zero_approx(_reload_remaining):
		_finish_reload()


func set_equipped(equipped: bool) -> void:
	_equipped = equipped and weapon_definition != null
	if _weapon_model != null:
		_weapon_model.visible = _equipped
	if npc != null and not _equipped:
		npc.animation_component.set_combat_aiming(false)


func is_equipped() -> bool:
	return _equipped


func is_reloading() -> bool:
	return _reload_remaining > 0.0


func set_aim_target(world_position: Vector3) -> void:
	if not _equipped:
		return
	npc.animation_component.set_combat_aiming(true)
	npc.animation_component.set_combat_aim_target(world_position)
	npc.movement_component.set_facing_override(world_position)


func clear_aim() -> void:
	npc.animation_component.set_combat_aiming(false)
	npc.movement_component.clear_facing_override()


func has_line_of_fire(target: Node3D, target_position: Vector3) -> bool:
	if not _equipped or target == null:
		return false
	var origin := _get_muzzle_position()
	var query := PhysicsRayQueryParameters3D.create(origin, target_position)
	query.exclude = [npc.get_rid()]
	query.collision_mask = 3
	var hit: Dictionary = (
		npc.get_world_3d().direct_space_state.intersect_ray(query)
	)
	if hit.is_empty():
		return false
	return _is_node_or_descendant(hit.get("collider") as Node, target)


func try_fire_at(target_position: Vector3, spread_degrees: float) -> bool:
	if (
		not _equipped
		or weapon_definition == null
		or _cooldown_remaining > 0.0
		or is_reloading()
	):
		return false
	if _magazine <= 0:
		return try_reload()
	var origin := _get_muzzle_position()
	var direction := (target_position - origin).normalized()
	direction = direction.rotated(
		Vector3.UP,
		deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	)
	var right := direction.cross(Vector3.UP).normalized()
	direction = direction.rotated(
		right,
		deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	)
	var destination := origin + direction * weapon_definition.max_range
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.exclude = [npc.get_rid()]
	query.collision_mask = 3
	var hit: Dictionary = (
		npc.get_world_3d().direct_space_state.intersect_ray(query)
	)
	var hit_position := destination
	if not hit.is_empty():
		hit_position = hit.get("position", destination) as Vector3
		_apply_hit(
			hit.get("collider") as Node,
			hit_position,
			direction
		)
	_spawn_tracer(origin, hit_position)
	_play_near_miss_whiz(origin, hit_position, hit.get("collider") as Node)
	_magazine -= 1
	_cooldown_remaining = get_fire_interval()
	npc.animation_component.trigger_combat_recoil()
	_play_gunshot()
	if _muzzle_particles != null:
		_muzzle_particles.restart()
	npc.get_tree().call_group(
		&"gunshot_listener",
		&"hear_gunshot",
		origin,
		45.0
	)
	fired.emit(hit_position)
	return true


func try_reload() -> bool:
	if (
		weapon_definition == null
		or is_reloading()
		or _magazine >= weapon_definition.magazine_capacity
		or _reserve <= 0
	):
		return false
	_reload_remaining = weapon_definition.reload_duration
	npc.animation_component.trigger_combat_reload(_reload_remaining)
	if reload_sound != null:
		_reload_player.stream = reload_sound
		_reload_player.volume_db = reload_volume_db
		_reload_player.play()
	reload_started.emit()
	return true


func reset_for_reuse() -> void:
	_cooldown_remaining = 0.0
	_reload_remaining = 0.0
	if weapon_definition != null:
		_magazine = weapon_definition.magazine_capacity
		_reserve = weapon_definition.starting_reserve_ammo
	set_equipped(false)


func _replace_weapon_visual() -> void:
	if _weapon_socket == null:
		return
	if _weapon_model != null:
		_weapon_socket.remove_child(_weapon_model)
		_weapon_model.queue_free()
		_weapon_model = null
	_muzzle_particles = null
	if weapon_definition == null or weapon_definition.visual_scene == null:
		return
	_weapon_model = weapon_definition.visual_scene.instantiate() as Node3D
	if _weapon_model == null:
		return
	_weapon_model.name = "EquippedWeapon"
	_weapon_model.transform = _weapon_visual_transform
	_weapon_socket.add_child(_weapon_model)
	_muzzle_particles = _find_muzzle_particles(_weapon_model)


func _find_muzzle_particles(node: Node) -> GPUParticles3D:
	if node is GPUParticles3D:
		return node as GPUParticles3D
	for child in node.get_children():
		var result := _find_muzzle_particles(child)
		if result != null:
			return result
	return null


func _finish_reload() -> void:
	var needed := weapon_definition.magazine_capacity - _magazine
	var transferred := mini(needed, _reserve)
	_magazine += transferred
	_reserve -= transferred
	reload_completed.emit()


func _apply_hit(
	collider: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	var current := collider
	while current != null:
		var damageable := current.get_node_or_null(
			"DamageableComponent"
		) as DamageableComponent
		if damageable != null:
			damageable.apply_damage(
				weapon_definition.damage,
				npc,
				hit_position,
				hit_direction
			)
			return
		var stats := current.get_node_or_null(
			"Components/StatsComponent"
		) as PlayerStatsComponent
		if stats != null:
			var feedback := current.get_node_or_null(
				"Components/DamageFeedbackComponent"
			) as PlayerDamageFeedbackComponent
			if feedback != null:
				feedback.receive_hit(
					weapon_definition.damage,
					npc,
					hit_position,
					hit_direction
				)
			else:
				stats.take_damage(weapon_definition.damage)
			return
		current = current.get_parent()


func _play_gunshot() -> void:
	var effective_sound := get_effective_gunshot_sound()
	if effective_sound == null:
		return
	_gunshot_player.global_position = _get_muzzle_position()
	_gunshot_player.stream = effective_sound
	_gunshot_player.volume_db = gunshot_volume_db
	_gunshot_player.pitch_scale = randf_range(0.97, 1.03)
	_gunshot_player.play()


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var segment := to - from
	var length := segment.length()
	if length <= 0.05:
		return
	var tracer := MeshInstance3D.new()
	tracer.name = "IncomingBulletTracer"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, length)
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.albedo_color = Color(1.0, 0.82, 0.28, 0.62)
		_tracer_material.emission_enabled = true
		_tracer_material.emission = Color(1.0, 0.62, 0.1)
		_tracer_material.emission_energy_multiplier = 1.9
	mesh.material = _tracer_material
	tracer.mesh = mesh
	var host: Node = npc.get_tree().current_scene
	if host == null:
		host = npc.get_tree().root
	host.add_child(tracer)
	tracer.global_position = from + segment * 0.5
	tracer.look_at(to, Vector3.UP)
	npc.get_tree().create_timer(tracer_lifetime).timeout.connect(
		func() -> void:
			if is_instance_valid(tracer):
				tracer.queue_free()
	)


func _play_near_miss_whiz(
	from: Vector3,
	to: Vector3,
	hit_collider: Node
) -> void:
	for player in npc.get_tree().get_nodes_in_group(&"player"):
		if (
			player == null
			or player == hit_collider
			or _is_node_or_descendant(hit_collider, player)
		):
			continue
		var feedback := player.get_node_or_null(
			"Components/DamageFeedbackComponent"
		) as PlayerDamageFeedbackComponent
		if feedback == null:
			continue
		var closest := _closest_point_on_segment(
			player.global_position + Vector3.UP,
			from,
			to
		)
		if (
			closest.distance_to(player.global_position + Vector3.UP)
			<= bullet_whiz_radius
		):
			feedback.play_bullet_whiz()


func _closest_point_on_segment(
	point: Vector3,
	segment_start: Vector3,
	segment_end: Vector3
) -> Vector3:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if is_zero_approx(length_squared):
		return segment_start
	var t := clampf(
		(point - segment_start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return segment_start + segment * t


func _get_muzzle_position() -> Vector3:
	if _muzzle_particles != null:
		return _muzzle_particles.global_position
	return _weapon_model.global_position


func _is_node_or_descendant(node: Node, target: Node) -> bool:
	var current := node
	while current != null:
		if current == target:
			return true
		current = current.get_parent()
	return false
