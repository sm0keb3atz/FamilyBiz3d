class_name EconomyCatalog
extends RefCounted

const WEED_1G := preload("res://Scripts/Gameplay/Resources/weed_1g.tres")
const WEED_BRICK := preload("res://Scripts/Gameplay/Resources/weed_brick.tres")
const COKE_1G := preload("res://Scripts/Gameplay/Resources/coke_1g.tres")
const COKE_BRICK := preload("res://Scripts/Gameplay/Resources/coke_brick.tres")
const FENT_1G := preload("res://Scripts/Gameplay/Resources/fent_1g.tres")
const FENT_BRICK := preload("res://Scripts/Gameplay/Resources/fent_brick.tres")


static func get_all_products() -> Array[ProductDefinition]:
	return [
		WEED_1G,
		WEED_BRICK,
		COKE_1G,
		COKE_BRICK,
		FENT_1G,
		FENT_BRICK,
	]


static func get_gram_products() -> Array[ProductDefinition]:
	return [WEED_1G, COKE_1G, FENT_1G]


static func get_brick_products() -> Array[ProductDefinition]:
	return [WEED_BRICK, COKE_BRICK, FENT_BRICK]


static func get_product(product_id: StringName) -> ProductDefinition:
	for product in get_all_products():
		if product.product_id == product_id:
			return product
	return null


static func get_gram_for_drug(drug_type: int) -> ProductDefinition:
	for product in get_gram_products():
		if product.drug_type == drug_type:
			return product
	return null


static func get_brick_for_drug(drug_type: int) -> ProductDefinition:
	for product in get_brick_products():
		if product.drug_type == drug_type:
			return product
	return null
