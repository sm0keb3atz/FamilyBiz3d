class_name ClothingDefinition
extends Resource

@export var clothing_id: StringName
@export var display_name := ""
@export var category: StringName
@export var clothing_type: StringName
@export var brand := ""
@export var variant_name := ""
@export var mesh_name: StringName
@export var material: Material
@export var price := 0
@export var aura := 0
@export var tintable := false
@export var starting_owned := false


func is_valid() -> bool:
	return (
		not clothing_id.is_empty()
		and not category.is_empty()
		and not clothing_type.is_empty()
		and not brand.is_empty()
		and not variant_name.is_empty()
		and not mesh_name.is_empty()
		and price >= 0
	)
