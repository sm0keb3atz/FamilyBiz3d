class_name PlayerPropertyComponent
extends Node

signal ownership_changed(property_id: StringName, owned: bool)
signal stash_changed(property_id: StringName)

@export var wallet_component_path := NodePath("../WalletComponent")
@export var inventory_component_path := NodePath("../InventoryComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var inventory := get_node(inventory_component_path) as PlayerInventoryComponent
@onready var weapon := get_node(weapon_component_path) as PlayerWeaponComponent

var _owned: Dictionary[StringName, bool] = {}
var _stashes: Dictionary[StringName, Dictionary] = {}


func owns(property_id: StringName) -> bool:
	return bool(_owned.get(property_id, false))


func purchase(property_id: StringName) -> bool:
	var definition := PropertyCatalog.get_by_id(property_id)
	if definition == null or owns(property_id):
		return false
	if not wallet.spend_clean(definition.purchase_price):
		return false
	_owned[property_id] = true
	_ensure_stash(property_id)
	ownership_changed.emit(property_id, true)
	return true


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
	return definition.stash_capacity if definition != null else 0


func get_stash_used_capacity(property_id: StringName) -> int:
	var stash := _ensure_stash(property_id)
	var used := (stash.get("weapons", {}) as Dictionary).size()
	for value in (stash.get("products", {}) as Dictionary).values():
		used += maxi(int(value), 0)
	return used


func get_stash_remaining_capacity(property_id: StringName) -> int:
	return maxi(get_stash_capacity(property_id) - get_stash_used_capacity(property_id), 0)


func transfer_dirty_cash(property_id: StringName, requested_amount: int, to_stash: bool) -> int:
	if not owns(property_id) or requested_amount <= 0:
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


func transfer_product(property_id: StringName, product: ProductDefinition, requested_amount: int, to_stash: bool) -> int:
	if not owns(property_id) or product == null or requested_amount <= 0:
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
	if not owns(property_id) or get_stash_remaining_capacity(property_id) <= 0:
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
	if not owns(property_id) or weapon.owns_weapon(weapon_id):
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
	for definition in PropertyCatalog.get_all():
		if owns(definition.property_id):
			owned_ids.append(String(definition.property_id))
			stash_data[String(definition.property_id)] = _sanitize_stash(_ensure_stash(definition.property_id))
	return {"owned_ids": owned_ids, "stashes": stash_data}


func import_save_data(data: Dictionary) -> void:
	_owned.clear()
	_stashes.clear()
	for value in data.get("owned_ids", []) as Array:
		var property_id := StringName(str(value))
		if PropertyCatalog.get_by_id(property_id) != null:
			_owned[property_id] = true
	var saved_stashes := data.get("stashes", {}) as Dictionary
	for definition in PropertyCatalog.get_all():
		var property_id := definition.property_id
		if owns(property_id):
			var saved := saved_stashes.get(String(property_id), {}) as Dictionary
			_stashes[property_id] = _sanitize_stash(saved)
			stash_changed.emit(property_id)
		ownership_changed.emit(property_id, owns(property_id))


func _ensure_stash(property_id: StringName) -> Dictionary:
	if not _stashes.has(property_id):
		_stashes[property_id] = {"dirty_cash": 0, "products": {}, "weapons": {}}
	return _stashes[property_id]


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
