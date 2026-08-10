class_name DealerNPC
extends BaseNPC

## Dealer composition root. Shop behavior belongs to DealerRoleComponent.

const WHOLESALER_KILL_EXPERIENCE := 2500.0
const WHOLESALER_CORPSE_CASH := 50000

@export_category("Bodyguard")
@export_range(5.0, 40.0, 0.5) var bodyguard_target_radius := 18.0
@export_range(5.0, 40.0, 0.5) var bodyguard_combat_leash_radius := 20.0
@export_range(10.0, 80.0, 0.5) var bodyguard_hard_recall_distance := 30.0
@export_range(0.25, 5.0, 0.25) var bodyguard_lost_sight_grace := 1.5

@onready var role_component := (
	$Components/RoleComponent as DealerRoleComponent
)

var product: ProductDefinition:
	get:
		var role := get_role_component()
		return role.get_primary_product() if role != null else null

var _hostile := false
var _target_player: CharacterBody3D
var _combat_target: Node3D
@onready var bt_player := get_node_or_null("BTPlayer") as BTPlayer
var activity_zone: DealerActivityZone3D
var zone_member_id: StringName
var is_temporary_war_attacker := false
var _first_player_hit_recorded := false
var _activity_animation: StringName = &"Idle"
var _is_required_interactable := false
var _corpse_loot_available := false
var _corpse_cash := 0
var _corpse_stock: Array[Dictionary] = []
var _corpse_loot_proxy: DealerCorpseLoot
var _zone_presentation_target := Vector3.ZERO
var _zone_navigation_target := Vector3.ZERO
var _zone_presentation_yaw := 0.0
var _zone_presentation_configured := false
var _zone_presentation_pending := false
var _zone_activity_playing := false
var _shop_interaction_active := false
var _shop_interaction_player: CharacterBody3D
var _customer_visit: StoreCustomerVisit3D
var _bodyguard_following := false
var _bodyguard_player: CharacterBody3D
var _bodyguard_follow_slot := 0
var _bodyguard_repath_remaining := 0.0
var _bodyguard_target_scan_remaining := 0.0
var _bodyguard_lost_sight_elapsed := 0.0


func _ready() -> void:
	super()
	role_component = get_role_component()
	if role_component != null:
		role_component.initialize(self)
		role_component.activate()
	var combat := get_combat_component()
	if combat != null:
		combat.initialize(self)
	_target_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	_combat_target = _target_player
	var threat := get_threat_component()
	var ai := get_ai_component()
	if _target_player != null and threat != null and ai != null:
		threat.initialize(self, _target_player)
		ai.initialize(self, _target_player)
		threat.provoked.connect(provoke)
	damageable.damaged.connect(_on_damaged)
	_apply_combat_loadout()


func get_role_component() -> DealerRoleComponent:
	if role_component != null:
		return role_component
	return get_node_or_null("Components/RoleComponent") as DealerRoleComponent


func can_interact(player: CharacterBody3D) -> bool:
	var role := get_role_component()
	return not _hostile and role != null and role.can_interact(player)


func get_interaction_prompt(player: CharacterBody3D) -> String:
	if _is_player_operated():
		return "E - Dealer Status"
	var role := get_role_component()
	return role.get_interaction_prompt(player) if role != null else ""


func interact(player: CharacterBody3D) -> void:
	if _is_player_operated():
		var service := get_tree().get_first_node_in_group(&"territory_dealer_service") as TerritoryDealerService
		var hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
		if service != null and hud != null:
			hud.show_feedback(service.get_dealer_status(activity_zone.zone_id, zone_member_id), 4.0)
		return
	var role := get_role_component()
	if role != null:
		role.interact(player)


func begin_shop_interaction(player: CharacterBody3D) -> void:
	if player == null or _hostile or is_defeated():
		return
	_shop_interaction_active = true
	_shop_interaction_player = player
	_zone_presentation_pending = false
	_zone_activity_playing = false
	set_navigation_avoidance_enabled(false)
	set_local_obstacle_steering_enabled(false)
	clear_navigation_target()
	velocity = Vector3.ZERO
	_face_shop_player(true)
	if animation_component != null:
		animation_component.play_activity_animation(&"Talking")


func end_shop_interaction() -> void:
	if not _shop_interaction_active:
		return
	_shop_interaction_active = false
	_shop_interaction_player = null
	if animation_component != null:
		animation_component.stop_activity_animation()
	if _zone_presentation_configured and not _hostile and not is_defeated():
		_zone_presentation_pending = true
		_zone_activity_playing = false
		set_navigation_avoidance_enabled(true)
		set_local_obstacle_steering_enabled(true)
		set_navigation_target(_zone_navigation_target)
	if activity_zone != null:
		activity_zone.refresh_group_presentation()


func is_shop_interaction_active() -> bool:
	return _shop_interaction_active


func try_purchase(
	player: CharacterBody3D,
	requested_product: ProductDefinition = null,
	amount := 1,
	delivery_property_id: StringName = &""
) -> String:
	if _is_player_operated():
		return "Your dealer sells from territory stash supply."
	var purchase_product := requested_product
	if purchase_product == null:
		purchase_product = product
	var role := get_role_component()
	if role == null:
		return "Dealer is not ready."
	return role.try_purchase(
		player,
		purchase_product,
		amount,
		delivery_property_id
	)


func configure_dealer(level := 1, wholesaler := false) -> void:
	var role := get_role_component()
	if role != null:
		role.initialize(self)
		role.configure_dealer(level, wholesaler)
	_apply_combat_loadout()


func configure_zone_member(
	zone: DealerActivityZone3D,
	member_id: StringName,
	level: int,
	activity_animation: StringName,
	required_interactable: bool
) -> void:
	activity_zone = zone
	zone_member_id = member_id
	_activity_animation = activity_animation
	_is_required_interactable = required_interactable
	var role := get_role_component()
	if role != null:
		role.territory_id = zone.territory_id
		role.set_fixed_progression_level(level)
	configure_dealer(level, false)
	set_player_operated(zone.faction == TerritoryStatsComponent.OwnerFaction.PLAYER)


func set_player_operated(enabled: bool) -> void:
	var role := get_role_component()
	if role != null:
		role.set_player_operated(enabled)
	if enabled:
		_ensure_customer_visit()
	elif is_instance_valid(_customer_visit):
		_customer_visit.release_itinerary(_customer_visit.get_active_visitor())
		_customer_visit.queue_free()
		_customer_visit = null


func set_player_operation_level(level: int) -> void:
	var role := get_role_component()
	if role == null:
		return
	role.set_fixed_progression_level(clampi(level, 1, 4))
	configure_dealer(level, false)
	set_player_operated(true)


func _is_player_operated() -> bool:
	return activity_zone != null and activity_zone.faction == TerritoryStatsComponent.OwnerFaction.PLAYER


func cancel_customer_sale_presentation() -> void:
	if is_instance_valid(_customer_visit):
		var visitor := _customer_visit.get_active_visitor()
		if visitor != null:
			visitor.cancel_store_visit(true)
	end_shop_interaction()


func present_customer_sale() -> void:
	if _bodyguard_following:
		return
	_ensure_customer_visit()
	if is_instance_valid(_customer_visit):
		_customer_visit.offer_external_ticket()


func _ensure_customer_visit() -> void:
	if is_instance_valid(_customer_visit) or not _is_player_operated():
		return
	_customer_visit = StoreCustomerVisit3D.new()
	_customer_visit.name = "DealerCustomerVisit"
	_customer_visit.ticket_lifetime = 15.0
	_customer_visit.customer_search_radius = 40.0
	_customer_visit.presentation_radius = 55.0
	_customer_visit.configure_external_dealer_visit(self)
	var names := ["Entrance", "Browse", "Counter", "Exit"]
	var positions := [Vector3(0.0, 0.0, 1.8), Vector3(-0.35, 0.0, 1.25),
		Vector3(0.35, 0.0, 1.25), Vector3(0.8, 0.0, 1.8)]
	for index in names.size():
		var spot := ActivitySpot3D.new()
		spot.name = names[index]
		spot.position = positions[index]
		spot.rotation.y = PI
		spot.animation_name = &"Talking" if index in [1, 2] else &"Idle"
		spot.minimum_duration = 1.0 if index in [0, 3] else 2.0
		spot.maximum_duration = 1.5 if index in [0, 3] else 3.0
		spot.allow_random_selection = false
		_customer_visit.add_child(spot)
	add_child(_customer_visit)


func set_zone_presentation(
	target_position: Vector3,
	animation_name: StringName,
	facing_yaw: float,
	approach_position: Variant = null
) -> void:
	_zone_presentation_target = target_position
	_zone_navigation_target = target_position
	if approach_position is Vector3:
		_zone_navigation_target = approach_position as Vector3
	_zone_presentation_yaw = facing_yaw
	_activity_animation = animation_name
	_zone_presentation_configured = true
	_zone_presentation_pending = true
	_zone_activity_playing = false
	if animation_component != null:
		animation_component.stop_activity_animation()
		animation_component.use_sex_appropriate_walk()
	set_navigation_avoidance_enabled(true)
	set_local_obstacle_steering_enabled(true)
	set_navigation_target(_zone_navigation_target)


func configure_war_attacker(level: int, territory_id: StringName) -> void:
	is_temporary_war_attacker = true
	var role := get_role_component()
	if role != null:
		role.territory_id = territory_id
	configure_dealer(level, false)
	provoke(_target_player, global_position)


func begin_bodyguard_following(player: CharacterBody3D) -> void:
	if player == null or is_defeated() or not _is_player_operated():
		return
	cancel_customer_sale_presentation()
	if _hostile:
		clear_hostility()
	_bodyguard_following = true
	_bodyguard_player = player
	_bodyguard_repath_remaining = 0.0
	_bodyguard_target_scan_remaining = 0.0
	_bodyguard_lost_sight_elapsed = 0.0
	_zone_presentation_pending = false
	_zone_activity_playing = false
	_shop_interaction_active = false
	_shop_interaction_player = null
	if animation_component != null:
		animation_component.stop_activity_animation()
		animation_component.use_sex_appropriate_walk()
	if role_component != null:
		role_component.deactivate()
	add_to_group(&"dealer_bodyguard")
	set_navigation_avoidance_enabled(true)
	set_local_obstacle_steering_enabled(true)
	_set_combat_target(_target_player)
	_teleport_near_bodyguard_player()


func end_bodyguard_following() -> void:
	if not _bodyguard_following:
		return
	_bodyguard_following = false
	_bodyguard_player = null
	_bodyguard_repath_remaining = 0.0
	_bodyguard_target_scan_remaining = 0.0
	_bodyguard_lost_sight_elapsed = 0.0
	remove_from_group(&"dealer_bodyguard")
	if _hostile:
		clear_hostility()
	else:
		_set_combat_target(_target_player)
		var combat := get_combat_component()
		if combat != null:
			combat.clear_aim()
			combat.set_equipped(false)
	if role_component != null:
		role_component.activate()
	clear_navigation_target()
	velocity = Vector3.ZERO


func set_bodyguard_follow_slot(slot: int) -> void:
	_bodyguard_follow_slot = maxi(slot, 0)


func is_bodyguard_following() -> bool:
	return _bodyguard_following


func provoke(source: Node = null, world_position := Vector3.ZERO) -> void:
	if is_defeated():
		return
	var source_actor := _find_combat_actor(source)
	if source != null and (source_actor == null or not _can_target_actor(source_actor)):
		return
	if source_actor != null:
		_set_combat_target(source_actor)
	if _hostile:
		return
	cancel_customer_sale_presentation()
	_hostile = true
	_shop_interaction_active = false
	_shop_interaction_player = null
	_zone_presentation_pending = false
	_zone_activity_playing = false
	if animation_component != null:
		animation_component.stop_activity_animation()
	remove_from_group("interactable_npc")
	remove_from_group("interactable")
	var combat := get_combat_component()
	if combat != null:
		combat.set_equipped(true)
	var ai := get_ai_component()
	if ai != null:
		var incident_position := world_position
		if is_instance_valid(_combat_target):
			incident_position = _combat_target.global_position
		ai.call("note_incident", incident_position)


func clear_hostility() -> void:
	if not _hostile:
		return
	_hostile = false
	_set_combat_target(_target_player)
	var combat := get_combat_component()
	if combat != null:
		combat.clear_aim()
		combat.set_equipped(false)
	if role_component != null and not _bodyguard_following:
		role_component.activate()
	if (
		activity_zone != null
		and animation_component != null
		and not _bodyguard_following
	):
		_zone_presentation_pending = _zone_presentation_configured
		_zone_activity_playing = false
		if _zone_presentation_pending:
			animation_component.stop_activity_animation()
			animation_component.use_sex_appropriate_walk()
			set_navigation_avoidance_enabled(true)
			set_local_obstacle_steering_enabled(true)
			set_navigation_target(_zone_navigation_target)


func is_hostile() -> bool:
	return _hostile


func get_zone_activity_animation() -> StringName:
	return _activity_animation


func get_zone_presentation_target() -> Vector3:
	return _zone_presentation_target


func get_zone_navigation_target() -> Vector3:
	return _zone_navigation_target


func get_zone_presentation_yaw() -> float:
	return _zone_presentation_yaw


func is_zone_presentation_configured() -> bool:
	return _zone_presentation_configured


func is_zone_activity_playing() -> bool:
	return _zone_activity_playing


func get_wanted_level() -> int:
	return 2 if _hostile else 0


func can_see_wanted_player() -> bool:
	var threat := get_threat_component()
	return _hostile and threat != null and bool(threat.call("can_see_player"))


func can_see_combat_target() -> bool:
	var threat := get_threat_component()
	return _hostile and threat != null and bool(threat.call("can_see_target"))


func get_combat_target() -> Node3D:
	return _combat_target if is_instance_valid(_combat_target) else null


func tick_dealer_ai_mode(mode: int, delta: float) -> void:
	var translated_mode := 0
	if mode == 1:
		translated_mode = 2
	elif mode == 2:
		translated_mode = 4
	tick_ai_mode(translated_mode, delta)


func get_faction_id() -> StringName:
	if _is_player_operated():
		return &"player_allies"
	if is_temporary_war_attacker:
		return &"rival_attackers"
	return StringName("dealers_%s" % String(
		activity_zone.territory_id if activity_zone != null else &"unassigned"
	))


func tick_ai_mode(mode: int, delta: float) -> void:
	if _bodyguard_following:
		if _hostile and not _maintain_bodyguard_combat_target(delta):
			clear_hostility()
		_tick_bodyguard_targeting(delta)
		if not _hostile:
			_tick_bodyguard_follow(delta)
			return
	if _shop_interaction_active:
		stop_moving(delta)
		_face_shop_player(false, delta)
		return
	if not _hostile and _tick_zone_presentation(delta):
		return
	var ai := get_ai_component()
	if ai != null:
		ai.call("tick_mode", mode, delta)


func _tick_bodyguard_targeting(delta: float) -> void:
	if _hostile:
		return
	_bodyguard_target_scan_remaining = maxf(
		_bodyguard_target_scan_remaining - delta,
		0.0
	)
	if _bodyguard_target_scan_remaining > 0.0:
		return
	_bodyguard_target_scan_remaining = 0.25
	var target := _find_bodyguard_support_target()
	if target != null:
		provoke(target, target.global_position)


func _find_bodyguard_support_target() -> Node3D:
	if not _bodyguard_following or not is_instance_valid(_bodyguard_player):
		return null
	var threat := get_threat_component() as DealerThreatComponent
	var maximum_range := threat.threat_range if threat != null else 24.0
	var maximum_distance_squared := maximum_range * maximum_range
	var nearest: Node3D
	var nearest_distance_squared := INF
	var wanted := _bodyguard_player.get_node_or_null(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	if wanted != null and wanted.wanted_level > 0:
		for node in get_tree().get_nodes_in_group(&"police_npc"):
			var police := node as PoliceNPC
			if (
				police == null
				or police.is_defeated()
				or not police.is_pool_active()
				or not (
					police.is_response_assigned()
					or police.can_see_wanted_player()
					or police.has_confirmed_wanted_player_location()
				)
			):
				continue
			var distance_squared := global_position.distance_squared_to(
				police.global_position
			)
			if (
				distance_squared <= maximum_distance_squared
				and _bodyguard_player.global_position.distance_squared_to(
					police.global_position
				) <= bodyguard_target_radius * bodyguard_target_radius
				and distance_squared < nearest_distance_squared
			):
				nearest = police
				nearest_distance_squared = distance_squared
	for node in get_tree().get_nodes_in_group(&"dealer_npc"):
		var dealer := node as DealerNPC
		if (
			dealer == null
			or dealer == self
			or dealer.is_defeated()
			or dealer.get_faction_id() == &"player_allies"
			or not _is_support_hostile_dealer(dealer)
		):
			continue
		var distance_squared := global_position.distance_squared_to(
			dealer.global_position
		)
		if (
			distance_squared <= maximum_distance_squared
			and _bodyguard_player.global_position.distance_squared_to(
				dealer.global_position
			) <= bodyguard_target_radius * bodyguard_target_radius
			and distance_squared < nearest_distance_squared
		):
			nearest = dealer
			nearest_distance_squared = distance_squared
	return nearest


func _is_support_hostile_dealer(dealer: DealerNPC) -> bool:
	if dealer.is_temporary_war_attacker:
		return true
	if not dealer.is_hostile():
		return false
	var target := dealer.get_combat_target()
	if target == null:
		return false
	if target.is_in_group(&"player"):
		return true
	return (
		target.has_method("get_faction_id")
		and StringName(target.call("get_faction_id")) == &"player_allies"
	)


func _maintain_bodyguard_combat_target(delta: float) -> bool:
	if not is_instance_valid(_bodyguard_player):
		return false
	var target := get_combat_target()
	if target == null or target.is_queued_for_deletion():
		return false
	if target.has_method("is_defeated") and bool(target.call("is_defeated")):
		return false
	if global_position.distance_squared_to(
		_bodyguard_player.global_position
	) > bodyguard_combat_leash_radius * bodyguard_combat_leash_radius:
		return false
	if target.global_position.distance_squared_to(
		_bodyguard_player.global_position
	) > bodyguard_target_radius * bodyguard_target_radius:
		return false
	if can_see_combat_target():
		_bodyguard_lost_sight_elapsed = 0.0
	else:
		_bodyguard_lost_sight_elapsed += delta
		if _bodyguard_lost_sight_elapsed >= bodyguard_lost_sight_grace:
			return false
	return true


func _tick_bodyguard_follow(delta: float) -> void:
	if not is_instance_valid(_bodyguard_player) or is_defeated():
		stop_moving(delta)
		return
	if global_position.distance_squared_to(
		_bodyguard_player.global_position
	) > bodyguard_hard_recall_distance * bodyguard_hard_recall_distance:
		_teleport_near_bodyguard_player()
		return
	var player_movement := _bodyguard_player.get_node_or_null(
		"Components/MovementComponent"
	) as PlayerMovementComponent
	if player_movement != null:
		move_speed = (
			player_movement.run_speed
			if player_movement.is_sprinting()
			else player_movement.walk_speed
		)
		navigation_agent.max_speed = move_speed
	var row := float(_bodyguard_follow_slot / 2)
	var side := -1.0 if _bodyguard_follow_slot % 2 == 0 else 1.0
	var target := (
		_bodyguard_player.global_position
		+ _bodyguard_player.global_basis.z * (2.2 + row * 1.2)
		+ _bodyguard_player.global_basis.x * side * (1.0 + row * 0.4)
	)
	_bodyguard_repath_remaining = maxf(
		_bodyguard_repath_remaining - delta,
		0.0
	)
	if _bodyguard_repath_remaining <= 0.0:
		set_navigation_target(target)
		_bodyguard_repath_remaining = 0.25
	if global_position.distance_squared_to(target) > 1.4 * 1.4:
		if animation_component != null:
			animation_component.use_sex_appropriate_walk()
		advance_companion_follow(target, _bodyguard_player, delta)
	else:
		stop_moving(delta)


func _teleport_near_bodyguard_player() -> void:
	if not is_instance_valid(_bodyguard_player):
		return
	var row := float(_bodyguard_follow_slot / 2)
	var side := -1.0 if _bodyguard_follow_slot % 2 == 0 else 1.0
	var spawn_position := (
		_bodyguard_player.global_position
		+ _bodyguard_player.global_basis.z * (6.0 + row * 1.2)
		+ _bodyguard_player.global_basis.x * side * (2.0 + row * 0.4)
	)
	var navigation_map := navigation_agent.get_navigation_map()
	if (
		navigation_map.is_valid()
		and NavigationServer3D.map_get_iteration_id(navigation_map) > 0
	):
		spawn_position = NavigationServer3D.map_get_closest_point(
			navigation_map,
			spawn_position
		)
	global_position = spawn_position
	velocity = Vector3.ZERO
	navigation_agent.set_velocity_forced(Vector3.ZERO)


func _tick_zone_presentation(delta: float) -> bool:
	if not _zone_presentation_configured or is_defeated():
		return false
	if _zone_activity_playing:
		stop_moving(delta)
		return true
	if not _zone_presentation_pending:
		return false
	var distance_squared := global_position.distance_squared_to(
		_zone_navigation_target
	)
	if distance_squared > 0.65 * 0.65:
		animation_component.use_sex_appropriate_walk()
		move_toward_navigation_target(_zone_navigation_target, delta)
		return true
	var final_distance := global_position.distance_to(_zone_presentation_target)
	if final_distance > 0.12:
		set_navigation_avoidance_enabled(false)
		set_local_obstacle_steering_enabled(false)
		clear_navigation_target()
		var direction := (
			_zone_presentation_target - global_position
		).normalized()
		velocity = direction * 1.25
		global_position = global_position.move_toward(
			_zone_presentation_target, 1.25 * delta
		)
		visual.rotation.y = lerp_angle(
			visual.rotation.y,
			atan2(direction.x, direction.z),
			minf(delta * 6.0, 1.0)
		)
		return true
	set_navigation_avoidance_enabled(false)
	set_local_obstacle_steering_enabled(false)
	clear_navigation_target()
	velocity = Vector3.ZERO
	global_position = _zone_presentation_target
	visual.rotation.y = _zone_presentation_yaw
	animation_component.play_activity_animation(_activity_animation)
	_zone_presentation_pending = false
	_zone_activity_playing = true
	return true


func _face_shop_player(immediate: bool, delta := 0.0) -> void:
	if not is_instance_valid(_shop_interaction_player):
		return
	var direction := _shop_interaction_player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	visual.rotation.y = (
		target_yaw
		if immediate
		else lerp_angle(
			visual.rotation.y,
			target_yaw,
			minf(delta * 8.0, 1.0)
		)
	)


func get_combat_component() -> NPCCombatComponent:
	return get_node_or_null("Components/CombatComponent") as NPCCombatComponent


func get_threat_component() -> Node:
	return get_node_or_null("Components/ThreatComponent")


func get_ai_component() -> Node:
	return get_node_or_null("Components/AIComponent")


func get_combat_weapon() -> WeaponDefinition:
	var combat := get_combat_component()
	return combat.get_weapon_definition() if combat != null else null


func uses_automatic_fire() -> bool:
	var combat := get_combat_component()
	return combat != null and combat.is_fully_automatic()


func get_stock_items() -> Array[Dictionary]:
	var role := get_role_component()
	return role.get_stock_items() if role != null else []


func get_stock_quantity(stock_product: ProductDefinition) -> int:
	var role := get_role_component()
	return role.get_stock_quantity(stock_product) if role != null else 0


func get_dealer_level_text() -> String:
	var role := get_role_component()
	return role.get_display_level() if role != null else "Dealer"


func get_cooldown_remaining() -> float:
	var role := get_role_component()
	return role.get_cooldown_remaining() if role != null else 0.0


func is_wholesaler() -> bool:
	var role := get_role_component()
	return role != null and role.is_wholesaler


func get_minimum_purchase_quantity() -> int:
	var role := get_role_component()
	return role.get_minimum_purchase_quantity() if role != null else 1


func force_restock() -> void:
	var role := get_role_component()
	if role != null:
		role.restock()


func export_save_data() -> Dictionary:
	var role := get_role_component()
	var data := role.export_save_data() if role != null else {}
	data["first_player_hit_recorded"] = _first_player_hit_recorded
	return data


func import_save_data(data: Dictionary) -> void:
	var role := get_role_component()
	if role != null:
		role.initialize(self)
		role.import_save_data(data)
	_first_player_hit_recorded = bool(data.get("first_player_hit_recorded", false))
	clear_hostility()
	_apply_combat_loadout()


func _apply_combat_loadout() -> void:
	var role := get_role_component()
	var combat := get_combat_component()
	if role == null or combat == null:
		return
	var effective_level := 4 if role.is_wholesaler else role.dealer_level
	var definition := load(
		"res://Scripts/Gameplay/Weapons/draco_definition.tres"
		if effective_level >= 3
		else "res://Scripts/Gameplay/Weapons/pistol_definition.tres"
	) as WeaponDefinition
	var automatic := effective_level == 2 or effective_level == 4
	var controlled_interval := -1.0
	if effective_level == 1:
		controlled_interval = 0.42
	elif effective_level == 3:
		controlled_interval = 0.26
	combat.configure_weapon(definition, automatic, controlled_interval)


func _on_damaged(
	_amount: float,
	_remaining_health: float,
	source: Node,
	hit_position: Vector3,
	_hit_direction: Vector3
) -> void:
	var source_actor := _find_combat_actor(source)
	if source_actor != null and _can_target_actor(source_actor):
		if _is_player_source(source) and not _first_player_hit_recorded:
			_first_player_hit_recorded = true
			if activity_zone != null:
				activity_zone.handle_member_first_hit(self)
		if activity_zone != null:
			activity_zone.alert_allies(source, hit_position, self)
		provoke(source, hit_position)


func _set_combat_target(target: Node3D) -> void:
	_combat_target = target
	var threat := get_threat_component()
	if threat != null and threat.has_method("set_target"):
		threat.call("set_target", target)
	var ai := get_ai_component()
	if ai != null and ai.has_method("set_combat_target"):
		ai.call("set_combat_target", target)


func _find_combat_actor(source: Node) -> Node3D:
	var current := source
	while current != null:
		if current is Node3D and (
			current.is_in_group(&"player")
			or current.has_method("get_faction_id")
		):
			return current as Node3D
		current = current.get_parent()
	return null


func _can_target_actor(actor: Node3D) -> bool:
	if actor == null or actor == self:
		return false
	var target_faction := (
		StringName(actor.call("get_faction_id"))
		if actor.has_method("get_faction_id")
		else &"player"
		if actor.is_in_group(&"player")
		else &"unknown"
	)
	var own_faction := get_faction_id()
	if target_faction == own_faction:
		return false
	if own_faction == &"player_allies" and target_faction == &"player":
		return false
	return target_faction != &"unknown"


func _is_player_source(source: Node) -> bool:
	if source == _target_player:
		return true
	var current := source
	while current != null:
		if current.is_in_group(&"player"):
			return true
		current = current.get_parent()
	return false


func _on_defeated(
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	cancel_customer_sale_presentation()
	_bodyguard_following = false
	_bodyguard_player = null
	_bodyguard_lost_sight_elapsed = 0.0
	remove_from_group(&"dealer_bodyguard")
	var player_caused := _is_player_source(source)
	if player_caused and not _is_player_operated():
		_grant_kill_experience(source)
	if activity_zone != null:
		name = "Corpse_%s_%s_%d" % [
			String(activity_zone.zone_id),
			String(zone_member_id),
			Time.get_ticks_msec(),
		]
		activity_zone.handle_member_defeated(self, player_caused)
		if player_caused:
			_prepare_corpse_loot()
	elif player_caused and is_wholesaler():
		_prepare_corpse_loot()
	var role := get_role_component()
	if role != null:
		role.deactivate()
	var combat := get_combat_component()
	if combat != null:
		combat.set_equipped(false)
	if bt_player != null:
		bt_player.set_active(false)
	super(source, hit_position, hit_direction)


func has_corpse_loot() -> bool:
	return _corpse_loot_available


func expire_corpse_loot() -> void:
	_corpse_loot_available = false
	_corpse_cash = 0
	_corpse_stock.clear()


func collect_corpse_loot(player: CharacterBody3D) -> void:
	if not _corpse_loot_available or player == null:
		return
	var wallet := player.get_node_or_null("Components/WalletComponent") as PlayerWalletComponent
	var inventory := player.get_node_or_null("Components/InventoryComponent") as PlayerInventoryComponent
	var carry_weight := player.get_node_or_null(
		"Components/CarryWeightComponent"
	) as PlayerCarryWeightComponent
	if wallet == null or inventory == null or carry_weight == null:
		return
	if not carry_weight.can_add_products(_corpse_stock):
		var added_weight := 0
		for entry in _corpse_stock:
			var product := entry.get("product") as ProductDefinition
			if product != null:
				added_weight += (
					product.package_size_grams
					* int(entry.get("quantity", 0))
				)
		var blocked_hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
		if blocked_hud != null:
			blocked_hud.show_feedback(
				carry_weight.get_capacity_failure_message(added_weight),
				3.0
			)
		return
	var product_units := 0
	for entry in _corpse_stock:
		var stock_product := entry.get("product") as ProductDefinition
		var quantity := int(entry.get("quantity", 0))
		if stock_product != null and quantity > 0:
			inventory.add_product(stock_product, quantity)
			product_units += quantity
	if _corpse_cash > 0:
		wallet.add_dirty(_corpse_cash, true, "Cash Pickup", "Recovered dealer cash")
	var hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
	if hud != null:
		hud.show_feedback("Searched dealer: $%d Dirty Cash, %d product units." % [_corpse_cash, product_units], 3.0)
	expire_corpse_loot()


func can_purchase_territory() -> bool:
	if activity_zone == null:
		return false
	for controller in get_tree().get_nodes_in_group(&"territory_encounter"):
		if bool(controller.call("can_purchase_territory", activity_zone.territory_id)):
			return true
	return false


func purchase_territory(player: CharacterBody3D) -> String:
	if activity_zone == null:
		return "This dealer cannot arrange a territory purchase."
	for controller in get_tree().get_nodes_in_group(&"territory_encounter"):
		return String(controller.call("purchase_territory", activity_zone.territory_id, player))
	return "Territory control is unavailable."


func _grant_kill_experience(source: Node) -> void:
	var player := _find_player_ancestor(source)
	if player == null:
		return
	var stats := player.get_node_or_null("Components/StatsComponent") as PlayerStatsComponent
	var role := get_role_component()
	if stats == null or role == null:
		return
	if role.is_wholesaler:
		stats.add_experience(WHOLESALER_KILL_EXPERIENCE)
		return
	var rewards := [25.0, 40.0, 60.0, 90.0]
	stats.add_experience(rewards[clampi(role.dealer_level, 1, 4) - 1])


func _prepare_corpse_loot() -> void:
	if is_temporary_war_attacker or _is_player_operated():
		return
	var role := get_role_component()
	if role == null:
		return
	if role.is_wholesaler:
		role.take_all_stock()
		_corpse_stock.clear()
		_corpse_cash = WHOLESALER_CORPSE_CASH
	else:
		_corpse_stock = role.take_all_stock()
		var ranges := [
			Vector2i(100, 250),
			Vector2i(250, 500),
			Vector2i(500, 1000),
			Vector2i(1000, 2000),
		]
		var cash_range: Vector2i = ranges[
			clampi(role.dealer_level, 1, 4) - 1
		]
		_corpse_cash = randi_range(cash_range.x, cash_range.y)
	_corpse_loot_available = true
	_corpse_loot_proxy = DealerCorpseLoot.new()
	get_parent().add_child(_corpse_loot_proxy)
	_corpse_loot_proxy.global_position = get_vfx_pool_origin()
	_corpse_loot_proxy.setup(self, 20.0)


func _find_player_ancestor(source: Node) -> CharacterBody3D:
	var current := source
	while current != null:
		if current.is_in_group(&"player"):
			return current as CharacterBody3D
		current = current.get_parent()
	return null
