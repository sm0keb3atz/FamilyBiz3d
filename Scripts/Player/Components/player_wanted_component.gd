class_name PlayerWantedComponent
extends Node

signal wanted_level_changed(previous: int, current: int)
signal wanted_cleared
signal escape_progress_changed(progress: float, escaping: bool)
signal police_search_updated(world_position: Vector3, revision: int)

const MAX_WANTED_LEVEL := 3

@export var player_path := NodePath("../..")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var health_component_path := NodePath("../HealthComponent")
@export_range(0.0, 100.0, 0.5) var visible_weapon_heat_per_second := 25.0
@export_range(0.0, 100.0, 1.0) var witnessed_sale_heat := 50.0
@export_range(0.0, 100.0, 1.0) var witnessed_solicitation_heat := 25.0
@export_range(0.0, 100.0, 1.0) var arrest_heat_reset := 25.0
@export_range(0.05, 1.0, 0.05) var witness_heartbeat_grace := 0.3
@export_range(1.0, 30.0, 0.5) var escape_seconds_per_star := 8.0
@export_range(0.05, 1.0, 0.05) var visual_contact_grace := 0.3
@export_range(0.5, 10.0, 0.5) var dispatch_update_distance := 2.5

@onready var player := get_node(player_path) as CharacterBody3D
@onready var weapon_component := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)
@onready var health_component := (
	get_node(health_component_path) as PlayerHealthComponent
)

var wanted_level: int:
	get:
		return _wanted_level

var escape_progress: float:
	get:
		return _escape_progress

var is_escaping: bool:
	get:
		return _is_escaping

var police_search_position: Vector3:
	get:
		return _police_search_position

var police_search_revision: int:
	get:
		return _police_search_revision

var has_police_search_position: bool:
	get:
		return _has_police_search_position

var _wanted_level := 0
var _trigger_territory_id := &""
var _weapon_witness_remaining := 0.0
var _visual_contact_remaining := 0.0
var _escape_progress := 1.0
var _is_escaping := false
var _police_search_position := Vector3.ZERO
var _police_search_revision := 0
var _has_police_search_position := false


func _ready() -> void:
	weapon_component.shot_resolved.connect(_on_player_shot_resolved)
	health_component.respawn_completed.connect(_on_respawn_completed)
	for node in get_tree().get_nodes_in_group("territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if (
			boundary != null
			and boundary.stats != null
		):
			boundary.stats.heat_changed.connect(
				_on_territory_heat_changed.bind(boundary)
			)
	set_process(true)


func _process(delta: float) -> void:
	_weapon_witness_remaining = maxf(
		_weapon_witness_remaining - delta,
		0.0
	)
	_visual_contact_remaining = maxf(
		_visual_contact_remaining - delta,
		0.0
	)
	_update_escape(delta)
	if _weapon_witness_remaining > 0.0 and _wanted_level == 0:
		add_suspicion_heat(
			player.global_position,
			visible_weapon_heat_per_second * delta
		)
	if _wanted_level == 0:
		var boundary := TerritoryBoundary.find_at_position(
			get_tree(),
			player.global_position
		)
		if (
			boundary != null
			and boundary.stats != null
			and boundary.stats.heat >= 100.0
		):
			_trigger_territory_id = boundary.territory_id
			set_wanted_level(1)


func report_visible_weapon_witness() -> void:
	if weapon_component.get_equipped_weapon() == null:
		return
	_weapon_witness_remaining = witness_heartbeat_grace


func report_police_visual_contact(
	world_position: Vector3 = Vector3.INF
) -> void:
	if _wanted_level <= 0:
		return
	_visual_contact_remaining = visual_contact_grace
	_set_escape_state(1.0, false)
	if world_position.is_finite():
		_update_police_search_position(world_position)


func report_police_incident(world_position: Vector3) -> void:
	_update_police_search_position(world_position)


func report_sale(world_position: Vector3) -> void:
	if _has_police_witness(world_position):
		report_police_incident(world_position)
		add_suspicion_heat(world_position, witnessed_sale_heat)


func report_solicitation(
	world_position: Vector3,
	solicitation_radius: float
) -> void:
	if _has_police_in_radius(world_position, solicitation_radius):
		report_police_incident(world_position)
		add_suspicion_heat(
			world_position,
			witnessed_solicitation_heat
		)


func add_suspicion_heat(world_position: Vector3, amount: float) -> void:
	if amount <= 0.0:
		return
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(),
		world_position
	)
	if boundary == null or boundary.stats == null:
		return
	_trigger_territory_id = boundary.territory_id
	boundary.stats.add_heat(amount)
	if boundary.stats.heat >= 100.0:
		set_wanted_level(1)


func report_violence(target: Node, fatal: bool) -> void:
	if target == null:
		return
	var next_level := 3 if fatal else 2
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(),
		player.global_position
	)
	if boundary != null:
		_trigger_territory_id = boundary.territory_id
	report_police_incident(player.global_position)
	set_wanted_level(maxi(_wanted_level, next_level))


func set_wanted_level(level: int) -> void:
	var next_level := clampi(level, 0, MAX_WANTED_LEVEL)
	if next_level == _wanted_level:
		return
	var previous := _wanted_level
	_wanted_level = next_level
	if _wanted_level > previous:
		if not _has_police_search_position:
			report_police_incident(player.global_position)
		_visual_contact_remaining = 0.0
		_set_escape_state(1.0, false)
	elif _wanted_level == 0:
		_set_escape_state(1.0, false)
	wanted_level_changed.emit(previous, _wanted_level)
	if _wanted_level == 0:
		wanted_cleared.emit()


func resolve_arrest() -> void:
	clear_wanted(true)


func clear_wanted(cool_territory := true) -> void:
	if cool_territory:
		var boundary := _find_trigger_territory()
		if boundary != null and boundary.stats != null:
			boundary.stats.set_heat(arrest_heat_reset)
	set_wanted_level(0)
	_weapon_witness_remaining = 0.0
	_visual_contact_remaining = 0.0
	_set_escape_state(1.0, false)
	_clear_police_search()


func export_save_data() -> Dictionary:
	return {
		"wanted_level": _wanted_level,
		"trigger_territory_id": String(_trigger_territory_id),
	}


func import_save_data(data: Dictionary) -> void:
	_trigger_territory_id = StringName(
		str(data.get("trigger_territory_id", ""))
	)
	set_wanted_level(int(data.get("wanted_level", 0)))


func _on_player_shot_resolved(
	target: Node,
	fatal: bool,
	_hit_position: Vector3
) -> void:
	if target != null:
		report_violence(target, fatal)
		return
	if _has_police_hearing(player.global_position):
		report_police_incident(player.global_position)
		set_wanted_level(maxi(_wanted_level, 2))


func _has_police_witness(world_position: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("police_npc"):
		if (
			node.has_method("can_witness_position")
			and bool(node.call("can_witness_position", world_position))
		):
			return true
	return false


func _has_police_hearing(world_position: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("police_npc"):
		if (
			node.has_method("can_hear_position")
			and bool(node.call("can_hear_position", world_position))
		):
			return true
	return false


func _has_police_in_radius(
	world_position: Vector3,
	radius: float
) -> bool:
	var radius_squared := maxf(radius, 0.0) * maxf(radius, 0.0)
	for node in get_tree().get_nodes_in_group("police_npc"):
		var police := node as PoliceNPC
		if (
			police != null
			and police.is_pool_active()
			and not police.is_defeated()
			and police.global_position.distance_squared_to(world_position)
			<= radius_squared
		):
			return true
	return false


func _find_trigger_territory() -> TerritoryBoundary:
	for node in get_tree().get_nodes_in_group("territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.territory_id == _trigger_territory_id:
			return boundary
	return null


func _update_escape(delta: float) -> void:
	if _wanted_level <= 0:
		_set_escape_state(1.0, false)
		return
	if _visual_contact_remaining > 0.0:
		_set_escape_state(1.0, false)
		return
	var next_progress := maxf(
		_escape_progress
		- delta / maxf(escape_seconds_per_star, 0.01),
		0.0
	)
	_set_escape_state(next_progress, true)
	if next_progress > 0.0:
		return
	var next_level := _wanted_level - 1
	if next_level <= 0:
		clear_wanted(true)
		return
	set_wanted_level(next_level)
	_set_escape_state(1.0, true)


func _set_escape_state(progress: float, escaping: bool) -> void:
	var next_progress := clampf(progress, 0.0, 1.0)
	if (
		is_equal_approx(next_progress, _escape_progress)
		and escaping == _is_escaping
	):
		return
	_escape_progress = next_progress
	_is_escaping = escaping
	escape_progress_changed.emit(_escape_progress, _is_escaping)


func _update_police_search_position(
	world_position: Vector3,
	force := false
) -> void:
	if not world_position.is_finite():
		return
	var update_distance_squared := (
		dispatch_update_distance * dispatch_update_distance
	)
	if (
		not force
		and _has_police_search_position
		and _police_search_position.distance_squared_to(world_position)
		< update_distance_squared
	):
		return
	_police_search_position = world_position
	_has_police_search_position = true
	_police_search_revision += 1
	police_search_updated.emit(
		_police_search_position,
		_police_search_revision
	)


func _clear_police_search() -> void:
	if not _has_police_search_position:
		return
	_has_police_search_position = false
	_police_search_position = Vector3.ZERO
	_police_search_revision += 1


func _on_respawn_completed() -> void:
	if _wanted_level > 0:
		clear_wanted(true)


func _on_territory_heat_changed(
	current: float,
	boundary: TerritoryBoundary
) -> void:
	if current < 100.0 or _wanted_level > 0:
		return
	_trigger_territory_id = boundary.territory_id
	set_wanted_level(1)
