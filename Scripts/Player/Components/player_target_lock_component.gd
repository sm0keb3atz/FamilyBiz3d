class_name PlayerTargetLockComponent
extends Node

const HITBOX_COLLISION_LAYER := 1 << 2
const WORLD_COLLISION_LAYER := 1 << 0
const LOCK_QUERY_MASK := WORLD_COLLISION_LAYER | HITBOX_COLLISION_LAYER
const OUTLINE_SHADER := preload(
	"res://Assets/VFX/Shaders/target_lock_outline.gdshader"
)

signal lock_changed(previous: Node, current: Node)

@export_category("Scene References")
@export var body_path := NodePath("../..")
@export var camera_path := NodePath("../../CameraPivot/SpringArm3D/Camera3D")
@export var weapon_component_path := NodePath("../WeaponComponent")

@export_category("Targeting")
@export_range(5.0, 150.0, 1.0) var lock_range := 55.0
@export_range(16.0, 720.0, 1.0) var acquire_screen_radius := 145.0
@export_range(16.0, 900.0, 1.0) var keep_screen_radius := 310.0
@export_range(16.0, 1200.0, 1.0) var cycle_screen_radius := 900.0
@export_range(0.0, 2.0, 0.05) var blocked_break_grace := 0.45
@export_range(0.2, 2.2, 0.05) var lock_point_height := 1.25
@export_range(16.0, 400.0, 1.0) var manual_break_mouse_pixels := 70.0
@export_range(0.0, 400.0, 1.0) var manual_break_recovery_pixels_per_second := 70.0
@export_range(0.0, 1.0, 0.01) var minimum_aim_time_before_acquire := 0.18
@export_range(0.0, 2.0, 0.01) var reacquire_cooldown_time := 0.45
@export_range(0.0, 2.0, 0.01) var manual_break_cooldown_time := 0.75

@export_category("Outline")
@export var outline_color := Color(1.0, 0.08, 0.03, 1.0)
@export_range(0.0, 0.3, 0.005) var outline_thickness := 0.035
@export_range(0.0, 4.0, 0.05) var outline_energy := 1.4

@onready var body := get_node(body_path) as CharacterBody3D
@onready var camera := get_node(camera_path) as Camera3D
@onready var weapon_component := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)

var _locked_target: Node3D
var _blocked_elapsed := 0.0
var _manual_break_pressure := 0.0
var _aim_elapsed := 0.0
var _acquire_cooldown := 0.0
var _outline_material: ShaderMaterial
var _outlined_mesh_overlays: Dictionary[int, Array] = {}


func _ready() -> void:
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline_material.set_shader_parameter(
		&"outline_color",
		Vector3(outline_color.r, outline_color.g, outline_color.b)
	)
	_outline_material.set_shader_parameter(&"thickness", outline_thickness)
	_outline_material.set_shader_parameter(&"outline_energy", outline_energy)
	_outline_material.set_shader_parameter(&"merge_group", true)


func _process(delta: float) -> void:
	if not weapon_component.is_aiming():
		_aim_elapsed = 0.0
		_acquire_cooldown = 0.0
		_set_locked_target(null)
		return
	_aim_elapsed += delta
	_acquire_cooldown = maxf(_acquire_cooldown - delta, 0.0)
	_manual_break_pressure = move_toward(
		_manual_break_pressure,
		0.0,
		manual_break_recovery_pixels_per_second * delta
	)

	var had_locked_target := has_locked_target()
	if _is_valid_current_target(delta):
		return

	if had_locked_target:
		_clear_lock(false)
		return
	if _acquire_cooldown > 0.0:
		return
	if _aim_elapsed < minimum_aim_time_before_acquire:
		return
	_set_locked_target(_find_best_target())


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseMotion
		and has_locked_target()
		and weapon_component.is_aiming()
	):
		var motion := event as InputEventMouseMotion
		_manual_break_pressure += motion.relative.length()
		if _manual_break_pressure >= manual_break_mouse_pixels:
			_clear_lock(true)
			get_viewport().set_input_as_handled()
			return

	if not has_locked_target():
		return
	if event.is_action_pressed(weapon_component.next_weapon_action):
		if cycle_locked_target(1):
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(weapon_component.previous_weapon_action):
		if cycle_locked_target(-1):
			get_viewport().set_input_as_handled()


func has_locked_target() -> bool:
	return is_instance_valid(_locked_target) and not _is_target_defeated(
		_locked_target
	)


func get_locked_target() -> Node3D:
	return _locked_target if has_locked_target() else null


func get_lock_point() -> Vector3:
	if not has_locked_target():
		return Vector3.ZERO
	return _get_target_lock_point(_locked_target)


func clear_lock() -> void:
	_clear_lock(false)


func cycle_locked_target(direction: int) -> bool:
	if direction == 0 or not has_locked_target():
		return false
	var candidates := _get_sorted_candidates(cycle_screen_radius)
	if candidates.size() <= 1:
		return false
	var current_index := candidates.find(_locked_target)
	if current_index < 0:
		_set_locked_target(candidates[0])
		return true
	_set_locked_target(candidates[wrapi(
		current_index + signi(direction),
		0,
		candidates.size()
	)])
	return true


func get_outline_mesh_count() -> int:
	return _outlined_mesh_overlays.size()


func _is_valid_current_target(delta: float) -> bool:
	if not has_locked_target():
		_blocked_elapsed = 0.0
		return false
	if not _is_target_in_range(_locked_target):
		return false
	if not _is_target_near_screen_center(_locked_target, keep_screen_radius):
		return false
	if _has_line_of_sight(_locked_target):
		_blocked_elapsed = 0.0
		return true
	_blocked_elapsed += delta
	return _blocked_elapsed < blocked_break_grace


func _find_best_target() -> Node3D:
	var candidates := _get_sorted_candidates(acquire_screen_radius)
	if candidates.is_empty():
		return null
	return candidates[0]


func _get_sorted_candidates(screen_radius: float) -> Array[Node3D]:
	var scored: Array[Dictionary] = []
	var screen_center := camera.get_viewport().get_visible_rect().size * 0.5
	for node in get_tree().get_nodes_in_group(&"lock_target"):
		if not is_instance_valid(node):
			continue
		var target: Node3D = node as Node3D
		if target == null:
			continue
		if not _is_target_candidate(target, screen_radius):
			continue
		var screen_position := camera.unproject_position(
			_get_target_lock_point(target)
		)
		var screen_distance := screen_position.distance_to(screen_center)
		var world_distance := body.global_position.distance_to(
			target.global_position
		)
		scored.append({
			"target": target,
			"score": screen_distance + world_distance * 2.0,
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) < float(b["score"])
	)

	var result: Array[Node3D] = []
	for item in scored:
		var candidate: Variant = item["target"]
		if is_instance_valid(candidate) and candidate is Node3D:
			result.append(candidate as Node3D)
	return result


func _is_target_candidate(target: Node3D, screen_radius: float) -> bool:
	return (
		is_instance_valid(target)
		and target.visible
		and not _is_target_defeated(target)
		and _is_target_in_range(target)
		and _is_target_near_screen_center(target, screen_radius)
		and _has_line_of_sight(target)
	)


func _is_target_defeated(target: Node) -> bool:
	if not is_instance_valid(target):
		return true
	if not target.has_method("is_defeated"):
		return false
	return bool(target.call("is_defeated"))


func _is_target_in_range(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	return (
		body.global_position.distance_squared_to(target.global_position)
		<= lock_range * lock_range
	)


func _is_target_near_screen_center(
	target: Node3D,
	screen_radius: float
) -> bool:
	if not is_instance_valid(target):
		return false
	var lock_point := _get_target_lock_point(target)
	if camera.is_position_behind(lock_point):
		return false
	var screen_center := camera.get_viewport().get_visible_rect().size * 0.5
	var screen_position := camera.unproject_position(lock_point)
	return screen_position.distance_squared_to(screen_center) <= (
		screen_radius * screen_radius
	)


func _has_line_of_sight(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		_get_target_lock_point(target)
	)
	query.exclude = [body.get_rid()]
	query.collision_mask = LOCK_QUERY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	return _is_node_or_descendant(hit.collider as Node, target)


func _get_target_lock_point(target: Node3D) -> Vector3:
	if not is_instance_valid(target):
		return Vector3.ZERO
	return target.global_position + Vector3.UP * lock_point_height


func _clear_lock(from_manual_break: bool) -> void:
	if from_manual_break:
		_acquire_cooldown = manual_break_cooldown_time
	else:
		_acquire_cooldown = maxf(_acquire_cooldown, reacquire_cooldown_time)
	_set_locked_target(null)


func _set_locked_target(target: Node3D) -> void:
	if _locked_target != null and not is_instance_valid(_locked_target):
		_locked_target = null
	if target != null and not is_instance_valid(target):
		target = null
	var previous: Node3D = (
		_locked_target if is_instance_valid(_locked_target) else null
	)
	if previous == target:
		return
	_clear_outline()
	_locked_target = target
	_blocked_elapsed = 0.0
	_manual_break_pressure = 0.0
	if has_locked_target():
		_apply_outline(_locked_target)
	lock_changed.emit(previous, _locked_target)


func _apply_outline(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var root := target.get_node_or_null("Visual") as Node
	if root == null:
		root = target
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh == null or not mesh.visible:
			continue
		var id := mesh.get_instance_id()
		_outlined_mesh_overlays[id] = [mesh, mesh.material_overlay]
		mesh.material_overlay = _outline_material


func _clear_outline() -> void:
	for item in _outlined_mesh_overlays.values():
		var mesh_object: Variant = item[0]
		if is_instance_valid(mesh_object) and mesh_object is MeshInstance3D:
			var mesh := mesh_object as MeshInstance3D
			mesh.material_overlay = item[1] as Material
	_outlined_mesh_overlays.clear()


func _is_node_or_descendant(node: Node, target: Node) -> bool:
	if not is_instance_valid(node) or not is_instance_valid(target):
		return false
	var current := node
	while current != null:
		if current == target:
			return true
		current = current.get_parent()
	return false
