class_name TerritoryMarketService
extends Node

signal market_changed(date_key: String)

var generated_date := ""
var _quotes: Dictionary = {}
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"territory_market_service")
	_random.randomize()


func ensure_quotes(date_key: String) -> bool:
	if date_key.is_empty():
		return false
	var territory_ids := _get_territory_ids()
	if generated_date == date_key and _has_complete_quotes(territory_ids):
		return false

	generated_date = date_key
	_quotes.clear()
	for territory_id in territory_ids:
		var territory_quotes := {}
		for product in EconomyCatalog.get_all_products():
			var dealer_quote := _roll_price(product.dealer_price)
			territory_quotes[String(product.product_id)] = {
				"buy": dealer_quote,
				"sell": dealer_quote,
			}
		_quotes[territory_id] = territory_quotes
	market_changed.emit(generated_date)
	return true


func get_buy_quote(
	territory_id: StringName,
	product: ProductDefinition
) -> int:
	return _get_quote(territory_id, product, "buy")


func get_sell_quote(
	territory_id: StringName,
	product: ProductDefinition
) -> int:
	return get_buy_quote(territory_id, product)


func export_save_data() -> Dictionary:
	return {
		"generated_date": generated_date,
		"quotes": _quotes.duplicate(true),
	}


func import_save_data(data: Dictionary, current_date_key: String) -> void:
	generated_date = String(data.get("generated_date", ""))
	var imported_quotes: Variant = data.get("quotes", {})
	_quotes = (
		(imported_quotes as Dictionary).duplicate(true)
		if imported_quotes is Dictionary
		else {}
	)
	if generated_date != current_date_key or not _has_complete_quotes(
		_get_territory_ids()
	):
		generated_date = ""
		_quotes.clear()
		ensure_quotes(current_date_key)
	else:
		_mirror_sell_quotes_to_buy()
		market_changed.emit(generated_date)


static func find(tree: SceneTree) -> TerritoryMarketService:
	return tree.get_first_node_in_group(
		&"territory_market_service"
	) as TerritoryMarketService


func _roll_price(base_price: int) -> int:
	var band_roll := _random.randi_range(1, 100)
	var multiplier := 1.0
	if band_roll <= 80:
		multiplier = _random.randf_range(0.85, 1.15)
	elif band_roll <= 90:
		multiplier = _random.randf_range(0.70, 0.84)
	else:
		multiplier = _random.randf_range(1.16, 1.30)
	return maxi(roundi(float(base_price) * multiplier), 1)


func _get_quote(
	territory_id: StringName,
	product: ProductDefinition,
	quote_type: String
) -> int:
	if product == null:
		return 0
	var territory_quotes := _quotes.get(String(territory_id), {}) as Dictionary
	var product_quotes := territory_quotes.get(
		String(product.product_id), {}
	) as Dictionary
	var fallback := (
		product.dealer_price if quote_type == "buy" else product.sale_price
	)
	return maxi(int(product_quotes.get(quote_type, fallback)), 1)


func _get_territory_ids() -> Array[String]:
	var ids: Array[String] = []
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and not String(boundary.territory_id).is_empty():
			ids.append(String(boundary.territory_id))
	ids.sort()
	return ids


func _has_complete_quotes(territory_ids: Array[String]) -> bool:
	if territory_ids.is_empty():
		return false
	for territory_id in territory_ids:
		var territory_quotes: Variant = _quotes.get(territory_id)
		if territory_quotes is not Dictionary:
			return false
		for product in EconomyCatalog.get_all_products():
			var product_quotes: Variant = territory_quotes.get(
				String(product.product_id)
			)
			if product_quotes is not Dictionary:
				return false
			if (
				int(product_quotes.get("buy", 0)) < 1
				or int(product_quotes.get("sell", 0)) < 1
			):
				return false
	return true


func _mirror_sell_quotes_to_buy() -> void:
	for territory_id in _quotes.keys():
		var territory_quotes := _quotes[territory_id] as Dictionary
		for product_id in territory_quotes.keys():
			var product_quotes := territory_quotes[product_id] as Dictionary
			product_quotes["sell"] = maxi(
				int(product_quotes.get("buy", 1)),
				1
			)
