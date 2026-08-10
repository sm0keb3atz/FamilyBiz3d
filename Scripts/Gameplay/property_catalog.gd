class_name PropertyCatalog
extends RefCounted

const PURCHASE_PRICE := 10000
const HOOD_DEALER_CAPACITY := 2
const HOOD_VEHICLE_STORAGE_CAPACITY := 2
const BRICK_STATION_COST := 5000
const BRICK_STATION_INTERVAL_MINUTES := 3 * 60
const RUNNER_UPGRADE_COST := 5000
const PROPERTY_IDS: Array[StringName] = [
	&"hood_east_house_1",
	&"hood_east_house_2",
	&"hood_east_house_3",
	&"hood_east_house_4",
]
const CLOTHING_STORE_ID := &"hood_east_clothing_store"
const GUN_STORE_ID := &"hood_east_gun_store"
const DOWNTOWN_CAR_DEALERSHIP_ID := &"downtown_east_car_dealership"
const GAS_STATION_ID := &"hood_east_gas_station"
const BUSINESS_IDS: Array[StringName] = [
	CLOTHING_STORE_ID,
	GUN_STORE_ID,
	DOWNTOWN_CAR_DEALERSHIP_ID,
	GAS_STATION_ID,
]

static var _definitions: Array[PropertyDefinition] = []
static var _by_id: Dictionary[StringName, PropertyDefinition] = {}


static func get_all() -> Array[PropertyDefinition]:
	_ensure_catalog()
	return _definitions.duplicate()


static func get_by_id(property_id: StringName) -> PropertyDefinition:
	_ensure_catalog()
	return _by_id.get(property_id) as PropertyDefinition


static func _ensure_catalog() -> void:
	if not _definitions.is_empty():
		return
	for index in PROPERTY_IDS.size():
		var definition := PropertyDefinition.new(
			PROPERTY_IDS[index],
			"Hood House %d" % (index + 1),
			"Hood East",
			PURCHASE_PRICE,
			1000,
			&"hood_east",
			PropertyDefinition.PropertyRole.STASH_HOUSE,
			0,
			0,
			0,
			0,
			0,
			0,
			HOOD_DEALER_CAPACITY,
			BRICK_STATION_COST,
			BRICK_STATION_INTERVAL_MINUTES,
			"Business",
			HOOD_VEHICLE_STORAGE_CAPACITY
		)
		_definitions.append(definition)
		_by_id[definition.property_id] = definition
	_register(PropertyDefinition.new(
		CLOTHING_STORE_ID,
		"Hood East Clothing Store",
		"Hood East",
		15000,
		0,
		&"hood_east",
		PropertyDefinition.PropertyRole.FRONT_BUSINESS,
		30,
		100,
		150,
		60,
		9 * 60,
		21 * 60,
		0,
		0,
		0,
		"Clothing Store"
	))
	_register(PropertyDefinition.new(
		GUN_STORE_ID,
		"Hood East Gun Store",
		"Hood East",
		25000,
		0,
		&"hood_east",
		PropertyDefinition.PropertyRole.FRONT_BUSINESS,
		20,
		250,
		400,
		120,
		10 * 60,
		20 * 60,
		0,
		0,
		0,
		"Gun Store"
	))
	_register(PropertyDefinition.new(
		DOWNTOWN_CAR_DEALERSHIP_ID,
		"Downtown East Car Dealership",
		"Downtown East",
		75000,
		0,
		&"downtown_east",
		PropertyDefinition.PropertyRole.FRONT_BUSINESS,
		6,
		2000,
		3000,
		180,
		9 * 60,
		21 * 60,
		0,
		0,
		0,
		"Car Dealership"
	))
	_register(PropertyDefinition.new(
		GAS_STATION_ID,
		"Hood East Gas Station",
		"Hood East",
		50000,
		0,
		&"hood_east",
		PropertyDefinition.PropertyRole.FRONT_BUSINESS,
		36,
		125,
		250,
		120,
		0,
		1440,
		0,
		0,
		0,
		"Gas Station"
	))


static func _register(definition: PropertyDefinition) -> void:
	_definitions.append(definition)
	_by_id[definition.property_id] = definition
