class_name DealerNPC
extends BaseNPC

@export var product: ProductDefinition


func _ready() -> void:
	super()
	add_to_group("interactable_npc")


func can_interact(_player: CharacterBody3D) -> bool:
	return not is_defeated() and product != null


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return "E — Shop"


func interact(player: CharacterBody3D) -> void:
	var shop_menu := player.get_node_or_null("DealerShopMenu") as DealerShopMenu
	if shop_menu != null:
		shop_menu.open_for(self)


func try_purchase(player: CharacterBody3D) -> String:
	if product == null:
		return "This dealer has nothing for sale."

	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent

	if not wallet.can_spend_dirty(product.dealer_price):
		return "Not enough Dirty Cash."

	if not wallet.spend_dirty(product.dealer_price):
		return "Purchase failed."
	if not inventory.add_product(product, 1):
		wallet.add_dirty(product.dealer_price)
		return "Purchase failed."

	return "Purchased 1 %s." % product.display_name
