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

@export_category("Scene References")
@export var animation_component_path := NodePath("../AnimationComponent")
@export var health_component_path := NodePath("../HealthComponent")
@export var sound_component_path := NodePath("../SoundComponent")
@export var target_lock_component_path := NodePath("../TargetLockComponent")
@export var body_path := NodePath("../..")
@export var camera_path := NodePath("../../CameraPivot/SpringArm3D/Camera3D")
@export var weapon_model_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton/WeaponSocket/EquippedWeapon"
)
@export var muzzle_particles_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton/WeaponSocket/"
	+ "EquippedWeapon/Mesh/MuzzleFlash/MuzzlePlanes"
)

@export_category("Loadout")
@export var pistol_definition: WeaponDefinition

@export_category("Input")
@export var aim_action := &"aim"
@export var fire_action := &"fire"
@export var reload_action := &"reload"
@export var next_weapon_action := &"weapon_next"
@export var previous_weapon_action := &"weapon_previous"

@export_category("World Response")
@export_range(1.0, 200.0, 1.0) var gunshot_alert_radius := 45.0

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
@onready var weapon_model := get_node(weapon_model_path) as Node3D
@onready var muzzle_particles := (
	get_node_or_null(muzzle_particles_path) as GPUParticles3D
)

var _slots: Array[WeaponDefinition] = []
var _magazine_ammo: Dictionary[StringName, int] = {}
var _reserve_ammo: Dictionary[StringName, int] = {}
var _equipped_slot := 0
var _cooldown_remaining := 0.0
var _reload_remaining := 0.0


func _ready() -> void:
	BloodImpactVFX.prewarm_resources()
	call_deferred("_prewarm_blood_vfx_runtime")
	_slots.append(null)
	if pistol_definition != null:
		_slots.append(pistol_definition)
		_magazine_ammo[pistol_definition.weapon_id] = (
			pistol_definition.magazine_capacity
		)
		_reserve_ammo[pistol_definition.weapon_id] = (
			pistol_definition.starting_reserve_ammo
		)
	health_component.state_changed.connect(_on_health_state_changed)
	if muzzle_particles != null:
		muzzle_particles.emitting = false
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


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _reload_remaining <= 0.0:
		return

	_reload_remaining = maxf(_reload_remaining - delta, 0.0)
	if is_zero_approx(_reload_remaining):
		_finish_reload()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(next_weapon_action):
		if is_aiming():
			if target_lock_component != null:
				target_lock_component.cycle_locked_target(1)
			get_viewport().set_input_as_handled()
			return
		cycle_weapon(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(previous_weapon_action):
		if is_aiming():
			if target_lock_component != null:
				target_lock_component.cycle_locked_target(-1)
			get_viewport().set_input_as_handled()
			return
		cycle_weapon(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(fire_action):
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
	_cooldown_remaining = definition.fire_interval
	animation_component.trigger_recoil()
	_play_gunshot()
	_broadcast_gunshot()
	_play_muzzle_flash()
	var hit_position := _fire_hitscan(definition)
	ammo_changed.emit(get_magazine_ammo(), get_reserve_ammo())
	fired.emit(hit_position)
	return true


func try_reload() -> bool:
	var definition := get_equipped_weapon()
	if (
		definition == null
		or not health_component.is_alive()
		or is_reloading()
		or get_magazine_ammo() >= definition.magazine_capacity
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


func get_aim_target_position() -> Vector3:
	if (
		target_lock_component != null
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
	weapon_model.visible = definition != null
	weapon_changed.emit(definition)
	ammo_changed.emit(get_magazine_ammo(), get_reserve_ammo())


func _finish_reload() -> void:
	var definition := get_equipped_weapon()
	if definition == null:
		return

	var missing_ammo := definition.magazine_capacity - get_magazine_ammo()
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
		_spawn_blood_impact(
			hit_position,
			hit_normal,
			ray_direction,
			collider as Node3D,
			fatal_hit
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
	sound_component.play_gunshot(weapon_model.global_position)


func _broadcast_gunshot() -> void:
	get_tree().call_group(
		&"gunshot_listener",
		&"hear_gunshot",
		weapon_model.global_position,
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
	fatal_hit: bool
) -> void:
	var effect := BLOOD_IMPACT_VFX.instantiate() as BloodImpactVFX
	get_tree().current_scene.add_child(effect)
	effect.setup_blood_hit(
		hit_position,
		hit_normal,
		hit_direction,
		hit_collider,
		fatal_hit
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
