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


func assign_solicitation_order(
	requested_product: ProductDefinition,
	requested_amount: int
) -> void:
	product_wanted = requested_product
	amount_wanted = maxi(requested_amount, 0)
	_refresh_role_label()


func roll_solicitation_amount() -> int:
	var amount_range := get_solicitation_amount_range()
	return _random.randi_range(amount_range.x, amount_range.y)


func get_solicitation_amount_range() -> Vector2i:
	match clampi(customer_level, 1, 4):
		1:
			return Vector2i(1, 4)
		2:
			return Vector2i(5, 10)
		3:
			return Vector2i(10, 20)
		4:
			return Vector2i(20, 40)
	return Vector2i.ONE


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
	var gram_products := EconomyCatalog.get_gram_products()
	product_wanted = gram_products[
		_random.randi_range(0, gram_products.size() - 1)
	]
	amount_wanted = roll_solicitation_amount()
	if npc != null and npc.has_method("apply_customer_level_style"):
		npc.call("apply_customer_level_style", customer_level)


func _refresh_role_label() -> void:
	if npc == null:
		return
	var label := npc.get_node_or_null("RoleLabel") as Label3D
	if label != null:
		label.text = "CUSTOMER L%d" % customer_level
