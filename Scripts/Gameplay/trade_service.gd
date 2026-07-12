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


func buy_product(
	product: ProductDefinition,
	amount := 1,
	unit_price := -1
) -> TradeResult:
	if product == null:
		return TradeResult.failed("This dealer has nothing for sale.")
	if amount <= 0:
		return TradeResult.failed("Invalid purchase amount.")

	var price := product.dealer_price if unit_price < 0 else unit_price
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
			"You need %d %s to sell." % [amount, product.display_name]
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

	var total_sale_price := product.sale_price * amount
	var total_experience := product.experience_reward * float(amount)
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
		"Sold %d %s for $%d | +%d EXP | +%.0f Rep | +%.0f Heat"
		% [
			amount,
			product.display_name,
			total_sale_price,
			roundi(total_experience),
			total_reputation,
			total_heat,
		]
	)
	return result
