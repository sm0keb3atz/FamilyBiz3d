class_name DealerRoleComponent
extends NPCRoleComponent

const DEALER_REP_REQUIREMENTS := [0.0, 15.0, 40.0, 80.0]
const WHOLESALER_REP_REQUIREMENT := 100.0

signal stock_changed
signal cooldown_changed(remaining: float)

@export var product: ProductDefinition
@export_range(1, 4, 1) var dealer_level := 1
@export var is_wholesaler := false
@export var territory_id: StringName
@export_range(0.0, 300.0, 1.0) var restock_cooldown := 30.0
@export var restock_on_ready := true

var _stock: Dictionary[StringName, int] = {}
var _products: Dictionary[StringName, ProductDefinition] = {}
var _cooldown_remaining := 0.0
var _random := RandomNumberGenerator.new()
var _fixed_progression_level := 0


func _ready() -> void:
	_random.randomize()
	set_process(false)


func activate() -> void:
	npc.add_to_group("dealer_npc")
	npc.add_to_group("interactable_npc")
	npc.add_to_group("interactable")
	if restock_on_ready and _stock.is_empty():
		restock()
	_refresh_role_label()
	_refresh_wholesaler_visibility()
	set_process(true)


func deactivate() -> void:
	npc.remove_from_group("dealer_npc")
	npc.remove_from_group("interactable_npc")
	npc.remove_from_group("interactable")
	set_process(false)


func _process(delta: float) -> void:
	_refresh_wholesaler_visibility()
	if _cooldown_remaining <= 0.0:
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	cooldown_changed.emit(_cooldown_remaining)
	if is_zero_approx(_cooldown_remaining):
		restock()


func configure_dealer(level := 1, wholesaler := false) -> void:
	dealer_level = clampi(level, 1, 4)
	is_wholesaler = wholesaler
	restock()
	_refresh_role_label()
	_refresh_wholesaler_visibility()


func set_fixed_progression_level(level: int) -> void:
	_fixed_progression_level = clampi(level, 0, 4)


static func roll_weighted_level(random: RandomNumberGenerator) -> int:
	var roll := random.randi_range(1, 100)
	if roll <= 55:
		return 1
	if roll <= 80:
		return 2
	if roll <= 95:
		return 3
	return 4


func can_interact(_player: CharacterBody3D) -> bool:
	_refresh_wholesaler_visibility()
	return not npc.is_defeated()


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	if not _is_unlocked():
		return "E - Locked (%d Territory Rep)" % roundi(
			get_required_reputation()
		)
	if _cooldown_remaining > 0.0:
		return "E - Dealer restocking"
	return "E - Shop"


func interact(player: CharacterBody3D) -> void:
	if not _is_unlocked():
		var hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
		if hud != null:
			hud.show_feedback(
				"Requires %d Reputation in this territory."
				% roundi(get_required_reputation())
			)
		return
	var shop_menu := player.get_node_or_null(
		"DealerShopMenu"
	) as DealerShopMenu
	if shop_menu != null:
		shop_menu.open_for(npc)


func try_purchase(
	player: CharacterBody3D,
	requested_product: ProductDefinition,
	amount := 1
) -> String:
	if requested_product == null:
		return "This dealer has nothing for sale."
	if amount <= 0:
		return "Invalid purchase amount."
	if not _is_unlocked():
		return "Requires %d Reputation in this territory." % roundi(
			get_required_reputation()
		)
	if _cooldown_remaining > 0.0:
		return "Dealer is restocking."

	var available := get_stock_quantity(requested_product)
	if available <= 0:
		return "%s is out of stock." % requested_product.display_name
	if amount > available:
		return "Only %d %s left." % [
			available,
			requested_product.display_name,
		]

	var trade_service := player.get_node(
		"Components/TradeService"
	) as TradeService
	var territory := _find_territory()
	if territory == null:
		return "This dealer is outside a territory."
	var result := trade_service.buy_product(
		requested_product,
		territory.territory_id,
		amount
	)
	if not result.success:
		return result.message

	_stock[requested_product.product_id] = available - amount
	if _stock[requested_product.product_id] <= 0:
		_stock.erase(requested_product.product_id)
		_products.erase(requested_product.product_id)
	stock_changed.emit()
	if _stock.is_empty():
		_start_cooldown()
	return result.message


func restock() -> void:
	_stock.clear()
	_products.clear()
	_cooldown_remaining = 0.0
	if is_wholesaler:
		_stock_product(EconomyCatalog.WEED_BRICK, _random.randi_range(8, 15))
		_stock_product(EconomyCatalog.COKE_BRICK, _random.randi_range(8, 15))
		_stock_product(EconomyCatalog.FENT_BRICK, _random.randi_range(8, 15))
	else:
		match dealer_level:
			1:
				_stock_product(EconomyCatalog.WEED_1G, _random.randi_range(25, 35))
			2:
				_stock_product(EconomyCatalog.WEED_1G, _random.randi_range(14, 28))
				_stock_product(EconomyCatalog.COKE_1G, _random.randi_range(2, 6))
			3:
				_stock_product(EconomyCatalog.COKE_1G, _random.randi_range(10, 22))
				_stock_product(EconomyCatalog.FENT_1G, _random.randi_range(2, 6))
			4:
				var bricks := EconomyCatalog.get_brick_products()
				_stock_product(bricks[_random.randi_range(0, bricks.size() - 1)], _random.randi_range(1, 3))
			_:
				_stock_product(EconomyCatalog.WEED_1G, _random.randi_range(4, 10))
	product = get_primary_product()
	_refresh_role_label()
	stock_changed.emit()
	cooldown_changed.emit(_cooldown_remaining)


func get_stock_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var territory := _find_territory()
	var market := TerritoryMarketService.find(get_tree())
	for product_id in _products.keys():
		var stock_product := _products[product_id]
		var unit_price := stock_product.dealer_price
		if territory != null and market != null:
			unit_price = market.get_buy_quote(
				territory.territory_id,
				stock_product
			)
		items.append({
			"product": stock_product,
			"quantity": _stock.get(product_id, 0),
			"unit_price": unit_price,
		})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_product := a.get("product") as ProductDefinition
		var b_product := b.get("product") as ProductDefinition
		if a_product == null or b_product == null:
			return false
		return String(a_product.product_id) < String(b_product.product_id)
	)
	return items


func get_stock_quantity(stock_product: ProductDefinition) -> int:
	if stock_product == null:
		return 0
	return _stock.get(stock_product.product_id, 0)


func get_primary_product() -> ProductDefinition:
	if not _products.is_empty():
		return _products[_products.keys()[0]]
	return product


func get_display_level() -> String:
	if is_wholesaler:
		return "Wholesaler"
	return "Level %d" % dealer_level


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func export_save_data() -> Dictionary:
	var stock_data := {}
	for product_id in _stock.keys():
		stock_data[String(product_id)] = _stock[product_id]
	return {
		"dealer_level": dealer_level,
		"is_wholesaler": is_wholesaler,
		"cooldown_remaining": _cooldown_remaining,
		"stock": stock_data,
	}


func import_save_data(data: Dictionary) -> void:
	var imported_level := clampi(
		int(data.get("dealer_level", dealer_level)),
		1,
		4
	)
	var imported_wholesaler := bool(data.get("is_wholesaler", is_wholesaler))
	if _fixed_progression_level > 0:
		dealer_level = _fixed_progression_level
		is_wholesaler = false
		if imported_level != dealer_level or imported_wholesaler:
			restock()
			return
	else:
		dealer_level = imported_level
		is_wholesaler = imported_wholesaler
	_cooldown_remaining = maxf(float(data.get("cooldown_remaining", 0.0)), 0.0)
	_stock.clear()
	_products.clear()
	var stock_data := data.get("stock", {}) as Dictionary
	for product_id_text in stock_data.keys():
		var stock_product := EconomyCatalog.get_product(StringName(String(product_id_text)))
		var quantity := maxi(int(stock_data[product_id_text]), 0)
		if stock_product != null and quantity > 0:
			_stock_product(stock_product, quantity)
	product = get_primary_product()
	if _stock.is_empty() and is_zero_approx(_cooldown_remaining):
		restock()
	_refresh_role_label()
	_refresh_wholesaler_visibility()
	stock_changed.emit()
	cooldown_changed.emit(_cooldown_remaining)


func _stock_product(stock_product: ProductDefinition, amount: int) -> void:
	if stock_product == null or amount <= 0:
		return
	_products[stock_product.product_id] = stock_product
	_stock[stock_product.product_id] = (
		_stock.get(stock_product.product_id, 0) + amount
	)


func _start_cooldown() -> void:
	_cooldown_remaining = restock_cooldown
	cooldown_changed.emit(_cooldown_remaining)


func get_required_reputation() -> float:
	if is_wholesaler:
		return WHOLESALER_REP_REQUIREMENT
	return DEALER_REP_REQUIREMENTS[clampi(dealer_level, 1, 4) - 1]


func _is_unlocked() -> bool:
	var territory := _find_territory()
	return (
		territory != null
		and territory.stats != null
		and territory.stats.reputation >= get_required_reputation()
	)


func _refresh_wholesaler_visibility() -> void:
	if npc == null:
		return
	npc.visible = true
	_refresh_role_label()


func _refresh_role_label() -> void:
	if npc == null:
		return
	var label := npc.get_node_or_null("RoleLabel") as Label3D
	if label == null:
		return
	var title := "WHOLESALER" if is_wholesaler else "DEALER L%d" % dealer_level
	if _is_unlocked():
		label.text = title
	else:
		label.text = "%s (%d REP)" % [
			title,
			roundi(get_required_reputation()),
		]


func _find_territory() -> TerritoryBoundary:
	if String(territory_id) != "":
		for node in get_tree().get_nodes_in_group("territory_boundaries"):
			var boundary := node as TerritoryBoundary
			if boundary != null and boundary.territory_id == territory_id:
				return boundary
	return TerritoryBoundary.find_at_position(get_tree(), npc.global_position)
