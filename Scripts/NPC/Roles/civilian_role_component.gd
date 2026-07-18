class_name CivilianRoleComponent
extends NPCRoleComponent

@export var product_wanted: ProductDefinition
@export_range(1, 4, 1) var customer_level := 1
@export_range(1, 100, 1) var amount_wanted := 1
@export var randomize_demand_on_activate := true

var _random := RandomNumberGenerator.new()
var _demand_hustle := 1
var _cached_prompt_product_id: StringName = &""
var _cached_prompt_territory_id: StringName = &""
var _cached_prompt_amount := -1
var _cached_prompt_unit_price := -1
var _cached_prompt_total := -1
var _cached_trade_prompt := ""


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
		and npc.get_state_name() in [
			"ROAMING",
			"TRAVELING_TO_ACTIVITY",
			"PERFORMING_ACTIVITY",
		]
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


func get_interaction_prompt(player: CharacterBody3D) -> String:
	if npc.can_attempt_girlfriend_recruitment(player):
		return "E - Talk to %s (Level %d)" % [npc.get_civilian_name(), customer_level]
	if product_wanted == null:
		return ""
	var trade_service := player.get_node_or_null(
		"Components/TradeService"
	) as TradeService
	var territory := TerritoryBoundary.find_at_position(
		get_tree(),
		npc.global_position
	)
	if trade_service == null or territory == null:
		return "E - Sell %s" % product_wanted.get_quantity_display_name(
			amount_wanted
		)
	var pricing := trade_service.get_sale_pricing(
		product_wanted,
		territory.territory_id,
		amount_wanted
	)
	if (
		_cached_prompt_product_id != product_wanted.product_id
		or _cached_prompt_territory_id != territory.territory_id
		or _cached_prompt_amount != amount_wanted
		or _cached_prompt_unit_price != pricing.x
		or _cached_prompt_total != pricing.y
	):
		_cached_prompt_product_id = product_wanted.product_id
		_cached_prompt_territory_id = territory.territory_id
		_cached_prompt_amount = amount_wanted
		_cached_prompt_unit_price = pricing.x
		_cached_prompt_total = pricing.y
		_cached_trade_prompt = "E - Sell %s | Dealer $%d/g | Payout $%d" % [
			product_wanted.get_quantity_display_name(amount_wanted),
			pricing.x,
			pricing.y,
		]
	return _cached_trade_prompt


func get_sale_interaction_data(player: CharacterBody3D) -> Dictionary:
	if (
		product_wanted == null
		or not npc.is_waiting_for_customer_trade(player)
		or npc.can_attempt_girlfriend_recruitment(player)
	):
		return {}
	var payout := product_wanted.sale_price * amount_wanted
	var trade_service := player.get_node_or_null(
		"Components/TradeService"
	) as TradeService
	var territory := TerritoryBoundary.find_at_position(
		get_tree(),
		npc.global_position
	)
	if trade_service != null and territory != null:
		payout = trade_service.get_sale_pricing(
			product_wanted,
			territory.territory_id,
			amount_wanted
		).y
	return {
		"product_name": product_wanted.get_short_display_name(),
		"grams": amount_wanted * product_wanted.package_size_grams,
		"payout": payout,
		"icon": product_wanted.icon,
	}


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
	return product_wanted.get_quantity_display_name(amount_wanted)


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


static func get_level_weights(hustle: int) -> Array[int]:
	# High-value customers are progression rewards instead of common early rolls.
	# Each row totals 100 and maps to customer levels 1 through 4.
	var weights: Array[Array] = [
		[88, 11, 1, 0],
		[84, 14, 2, 0],
		[78, 18, 4, 0],
		[72, 21, 7, 0],
		[65, 24, 10, 1],
		[59, 26, 13, 2],
		[53, 28, 16, 3],
		[48, 29, 19, 4],
		[43, 30, 21, 6],
		[38, 31, 23, 8],
	]
	var selected: Array[int] = []
	selected.assign(weights[clampi(hustle, 1, 10) - 1])
	return selected


static func roll_weighted_level(
	random: RandomNumberGenerator,
	hustle: int = 1
) -> int:
	var roll := random.randi_range(1, 100)
	var cumulative := 0
	var weights := get_level_weights(hustle)
	for index in range(weights.size()):
		cumulative += weights[index]
		if roll <= cumulative:
			return index + 1
	return 4


func set_demand_hustle(hustle: int) -> void:
	_demand_hustle = clampi(hustle, 1, 10)


func _roll_demand() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if player != null:
		var stats := player.get_node_or_null(
			"Components/StatsComponent"
		) as PlayerStatsComponent
		if stats != null:
			_demand_hustle = stats.hustle
	customer_level = roll_weighted_level(_random, _demand_hustle)
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
