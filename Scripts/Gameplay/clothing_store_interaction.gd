class_name ClothingStoreInteraction
extends Area3D


func _ready() -> void:
	add_to_group(&"interactable")


func can_interact(player: CharacterBody3D) -> bool:
	return player != null and player.get_node_or_null("ClothingStoreMenu") != null


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return "E - Browse Clothing"


func interact(player: CharacterBody3D) -> void:
	var menu := player.get_node_or_null("ClothingStoreMenu")
	if menu != null and menu.has_method("open_store"):
		menu.call("open_store")
