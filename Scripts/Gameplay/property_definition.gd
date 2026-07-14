class_name PropertyDefinition
extends RefCounted

var property_id: StringName
var display_name := ""
var neighborhood := ""
var purchase_price := 0
var stash_capacity := 1000


func _init(
	value_id: StringName = &"",
	value_name := "",
	value_neighborhood := "",
	value_price := 0,
	value_stash_capacity := 1000
) -> void:
	property_id = value_id
	display_name = value_name
	neighborhood = value_neighborhood
	purchase_price = maxi(value_price, 0)
	stash_capacity = maxi(value_stash_capacity, 0)


func is_valid() -> bool:
	return not property_id.is_empty() and not display_name.is_empty()
