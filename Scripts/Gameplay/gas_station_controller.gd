class_name GasStationController
extends Node3D

const PROPERTY_ID := &"hood_east_gas_station"
const BASE_FUEL_PRICE := 4
const PUMP_RATE_GALLONS_PER_SECOND := 2.0
const MAXIMUM_SERVICE_SPEED := 0.5

@export var gas_pump_area_path := NodePath("GasPumpArea")
@export var car_shop_area_path := NodePath("CarShopArea")

@onready var gas_pump_area := get_node(gas_pump_area_path) as Area3D
@onready var car_shop_area := get_node(car_shop_area_path) as Area3D

var _player: CharacterBody3D
var _wallet: PlayerWalletComponent
var _properties: PlayerPropertyComponent
var _vehicle_component: PlayerVehicleComponent
var _hud: PlayerHUD
var _menu: GasStationMenu
var _pump_vehicle: BaseVehicle
var _dispensed := 0.0
var _session_cost := 0


func _ready() -> void:
	call_deferred("_resolve_player")


func _process(delta: float) -> void:
	if _player == null:
		_resolve_player()
		return
	var vehicle := _vehicle_component.get_current_vehicle() as BaseVehicle
	if vehicle == null:
		_clear_pump_session()
		_hud.set_vehicle_service_prompt("")
		return
	var stopped := vehicle.linear_velocity.length() <= MAXIMUM_SERVICE_SPEED
	if gas_pump_area.overlaps_body(vehicle):
		_process_pump(delta, vehicle, stopped)
		return
	_clear_pump_session()
	if car_shop_area.overlaps_body(vehicle):
		_hud.set_vehicle_service_prompt(
			"F - OPEN AUTO SHOP" if stopped else "STOP VEHICLE FOR AUTO SERVICE"
		)
		if stopped and Input.is_action_just_pressed(&"vehicle_service"):
			_menu.open_auto_shop(vehicle, self)
	else:
		_hud.set_vehicle_service_prompt("")


func get_discounted_price(base_price: int) -> int:
	return ceili(float(base_price) * (0.75 if is_owned() else 1.0))


func get_fuel_price() -> int:
	return get_discounted_price(BASE_FUEL_PRICE)


func is_owned() -> bool:
	return _properties != null and _properties.owns(PROPERTY_ID)


func _process_pump(delta: float, vehicle: BaseVehicle, stopped: bool) -> void:
	if _pump_vehicle != vehicle:
		_clear_pump_session()
		_pump_vehicle = vehicle
	var condition := vehicle.condition_component
	var is_full := condition.fuel_gallons >= condition.get_fuel_capacity() - 0.001
	var prompt := "TANK FULL" if is_full else (
		"HOLD F - REFUEL $%d/GAL" % get_fuel_price()
		if stopped
		else "STOP VEHICLE TO REFUEL"
	)
	_hud.set_vehicle_service_prompt(prompt)
	_hud.update_fuel_pump(
		true,
		condition.fuel_gallons,
		condition.get_fuel_capacity(),
		_dispensed,
		get_fuel_price(),
		_session_cost,
		_wallet.clean_cash
	)
	if not stopped or is_full or not Input.is_action_pressed(&"vehicle_service"):
		return
	var remaining := condition.get_fuel_capacity() - condition.fuel_gallons
	var requested := minf(PUMP_RATE_GALLONS_PER_SECOND * delta, remaining)
	var price := get_fuel_price()
	var affordable_total := float(_session_cost + _wallet.clean_cash) / float(price)
	requested = minf(requested, maxf(affordable_total - _dispensed, 0.0))
	if requested <= 0.0:
		_hud.show_feedback("NOT ENOUGH CLEAN CASH", 1.5)
		return
	var next_dispensed := _dispensed + requested
	var next_cost := ceili(next_dispensed * float(price))
	var charge := next_cost - _session_cost
	if charge > 0 and not _wallet.spend_clean(
		charge, true, "Vehicle Fuel", "Fuel pump purchase"
	):
		return
	var added := condition.add_fuel(requested)
	_dispensed += added
	_session_cost = next_cost


func _clear_pump_session() -> void:
	_pump_vehicle = null
	_dispensed = 0.0
	_session_cost = 0
	if _hud != null:
		_hud.update_fuel_pump(false)


func _resolve_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if _player == null:
		return
	_wallet = _player.get_node("Components/WalletComponent") as PlayerWalletComponent
	_properties = _player.get_node("Components/PropertyComponent") as PlayerPropertyComponent
	_vehicle_component = _player.get_node("Components/VehicleComponent") as PlayerVehicleComponent
	_hud = _player.get_node("PlayerHUD") as PlayerHUD
	_menu = _player.get_node("GasStationMenu") as GasStationMenu
