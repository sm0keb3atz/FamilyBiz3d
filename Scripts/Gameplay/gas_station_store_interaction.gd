class_name GasStationStoreInteraction
extends Area3D


func _ready() -> void:
	add_to_group(&"interactable")


func can_interact(player: CharacterBody3D) -> bool:
	return player != null and player.get_node_or_null("GasStationMenu") != null


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return "E - Open Gas Station Store"


func interact(player: CharacterBody3D) -> void:
	var menu := player.get_node_or_null("GasStationMenu") as GasStationMenu
	if menu != null:
		menu.open_store()
