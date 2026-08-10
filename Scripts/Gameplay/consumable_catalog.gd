class_name ConsumableCatalog
extends RefCounted

static var _items: Array[ConsumableDefinition] = []
static var _by_id: Dictionary[StringName, ConsumableDefinition] = {}


static func get_all() -> Array[ConsumableDefinition]:
	_ensure()
	return _items.duplicate()


static func get_by_id(item_id: StringName) -> ConsumableDefinition:
	_ensure()
	return _by_id.get(item_id) as ConsumableDefinition


static func _ensure() -> void:
	if not _items.is_empty():
		return
	_register(_make(&"bottled_water", "Bottled Water", 15, 40, 0, 25))
	_register(_make(&"protein_bar", "Protein Bar", 25, 30, 20, 0))
	_register(_make(&"trail_mix", "Trail Mix", 40, 40, 15, 25))
	_register(_make(&"energy_drink", "Energy Drink", 75, 50, 0, 40, 1.0, 2.0, 60))
	_register(_make(&"recovery_shake", "Recovery Shake", 100, 60, 25, 0, 2.0, 1.0, 60))
	var fuel_can := _make(&"emergency_fuel_can", "Emergency Fuel Can", 100, 150, 0, 0)
	fuel_can.vehicle_fuel_gallons = 1.0
	fuel_can.description = "Adds one gallon to a nearby vehicle."
	_register(fuel_can)


static func _make(
	id: StringName,
	label: String,
	price: int,
	weight: int,
	health: float,
	stamina: float,
	health_regen := 1.0,
	stamina_regen := 1.0,
	duration := 0
) -> ConsumableDefinition:
	var item := ConsumableDefinition.new()
	item.item_id = id
	item.display_name = label
	item.price = price
	item.weight_grams = weight
	item.health_restore = health
	item.stamina_restore = stamina
	item.health_regen_multiplier = health_regen
	item.stamina_regen_multiplier = stamina_regen
	item.duration_game_minutes = duration
	item.description = _description(item)
	return item


static func _description(item: ConsumableDefinition) -> String:
	var parts: Array[String] = []
	if item.health_restore > 0.0:
		parts.append("Restores %d health" % roundi(item.health_restore))
	if item.stamina_restore > 0.0:
		parts.append("Restores %d stamina" % roundi(item.stamina_restore))
	if item.health_regen_multiplier > 1.0:
		parts.append("2x health regeneration for 1 game hour")
	if item.stamina_regen_multiplier > 1.0:
		parts.append("2x stamina regeneration for 1 game hour")
	return ". ".join(parts) + "."


static func _register(item: ConsumableDefinition) -> void:
	_items.append(item)
	_by_id[item.item_id] = item
