class_name PropertyDefinition
extends RefCounted

enum PropertyRole {
	STASH_HOUSE,
	FRONT_BUSINESS,
}

var property_id: StringName
var display_name := ""
var neighborhood := ""
var territory_id: StringName
var purchase_price := 0
var stash_capacity := 1000
var role := PropertyRole.STASH_HOUSE
var business_stock_capacity := 0
var business_restock_unit_cost := 0
var business_revenue_per_sale := 0
var business_sales_interval_minutes := 0
var business_open_minute := 0
var business_close_minute := 0


func _init(
	value_id: StringName = &"",
	value_name := "",
	value_neighborhood := "",
	value_price := 0,
	value_stash_capacity := 1000,
	value_territory_id: StringName = &"",
	value_role := PropertyRole.STASH_HOUSE,
	value_business_stock_capacity := 0,
	value_business_restock_unit_cost := 0,
	value_business_revenue_per_sale := 0,
	value_business_sales_interval_minutes := 0,
	value_business_open_minute := 0,
	value_business_close_minute := 0
) -> void:
	property_id = value_id
	display_name = value_name
	neighborhood = value_neighborhood
	territory_id = value_territory_id
	purchase_price = maxi(value_price, 0)
	stash_capacity = maxi(value_stash_capacity, 0)
	role = value_role
	business_stock_capacity = maxi(value_business_stock_capacity, 0)
	business_restock_unit_cost = maxi(value_business_restock_unit_cost, 0)
	business_revenue_per_sale = maxi(value_business_revenue_per_sale, 0)
	business_sales_interval_minutes = maxi(value_business_sales_interval_minutes, 0)
	business_open_minute = clampi(value_business_open_minute, 0, 1439)
	business_close_minute = clampi(value_business_close_minute, 0, 1440)


func is_valid() -> bool:
	if property_id.is_empty() or display_name.is_empty():
		return false
	if is_front_business():
		return (
			business_stock_capacity > 0
			and business_restock_unit_cost > 0
			and business_revenue_per_sale > 0
			and business_sales_interval_minutes > 0
			and business_open_minute < business_close_minute
		)
	return role == PropertyRole.STASH_HOUSE


func is_stash_house() -> bool:
	return role == PropertyRole.STASH_HOUSE


func is_front_business() -> bool:
	return role == PropertyRole.FRONT_BUSINESS
