class_name StoreCustomerVisit3D
extends Node3D

const AMBIENT_CUSTOMER_GROUP := &"ambient_customer"

@export var property_id: StringName
@export var entrance_path := NodePath("Entrance")
@export var browse_path := NodePath("Browse")
@export var counter_path := NodePath("Counter")
@export var exit_path := NodePath("Exit")
@export_range(1.0, 120.0, 1.0) var presentation_radius := 55.0
@export_range(1.0, 120.0, 1.0) var customer_search_radius := 40.0
@export_range(0.1, 60.0, 0.1) var ticket_lifetime := 15.0
@export_flags_3d_physics var approach_collision_mask := 1

@onready var entrance := get_node(entrance_path) as ActivitySpot3D
@onready var browse := get_node(browse_path) as ActivitySpot3D
@onready var counter := get_node(counter_path) as ActivitySpot3D
@onready var exit_destination := get_node(exit_path) as ActivitySpot3D

var _properties: PlayerPropertyComponent
var _world_time: WorldTimeComponent
var _player: CharacterBody3D
var _ticket_remaining := 0.0
var _visitor: WeakRef
var _external_host: DealerNPC


func configure_external_dealer_visit(host: DealerNPC) -> void:
	_external_host = host


func offer_external_ticket() -> void:
	if is_instance_valid(_external_host) and not is_busy():
		_ticket_remaining = ticket_lifetime


func _ready() -> void:
	if is_instance_valid(_external_host):
		add_to_group(&"dealer_customer_visit")
		call_deferred("_resolve_external_dependencies")
	else:
		add_to_group(&"store_customer_visit")
		call_deferred("_resolve_dependencies")


func _process(delta: float) -> void:
	if _ticket_remaining <= 0.0:
		return
	_ticket_remaining = maxf(_ticket_remaining - delta, 0.0)
	if not _can_present_visit(false):
		_ticket_remaining = 0.0
		return
	var customer := _find_nearest_eligible_customer()
	if customer != null and customer.try_begin_store_visit(self):
		_visitor = weakref(customer)
		_ticket_remaining = 0.0
		if is_instance_valid(_external_host):
			_external_host.begin_shop_interaction(customer)


func try_reserve_itinerary(npc: Node) -> bool:
	if npc == null or is_busy():
		return false
	var reserved: Array[ActivitySpot3D] = []
	for destination in get_destinations():
		if not is_instance_valid(destination):
			for held in reserved:
				held.release(npc)
			return false
		if destination.try_reserve(npc) < 0:
			for held in reserved:
				held.release(npc)
			return false
		reserved.append(destination)
	_visitor = weakref(npc)
	return true


func release_itinerary(npc: Node) -> void:
	if npc == null:
		return
	for destination in get_destinations():
		if is_instance_valid(destination):
			destination.release(npc)
	var current := get_active_visitor()
	if current == null or current == npc:
		_visitor = null
		if is_instance_valid(_external_host):
			_external_host.end_shop_interaction()


func has_complete_reservation(npc: Node) -> bool:
	if npc == null:
		return false
	for destination in get_destinations():
		if (
			not is_instance_valid(destination)
			or not destination.has_reservation(npc)
		):
			return false
	return true


func get_destination(stage_index: int) -> ActivitySpot3D:
	var destinations := get_destinations()
	if stage_index < 0 or stage_index >= destinations.size():
		return null
	var destination := destinations[stage_index]
	return destination if is_instance_valid(destination) else null


func get_destinations() -> Array[ActivitySpot3D]:
	return [entrance, browse, counter, exit_destination]


func get_active_visitor() -> CustomerNPC:
	if _visitor == null:
		return null
	var npc := _visitor.get_ref() as CustomerNPC
	if not is_instance_valid(npc):
		_visitor = null
		return null
	return npc


func is_busy() -> bool:
	var visitor := get_active_visitor()
	if visitor == null:
		return false
	if not has_complete_reservation(visitor):
		_visitor = null
		return false
	return true


func has_pending_ticket() -> bool:
	return _ticket_remaining > 0.0


func get_reserved_destination_count() -> int:
	var count := 0
	for destination in get_destinations():
		if is_instance_valid(destination):
			count += destination.get_reserved_count()
	return count


func _resolve_dependencies() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	_world_time = get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if _player != null:
		_properties = _player.get_node_or_null(
			"Components/PropertyComponent"
		) as PlayerPropertyComponent
	if (
		_properties != null
		and not _properties.business_sale_processed.is_connected(
			_on_business_sale_processed
		)
	):
		_properties.business_sale_processed.connect(_on_business_sale_processed)


func _resolve_external_dependencies() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	_world_time = get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent


func _on_business_sale_processed(
	sale_property_id: StringName,
	sale_absolute_minute: int
) -> void:
	if (
		sale_property_id != property_id
		or _world_time == null
		or sale_absolute_minute != _world_time.get_absolute_minute()
		or is_busy()
		or not _can_present_visit(true)
	):
		return
	_ticket_remaining = ticket_lifetime


func _can_present_visit(require_stock := true) -> bool:
	if is_instance_valid(_external_host):
		return (
			_player != null
			and not _external_host.is_defeated()
			and not _external_host.is_hostile()
			and _external_host.activity_zone != null
			and _external_host.activity_zone.faction == TerritoryStatsComponent.OwnerFaction.PLAYER
			and _player.global_position.distance_squared_to(_external_host.global_position)
			<= presentation_radius * presentation_radius
		)
	if _player == null or _properties == null or _world_time == null:
		return false
	if not _properties.owns(property_id):
		return false
	var definition := PropertyCatalog.get_by_id(property_id)
	if definition == null:
		return false
	if require_stock and _properties.get_business_stock(property_id) <= 0:
		return false
	var minute := posmod(
		_world_time.get_absolute_minute(),
		WorldTimeComponent.MINUTES_PER_DAY
	)
	if (
		minute < definition.business_open_minute
		or minute >= definition.business_close_minute
	):
		return false
	return _player.global_position.distance_squared_to(global_position) <= (
		presentation_radius * presentation_radius
	)


func _find_nearest_eligible_customer() -> CustomerNPC:
	var nearest: CustomerNPC
	var nearest_distance_squared := customer_search_radius * customer_search_radius
	for node in get_tree().get_nodes_in_group(AMBIENT_CUSTOMER_GROUP):
		var customer := node as CustomerNPC
		if (
			customer == null
			or not customer.can_accept_store_visit()
			or not _has_clear_store_route(customer)
		):
			continue
		var distance_squared := customer.global_position.distance_squared_to(
			global_position
		)
		if distance_squared <= nearest_distance_squared:
			nearest = customer
			nearest_distance_squared = distance_squared
	return nearest


func _has_clear_store_route(customer: CustomerNPC) -> bool:
	if customer == null or not is_instance_valid(entrance):
		return false
	var network := customer.get_pedestrian_network()
	if network == null:
		return false
	var current_anchor := customer.get_current_waypoint()
	if not is_instance_valid(current_anchor):
		current_anchor = network.get_nearest_waypoint(customer.global_position)
	var entrance_anchor := network.get_nearest_waypoint(
		entrance.global_position,
		30.0
	)
	var exit_anchor := network.get_nearest_waypoint(
		exit_destination.global_position,
		30.0
	)
	var resume_waypoint := customer.get_route_target()
	if not is_instance_valid(resume_waypoint):
		resume_waypoint = customer.get_current_waypoint()
	if (
		not is_instance_valid(current_anchor)
		or not is_instance_valid(entrance_anchor)
		or not is_instance_valid(exit_anchor)
		or not is_instance_valid(resume_waypoint)
	):
		return false
	var approach := network.find_path(current_anchor, entrance_anchor)
	var return_path := network.find_path(exit_anchor, resume_waypoint)
	if approach.is_empty() or return_path.is_empty():
		return false
	# Store travel uses a direct final approach, so only choose visitors whose
	# authored approach stays on the same side of every driving lane.
	if (
		network.path_requires_crossing(approach)
		or network.path_requires_crossing(return_path)
	):
		return false
	return true


func _has_clear_path(
	from_position: Vector3,
	to_position: Vector3,
	customer: CustomerNPC
) -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		from_position + Vector3.UP,
		to_position + Vector3.UP,
		approach_collision_mask,
		[customer.get_rid()]
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.direct_space_state.intersect_ray(query).is_empty()
