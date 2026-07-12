class_name DealerSpawner
extends Marker3D

@export var dealer_scene: PackedScene
@export var dealer_container_path := NodePath("../Gameplay")
@export var territory_id: StringName
@export_range(1, 12, 1) var dealer_count := 3
@export var guarantee_level_one_in_territory := true
@export_range(0.0, 20.0, 0.5) var spawn_radius := 4.0
@export_range(-1.0, 1.0, 0.01) var spawn_vertical_offset := -0.1
@export var spawn_on_ready := true

var _random := RandomNumberGenerator.new()
var _spawned_dealers: Array[DealerNPC] = []


func _ready() -> void:
	_random.randomize()
	if spawn_on_ready:
		spawn_dealers()


func spawn_dealers() -> Array[DealerNPC]:
	for dealer in _spawned_dealers:
		if is_instance_valid(dealer):
			dealer.queue_free()
	_spawned_dealers.clear()

	if dealer_scene == null:
		return _spawned_dealers
	var container := get_node_or_null(dealer_container_path)
	if container == null:
		container = get_parent()
	if container == null:
		return _spawned_dealers

	var needs_level_one := (
		guarantee_level_one_in_territory
		and not _territory_has_level_one_dealer()
	)
	for index in range(dealer_count):
		var dealer := dealer_scene.instantiate() as DealerNPC
		if dealer == null:
			continue
		container.add_child(dealer)
		dealer.global_transform = global_transform
		dealer.global_position += _get_spawn_offset(index)
		dealer.global_position.y += spawn_vertical_offset
		var level := 1
		if not (needs_level_one and index == 0):
			level = DealerRoleComponent.roll_weighted_level(_random)
		var role := dealer.get_role_component()
		if role == null:
			dealer.queue_free()
			continue
		role.territory_id = territory_id
		dealer.configure_dealer(level, false)
		_spawned_dealers.append(dealer)
	return _spawned_dealers


func get_spawned_dealers() -> Array[DealerNPC]:
	return _spawned_dealers.duplicate()


func _get_spawn_offset(index: int) -> Vector3:
	if spawn_radius <= 0.0 or dealer_count <= 1:
		return Vector3.ZERO
	var angle := TAU * float(index) / float(dealer_count)
	return Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius


func _territory_has_level_one_dealer() -> bool:
	for node in get_tree().get_nodes_in_group("dealer_npc"):
		var dealer := node as DealerNPC
		if dealer == null:
			continue
		var role := dealer.get_role_component()
		if role == null:
			continue
		if role.is_wholesaler:
			continue
		if role.dealer_level != 1:
			continue
		if _dealer_is_in_spawner_territory(dealer):
			return true
	return false


func _dealer_is_in_spawner_territory(dealer: DealerNPC) -> bool:
	if String(territory_id) == "":
		var spawner_territory := TerritoryBoundary.find_at_position(
			get_tree(),
			global_position
		)
		var dealer_territory := TerritoryBoundary.find_at_position(
			get_tree(),
			dealer.global_position
		)
		return (
			spawner_territory != null
			and dealer_territory != null
			and spawner_territory.territory_id == dealer_territory.territory_id
		)
	var role := dealer.get_role_component()
	if role != null and role.territory_id == territory_id:
		return true
	var dealer_territory := TerritoryBoundary.find_at_position(
		get_tree(),
		dealer.global_position
	)
	return dealer_territory != null and dealer_territory.territory_id == territory_id
