class_name PlayerInventoryComponent
extends Node

signal quantity_changed(product: ProductDefinition, quantity: int)
signal consumable_quantity_changed(item: ConsumableDefinition, quantity: int)

@export var known_products: Array[ProductDefinition] = []
@export var carry_weight_component_path := NodePath("../CarryWeightComponent")

var _quantities: Dictionary[StringName, int] = {}
var _consumable_quantities: Dictionary[StringName, int] = {}


func _ready() -> void:
	for product in EconomyCatalog.get_all_products():
		_ensure_known_product(product)
	for product in known_products:
		if product != null:
			_quantities[product.product_id] = get_quantity(product)
			quantity_changed.emit(product, _quantities[product.product_id])


func get_quantity(product: ProductDefinition) -> int:
	if product == null:
		return 0
	return _quantities.get(product.product_id, 0)


func has_product(product: ProductDefinition, amount := 1) -> bool:
	return amount > 0 and get_quantity(product) >= amount


func add_product(product: ProductDefinition, amount := 1) -> bool:
	if product == null or amount <= 0:
		return false
	var carry_weight := _get_carry_weight()
	if carry_weight != null and not carry_weight.can_add_product(product, amount):
		return false

	var next_quantity := get_quantity(product) + amount
	_quantities[product.product_id] = next_quantity
	_ensure_known_product(product)
	quantity_changed.emit(product, next_quantity)
	return true


func remove_product(product: ProductDefinition, amount := 1) -> bool:
	if product == null or amount <= 0 or not has_product(product, amount):
		return false

	var next_quantity := get_quantity(product) - amount
	_quantities[product.product_id] = next_quantity
	quantity_changed.emit(product, next_quantity)
	return true


func get_known_products() -> Array[ProductDefinition]:
	return known_products.duplicate()


func get_fractional_product_transfer(percent: float) -> Dictionary:
	var result := {}
	var safe_percent := clampf(percent, 0.0, 1.0)
	if is_zero_approx(safe_percent):
		return result
	for product in known_products:
		if product == null:
			continue
		var amount := floori(float(get_quantity(product)) * safe_percent)
		if amount > 0:
			result[String(product.product_id)] = amount
	return result


func remove_product_transfer(transfer: Dictionary) -> bool:
	for product_id in transfer.keys():
		var product := EconomyCatalog.get_product(StringName(String(product_id)))
		var amount := int(transfer[product_id])
		if product == null or amount < 0 or get_quantity(product) < amount:
			return false
	for product_id in transfer.keys():
		var amount := int(transfer[product_id])
		if amount <= 0:
			continue
		var product := EconomyCatalog.get_product(StringName(String(product_id)))
		var next_quantity := get_quantity(product) - amount
		_quantities[product.product_id] = next_quantity
		quantity_changed.emit(product, next_quantity)
	return true


func restore_product_transfer(transfer: Dictionary) -> void:
	# Recovery intentionally bypasses capacity checks. The items already belonged
	# to the player, so an encounter can never make them disappear permanently.
	for product_id in transfer.keys():
		var product := EconomyCatalog.get_product(StringName(String(product_id)))
		var amount := maxi(int(transfer[product_id]), 0)
		if product == null or amount <= 0:
			continue
		var next_quantity := get_quantity(product) + amount
		_quantities[product.product_id] = next_quantity
		_ensure_known_product(product)
		quantity_changed.emit(product, next_quantity)


func get_consumable_quantity(item: ConsumableDefinition) -> int:
	return int(_consumable_quantities.get(item.item_id, 0)) if item != null else 0


func has_consumable(item: ConsumableDefinition, amount := 1) -> bool:
	return item != null and amount > 0 and get_consumable_quantity(item) >= amount


func add_consumable(item: ConsumableDefinition, amount := 1) -> bool:
	if item == null or amount <= 0:
		return false
	var carry_weight := _get_carry_weight()
	if carry_weight != null and not carry_weight.can_add_weight(item.weight_grams * amount):
		return false
	var quantity := get_consumable_quantity(item) + amount
	_consumable_quantities[item.item_id] = quantity
	consumable_quantity_changed.emit(item, quantity)
	return true


func remove_consumable(item: ConsumableDefinition, amount := 1) -> bool:
	if not has_consumable(item, amount):
		return false
	var quantity := get_consumable_quantity(item) - amount
	_consumable_quantities[item.item_id] = quantity
	consumable_quantity_changed.emit(item, quantity)
	return true


func break_down_product(product: ProductDefinition) -> bool:
	if product == null or not product.can_break_down():
		return false
	if not has_product(product, 1):
		return false
	var output := product.breakdown_product
	var output_amount := product.breakdown_amount
	if output == null or output_amount <= 0:
		return false
	var weight_delta := (
		output.package_size_grams * output_amount
		- product.package_size_grams
	)
	var carry_weight := _get_carry_weight()
	if (
		carry_weight != null
		and not carry_weight.can_add_weight(weight_delta)
	):
		return false
	var input_quantity := get_quantity(product) - 1
	var output_quantity := get_quantity(output) + output_amount
	_quantities[product.product_id] = input_quantity
	_quantities[output.product_id] = output_quantity
	_ensure_known_product(output)
	quantity_changed.emit(product, input_quantity)
	quantity_changed.emit(output, output_quantity)
	return true


func export_save_data() -> Dictionary:
	var data := {}
	for product in known_products:
		if product != null:
			data[String(product.product_id)] = get_quantity(product)
	var consumables := {}
	for item in ConsumableCatalog.get_all():
		consumables[String(item.item_id)] = get_consumable_quantity(item)
	data["consumables"] = consumables
	return data


func import_save_data(data: Dictionary) -> void:
	for product in EconomyCatalog.get_all_products():
		_ensure_known_product(product)
	for product in known_products:
		if product == null:
			continue
		var quantity := maxi(int(data.get(String(product.product_id), 0)), 0)
		_quantities[product.product_id] = quantity
		quantity_changed.emit(product, quantity)
	var consumables := data.get("consumables", {}) as Dictionary
	for item in ConsumableCatalog.get_all():
		var quantity := maxi(int(consumables.get(String(item.item_id), 0)), 0)
		_consumable_quantities[item.item_id] = quantity
		consumable_quantity_changed.emit(item, quantity)


func confiscate_all() -> Dictionary:
	var confiscated := {}
	for product in known_products:
		if product == null:
			continue
		confiscated[String(product.product_id)] = get_quantity(product)
		_quantities[product.product_id] = 0
		quantity_changed.emit(product, 0)
	return confiscated


func reset_to_new_game() -> void:
	import_save_data({})


func _ensure_known_product(product: ProductDefinition) -> void:
	if product != null and product not in known_products:
		known_products.append(product)


func get_product_weight_grams(product: ProductDefinition, amount := -1) -> int:
	if product == null:
		return 0
	var quantity := get_quantity(product) if amount < 0 else maxi(amount, 0)
	return quantity * product.package_size_grams


func can_add_product(product: ProductDefinition, amount := 1) -> bool:
	if product == null or amount <= 0:
		return false
	var carry_weight := _get_carry_weight()
	return carry_weight == null or carry_weight.can_add_product(product, amount)


func _get_carry_weight() -> PlayerCarryWeightComponent:
	return get_node_or_null(
		carry_weight_component_path
	) as PlayerCarryWeightComponent
