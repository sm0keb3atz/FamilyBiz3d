class_name PropertyGarageInteraction
extends Marker3D

@onready var garage_controller := get_parent() as PropertyGarageController


func _ready() -> void:
	add_to_group(&"interactable")


func can_interact(player: CharacterBody3D) -> bool:
	return (
		player != null
		and garage_controller != null
		and garage_controller.is_available()
		and player.get_node_or_null("PropertyStashMenu") != null
	)


func get_interaction_prompt(player: CharacterBody3D) -> String:
	var garage := player.get_node_or_null(
		"Components/VehicleGarageComponent"
	) as PlayerVehicleGarageComponent
	var property_id := garage_controller.get_property_id()
	var capacity := garage.get_storage_capacity(property_id) if garage != null else 0
	var stored := garage.get_stored_count(property_id) if garage != null else 0
	return "E - Manage Garage (%d / %d)" % [stored, capacity]


func interact(player: CharacterBody3D) -> void:
	if not can_interact(player):
		return
	player.get_node("PropertyStashMenu").call(
		"open_local",
		garage_controller.building,
		&"garage"
	)
