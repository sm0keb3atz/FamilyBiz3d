class_name TradeResult
extends RefCounted

var success := false
var message := ""
var dirty_cash_delta := 0
var product_quantity_delta := 0
var experience_delta := 0.0
var reputation_delta := 0.0
var heat_delta := 0.0


static func failed(reason: String) -> TradeResult:
	var result := TradeResult.new()
	result.message = reason
	return result

