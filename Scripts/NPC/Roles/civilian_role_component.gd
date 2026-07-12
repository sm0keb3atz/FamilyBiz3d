class_name CivilianRoleComponent
extends NPCRoleComponent

@export var product_wanted: ProductDefinition
@export_range(1, 4, 1) var customer_level := 1
@export_range(1, 100, 1) var amount_wanted := 1
@export var randomize_demand_on_activate := true

var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()


func activate() -> void:
	if randomize_demand_on_activate:
		_roll_demand()
	_refresh_role_label()
	npc.add_to_group("customer_npc")
	npc.add_to_group("interactable_npc")
	npc.add_to_group("interactable")
	npc.add_to_group("gunshot_listener")


func deactivate() -> void:
	npc.remove_from_group("customer_npc")
	npc.remove_from_group("interactable_npc")
	npc.remove_from_group("interactable")
	npc.remove_from_group("gunshot_listener")


func can_respond_to_solicitation() -> bool:
	return (
		npc.is_pool_active()
		and not npc.is_defeated()
		and npc.get_state_name() == "ROAMING"
		and npc.is_solicitation_ready()
		and product_wanted != null
		and amount_wanted > 0
	)


func respond_to_solicitation(player: CharacterBody3D) -> bool:
	if not can_respond_to_solicitation():
		return false
	if not can_player_fill_order(player):
		return false
	npc.begin_solicitation(player)
	return true


func can_interact(player: CharacterBody3D) -> bool:
	var can_trade: bool = (
		npc.is_pool_active()
		and not npc.is_defeated()
		and npc.is_waiting_for_customer_trade(player)
		and product_wanted != null
		and amount_wanted > 0
	)
	return can_trade or npc.can_attempt_girlfriend_recruitment(player)


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	if npc.can_attempt_girlfriend_recruitment(_player):
		return "E - Talk to %s (Level %d)" % [npc.get_civilian_name(), customer_level]
	if product_wanted == null:
		return ""
	return "E - Sell %d %s" % [amount_wanted, product_wanted.display_name]


func interact(player: CharacterBody3D) -> void:
	if not can_interact(player):
		return
	if npc.can_attempt_girlfriend_recruitment(player):
		npc.attempt_girlfriend_recruitment(player)
		return
	var hud := player.get_node("PlayerHUD") as PlayerHUD
	var trade_service := player.get_node(
		"Components/TradeService"
	) as TradeService
	var result: TradeResult = trade_service.sell_product(
		product_wanted,
		npc.global_position,
		amount_wanted
	)
	hud.show_feedback(result.message)
	npc.finish_customer_trade()


func get_demand_text() -> String:
	if product_wanted == null:
		return ""
	return "%d %s" % [amount_wanted, product_wanted.display_name]


func can_player_fill_order(player: CharacterBody3D) -> bool:
	if product_wanted == null or player == null:
		return false
	var inventory := player.get_node_or_null(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	return inventory != null and inventory.has_product(product_wanted, amount_wanted)


static func roll_weighted_level(random: RandomNumberGenerator) -> int:
	var roll := random.randi_range(1, 100)
	if roll <= 55:
		return 1
	if roll <= 80:
		return 2
	if roll <= 95:
		return 3
	return 4


func _roll_demand() -> void:
	customer_level = roll_weighted_level(_random)
	match customer_level:
		1:
			product_wanted = EconomyCatalog.WEED_1G
			amount_wanted = _random.randi_range(1, 3)
		2:
			if _random.randf() < 0.65:
				product_wanted = EconomyCatalog.WEED_1G
				amount_wanted = _random.randi_range(4, 10)
			else:
				product_wanted = EconomyCatalog.COKE_1G
				amount_wanted = _random.randi_range(1, 3)
		3:
			if _random.randf() < 0.7:
				product_wanted = EconomyCatalog.COKE_1G
				amount_wanted = _random.randi_range(4, 10)
			else:
				product_wanted = EconomyCatalog.FENT_1G
				amount_wanted = _random.randi_range(1, 3)
		4:
			if _random.randf() < 0.55:
				product_wanted = EconomyCatalog.COKE_1G
				amount_wanted = _random.randi_range(10, 20)
			else:
				product_wanted = EconomyCatalog.FENT_1G
				amount_wanted = _random.randi_range(4, 10)
		_:
			product_wanted = EconomyCatalog.WEED_1G
			amount_wanted = 1
	if npc != null and npc.has_method("apply_customer_level_style"):
		npc.call("apply_customer_level_style", customer_level)


func _refresh_role_label() -> void:
	if npc == null:
		return
	var label := npc.get_node_or_null("RoleLabel") as Label3D
	if label != null:
		label.text = "CUSTOMER L%d" % customer_level
