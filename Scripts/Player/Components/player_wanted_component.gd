class_name PlayerWantedComponent
extends Node

signal wanted_level_changed(previous: int, current: int)
signal wanted_cleared

const MAX_WANTED_LEVEL := 3

@export var player_path := NodePath("../..")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var health_component_path := NodePath("../HealthComponent")
@export_range(0.0, 100.0, 0.5) var visible_weapon_heat_per_second := 25.0
@export_range(0.0, 100.0, 1.0) var witnessed_sale_heat := 50.0
@export_range(0.0, 100.0, 1.0) var arrest_heat_reset := 25.0
@export_range(0.05, 1.0, 0.05) var witness_heartbeat_grace := 0.3

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

var _wanted_level := 0
var _trigger_territory_id := &""
var _weapon_witness_remaining := 0.0


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


func report_sale(world_position: Vector3) -> void:
	if _has_police_witness(world_position):
		add_suspicion_heat(world_position, witnessed_sale_heat)


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
	set_wanted_level(maxi(_wanted_level, next_level))


func set_wanted_level(level: int) -> void:
	var next_level := clampi(level, 0, MAX_WANTED_LEVEL)
	if next_level == _wanted_level:
		return
	var previous := _wanted_level
	_wanted_level = next_level
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


func _find_trigger_territory() -> TerritoryBoundary:
	for node in get_tree().get_nodes_in_group("territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.territory_id == _trigger_territory_id:
			return boundary
	return null


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
