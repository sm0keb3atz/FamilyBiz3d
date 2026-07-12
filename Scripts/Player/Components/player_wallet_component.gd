class_name PlayerWalletComponent
extends Node

signal money_changed(dirty_cash: int, clean_cash: int)
signal transaction_completed(dirty_cash_delta: int, clean_cash_delta: int)

@export_range(0, 100000000, 1) var starting_dirty_cash := 100
@export_range(0, 100000000, 1) var starting_clean_cash := 0

var dirty_cash: int:
	get:
		return _dirty_cash
var clean_cash: int:
	get:
		return _clean_cash

var _dirty_cash := 0
var _clean_cash := 0


func _ready() -> void:
	_dirty_cash = maxi(starting_dirty_cash, 0)
	_clean_cash = maxi(starting_clean_cash, 0)
	money_changed.emit(_dirty_cash, _clean_cash)


func can_spend_dirty(amount: int) -> bool:
	return amount >= 0 and _dirty_cash >= amount


func spend_dirty(amount: int, record_transaction := true) -> bool:
	if amount < 0 or not can_spend_dirty(amount):
		return false
	if amount == 0:
		return true

	_dirty_cash -= amount
	money_changed.emit(_dirty_cash, _clean_cash)
	if record_transaction:
		transaction_completed.emit(-amount, 0)
	return true


func add_dirty(amount: int, record_transaction := true) -> bool:
	if amount <= 0:
		return false

	_dirty_cash += amount
	money_changed.emit(_dirty_cash, _clean_cash)
	if record_transaction:
		transaction_completed.emit(amount, 0)
	return true


func add_clean(amount: int, record_transaction := true) -> bool:
	if amount <= 0:
		return false

	_clean_cash += amount
	money_changed.emit(_dirty_cash, _clean_cash)
	if record_transaction:
		transaction_completed.emit(0, amount)
	return true


func record_transaction(dirty_cash_delta: int, clean_cash_delta: int) -> void:
	if dirty_cash_delta == 0 and clean_cash_delta == 0:
		return
	transaction_completed.emit(dirty_cash_delta, clean_cash_delta)


func export_save_data() -> Dictionary:
	return {"dirty_cash": _dirty_cash, "clean_cash": _clean_cash}


func import_save_data(data: Dictionary) -> void:
	_dirty_cash = maxi(int(data.get("dirty_cash", starting_dirty_cash)), 0)
	_clean_cash = maxi(int(data.get("clean_cash", starting_clean_cash)), 0)
	money_changed.emit(_dirty_cash, _clean_cash)
