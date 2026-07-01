class_name PlayerInventoryComponent
extends Node

signal quantity_changed(product: ProductDefinition, quantity: int)

@export var known_products: Array[ProductDefinition] = []

var _quantities: Dictionary[StringName, int] = {}


func _ready() -> void:
	for product in known_products:
		if product != null:
			_quantities[product.product_id] = 0
			quantity_changed.emit(product, 0)


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
	if product not in known_products:
		known_products.append(product)
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
