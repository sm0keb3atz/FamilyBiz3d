class_name PlayerWeaponComponent
extends Node

const BLOOD_IMPACT_VFX := preload(
	"res://Scenes/VFX/BloodImpactVFX.tscn"
)
const WORLD_COLLISION_LAYER := 1 << 0
const HITBOX_COLLISION_LAYER := 1 << 2
const AIM_COLLISION_MASK := WORLD_COLLISION_LAYER | HITBOX_COLLISION_LAYER

signal weapon_changed(definition: WeaponDefinition)
signal ammo_changed(magazine: int, reserve: int)
signal fired(hit_position: Vector3)
signal shot_resolved(target: Node, fatal: bool, hit_position: Vector3)
signal hit_confirmed(fatal_hit: bool)
signal reload_started
signal reload_completed
signal attachments_changed

enum MagazineType {
	STANDARD,
	EXTENDED,
	DRUM,
}

@export_category("Scene References")
@export var animation_component_path := NodePath("../AnimationComponent")
@export var health_component_path := NodePath("../HealthComponent")
@export var sound_component_path := NodePath("../SoundComponent")
@export var target_lock_component_path := NodePath("../TargetLockComponent")
@export var body_path := NodePath("../..")
@export var camera_path := NodePath("../../CameraPivot/SpringArm3D/Camera3D")
@export var weapon_socket_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton/WeaponSocket"
)

@export_category("Loadout")
@export var pistol_definition: WeaponDefinition
@export var draco_definition: WeaponDefinition
@export var loadout: Array[WeaponDefinition] = []

@export_category("Input")
@export var aim_action := &"aim"
@export var fire_action := &"fire"
@export var reload_action := &"reload"
@export var next_weapon_action := &"weapon_next"
@export var previous_weapon_action := &"weapon_previous"

@export_category("World Response")
@export_range(1.0, 200.0, 1.0) var gunshot_alert_radius := 45.0
@export_range(0.02, 0.3, 0.01) var tracer_lifetime := 0.08
@export_range(0.5, 8.0, 0.1) var tracer_length := 2.4
@export_range(100.0, 2000.0, 50.0) var tracer_speed := 900.0

@onready var animation_component := (
	get_node(animation_component_path) as PlayerAnimationComponent
)
@onready var health_component := (
	get_node(health_component_path) as PlayerHealthComponent
)
@onready var sound_component := (
	get_node(sound_component_path) as PlayerSoundComponent
)
@onready var target_lock_component := (
	get_node_or_null(target_lock_component_path) as PlayerTargetLockComponent
)
@onready var body := get_node(body_path) as CharacterBody3D
@onready var camera := get_node(camera_path) as Camera3D
@onready var weapon_socket := get_node(weapon_socket_path) as Node3D

var _slots: Array[WeaponDefinition] = []
var _magazine_ammo: Dictionary[StringName, int] = {}
var _reserve_ammo: Dictionary[StringName, int] = {}
var _equipped_slot := 0
var _cooldown_remaining := 0.0
var _reload_remaining := 0.0
var _sights_enabled := false
var _laser_enabled := false
var _switch_enabled := false
var _magazine_type := MagazineType.STANDARD
var _tracer_material: StandardMaterial3D
var weapon_model: Node3D
var muzzle_particles: GPUParticles3D
var _default_weapon_visual_transform := Transform3D.IDENTITY
var _weapon_visual_transforms: Dictionary[StringName, Transform3D] = {}
var _weapon_visual_templates: Dictionary[StringName, Node3D] = {}


func _ready() -> void:
	BloodImpactVFX.prewarm_resources()
	call_deferred("_prewarm_blood_vfx_runtime")
	_cache_initial_weapon_transform()
	_clear_weapon_visual()
	_initialize_weapon_slots()
	health_component.state_changed.connect(_on_health_state_changed)
	_apply_equipped_weapon()


func _prewarm_blood_vfx_runtime() -> void:
	if camera == null:
		return
	var effect := BLOOD_IMPACT_VFX.instantiate() as BloodImpactVFX
	camera.add_child(effect)
	effect.position = Vector3(
		0.0,
		0.0,
		-maxf(camera.near * 2.0, 0.12)
	)
	effect.scale = Vector3.ONE * 0.0001
	effect.prewarm_runtime()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(effect):
		effect.queue_free()


func _cache_initial_weapon_transform() -> void:
	var existing_weapon := (
		weapon_socket.get_node_or_null("EquippedWeapon") as Node3D
	)
	if existing_weapon != null:
		_default_weapon_visual_transform = existing_weapon.transform
	var editor_preview := (
		weapon_socket.get_node_or_null("WeaponEditorPreview") as Node3D
	)
	if editor_preview != null:
		_weapon_visual_transforms[&"draco"] = editor_preview.transform
		_weapon_visual_templates[&"draco"] = editor_preview.duplicate() as Node3D


func _initialize_weapon_slots() -> void:
	_slots.append(null)
	var starter_weapons := loadout.duplicate()
	if starter_weapons.is_empty():
		starter_weapons.append(pistol_definition)
		starter_weapons.append(draco_definition)
	for definition in starter_weapons:
		_add_weapon_definition(definition)


func _add_weapon_definition(definition: WeaponDefinition) -> void:
	if definition == null or String(definition.weapon_id).is_empty():
		return
	if _magazine_ammo.has(definition.weapon_id):
		return
	_slots.append(definition)
	_magazine_ammo[definition.weapon_id] = definition.magazine_capacity
	_reserve_ammo[definition.weapon_id] = definition.starting_reserve_ammo


func _clear_weapon_visual() -> void:
	for child in weapon_socket.get_children():
		if (
			child is Node3D
			and (
				child.name == "EquippedWeapon"
				or child.name == "WeaponEditorPreview"
			)
		):
			weapon_socket.remove_child(child)
			child.queue_free()
	weapon_model = null
	muzzle_particles = null


func _instantiate_weapon_visual(definition: WeaponDefinition) -> void:
	_clear_weapon_visual()
	if definition == null:
		return
	var instance: Node3D
	if _weapon_visual_templates.has(definition.weapon_id):
		instance = _weapon_visual_templates[definition.weapon_id].duplicate() as Node3D
	elif definition.visual_scene != null:
		instance = definition.visual_scene.instantiate() as Node3D
	if instance == null:
		return
	instance.name = "EquippedWeapon"
	instance.transform = _weapon_visual_transforms.get(
		definition.weapon_id,
		_default_weapon_visual_transform
	)
	weapon_socket.add_child(instance)
	weapon_model = instance
	var muzzle_flash := instance.get_node_or_null("MuzzleFlash") as Node3D
	if muzzle_flash != null:
		muzzle_flash.scale = Vector3.ONE * definition.muzzle_flash_scale
	muzzle_particles = (
		instance.get_node_or_null("MuzzleFlash/MuzzlePlanes") as GPUParticles3D
	)
	if muzzle_particles != null:
		muzzle_particles.emitting = false


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_update_laser_beam()
	if is_fully_automatic() and Input.is_action_pressed(fire_action):
		try_fire()
	if _reload_remaining <= 0.0:
		return

	_reload_remaining = maxf(_reload_remaining - delta, 0.0)
	if is_zero_approx(_reload_remaining):
		_finish_reload()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(next_weapon_action):
		if is_aiming() and is_target_lock_enabled():
			if target_lock_component != null and target_lock_component.has_locked_target():
				target_lock_component.cycle_locked_target(1)
				get_viewport().set_input_as_handled()
				return
		cycle_weapon(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(previous_weapon_action):
		if is_aiming() and is_target_lock_enabled():
			if target_lock_component != null and target_lock_component.has_locked_target():
				target_lock_component.cycle_locked_target(-1)
				get_viewport().set_input_as_handled()
				return
		cycle_weapon(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(fire_action):
		if is_fully_automatic():
			get_viewport().set_input_as_handled()
			return
		if try_fire():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(reload_action):
		if try_reload():
			get_viewport().set_input_as_handled()


func cycle_weapon(direction: int) -> bool:
	if direction == 0 or _slots.size() <= 1 or not health_component.is_alive():
		return false

	var next_slot := wrapi(_equipped_slot + signi(direction), 0, _slots.size())
	return equip_slot(next_slot)


func equip_slot(slot_index: int) -> bool:
	if (
		slot_index < 0
		or slot_index >= _slots.size()
		or slot_index == _equipped_slot
	):
		return false

	cancel_reload()
	_equipped_slot = slot_index
	_cooldown_remaining = 0.0
	_apply_equipped_weapon()
	if get_equipped_weapon() != null:
		sound_component.play_equip_sound()
	return true


func try_fire() -> bool:
	var definition := get_equipped_weapon()
	if (
		definition == null
		or not health_component.is_alive()
		or not is_aiming()
		or _cooldown_remaining > 0.0
		or is_reloading()
	):
		return false

	if get_magazine_ammo() <= 0:
		return try_reload()

	_magazine_ammo[definition.weapon_id] = get_magazine_ammo() - 1
	_cooldown_remaining = _get_fire_interval(definition)
	animation_component.trigger_weapon_fire(definition)
	_play_gunshot()
	_broadcast_gunshot()
	_play_muzzle_flash()
	var hit_position := _fire_hitscan(definition)
	_spawn_tracer(_get_muzzle_position(), hit_position)
	ammo_changed.emit(get_magazine_ammo(), get_reserve_ammo())
	fired.emit(hit_position)
	return true


func try_reload() -> bool:
	var definition := get_equipped_weapon()
	if (
		definition == null
		or not health_component.is_alive()
		or is_reloading()
		or get_magazine_ammo() >= get_magazine_capacity()
		or get_reserve_ammo() <= 0
		or not animation_component.trigger_reload(definition.reload_duration)
	):
		return false

	_reload_remaining = definition.reload_duration
	reload_started.emit()
	return true


func cancel_reload() -> void:
	if not is_reloading():
		return

	_reload_remaining = 0.0
	animation_component.cancel_reload()
	sound_component.stop_reload()


func is_reloading() -> bool:
	return _reload_remaining > 0.0


func is_aiming() -> bool:
	return (
		get_equipped_weapon() != null
		and health_component.is_alive()
		and Input.is_action_pressed(aim_action)
	)


func get_equipped_weapon() -> WeaponDefinition:
	if _slots.is_empty():
		return null
	return _slots[_equipped_slot]


func get_weapon_slots() -> Array[WeaponDefinition]:
	var weapons: Array[WeaponDefinition] = []
	for weapon in _slots:
		if weapon != null:
			weapons.append(weapon)
	return weapons.duplicate()


func get_magazine_ammo() -> int:
	var definition := get_equipped_weapon()
	if definition == null:
		return 0
	return _magazine_ammo.get(definition.weapon_id, 0)


func get_reserve_ammo() -> int:
	var definition := get_equipped_weapon()
	if definition == null:
		return 0
	return _reserve_ammo.get(definition.weapon_id, 0)


func get_magazine_capacity() -> int:
	var definition := get_equipped_weapon()
	if definition == null:
		return 0
	return definition.get_capacity_for_magazine_type(_magazine_type)


func get_magazine_type() -> int:
	return _magazine_type


func set_magazine_type(magazine_type: int) -> void:
	if magazine_type < MagazineType.STANDARD or magazine_type > MagazineType.DRUM:
		return
	if _magazine_type == magazine_type:
		return
	var definition := get_equipped_weapon()
	if definition == null:
		return
	_magazine_type = magazine_type
	var loaded_ammo := get_magazine_ammo()
	var capacity := get_magazine_capacity()
	if loaded_ammo > capacity:
		var overflow := loaded_ammo - capacity
		_magazine_ammo[definition.weapon_id] = capacity
		_reserve_ammo[definition.weapon_id] = get_reserve_ammo() + overflow
	_apply_attachment_visuals()
	attachments_changed.emit()
	ammo_changed.emit(get_magazine_ammo(), get_reserve_ammo())


func is_sights_enabled() -> bool:
	return _sights_enabled


func set_sights_enabled(enabled: bool) -> void:
	if _sights_enabled == enabled:
		return
	_sights_enabled = enabled
	_apply_attachment_visuals()
	attachments_changed.emit()


func is_laser_enabled() -> bool:
	return _laser_enabled


func set_laser_enabled(enabled: bool) -> void:
	if _laser_enabled == enabled:
		return
	_laser_enabled = enabled
	if not _laser_enabled and target_lock_component != null:
		target_lock_component.clear_lock()
	_apply_attachment_visuals()
	attachments_changed.emit()


func is_switch_enabled() -> bool:
	return _switch_enabled


func set_switch_enabled(enabled: bool) -> void:
	if _switch_enabled == enabled:
		return
	_switch_enabled = enabled
	_apply_attachment_visuals()
	attachments_changed.emit()


func is_fully_automatic() -> bool:
	var definition := get_equipped_weapon()
	return _switch_enabled and definition != null and definition.supports_full_auto


func _get_fire_interval(definition: WeaponDefinition) -> float:
	if is_fully_automatic():
		return definition.full_auto_fire_interval
	return definition.fire_interval


func is_target_lock_enabled() -> bool:
	var definition := get_equipped_weapon()
	return _laser_enabled and definition != null


func get_aim_distance_override() -> float:
	var definition := get_equipped_weapon()
	if _sights_enabled and definition != null:
		return definition.sights_aim_distance
	return -1.0


func add_reserve_ammo(amount: int) -> void:
	var definition := get_equipped_weapon()
	if definition == null or amount <= 0:
		return
	_reserve_ammo[definition.weapon_id] = get_reserve_ammo() + amount
	ammo_changed.emit(get_magazine_ammo(), get_reserve_ammo())


func get_aim_target_position() -> Vector3:
	if (
		target_lock_component != null
		and is_target_lock_enabled()
		and target_lock_component.has_locked_target()
	):
		return target_lock_component.get_lock_point()

	var definition := get_equipped_weapon()
	var max_range := definition.max_range if definition != null else 50.0
	var query := _create_aim_query(max_range)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		shot_resolved.emit(null, false, query.to)
		return query.to
	return hit.position as Vector3


func _apply_equipped_weapon() -> void:
	var definition := get_equipped_weapon()
	_instantiate_weapon_visual(definition)
	animation_component.set_weapon_definition(definition)
	_apply_attachment_visuals()
	weapon_changed.emit(definition)
	ammo_changed.emit(get_magazine_ammo(), get_reserve_ammo())


func _finish_reload() -> void:
	var definition := get_equipped_weapon()
	if definition == null:
		return

	var missing_ammo := get_magazine_capacity() - get_magazine_ammo()
	var transferred_ammo := mini(missing_ammo, get_reserve_ammo())
	_magazine_ammo[definition.weapon_id] = (
		get_magazine_ammo() + transferred_ammo
	)
	_reserve_ammo[definition.weapon_id] = (
		get_reserve_ammo() - transferred_ammo
	)
	ammo_changed.emit(get_magazine_ammo(), get_reserve_ammo())
	reload_completed.emit()


func _fire_hitscan(definition: WeaponDefinition) -> Vector3:
	var query := _create_aim_query(definition.max_range)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		if (
			target_lock_component != null
			and is_target_lock_enabled()
			and target_lock_component.has_locked_target()
		):
			var assist_query := _create_lock_assist_query(
				definition.max_range
			)
			var assist_hit := (
				body.get_world_3d().direct_space_state.intersect_ray(
					assist_query
				)
			)
			if not assist_hit.is_empty():
				return _resolve_hitscan_hit(definition, assist_query, assist_hit)
		shot_resolved.emit(null, false, query.to)
		return query.to

	return _resolve_hitscan_hit(definition, query, hit)


func _apply_attachment_visuals() -> void:
	if weapon_model == null or not weapon_model.has_method("apply_attachment_visuals"):
		return
	weapon_model.call(
		"apply_attachment_visuals",
		_sights_enabled,
		_laser_enabled,
		_magazine_type,
		_switch_enabled
	)


func _update_laser_beam() -> void:
	if weapon_model == null or not weapon_model.has_method("update_laser_beam"):
		return
	if not is_laser_enabled() or not is_aiming() or is_reloading():
		if weapon_model.has_method("hide_laser_beam"):
			weapon_model.call("hide_laser_beam")
		return
	var definition := get_equipped_weapon()
	if definition == null:
		return
	var target_position := _get_laser_target_position(definition.max_range)
	weapon_model.call("update_laser_beam", target_position)


func _get_laser_target_position(max_range: float) -> Vector3:
	var query := _create_aim_query(max_range)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position", query.to) as Vector3


func _get_muzzle_position() -> Vector3:
	if muzzle_particles != null:
		return muzzle_particles.global_position
	if weapon_model != null:
		return weapon_model.global_position
	return weapon_socket.global_position


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var segment := to - from
	var length := segment.length()
	if length <= 0.05:
		return
	var direction := segment / length
	var visible_length := minf(tracer_length, length)
	var tracer := MeshInstance3D.new()
	tracer.name = "PlayerBulletTracer"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.018, visible_length)
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.albedo_color = Color(1.0, 0.82, 0.28, 0.7)
		_tracer_material.emission_enabled = true
		_tracer_material.emission = Color(1.0, 0.62, 0.1)
		_tracer_material.emission_energy_multiplier = 2.3
	mesh.material = _tracer_material
	tracer.mesh = mesh
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(tracer)
	tracer.global_position = from + direction * visible_length * 0.5
	tracer.look_at(to, Vector3.UP)
	var end_position := to - direction * visible_length * 0.5
	var travel_duration := clampf(length / tracer_speed, 0.015, tracer_lifetime)
	var tween := get_tree().create_tween()
	tween.tween_property(tracer, "global_position", end_position, travel_duration)
	tween.tween_callback(tracer.queue_free)


func _resolve_hitscan_hit(
	definition: WeaponDefinition,
	query: PhysicsRayQueryParameters3D,
	hit: Dictionary
) -> Vector3:
	var ray_direction := (query.to - query.from).normalized()

	var hit_position := hit.position as Vector3
	var hit_normal := hit.normal as Vector3
	var collider := hit.collider as Node
	var hitbox := _find_combat_hitbox(collider)
	var damageable := (
		hitbox.get_damageable()
		if hitbox != null
		else _find_damageable(collider)
	)
	if damageable != null:
		if hitbox != null:
			hitbox.resolve_damage(
				definition.damage,
				body,
				hit_position,
				ray_direction
			)
		else:
			damageable.apply_damage(
				definition.damage,
				body,
				hit_position,
				ray_direction
			)
		var fatal_hit := damageable.is_depleted()
		hit_confirmed.emit(fatal_hit)
		shot_resolved.emit(
			damageable.get_parent(),
			fatal_hit,
			hit_position
		)
		_play_npc_impact(hit_position)
		var blood_spray_multiplier := 1.0
		if hitbox != null and hitbox.hit_zone == CombatHitbox.HEAD_ZONE:
			blood_spray_multiplier = 3.0
		_spawn_blood_impact(
			hit_position,
			hit_normal,
			ray_direction,
			collider as Node3D,
			fatal_hit,
			blood_spray_multiplier
		)
	else:
		shot_resolved.emit(null, false, hit_position)
		_spawn_surface_impact(
			hit_position,
			hit_normal,
			collider as Node3D
		)
	return hit_position


func _create_aim_query(max_range: float) -> PhysicsRayQueryParameters3D:
	var screen_center := camera.get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_direction := camera.project_ray_normal(screen_center)
	var ray_end := ray_origin + ray_direction * max_range
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [body.get_rid()]
	query.collision_mask = AIM_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return query


func _create_lock_assist_query(max_range: float) -> PhysicsRayQueryParameters3D:
	var ray_origin := camera.global_position
	var lock_point := target_lock_component.get_lock_point()
	var ray_direction := (lock_point - ray_origin).normalized()
	var ray_end := ray_origin + ray_direction * max_range
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [body.get_rid()]
	query.collision_mask = AIM_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return query


func _play_gunshot() -> void:
	var definition := get_equipped_weapon()
	sound_component.play_gunshot(
		_get_muzzle_position(),
		definition.gunshot_sound if definition != null else null
	)


func _broadcast_gunshot() -> void:
	get_tree().call_group(
		&"gunshot_listener",
		&"hear_gunshot",
		_get_muzzle_position(),
		gunshot_alert_radius
	)


func _play_muzzle_flash() -> void:
	if muzzle_particles == null:
		return
	muzzle_particles.restart()


func _play_npc_impact(hit_position: Vector3) -> void:
	sound_component.play_npc_impact(hit_position)


func _spawn_blood_impact(
	hit_position: Vector3,
	hit_normal: Vector3,
	hit_direction: Vector3,
	hit_collider: Node3D,
	fatal_hit: bool,
	spray_multiplier := 1.0
) -> void:
	var effect := BLOOD_IMPACT_VFX.instantiate() as BloodImpactVFX
	get_tree().current_scene.add_child(effect)
	effect.setup_blood_hit(
		hit_position,
		hit_normal,
		hit_direction,
		hit_collider,
		fatal_hit,
		spray_multiplier
	)


func _spawn_surface_impact(
	hit_position: Vector3,
	hit_normal: Vector3,
	hit_collider: Node3D
) -> void:
	var is_metal := _is_metal_surface(hit_collider)
	sound_component.play_surface_impact(hit_position, is_metal)
	var effect := BLOOD_IMPACT_VFX.instantiate() as BloodImpactVFX
	get_tree().current_scene.add_child(effect)
	var impact_kind := BloodImpactVFX.SurfaceImpactKind.STONE
	if is_metal:
		impact_kind = BloodImpactVFX.SurfaceImpactKind.METAL
	effect.setup_surface_hit(
		hit_position,
		hit_normal,
		hit_collider,
		impact_kind
	)


func _find_damageable(collider: Node) -> DamageableComponent:
	var current := collider
	while current != null:
		var component := current.get_node_or_null(
			"DamageableComponent"
		) as DamageableComponent
		if component != null:
			return component
		current = current.get_parent()
	return null


func _find_combat_hitbox(collider: Node) -> CombatHitbox:
	var current := collider
	while current != null:
		if current is CombatHitbox:
			return current as CombatHitbox
		current = current.get_parent()
	return null


func _is_metal_surface(collider: Node) -> bool:
	var current := collider
	while current != null:
		if current is BaseVehicle:
			return true
		current = current.get_parent()
	return false


func _on_health_state_changed(
	_previous: PlayerHealthComponent.State,
	current: PlayerHealthComponent.State
) -> void:
	if current == PlayerHealthComponent.State.ALIVE:
		return

	cancel_reload()
	if _equipped_slot != 0:
		_equipped_slot = 0
		_apply_equipped_weapon()
