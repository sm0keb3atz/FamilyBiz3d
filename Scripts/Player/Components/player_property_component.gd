class_name PlayerPropertyComponent
extends Node

signal ownership_changed(property_id: StringName, owned: bool)
signal stash_changed(property_id: StringName)
signal business_state_changed(property_id: StringName)
signal business_sale_processed(
	property_id: StringName,
	sale_absolute_minute: int
)

@export var wallet_component_path := NodePath("../WalletComponent")
@export var inventory_component_path := NodePath("../InventoryComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var inventory := get_node(inventory_component_path) as PlayerInventoryComponent
@onready var weapon := get_node(weapon_component_path) as PlayerWeaponComponent

var _owned: Dictionary[StringName, bool] = {}
var _stashes: Dictionary[StringName, Dictionary] = {}
var _businesses: Dictionary[StringName, Dictionary] = {}


func owns(property_id: StringName) -> bool:
	return bool(_owned.get(property_id, false))


func purchase(property_id: StringName, current_absolute_minute := -1) -> bool:
	var definition := PropertyCatalog.get_by_id(property_id)
	if definition == null or owns(property_id):
		return false
	if not wallet.spend_clean(definition.purchase_price):
		return false
	_owned[property_id] = true
	if definition.is_stash_house():
		_ensure_stash(property_id)
	elif definition.is_front_business():
		var state := _ensure_business(property_id)
		state["last_processed_absolute_minute"] = current_absolute_minute
		business_state_changed.emit(property_id)
	ownership_changed.emit(property_id, true)
	return true


func get_business_state(property_id: StringName) -> Dictionary:
	var definition := PropertyCatalog.get_by_id(property_id)
	if definition == null or not definition.is_front_business():
		return {}
	return _ensure_business(property_id).duplicate(true)


func get_business_stock(property_id: StringName) -> int:
	return int(_ensure_business(property_id).get("stock", 0)) if _is_front_business(property_id) else 0


func get_business_accumulated_earnings(property_id: StringName) -> int:
	return int(_ensure_business(property_id).get("accumulated_earnings", 0)) if _is_front_business(property_id) else 0


func get_business_total_earned(property_id: StringName) -> int:
	return int(_ensure_business(property_id).get("total_earned", 0)) if _is_front_business(property_id) else 0


func get_business_total_sales(property_id: StringName) -> int:
	return int(_ensure_business(property_id).get("total_sales", 0)) if _is_front_business(property_id) else 0


func get_business_total_restock_spent(property_id: StringName) -> int:
	return int(_ensure_business(property_id).get("total_restock_spent", 0)) if _is_front_business(property_id) else 0


func get_business_daily_revenue(property_id: StringName, absolute_day: int) -> int:
	if not _is_front_business(property_id) or absolute_day < 0:
		return 0
	var daily := _ensure_business(property_id).get("daily_revenue", {}) as Dictionary
	return maxi(int(daily.get(str(absolute_day), 0)), 0)


func restock_business(property_id: StringName, requested_units: int) -> bool:
	var definition := PropertyCatalog.get_by_id(property_id)
	if (
		definition == null
		or not definition.is_front_business()
		or not owns(property_id)
		or requested_units <= 0
	):
		return false
	var state := _ensure_business(property_id)
	var stock := int(state.get("stock", 0))
	if stock + requested_units > definition.business_stock_capacity:
		return false
	var total_cost := requested_units * definition.business_restock_unit_cost
	if not wallet.spend_dirty(total_cost):
		return false
	state["stock"] = stock + requested_units
	state["total_restock_spent"] = int(state.get("total_restock_spent", 0)) + total_cost
	business_state_changed.emit(property_id)
	return true


func process_businesses_to(target_absolute_minute: int) -> void:
	if target_absolute_minute < 0:
		return
	for property_id in PropertyCatalog.BUSINESS_IDS:
		if not owns(property_id):
			continue
		var definition := PropertyCatalog.get_by_id(property_id)
		var state := _ensure_business(property_id)
		var last_minute := int(state.get("last_processed_absolute_minute", -1))
		if last_minute < 0:
			state["last_processed_absolute_minute"] = target_absolute_minute
			continue
		if target_absolute_minute <= last_minute:
			continue
		var stock := int(state.get("stock", 0))
		var earned := 0
		var sold := 0
		var daily := state.get("daily_revenue", {}) as Dictionary
		var first_day := last_minute / WorldTimeComponent.MINUTES_PER_DAY
		var last_day := target_absolute_minute / WorldTimeComponent.MINUTES_PER_DAY
		for day_index in range(first_day, last_day + 1):
			var sale_minute := (
				definition.business_open_minute
				+ definition.business_sales_interval_minutes
			)
			while sale_minute < definition.business_close_minute:
				var slot := day_index * WorldTimeComponent.MINUTES_PER_DAY + sale_minute
				if slot > last_minute and slot <= target_absolute_minute and stock > 0:
					stock -= 1
					earned += definition.business_revenue_per_sale
					sold += 1
					var day_key := str(day_index)
					daily[day_key] = int(daily.get(day_key, 0)) + definition.business_revenue_per_sale
					business_sale_processed.emit(property_id, slot)
				sale_minute += definition.business_sales_interval_minutes
		state["stock"] = stock
		state["last_processed_absolute_minute"] = target_absolute_minute
		if earned > 0:
			state["accumulated_earnings"] = int(state.get("accumulated_earnings", 0)) + earned
			state["total_earned"] = int(state.get("total_earned", 0)) + earned
			state["total_sales"] = int(state.get("total_sales", 0)) + sold
			state["daily_revenue"] = _trim_daily_revenue(daily)
			business_state_changed.emit(property_id)


func settle_business_earnings() -> int:
	var deposited := 0
	for property_id in PropertyCatalog.BUSINESS_IDS:
		if not owns(property_id):
			continue
		var state := _ensure_business(property_id)
		var amount := int(state.get("accumulated_earnings", 0))
		if amount <= 0:
			continue
		if wallet.add_clean(amount):
			state["accumulated_earnings"] = 0
			deposited += amount
			business_state_changed.emit(property_id)
	return deposited


func get_owned_definitions() -> Array[PropertyDefinition]:
	var result: Array[PropertyDefinition] = []
	for definition in PropertyCatalog.get_all():
		if owns(definition.property_id):
			result.append(definition)
	return result


func get_stashed_dirty_cash(property_id: StringName) -> int:
	return int(_ensure_stash(property_id).get("dirty_cash", 0))


func get_stash_capacity(property_id: StringName) -> int:
	var definition := PropertyCatalog.get_by_id(property_id)
	return definition.stash_capacity if definition != null and definition.is_stash_house() else 0


func get_stash_used_capacity(property_id: StringName) -> int:
	var stash := _ensure_stash(property_id)
	var used := (stash.get("weapons", {}) as Dictionary).size()
	for value in (stash.get("products", {}) as Dictionary).values():
		used += maxi(int(value), 0)
	return used


func get_stash_remaining_capacity(property_id: StringName) -> int:
	return maxi(get_stash_capacity(property_id) - get_stash_used_capacity(property_id), 0)


func transfer_dirty_cash(property_id: StringName, requested_amount: int, to_stash: bool) -> int:
	if not owns(property_id) or not _is_stash_house(property_id) or requested_amount <= 0:
		return 0
	var stash := _ensure_stash(property_id)
	var available := wallet.dirty_cash if to_stash else int(stash.get("dirty_cash", 0))
	var amount := mini(requested_amount, available)
	if amount <= 0:
		return 0
	if to_stash:
		if not wallet.spend_dirty(amount, false):
			return 0
		stash["dirty_cash"] = int(stash.get("dirty_cash", 0)) + amount
	else:
		stash["dirty_cash"] = int(stash.get("dirty_cash", 0)) - amount
		wallet.add_dirty(amount, false)
	stash_changed.emit(property_id)
	return amount


func get_stashed_product_quantity(property_id: StringName, product: ProductDefinition) -> int:
	if product == null:
		return 0
	var products := _ensure_stash(property_id).get("products", {}) as Dictionary
	return int(products.get(String(product.product_id), 0))


func get_territory_stashed_product_quantity(territory_id: StringName, product: ProductDefinition) -> int:
	var total := 0
	for definition in PropertyCatalog.get_all():
		if definition.territory_id == territory_id and definition.is_stash_house() and owns(definition.property_id):
			total += get_stashed_product_quantity(definition.property_id, product)
	return total


func get_territory_stash_summary(territory_id: StringName, products: Array[ProductDefinition]) -> Dictionary:
	var result := {"dirty_cash": 0, "product_units": 0, "products": {}, "stashes": []}
	var totals := result.products as Dictionary
	var stashes := result.stashes as Array
	for definition in PropertyCatalog.get_all():
		if definition.territory_id != territory_id or not definition.is_stash_house() or not owns(definition.property_id):
			continue
		var entry := {"property_id": definition.property_id, "display_name": definition.display_name,
			"dirty_cash": get_stashed_dirty_cash(definition.property_id), "products": {}}
		result.dirty_cash += int(entry.dirty_cash)
		var entry_products := entry.products as Dictionary
		for product in products:
			if product == null:
				continue
			var quantity := get_stashed_product_quantity(definition.property_id, product)
			entry_products[String(product.product_id)] = quantity
			totals[String(product.product_id)] = int(totals.get(String(product.product_id), 0)) + quantity
			result.product_units += quantity
		stashes.append(entry)
	return result


func process_territory_dealer_sale(territory_id: StringName, product: ProductDefinition,
	amount: int, net_dirty_cash: int) -> StringName:
	if product == null or amount <= 0 or net_dirty_cash < 0:
		return &""
	for definition in PropertyCatalog.get_all():
		if definition.territory_id != territory_id or not definition.is_stash_house() or not owns(definition.property_id):
			continue
		var stash := _ensure_stash(definition.property_id)
		var products := stash.get("products", {}) as Dictionary
		var key := String(product.product_id)
		var stored := int(products.get(key, 0))
		if stored < amount:
			continue
		products[key] = stored - amount
		if int(products[key]) <= 0:
			products.erase(key)
		stash.products = products
		stash.dirty_cash = int(stash.get("dirty_cash", 0)) + net_dirty_cash
		stash_changed.emit(definition.property_id)
		return definition.property_id
	return &""


func transfer_product(property_id: StringName, product: ProductDefinition, requested_amount: int, to_stash: bool) -> int:
	if not owns(property_id) or not _is_stash_house(property_id) or product == null or requested_amount <= 0:
		return 0
	var stash := _ensure_stash(property_id)
	var products := stash.get("products", {}) as Dictionary
	var stored := int(products.get(String(product.product_id), 0))
	var available := inventory.get_quantity(product) if to_stash else stored
	if to_stash:
		available = mini(available, get_stash_remaining_capacity(property_id))
	var amount := mini(requested_amount, available)
	if amount <= 0:
		return 0
	if to_stash:
		if not inventory.remove_product(product, amount):
			return 0
		products[String(product.product_id)] = stored + amount
	else:
		products[String(product.product_id)] = stored - amount
		if not inventory.add_product(product, amount):
			products[String(product.product_id)] = stored
			return 0
	stash["products"] = products
	stash_changed.emit(property_id)
	return amount


func get_stashed_weapon_ids(property_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var weapons := _ensure_stash(property_id).get("weapons", {}) as Dictionary
	for definition in weapon.get_catalog_weapons():
		if weapons.has(String(definition.weapon_id)):
			result.append(definition.weapon_id)
	return result


func store_weapon(property_id: StringName, weapon_id: StringName) -> bool:
	if not owns(property_id) or not _is_stash_house(property_id) or get_stash_remaining_capacity(property_id) <= 0:
		return false
	var stash := _ensure_stash(property_id)
	var weapons := stash.get("weapons", {}) as Dictionary
	if weapons.has(String(weapon_id)):
		return false
	var state := weapon.remove_weapon_with_state(weapon_id)
	if state.is_empty():
		return false
	weapons[String(weapon_id)] = state
	stash["weapons"] = weapons
	stash_changed.emit(property_id)
	return true


func take_weapon(property_id: StringName, weapon_id: StringName) -> bool:
	if not owns(property_id) or not _is_stash_house(property_id) or weapon.owns_weapon(weapon_id):
		return false
	var stash := _ensure_stash(property_id)
	var weapons := stash.get("weapons", {}) as Dictionary
	var state := weapons.get(String(weapon_id), {}) as Dictionary
	if state.is_empty() or not weapon.restore_weapon_state(state):
		return false
	weapons.erase(String(weapon_id))
	stash["weapons"] = weapons
	stash_changed.emit(property_id)
	return true


func get_stash_summary(property_id: StringName) -> Dictionary:
	var stash := _ensure_stash(property_id)
	var product_units := 0
	for value in (stash.get("products", {}) as Dictionary).values():
		product_units += maxi(int(value), 0)
	return {
		"dirty_cash": maxi(int(stash.get("dirty_cash", 0)), 0),
		"product_units": product_units,
		"weapon_count": (stash.get("weapons", {}) as Dictionary).size(),
		"used_capacity": product_units + (stash.get("weapons", {}) as Dictionary).size(),
		"capacity": get_stash_capacity(property_id),
		"remaining_capacity": get_stash_remaining_capacity(property_id),
	}


func export_save_data() -> Dictionary:
	var owned_ids: Array[String] = []
	var stash_data := {}
	var business_data := {}
	for definition in PropertyCatalog.get_all():
		if owns(definition.property_id):
			owned_ids.append(String(definition.property_id))
			if definition.is_stash_house():
				stash_data[String(definition.property_id)] = _sanitize_stash(_ensure_stash(definition.property_id))
			elif definition.is_front_business():
				business_data[String(definition.property_id)] = _sanitize_business(
					definition.property_id,
					_ensure_business(definition.property_id)
				)
	return {"owned_ids": owned_ids, "stashes": stash_data, "businesses": business_data}


func import_save_data(data: Dictionary) -> void:
	var previously_owned := _owned.keys()
	_owned.clear()
	_stashes.clear()
	_businesses.clear()
	for value in data.get("owned_ids", []) as Array:
		var property_id := StringName(str(value))
		if PropertyCatalog.get_by_id(property_id) != null:
			_owned[property_id] = true
	var saved_stashes := data.get("stashes", {}) as Dictionary
	var saved_businesses := data.get("businesses", {}) as Dictionary
	for definition in PropertyCatalog.get_all():
		var property_id := definition.property_id
		if owns(property_id):
			if definition.is_stash_house():
				var saved := saved_stashes.get(String(property_id), {}) as Dictionary
				_stashes[property_id] = _sanitize_stash(saved)
				stash_changed.emit(property_id)
			elif definition.is_front_business():
				var saved := saved_businesses.get(String(property_id), {}) as Dictionary
				_businesses[property_id] = _sanitize_business(property_id, saved)
				business_state_changed.emit(property_id)
			ownership_changed.emit(property_id, owns(property_id))
	for previous_id in previously_owned:
		var property_id := StringName(previous_id)
		if not owns(property_id):
			ownership_changed.emit(property_id, false)
			if _is_front_business(property_id):
				business_state_changed.emit(property_id)


func _ensure_stash(property_id: StringName) -> Dictionary:
	if not _stashes.has(property_id):
		_stashes[property_id] = {"dirty_cash": 0, "products": {}, "weapons": {}}
	return _stashes[property_id]


func _ensure_business(property_id: StringName) -> Dictionary:
	if not _businesses.has(property_id):
		_businesses[property_id] = {
			"stock": 0,
			"accumulated_earnings": 0,
			"total_earned": 0,
			"total_sales": 0,
			"total_restock_spent": 0,
			"daily_revenue": {},
			"last_processed_absolute_minute": -1,
		}
	return _businesses[property_id]


func _is_stash_house(property_id: StringName) -> bool:
	var definition := PropertyCatalog.get_by_id(property_id)
	return definition != null and definition.is_stash_house()


func _is_front_business(property_id: StringName) -> bool:
	var definition := PropertyCatalog.get_by_id(property_id)
	return definition != null and definition.is_front_business()


func _sanitize_stash(source: Dictionary) -> Dictionary:
	var result := {"dirty_cash": maxi(int(source.get("dirty_cash", 0)), 0), "products": {}, "weapons": {}}
	var source_products := source.get("products", {}) as Dictionary
	var products := result["products"] as Dictionary
	for product in EconomyCatalog.get_all_products():
		var amount := maxi(int(source_products.get(String(product.product_id), 0)), 0)
		if amount > 0:
			products[String(product.product_id)] = amount
	var source_weapons := source.get("weapons", {}) as Dictionary
	var weapons := result["weapons"] as Dictionary
	for definition in weapon.get_catalog_weapons():
		var key := String(definition.weapon_id)
		var state := source_weapons.get(key, {}) as Dictionary
		if not state.is_empty():
			var copy := state.duplicate(true)
			copy["weapon_id"] = key
			weapons[key] = copy
	return result


func _sanitize_business(property_id: StringName, source: Dictionary) -> Dictionary:
	var definition := PropertyCatalog.get_by_id(property_id)
	var capacity := definition.business_stock_capacity if definition != null else 0
	return {
		"stock": clampi(int(source.get("stock", 0)), 0, capacity),
		"accumulated_earnings": maxi(int(source.get("accumulated_earnings", 0)), 0),
		"total_earned": maxi(int(source.get("total_earned", 0)), 0),
		"total_sales": maxi(int(source.get("total_sales", 0)), 0),
		"total_restock_spent": maxi(int(source.get("total_restock_spent", 0)), 0),
		"daily_revenue": _trim_daily_revenue(source.get("daily_revenue", {}) as Dictionary),
		"last_processed_absolute_minute": maxi(
			int(source.get("last_processed_absolute_minute", -1)),
			-1
		),
	}


func _trim_daily_revenue(source: Dictionary) -> Dictionary:
	var days: Array[int] = []
	for key in source.keys():
		var day_index := int(str(key))
		if day_index >= 0 and not days.has(day_index):
			days.append(day_index)
	days.sort()
	while days.size() > 30:
		days.pop_front()
	var result := {}
	for day_index in days:
		var amount := maxi(int(source.get(str(day_index), source.get(day_index, 0))), 0)
		if amount > 0:
			result[str(day_index)] = amount
	return result
