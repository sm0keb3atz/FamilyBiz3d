class_name PropertyInteraction
extends Area3D

enum InteractionType {
	FOR_SALE,
	BED,
	WARDROBE,
	STASH,
}

@export var interaction_type := InteractionType.FOR_SALE

@onready var building := get_parent() as PropertyBuilding


func _ready() -> void:
	add_to_group(&"interactable")


func can_interact(player: CharacterBody3D) -> bool:
	if player == null or building == null or building.get_definition() == null:
		return false
	if interaction_type == InteractionType.FOR_SALE:
		return not building.is_owned() and player.get_node_or_null("PropertyPurchaseMenu") != null
	if not building.is_owned():
		return false
	match interaction_type:
		InteractionType.WARDROBE:
			return player.get_node_or_null("ClothingStoreMenu") != null
		InteractionType.STASH:
			return player.get_node_or_null("PropertyStashMenu") != null
		InteractionType.BED:
			return _get_world_controller() != null
	return false


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	var definition := building.get_definition()
	match interaction_type:
		InteractionType.FOR_SALE:
			return "E - Buy %s ($%s Clean)" % [definition.display_name, _money(definition.purchase_price)]
		InteractionType.BED:
			return "E - Sleep Until Morning & Save"
		InteractionType.WARDROBE:
			return "E - Open Wardrobe"
		InteractionType.STASH:
			return "E - Open Stash"
	return "E - Interact"


func interact(player: CharacterBody3D) -> void:
	if not can_interact(player):
		return
	match interaction_type:
		InteractionType.FOR_SALE:
			player.get_node("PropertyPurchaseMenu").call("open_property", building.property_id)
		InteractionType.BED:
			_get_world_controller().call("sleep_at_property", building.property_id)
		InteractionType.WARDROBE:
			player.get_node("ClothingStoreMenu").call("open_wardrobe")
		InteractionType.STASH:
			player.get_node("PropertyStashMenu").call("open_stash", building.property_id)


func _money(amount: int) -> String:
	var text := str(amount)
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result


func _get_world_controller() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		return scene.get_node_or_null("WorldController")
	for child in get_tree().root.get_children():
		var controller := child.get_node_or_null("WorldController")
		if controller != null:
			return controller
	return null
