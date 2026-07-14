class_name ProductDefinition
extends Resource

enum DrugType {
	WEED,
	COKE,
	FENT,
}

enum PackageKind {
	GRAM,
	BRICK,
}

@export var product_id: StringName = &"test_product"
@export var display_name := "Test Product"
@export var drug_type := DrugType.WEED
@export var package_kind := PackageKind.GRAM
@export_range(1, 1000, 1) var package_size_grams := 1
@export var icon: Texture2D
@export var breakdown_product: ProductDefinition
@export_range(1, 1000, 1) var breakdown_amount := 100
@export_range(0, 1000000, 1) var dealer_price := 10
@export_range(0, 1000000, 1) var sale_price := 20
@export_range(0.0, 100000.0, 1.0) var experience_reward := 10.0
@export_range(0.0, 100.0, 0.01) var reputation_reward := 1.0
@export_range(0.0, 100.0, 0.1) var heat_reward := 5.0


func is_brick() -> bool:
	return package_kind == PackageKind.BRICK


func can_break_down() -> bool:
	return is_brick() and breakdown_product != null and breakdown_amount > 0
