class_name PlayerPropertyComponent
extends Node

signal ownership_changed(property_id: StringName, owned: bool)
signal stash_changed(property_id: StringName)
signal brick_station_changed(property_id: StringName)
signal runner_changed(property_id: StringName)
signal business_state_changed(property_id: StringName)
signal business_sale_processed(
	property_id: StringName,
	sale_absolute_minute: int
)

@export var wallet_component_path := NodePath("../WalletComponent")
@export var inventory_component_path := NodePath("../InventoryComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var carry_weight_component_path := NodePath("../CarryWeightComponent")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var inventory := get_node(inventory_component_path) as PlayerInventoryComponent
@onready var weapon := get_node(weapon_component_path) as PlayerWeaponComponent
@onready var carry_weight := get_node(
	carry_weight_component_path
) as PlayerCarryWeightComponent

var _owned: Dictionary[StringName, bool] = {}
var _stashes: Dictionary[StringName, Dictionary] = {}
var _businesses: Dictionary[StringName, Dictionary] = {}
var last_transfer_error := ""


func has_runner(property_id: StringName) -> bool:
	return (
		owns(property_id)
		and _is_stash_house(property_id)
		and bool(_ensure_stash(property_id).get("runner_installed", false))
	)


func purchase_runner(property_id: StringName) -> bool:
	last_transfer_error = ""
	if not owns(property_id) or not _is_stash_house(property_id):
		last_transfer_error = "Own this stash before hiring a Runner."
		return false
	if has_runner(property_id):
		last_transfer_error = "This stash already has a Runner."
		return false
	if not wallet.spend_clean(
		PropertyCatalog.RUNNER_UPGRADE_COST, true, "Property Upgrade", "Stash runner"
	):
		last_transfer_error = "Not enough Clean Cash."
		return false
	var stash := _ensure_stash(property_id)
	stash["runner_installed"] = true
	runner_changed.emit(property_id)
	stash_changed.emit(property_id)
	return true


func get_runner_stash_definitions() -> Array[PropertyDefinition]:
	var result: Array[PropertyDefinition] = []
	for definition in get_owned_stash_definitions():
		if has_runner(definition.property_id):
			result.append(definition)
	return result


func get_runner_delivery_error(
	property_id: StringName,
	product: ProductDefinition,
	amount: int
) -> String:
	if not owns(property_id) or not _is_stash_house(property_id):
		return "Choose an owned stash for delivery."
	if not has_runner(property_id):
		return "Install the $5,000 Clean Runner upgrade at this stash."
	if product == null or not product.is_brick() or amount <= 0:
		return "Runners only accept valid brick orders."
	var available := get_stash_remaining_capacity(property_id)
	if available < amount:
		return "Destination needs %d free stash slots; %d available." % [
			amount,
			available,
		]
	return ""


func deliver_wholesale_product(
	property_id: StringName,
	product: ProductDefinition,
	amount: int
) -> bool:
	last_transfer_error = get_runner_delivery_error(
		property_id,
		product,
		amount
	)
	if not last_transfer_error.is_empty():
		return false
	var stash := _ensure_stash(property_id)
	var products := stash.get("products", {}) as Dictionary
	var key := String(product.product_id)
	products[key] = int(products.get(key, 0)) + amount
	stash["products"] = products
	stash_changed.emit(property_id)
	return true


func owns(property_id: StringName) -> bool:
	return bool(_owned.get(property_id, false))


func purchase(property_id: StringName, current_absolute_minute := -1) -> bool:
	var definition := PropertyCatalog.get_by_id(property_id)
	if definition == null or owns(property_id):
		return false
	if not wallet.spend_clean(
		definition.purchase_price, true, "Property Purchase", definition.display_name
	):
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
	if not wallet.spend_dirty(
		total_cost, true, "Business Restock",
		"%d units for %s" % [requested_units, definition.display_name]
	):
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


func process_properties_to(target_absolute_minute: int) -> void:
	process_businesses_to(target_absolute_minute)
	process_brick_stations_to(target_absolute_minute)


func process_brick_stations_to(target_absolute_minute: int) -> void:
	if target_absolute_minute < 0:
		return
	for definition in get_owned_definitions():
		if not definition.is_stash_house():
			continue
		var property_id := definition.property_id
		var stash := _ensure_stash(property_id)
		var station := stash.get("brick_station", {}) as Dictionary
		if not bool(station.get("installed", false)):
			continue
		var selected_id := StringName(
			station.get("selected_product_id", "")
		)
		if selected_id.is_empty():
			continue
		var interval := definition.brick_station_interval_minutes
		if interval <= 0:
			continue
		var next_minute := int(station.get("next_process_minute", -1))
		if next_minute < 0:
			station["next_process_minute"] = target_absolute_minute + interval
			stash["brick_station"] = station
			brick_station_changed.emit(property_id)
			continue
		var changed := false
		var stash_changed_during_processing := false
		while next_minute <= target_absolute_minute:
			var result := _try_process_stashed_brick(
				property_id,
				selected_id
			)
			station["last_block_reason"] = String(
				result.get("block_reason", "")
			)
			stash_changed_during_processing = (
				bool(result.get("processed", false))
				or stash_changed_during_processing
			)
			next_minute += interval
			changed = true
		station["next_process_minute"] = next_minute
		stash["brick_station"] = station
		if stash_changed_during_processing:
			stash_changed.emit(property_id)
		if changed:
			brick_station_changed.emit(property_id)


func purchase_brick_station(
	property_id: StringName,
	current_absolute_minute: int
) -> bool:
	var definition := PropertyCatalog.get_by_id(property_id)
	if (
		definition == null
		or not definition.is_stash_house()
		or not owns(property_id)
		or definition.brick_station_cost <= 0
	):
		return false
	var stash := _ensure_stash(property_id)
	var station := stash.get("brick_station", {}) as Dictionary
	if bool(station.get("installed", false)):
		return false
	if not wallet.spend_clean(
		definition.brick_station_cost, true, "Property Upgrade",
		"Brick station at %s" % definition.display_name
	):
		return false
	station["installed"] = true
	station["selected_product_id"] = ""
	station["next_process_minute"] = -1
	station["last_block_reason"] = ""
	stash["brick_station"] = station
	brick_station_changed.emit(property_id)
	return true


func set_brick_station_product(
	property_id: StringName,
	product_id: StringName,
	current_absolute_minute: int
) -> bool:
	if not owns(property_id) or not _is_stash_house(property_id):
		return false
	var stash := _ensure_stash(property_id)
	var station := stash.get("brick_station", {}) as Dictionary
	if not bool(station.get("installed", false)):
		return false
	var selected_id := product_id
	if not selected_id.is_empty():
		var product := EconomyCatalog.get_product(selected_id)
		if product == null or not product.can_break_down():
			return false
	var previous_id := StringName(station.get("selected_product_id", ""))
	if previous_id == selected_id:
		return true
	station["selected_product_id"] = String(selected_id)
	station["last_block_reason"] = ""
	if selected_id.is_empty():
		station["next_process_minute"] = -1
	elif previous_id.is_empty() or int(
		station.get("next_process_minute", -1)
	) < 0:
		var definition := PropertyCatalog.get_by_id(property_id)
		station["next_process_minute"] = (
			maxi(current_absolute_minute, 0)
			+ definition.brick_station_interval_minutes
		)
	stash["brick_station"] = station
	brick_station_changed.emit(property_id)
	return true


func get_brick_station_state(property_id: StringName) -> Dictionary:
	if not _is_stash_house(property_id):
		return {}
	var station := (
		_ensure_stash(property_id).get("brick_station", {}) as Dictionary
	)
	return station.duplicate(true)


func get_owned_stash_definitions(
	territory_id: StringName = &""
) -> Array[PropertyDefinition]:
	var result: Array[PropertyDefinition] = []
	for definition in PropertyCatalog.get_all():
		if (
			definition.is_stash_house()
			and owns(definition.property_id)
			and (
				territory_id.is_empty()
				or definition.territory_id == territory_id
			)
		):
			result.append(definition)
	return result


func settle_business_earnings() -> int:
	var deposited := 0
	for property_id in PropertyCatalog.BUSINESS_IDS:
		if not owns(property_id):
			continue
		var state := _ensure_business(property_id)
		var amount := int(state.get("accumulated_earnings", 0))
		if amount <= 0:
			continue
		var definition := PropertyCatalog.get_by_id(property_id)
		var business_name := definition.display_name if definition != null else String(property_id)
		if wallet.add_clean(amount, true, "Business Revenue", business_name):
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


func get_property_supply_summary(
	property_id: StringName,
	products: Array[ProductDefinition]
) -> Dictionary:
	var definition := PropertyCatalog.get_by_id(property_id)
	if (
		definition == null
		or not definition.is_stash_house()
		or not owns(property_id)
	):
		return {
			"property_id": property_id,
			"display_name": (
				definition.display_name if definition != null else ""
			),
			"dirty_cash": 0,
			"product_units": 0,
			"products": {},
		}
	var result := {
		"property_id": property_id,
		"display_name": definition.display_name,
		"dirty_cash": get_stashed_dirty_cash(property_id),
		"product_units": 0,
		"products": {},
	}
	var totals := result.products as Dictionary
	for product in products:
		if product == null:
			continue
		var quantity := get_stashed_product_quantity(property_id, product)
		totals[String(product.product_id)] = quantity
		result.product_units += quantity
	return result


func process_property_dealer_sale(
	property_id: StringName,
	product: ProductDefinition,
	amount: int,
	net_dirty_cash: int
) -> bool:
	if (
		product == null
		or amount <= 0
		or net_dirty_cash < 0
		or not owns(property_id)
		or not _is_stash_house(property_id)
	):
		return false
	var stash := _ensure_stash(property_id)
	var products := stash.get("products", {}) as Dictionary
	var key := String(product.product_id)
	var stored := int(products.get(key, 0))
	if stored < amount:
		return false
	products[key] = stored - amount
	if int(products[key]) <= 0:
		products.erase(key)
	stash["products"] = products
	stash["dirty_cash"] = (
		int(stash.get("dirty_cash", 0)) + net_dirty_cash
	)
	stash_changed.emit(property_id)
	return true


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
	last_transfer_error = ""
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
		if not inventory.can_add_product(product, amount):
			last_transfer_error = carry_weight.get_capacity_failure_message(
				product.package_size_grams * amount
			)
			return 0
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
	last_transfer_error = ""
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
	last_transfer_error = ""
	if not owns(property_id) or not _is_stash_house(property_id) or weapon.owns_weapon(weapon_id):
		return false
	var stash := _ensure_stash(property_id)
	var weapons := stash.get("weapons", {}) as Dictionary
	var state := weapons.get(String(weapon_id), {}) as Dictionary
	var definition := weapon.get_weapon_definition(weapon_id)
	var attachment_state := state.get("attachment_state", {}) as Dictionary
	if (
		definition != null
		and not carry_weight.can_add_weapon(definition, attachment_state)
	):
		last_transfer_error = carry_weight.get_capacity_failure_message(
			definition.get_carry_weight_grams(attachment_state)
		)
		return false
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
				runner_changed.emit(property_id)
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


func forfeit_front_businesses() -> void:
	for property_id in PropertyCatalog.BUSINESS_IDS:
		if not owns(property_id):
			continue
		_owned.erase(property_id)
		_businesses.erase(property_id)
		ownership_changed.emit(property_id, false)
		business_state_changed.emit(property_id)


func forfeit_stash_houses() -> void:
	for property_id in PropertyCatalog.PROPERTY_IDS:
		var definition := PropertyCatalog.get_by_id(property_id)
		if definition == null or not definition.is_stash_house() or not owns(property_id):
			continue
		_owned.erase(property_id)
		_stashes.erase(property_id)
		ownership_changed.emit(property_id, false)
		stash_changed.emit(property_id)


func reset_to_new_game() -> void:
	import_save_data({})


func _ensure_stash(property_id: StringName) -> Dictionary:
	if not _stashes.has(property_id):
		_stashes[property_id] = {
			"dirty_cash": 0,
			"products": {},
			"weapons": {},
			"brick_station": _default_brick_station(),
			"runner_installed": false,
		}
	elif not (_stashes[property_id] as Dictionary).has("brick_station"):
		(_stashes[property_id] as Dictionary)["brick_station"] = (
			_default_brick_station()
		)
	if not (_stashes[property_id] as Dictionary).has("runner_installed"):
		(_stashes[property_id] as Dictionary)["runner_installed"] = false
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
	var result := {
		"dirty_cash": maxi(int(source.get("dirty_cash", 0)), 0),
		"products": {},
		"weapons": {},
		"brick_station": _sanitize_brick_station(
			source.get("brick_station", {}) as Dictionary
		),
		"runner_installed": bool(source.get("runner_installed", false)),
	}
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


func _default_brick_station() -> Dictionary:
	return {
		"installed": false,
		"selected_product_id": "",
		"next_process_minute": -1,
		"last_block_reason": "",
	}


func _sanitize_brick_station(source: Dictionary) -> Dictionary:
	var result := _default_brick_station()
	result["installed"] = bool(source.get("installed", false))
	if not bool(result.installed):
		return result
	var selected_id := StringName(source.get("selected_product_id", ""))
	var product := EconomyCatalog.get_product(selected_id)
	if (
		not selected_id.is_empty()
		and product != null
		and product.can_break_down()
	):
		result["selected_product_id"] = String(selected_id)
		result["next_process_minute"] = maxi(
			int(source.get("next_process_minute", -1)),
			-1
		)
	result["last_block_reason"] = String(
		source.get("last_block_reason", "")
	)
	return result


func _try_process_stashed_brick(
	property_id: StringName,
	product_id: StringName
) -> Dictionary:
	var product := EconomyCatalog.get_product(product_id)
	if product == null or not product.can_break_down():
		return {"processed": false, "block_reason": "INVALID PRODUCT"}
	var stash := _ensure_stash(property_id)
	var products := stash.get("products", {}) as Dictionary
	var brick_key := String(product.product_id)
	if int(products.get(brick_key, 0)) <= 0:
		return {"processed": false, "block_reason": "NO BRICKS"}
	var extra_capacity := maxi(product.breakdown_amount - 1, 0)
	if get_stash_remaining_capacity(property_id) < extra_capacity:
		return {
			"processed": false,
			"block_reason": "NEED %d FREE CAPACITY" % extra_capacity,
		}
	products[brick_key] = int(products.get(brick_key, 0)) - 1
	if int(products[brick_key]) <= 0:
		products.erase(brick_key)
	var output_key := String(product.breakdown_product.product_id)
	products[output_key] = (
		int(products.get(output_key, 0)) + product.breakdown_amount
	)
	stash["products"] = products
	return {"processed": true, "block_reason": ""}


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
