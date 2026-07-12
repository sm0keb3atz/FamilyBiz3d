class_name PlayerInventoryComponent
extends Node

signal quantity_changed(product: ProductDefinition, quantity: int)

@export var known_products: Array[ProductDefinition] = []

var _quantities: Dictionary[StringName, int] = {}


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


func break_down_product(product: ProductDefinition) -> bool:
	if product == null or not product.can_break_down():
		return false
	if not has_product(product, 1):
		return false
	if not remove_product(product, 1):
		return false
	if add_product(product.breakdown_product, product.breakdown_amount):
		return true

	add_product(product, 1)
	return false


func export_save_data() -> Dictionary:
	var data := {}
	for product in known_products:
		if product != null:
			data[String(product.product_id)] = get_quantity(product)
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


func _ensure_known_product(product: ProductDefinition) -> void:
	if product != null and product not in known_products:
		known_products.append(product)
