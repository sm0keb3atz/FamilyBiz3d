class_name CivilianRoleComponent
extends NPCRoleComponent

@export var product_wanted: ProductDefinition


func activate() -> void:
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
	)


func respond_to_solicitation(player: CharacterBody3D) -> bool:
	if not can_respond_to_solicitation():
		return false
	npc.begin_solicitation(player)
	return true


func can_interact(player: CharacterBody3D) -> bool:
	return (
		npc.is_pool_active()
		and not npc.is_defeated()
		and npc.is_waiting_for_customer_trade(player)
		and product_wanted != null
	)


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	if product_wanted == null:
		return ""
	return "E — Sell %s" % product_wanted.display_name


func interact(player: CharacterBody3D) -> void:
	if not can_interact(player):
		return
	var hud := player.get_node("PlayerHUD") as PlayerHUD
	var trade_service := player.get_node(
		"Components/TradeService"
	) as TradeService
	var result: TradeResult = trade_service.sell_product(
		product_wanted,
		npc.global_position
	)
	hud.show_feedback(result.message)
	npc.finish_customer_trade()
