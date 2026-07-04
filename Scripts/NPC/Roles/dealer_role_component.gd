class_name DealerRoleComponent
extends NPCRoleComponent

@export var product: ProductDefinition


func activate() -> void:
	npc.add_to_group("interactable_npc")
	npc.add_to_group("interactable")


func deactivate() -> void:
	npc.remove_from_group("interactable_npc")
	npc.remove_from_group("interactable")


func can_interact(_player: CharacterBody3D) -> bool:
	return not npc.is_defeated() and product != null


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return "E — Shop"


func interact(player: CharacterBody3D) -> void:
	var shop_menu := player.get_node_or_null(
		"DealerShopMenu"
	) as DealerShopMenu
	if shop_menu != null:
		shop_menu.open_for(npc)


func try_purchase(player: CharacterBody3D) -> String:
	var trade_service := player.get_node(
		"Components/TradeService"
	) as TradeService
	return trade_service.buy_product(product).message
