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


func buy_product(product: ProductDefinition) -> TradeResult:
	if product == null:
		return TradeResult.failed("This dealer has nothing for sale.")
	if not wallet.can_spend_dirty(product.dealer_price):
		return TradeResult.failed("Not enough Dirty Cash.")

	# Validate first, then commit the complete transaction.
	if not wallet.spend_dirty(product.dealer_price):
		return TradeResult.failed("Purchase failed.")
	if not inventory.add_product(product, 1):
		wallet.add_dirty(product.dealer_price)
		return TradeResult.failed("Purchase failed.")

	var result := TradeResult.new()
	result.success = true
	result.message = "Purchased 1 %s." % product.display_name
	result.dirty_cash_delta = -product.dealer_price
	result.product_quantity_delta = 1
	return result


func sell_product(
	product: ProductDefinition,
	world_position: Vector3
) -> TradeResult:
	if product == null:
		return TradeResult.failed("This customer is not buying anything.")
	if not inventory.has_product(product, 1):
		return TradeResult.failed("You have no %s to sell." % product.display_name)

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
	if not inventory.remove_product(product, 1):
		return TradeResult.failed("Sale failed.")

	wallet.add_dirty(product.sale_price)
	stats.add_experience(product.experience_reward)
	territory.stats.record_sale(
		product.reputation_reward,
		product.heat_reward
	)

	var result := TradeResult.new()
	result.success = true
	result.dirty_cash_delta = product.sale_price
	result.product_quantity_delta = -1
	result.experience_delta = product.experience_reward
	result.reputation_delta = product.reputation_reward
	result.heat_delta = product.heat_reward
	result.message = (
		"Sold 1 %s for $%d  •  +%d EXP  •  +%.0f Rep  •  +%.0f Heat"
		% [
			product.display_name,
			product.sale_price,
			roundi(product.experience_reward),
			product.reputation_reward,
			product.heat_reward,
		]
	)
	return result

