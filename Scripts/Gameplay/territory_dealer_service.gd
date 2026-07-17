class_name TerritoryDealerService
extends Node

signal state_changed(territory_id: StringName)
signal dealer_sale_processed(
	territory_id: StringName, zone_id: StringName, member_id: StringName,
	product: ProductDefinition, property_id: StringName,
	gross: int, commission: int, net: int, absolute_minute: int
)

const HIRE_FEE := 500
const UPGRADE_COSTS := [1000, 2000, 4000]
const SALE_INTERVALS := [120, 90, 60, 45]
const COMMISSION_RATE := 0.10
const DAILY_HISTORY_LIMIT := 31
const SELLABLE_PRODUCTS: Array[ProductDefinition] = [
	EconomyCatalog.WEED_1G, EconomyCatalog.COKE_1G, EconomyCatalog.FENT_1G,
]

@export var player_path := NodePath("../Gameplay/Player")
@export var world_time_path := NodePath("../WorldTimeComponent")

@onready var player := get_node(player_path) as CharacterBody3D
@onready var world_time := get_node(world_time_path) as WorldTimeComponent
@onready var properties := player.get_node("Components/PropertyComponent") as PlayerPropertyComponent
@onready var wallet := player.get_node("Components/WalletComponent") as PlayerWalletComponent
@onready var trade := player.get_node("Components/TradeService") as TradeService

var _territories: Dictionary = {}


func _ready() -> void:
	add_to_group(&"territory_dealer_service")
	call_deferred("_connect_runtime")


func _connect_runtime() -> void:
	var encounter := get_tree().get_first_node_in_group(&"territory_encounter") as TerritoryEncounterController
	if encounter != null and not encounter.territory_claimed.is_connected(_on_territory_claimed):
		encounter.territory_claimed.connect(_on_territory_claimed)
	for zone in _all_zones():
		var callback := _on_zone_member_defeated.bind(zone)
		if not zone.member_defeated.is_connected(callback):
			zone.member_defeated.connect(callback)
	for territory_id in _owned_territory_ids():
		_ensure_territory(territory_id)
		_apply_staffing(territory_id)


func process_to(target_minute: int) -> void:
	if target_minute < 0:
		return
	for territory_id in _owned_territory_ids():
		_ensure_territory(territory_id)
		for entry in get_roster(territory_id):
			if not bool(entry.employed):
				continue
			var key := _slot_key(entry.zone_id, entry.member_id)
			var state := _get_slot_state(territory_id, key)
			var interval := get_sale_interval(int(state.level))
			var next_sale := int(state.get("next_sale_minute", -1))
			if next_sale < 0:
				next_sale = target_minute + interval
			var sale_processed := false
			while next_sale <= target_minute:
				sale_processed = _try_process_sale(territory_id, key, state, next_sale) or sale_processed
				next_sale += interval
			state.next_sale_minute = next_sale
			_set_slot_state(territory_id, key, state)
			if sale_processed:
				state_changed.emit(territory_id)


func hire_dealer(territory_id: StringName, zone_id: StringName, member_id: StringName) -> bool:
	if not _is_player_owned(territory_id):
		return false
	var zone := _find_zone(zone_id)
	if zone == null or zone.territory_id != territory_id or zone.member_ids.find(String(member_id)) < 0:
		return false
	_ensure_territory(territory_id)
	var key := _slot_key(zone_id, member_id)
	var previous := _get_slot_state(territory_id, key)
	if bool(previous.get("employed", false)):
		return false
	var level := 1
	if not wallet.spend_dirty(get_hire_fee(level)):
		return false
	var state := previous if not previous.is_empty() else _new_slot_state(zone, member_id)
	state.level = level
	state.employed = true
	state.next_sale_minute = world_time.get_absolute_minute() + get_sale_interval(level)
	_set_slot_state(territory_id, key, state)
	zone.set_member_player_level(member_id, level)
	zone.set_member_employed(member_id, true)
	state_changed.emit(territory_id)
	return true


func fire_dealer(territory_id: StringName, zone_id: StringName, member_id: StringName) -> bool:
	var key := _slot_key(zone_id, member_id)
	var state := _get_slot_state(territory_id, key)
	if not bool(state.get("employed", false)):
		return false
	state.employed = false
	state.level = 1
	state.next_sale_minute = -1
	_set_slot_state(territory_id, key, state)
	var zone := _find_zone(zone_id)
	if zone != null:
		zone.set_member_employed(member_id, false)
		zone.set_member_player_level(member_id, 1)
	state_changed.emit(territory_id)
	return true


func upgrade_dealer(territory_id: StringName, zone_id: StringName, member_id: StringName) -> bool:
	if not _is_player_owned(territory_id):
		return false
	var key := _slot_key(zone_id, member_id)
	var state := _get_slot_state(territory_id, key)
	if not bool(state.get("employed", false)):
		return false
	var current_level := clampi(int(state.get("level", 1)), 1, 4)
	if current_level >= 4:
		return false
	var cost := get_upgrade_cost(current_level)
	if not wallet.spend_dirty(cost):
		return false
	var next_level := current_level + 1
	state.level = next_level
	state.next_sale_minute = world_time.get_absolute_minute() + get_sale_interval(next_level)
	_set_slot_state(territory_id, key, state)
	var zone := _find_zone(zone_id)
	if zone != null:
		zone.set_member_player_level(member_id, next_level)
	state_changed.emit(territory_id)
	return true


func get_roster(territory_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone in _get_zones(territory_id):
		for text in zone.member_ids:
			var member_id := StringName(text)
			var state := _get_slot_state(territory_id, _slot_key(zone.zone_id, member_id))
			var level := clampi(int(state.get("level", 1)), 1, 4)
			result.append({
				"zone_id": zone.zone_id, "member_id": member_id, "level": level,
				"employed": bool(state.get("employed", false)),
				"hire_fee": get_hire_fee(level), "sale_interval": get_sale_interval(level),
				"upgrade_cost": get_upgrade_cost(level), "max_level": level >= 4,
				"next_sale_minute": int(state.get("next_sale_minute", -1)),
				"today_gross": _today_value(state, "gross"),
				"today_commission": _today_value(state, "commission"),
				"today_net": _today_value(state, "net"),
				"lifetime_gross": int(state.get("lifetime_gross", 0)),
				"lifetime_commission": int(state.get("lifetime_commission", 0)),
				"lifetime_net": int(state.get("lifetime_net", 0)),
			})
	return result


func get_supply_summary(territory_id: StringName) -> Dictionary:
	return properties.get_territory_stash_summary(territory_id, SELLABLE_PRODUCTS)


func get_earnings_summary(territory_id: StringName) -> Dictionary:
	var result := {"staffed": 0, "total_slots": 0, "today_gross": 0,
		"today_commission": 0, "today_net": 0, "lifetime_gross": 0,
		"lifetime_commission": 0, "lifetime_net": 0}
	for entry in get_roster(territory_id):
		result.total_slots += 1
		if bool(entry.employed):
			result.staffed += 1
		for key in ["today_gross", "today_commission", "today_net",
			"lifetime_gross", "lifetime_commission", "lifetime_net"]:
			result[key] += int(entry[key])
	return result


func get_recent_daily_net(territory_id: StringName, day_count := 7) -> Array[int]:
	var result: Array[int] = []
	var current_day := world_time.get_absolute_minute() / WorldTimeComponent.MINUTES_PER_DAY
	for day in range(current_day - maxi(day_count, 1) + 1, current_day + 1):
		var net := 0
		for entry in get_roster(territory_id):
			var state := _get_slot_state(
				territory_id, _slot_key(entry.zone_id, entry.member_id)
			)
			var history := state.get("daily_history", {}) as Dictionary
			var totals := history.get(str(day), {}) as Dictionary
			net += int(totals.get("net", 0))
		result.append(net)
	return result


func get_dealer_status(zone_id: StringName, member_id: StringName) -> String:
	var zone := _find_zone(zone_id)
	if zone == null:
		return "Dealer status unavailable."
	var state := _get_slot_state(zone.territory_id, _slot_key(zone_id, member_id))
	if not bool(state.get("employed", false)):
		return "This dealer slot is vacant."
	var available := int(get_supply_summary(zone.territory_id).get("product_units", 0))
	var remaining := maxi(int(state.get("next_sale_minute", 0)) - world_time.get_absolute_minute(), 0)
	return "Level %d Dealer | %s | Next sale: %dm | Today: $%d net" % [
		int(state.level), "OUT OF STOCK" if available <= 0 else "%d units available" % available,
		remaining, _today_value(state, "net")]


func get_hire_fee(_level: int) -> int:
	return HIRE_FEE


func get_upgrade_cost(current_level: int) -> int:
	if current_level >= 4:
		return 0
	return UPGRADE_COSTS[clampi(current_level, 1, 3) - 1]


func get_sale_interval(level: int) -> int:
	return SALE_INTERVALS[clampi(level, 1, 4) - 1]


func export_save_data() -> Dictionary:
	return _territories.duplicate(true)


func import_save_data(data: Dictionary) -> void:
	_territories = data.duplicate(true)
	for territory_key in _territories.keys():
		var territory := _territories[territory_key] as Dictionary
		var slots := territory.get("slots", {}) as Dictionary
		for slot_key in slots.keys():
			var state := slots[slot_key] as Dictionary
			if not bool(state.get("employed", false)):
				state["level"] = 1
			_migrate_daily_history(state)
			slots[slot_key] = state
		territory["slots"] = slots
		_territories[territory_key] = territory
	for territory_id in _owned_territory_ids():
		_ensure_territory(territory_id)
		_apply_staffing(territory_id)
		state_changed.emit(territory_id)


func _try_process_sale(territory_id: StringName, key: String, state: Dictionary, minute: int) -> bool:
	var sale_index := int(state.get("sale_index", 0))
	state.sale_index = sale_index + 1
	for offset in SELLABLE_PRODUCTS.size():
		var product := SELLABLE_PRODUCTS[(sale_index + offset) % SELLABLE_PRODUCTS.size()]
		if properties.get_territory_stashed_product_quantity(territory_id, product) <= 0:
			continue
		var gross := trade.get_sale_pricing(product, territory_id, 1).y
		var commission := roundi(float(gross) * COMMISSION_RATE)
		var net := maxi(gross - commission, 0)
		var property_id := properties.process_territory_dealer_sale(territory_id, product, 1, net)
		if property_id.is_empty():
			continue
		_record_earnings(state, minute, gross, commission, net)
		world_time.record_external_transaction(net, 0)
		var ids := _split_slot_key(key)
		dealer_sale_processed.emit(territory_id, ids[0], ids[1], product,
			property_id, gross, commission, net, minute)
		var zone := _find_zone(ids[0])
		var dealer := zone.get_member_dealer(ids[1]) if zone != null else null
		if dealer != null:
			dealer.present_customer_sale()
		return true
	return false


func _record_earnings(state: Dictionary, minute: int, gross: int, commission: int, net: int) -> void:
	var day := minute / WorldTimeComponent.MINUTES_PER_DAY
	if int(state.get("today_day", -1)) != day:
		state.today_day = day
		state.today_gross = 0
		state.today_commission = 0
		state.today_net = 0
	state.today_gross = int(state.get("today_gross", 0)) + gross
	state.today_commission = int(state.get("today_commission", 0)) + commission
	state.today_net = int(state.get("today_net", 0)) + net
	state.lifetime_gross = int(state.get("lifetime_gross", 0)) + gross
	state.lifetime_commission = int(state.get("lifetime_commission", 0)) + commission
	state.lifetime_net = int(state.get("lifetime_net", 0)) + net
	var history := state.get("daily_history", {}) as Dictionary
	var day_key := str(day)
	var totals := history.get(day_key, {
		"gross": 0, "commission": 0, "net": 0,
	}) as Dictionary
	totals.gross = int(totals.get("gross", 0)) + gross
	totals.commission = int(totals.get("commission", 0)) + commission
	totals.net = int(totals.get("net", 0)) + net
	history[day_key] = totals
	state.daily_history = _trim_daily_history(history)


func _today_value(state: Dictionary, suffix: String) -> int:
	if world_time == null or int(state.get("today_day", -1)) != world_time.get_absolute_minute() / WorldTimeComponent.MINUTES_PER_DAY:
		return 0
	return int(state.get("today_%s" % suffix, 0))


func _on_territory_claimed(territory_id: StringName, _route: StringName) -> void:
	_territories.erase(String(territory_id))
	_ensure_territory(territory_id)
	_apply_staffing(territory_id)
	state_changed.emit(territory_id)


func _on_zone_member_defeated(_zone_id: StringName, member_id: StringName, zone: DealerActivityZone3D) -> void:
	if zone == null or zone.faction != TerritoryStatsComponent.OwnerFaction.PLAYER:
		return
	var key := _slot_key(zone.zone_id, member_id)
	var state := _get_slot_state(zone.territory_id, key)
	if not bool(state.get("employed", false)):
		return
	state.employed = false
	state.level = 1
	state.next_sale_minute = -1
	_set_slot_state(zone.territory_id, key, state)
	zone.set_member_employed(member_id, false)
	state_changed.emit(zone.territory_id)


func _ensure_territory(territory_id: StringName) -> void:
	var territory_key := String(territory_id)
	var territory := _territories.get(territory_key, {}) as Dictionary
	var slots := territory.get("slots", {}) as Dictionary
	for zone in _get_zones(territory_id):
		for text in zone.member_ids:
			var member_id := StringName(text)
			var key := _slot_key(zone.zone_id, member_id)
			if not slots.has(key):
				slots[key] = _new_slot_state(zone, member_id)
	territory.slots = slots
	_territories[territory_key] = territory


func _new_slot_state(zone: DealerActivityZone3D, member_id: StringName) -> Dictionary:
	return {"zone_id": String(zone.zone_id), "member_id": String(member_id),
		"level": 1, "employed": false,
		"next_sale_minute": -1, "sale_index": 0, "today_day": -1,
		"today_gross": 0, "today_commission": 0, "today_net": 0,
		"daily_history": {},
		"lifetime_gross": 0, "lifetime_commission": 0, "lifetime_net": 0}


func _migrate_daily_history(state: Dictionary) -> void:
	var history := state.get("daily_history", {}) as Dictionary
	var today_day := int(state.get("today_day", -1))
	if today_day >= 0 and not history.has(str(today_day)):
		history[str(today_day)] = {
			"gross": int(state.get("today_gross", 0)),
			"commission": int(state.get("today_commission", 0)),
			"net": int(state.get("today_net", 0)),
		}
	state.daily_history = _trim_daily_history(history)


func _trim_daily_history(history: Dictionary) -> Dictionary:
	var days: Array[int] = []
	for key in history.keys():
		days.append(int(key))
	days.sort()
	while days.size() > DAILY_HISTORY_LIMIT:
		history.erase(str(days.pop_front()))
	return history


func _apply_staffing(territory_id: StringName) -> void:
	for zone in _get_zones(territory_id):
		var staffing := {}
		for text in zone.member_ids:
			var member_id := StringName(text)
			var state := _get_slot_state(territory_id, _slot_key(zone.zone_id, member_id))
			staffing[String(member_id)] = bool(state.get("employed", false))
			zone.set_member_player_level(member_id, clampi(int(state.get("level", 1)), 1, 4))
		zone.apply_player_staffing(staffing)


func _get_slot_state(territory_id: StringName, key: String) -> Dictionary:
	var territory := _territories.get(String(territory_id), {}) as Dictionary
	var slots := territory.get("slots", {}) as Dictionary
	return (slots.get(key, {}) as Dictionary).duplicate(true)


func _set_slot_state(territory_id: StringName, key: String, state: Dictionary) -> void:
	var territory_key := String(territory_id)
	var territory := _territories.get(territory_key, {}) as Dictionary
	var slots := territory.get("slots", {}) as Dictionary
	slots[key] = state
	territory.slots = slots
	_territories[territory_key] = territory


func _all_zones() -> Array[DealerActivityZone3D]:
	var result: Array[DealerActivityZone3D] = []
	for node in get_tree().get_nodes_in_group(&"dealer_activity_zone"):
		var zone := node as DealerActivityZone3D
		if zone != null:
			result.append(zone)
	return result


func _get_zones(territory_id: StringName) -> Array[DealerActivityZone3D]:
	var result: Array[DealerActivityZone3D] = []
	for zone in _all_zones():
		if zone.territory_id == territory_id:
			result.append(zone)
	result.sort_custom(func(a: DealerActivityZone3D, b: DealerActivityZone3D) -> bool:
		return String(a.zone_id) < String(b.zone_id))
	return result


func _find_zone(zone_id: StringName) -> DealerActivityZone3D:
	for zone in _all_zones():
		if zone.zone_id == zone_id:
			return zone
	return null


func _owned_territory_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.stats != null and boundary.stats.owner_faction == TerritoryStatsComponent.OwnerFaction.PLAYER:
			result.append(boundary.territory_id)
	return result


func _is_player_owned(territory_id: StringName) -> bool:
	return territory_id in _owned_territory_ids()


func _slot_key(zone_id: StringName, member_id: StringName) -> String:
	return "%s/%s" % [String(zone_id), String(member_id)]


func _split_slot_key(key: String) -> Array[StringName]:
	var parts := key.split("/", false, 1)
	return [StringName(parts[0]), StringName(parts[1])]
