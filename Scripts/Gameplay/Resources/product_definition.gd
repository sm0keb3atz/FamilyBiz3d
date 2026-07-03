class_name ProductDefinition
extends Resource

@export var product_id: StringName = &"test_product"
@export var display_name := "Test Product"
@export_range(0, 1000000, 1) var dealer_price := 10
@export_range(0, 1000000, 1) var sale_price := 20
@export_range(0.0, 100000.0, 1.0) var experience_reward := 10.0
@export_range(0.0, 100.0, 0.1) var reputation_reward := 1.0
@export_range(0.0, 100.0, 0.1) var heat_reward := 5.0
