class_name DealerNPC
extends BaseNPC

## Dealer composition root. Shop behavior belongs to DealerRoleComponent.

@onready var role_component := (
	$Components/RoleComponent as DealerRoleComponent
)

var product: ProductDefinition:
	get:
		var role := get_role_component()
		return role.get_primary_product() if role != null else null

var _hostile := false
var _target_player: CharacterBody3D
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
	amount := 1
) -> String:
	if _is_player_operated():
		return "Your dealer sells from territory stash supply."
	var purchase_product := requested_product
	if purchase_product == null:
		purchase_product = product
	var role := get_role_component()
	if role == null:
		return "Dealer is not ready."
	return role.try_purchase(player, purchase_product, amount)


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


func provoke(source: Node = null, world_position := Vector3.ZERO) -> void:
	if _hostile or is_defeated():
		return
	if source != null and not _is_player_source(source):
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
		if _target_player != null and _is_player_source(source):
			incident_position = _target_player.global_position
		ai.call("note_incident", incident_position)


func clear_hostility() -> void:
	if not _hostile:
		return
	_hostile = false
	var combat := get_combat_component()
	if combat != null:
		combat.clear_aim()
		combat.set_equipped(false)
	if role_component != null:
		role_component.activate()
	if activity_zone != null and animation_component != null:
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


func tick_ai_mode(mode: int, delta: float) -> void:
	if _shop_interaction_active:
		stop_moving(delta)
		_face_shop_player(false, delta)
		return
	if not _hostile and _tick_zone_presentation(delta):
		return
	var ai := get_ai_component()
	if ai != null:
		ai.call("tick_mode", mode, delta)


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
	if _is_player_source(source):
		if not _first_player_hit_recorded:
			_first_player_hit_recorded = true
			if activity_zone != null:
				activity_zone.handle_member_first_hit(self)
		if activity_zone != null:
			activity_zone.alert_allies(source, hit_position, self)
		provoke(source, hit_position)


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
	if wallet == null or inventory == null:
		return
	var product_units := 0
	for entry in _corpse_stock:
		var stock_product := entry.get("product") as ProductDefinition
		var quantity := int(entry.get("quantity", 0))
		if stock_product != null and quantity > 0:
			inventory.add_product(stock_product, quantity)
			product_units += quantity
	if _corpse_cash > 0:
		wallet.add_dirty(_corpse_cash)
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
	var rewards := [25.0, 40.0, 60.0, 90.0]
	stats.add_experience(rewards[clampi(role.dealer_level, 1, 4) - 1])


func _prepare_corpse_loot() -> void:
	if is_temporary_war_attacker or _is_player_operated():
		return
	var role := get_role_component()
	if role == null:
		return
	_corpse_stock = role.take_all_stock()
	var ranges := [Vector2i(100, 250), Vector2i(250, 500), Vector2i(500, 1000), Vector2i(1000, 2000)]
	var cash_range: Vector2i = ranges[clampi(role.dealer_level, 1, 4) - 1]
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
