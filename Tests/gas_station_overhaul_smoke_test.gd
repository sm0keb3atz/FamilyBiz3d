extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var station_scene := load(
		"res://Scenes/Maps/Buildings/gas_station.tscn"
	) as PackedScene
	assert(station_scene != null)
	var station := station_scene.instantiate() as GasStationController
	root.add_child(station)
	await process_frame
	assert(station != null)
	assert(station.get_node("GasPumpArea") is Area3D)
	assert(station.get_node("CarShopArea") is Area3D)
	assert(station.get_node("StoreInteraction") is GasStationStoreInteraction)
	assert(station.get_node("CustomerVisit") is StoreCustomerVisit3D)
	assert(station.get_node("CustomerVisit/Entrance") is Marker3D)
	assert(station.get_node("CustomerVisit/Browse") is Marker3D)
	assert(station.get_node("CustomerVisit/Counter") is Marker3D)
	assert(station.get_node("CustomerVisit/Exit") is Marker3D)
	assert(station.get_discounted_price(4) == 4)

	var player := (
		load("res://Scenes/Player.tscn") as PackedScene
	).instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	var menu := player.get_node("GasStationMenu") as GasStationMenu
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var consumables := player.get_node(
		"Components/ConsumableComponent"
	) as PlayerConsumableComponent
	assert(menu != null and consumables != null)
	assert(menu.find_child("ShopTab", true, false) != null)
	assert(menu.find_child("BusinessTab", true, false) != null)
	assert(menu.find_child("BusinessManagementPanel", true, false) != null)
	assert(menu.find_child("AutoServicePage", true, false) != null)
	for item in ConsumableCatalog.get_all():
		assert(item != null and item.is_valid())
	var supply_payload := {}
	for item in ConsumableCatalog.get_all():
		supply_payload[String(item.item_id)] = 1
	inventory.import_save_data({"consumables": supply_payload})
	assert((inventory.export_save_data().get("consumables", {}) as Dictionary).size() == 6)

	print("GAS_STATION_OVERHAUL_SMOKE_TEST_PASS")
	quit(0)
