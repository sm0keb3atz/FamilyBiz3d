class_name DealerNPC
extends BaseNPC

@export var product: ProductDefinition


func _ready() -> void:
	super()
	add_to_group("interactable_npc")
	add_to_group("interactable")


func can_interact(_player: CharacterBody3D) -> bool:
	return not is_defeated() and product != null


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return "E — Shop"


func interact(player: CharacterBody3D) -> void:
	var shop_menu := player.get_node_or_null("DealerShopMenu") as DealerShopMenu
	if shop_menu != null:
		shop_menu.open_for(self)


func try_purchase(player: CharacterBody3D) -> String:
	var trade_service := player.get_node(
		"Components/TradeService"
	) as TradeService
	return trade_service.buy_product(product).message
