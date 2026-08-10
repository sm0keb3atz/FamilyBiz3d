class_name CarDealershipService
extends Node

signal transaction_finished(message: String, success: bool)

@export var wallet_component_path := NodePath("../WalletComponent")
@export var garage_component_path := NodePath("../VehicleGarageComponent")
@export var player_path := NodePath("../..")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var garage := (
	get_node(garage_component_path) as PlayerVehicleGarageComponent
)
@onready var player := get_node(player_path) as CharacterBody3D


func purchase_vehicle(
	definition: VehicleDefinition,
	dealership: CarDealershipController
) -> BaseVehicle:
	if definition == null or not VehicleCatalog.is_valid_vehicle_id(
		definition.vehicle_id
	):
		_finish("This vehicle is unavailable.", false)
		return null
	if dealership == null:
		_finish("The dealership is unavailable.", false)
		return null
	if not wallet.can_spend_clean(definition.purchase_price):
		_finish("Not enough Clean Cash.", false)
		return null
	var delivery := dealership.get_first_free_delivery()
	if not bool(delivery.get("available", false)):
		_finish("Clear a parking space for vehicle delivery.", false)
		return null
	var container := player.get_parent() as Node3D
	var vehicle := garage.spawn_new_vehicle(
		definition.vehicle_id,
		delivery.get("transform") as Transform3D,
		container
	)
	if vehicle == null:
		_finish("Vehicle delivery failed.", false)
		return null
	dealership.register_delivery(delivery, vehicle)
	if not wallet.spend_clean(
		definition.purchase_price, true, "Vehicle Purchase", definition.display_name
	):
		garage.remove_owned_vehicle(vehicle)
		_finish("Purchase could not be completed.", false)
		return null
	_finish("Purchased %s. It is waiting outside." % definition.display_name, true)
	return vehicle


func sell_vehicle(
	vehicle: BaseVehicle,
	dealership: CarDealershipController
) -> bool:
	if (
		vehicle == null
		or dealership == null
		or not dealership.is_vehicle_parked_for_sale(vehicle, garage)
	):
		return _finish("Park an owned vehicle in a dealership space first.", false)
	var vehicle_id := vehicle.get_vehicle_id()
	var definition := VehicleCatalog.get_by_id(vehicle_id)
	var value := VehicleCatalog.get_resale_value(vehicle_id)
	if definition == null or value <= 0:
		return _finish("This vehicle cannot be sold.", false)
	if not garage.remove_owned_vehicle(vehicle):
		return _finish("Vehicle sale failed.", false)
	if not wallet.add_clean(value, true, "Vehicle Sale", definition.display_name):
		return _finish("Vehicle sale failed.", false)
	return _finish("Sold %s for $%d Clean Cash." % [definition.display_name, value], true)


func _finish(message: String, success: bool) -> bool:
	transaction_finished.emit(message, success)
	return success
