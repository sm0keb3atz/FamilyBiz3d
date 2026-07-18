class_name TradeService
extends Node

@export var player_path := NodePath("../..")

@onready var player := get_node(player_path) as CharacterBody3D
@onready var wallet := player.get_node(
	"Components/WalletComponent"
) as PlayerWalletComponent
@onready var inventory := player.get_node(
	"Components/InventoryComponent"
) as PlayerInventoryComponent
@onready var stats := player.get_node(
	"Components/StatsComponent"
) as PlayerStatsComponent
@onready var wanted := player.get_node(
	"Components/WantedComponent"
) as PlayerWantedComponent

var _market: TerritoryMarketService


func buy_product(
	product: ProductDefinition,
	territory_id: StringName,
	amount := 1
) -> TradeResult:
	if product == null:
		return TradeResult.failed("This dealer has nothing for sale.")
	if amount <= 0:
		return TradeResult.failed("Invalid purchase amount.")

	var price := get_buy_unit_price(product, territory_id)
	var total_price := price * amount
	if not wallet.can_spend_dirty(total_price):
		return TradeResult.failed("Not enough Dirty Cash.")

	# Validate first, then commit the complete transaction.
	if not wallet.spend_dirty(total_price, false):
		return TradeResult.failed("Purchase failed.")
	if not inventory.add_product(product, amount):
		wallet.add_dirty(total_price, false)
		return TradeResult.failed("Purchase failed.")
	wallet.record_transaction(-total_price, 0)

	var result := TradeResult.new()
	result.success = true
	result.message = "Purchased %d %s." % [amount, product.display_name]
	result.dirty_cash_delta = -total_price
	result.product_quantity_delta = amount
	return result


func sell_product(
	product: ProductDefinition,
	world_position: Vector3,
	amount := 1
) -> TradeResult:
	if product == null:
		return TradeResult.failed("This customer is not buying anything.")
	if amount <= 0:
		return TradeResult.failed("Invalid sale amount.")
	if not inventory.has_product(product, amount):
		return TradeResult.failed(
			"You need %s to sell." % product.get_quantity_display_name(amount)
		)

	var territory := TerritoryBoundary.find_at_position(
		get_tree(),
		world_position
	)
	if territory == null or territory.stats == null:
		return TradeResult.failed("You are outside a trading territory.")
	if territory.stats.is_trade_locked():
		return TradeResult.failed(
			"%s is too hot. Customers will not buy here."
			% territory.display_name
		)

	# Removal cannot fail after validation unless another transaction changed state.
	if not inventory.remove_product(product, amount):
		return TradeResult.failed("Sale failed.")

	var hustle_multiplier := stats.get_hustle_sale_multiplier()
	var unit_price := get_buy_unit_price(product, territory.territory_id)
	var total_sale_price := roundi(float(unit_price * amount) * hustle_multiplier)
	var total_experience := (
		product.experience_reward
		* float(amount)
		* stats.get_hustle_experience_multiplier()
	)
	var total_reputation := product.reputation_reward * float(amount)
	var total_heat := product.heat_reward * float(amount)
	wallet.add_dirty(total_sale_price)
	stats.add_experience(total_experience)
	territory.stats.record_sale(total_reputation, total_heat)
	wanted.report_sale(world_position)

	var result := TradeResult.new()
	result.success = true
	result.dirty_cash_delta = total_sale_price
	result.product_quantity_delta = -amount
	result.experience_delta = total_experience
	result.reputation_delta = total_reputation
	result.heat_delta = total_heat
	result.message = (
		"Sold %s for $%d | +%d EXP | +%.0f Rep | +%.0f Heat"
		% [
			product.get_quantity_display_name(amount),
			total_sale_price,
			roundi(total_experience),
			total_reputation,
			total_heat,
		]
	)
	return result


func get_buy_unit_price(
	product: ProductDefinition,
	territory_id: StringName
) -> int:
	if product == null:
		return 0
	var market := _get_market()
	if market == null:
		return product.dealer_price
	return market.get_buy_quote(territory_id, product)


func get_sell_unit_price(
	product: ProductDefinition,
	territory_id: StringName
) -> int:
	if product == null:
		return 0
	return get_buy_unit_price(product, territory_id)


func get_sale_total(
	product: ProductDefinition,
	world_position: Vector3,
	amount := 1
) -> int:
	if product == null or amount <= 0:
		return 0
	var territory := TerritoryBoundary.find_at_position(
		get_tree(),
		world_position
	)
	if territory == null:
		return 0
	return roundi(
		float(get_buy_unit_price(product, territory.territory_id) * amount)
		* stats.get_hustle_sale_multiplier()
	)


func get_sale_pricing(
	product: ProductDefinition,
	territory_id: StringName,
	amount := 1
) -> Vector2i:
	if product == null or amount <= 0:
		return Vector2i.ZERO
	var unit_price := get_buy_unit_price(product, territory_id)
	return Vector2i(
		unit_price,
		roundi(
			float(unit_price * amount) * stats.get_hustle_sale_multiplier()
		)
	)


func _get_market() -> TerritoryMarketService:
	if not is_instance_valid(_market):
		_market = TerritoryMarketService.find(get_tree())
	return _market
