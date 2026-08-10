class_name PlayerWalletComponent
extends Node

signal money_changed(dirty_cash: int, clean_cash: int)
signal transaction_completed(dirty_cash_delta: int, clean_cash_delta: int)
signal transaction_recorded(
	dirty_cash_delta: int,
	clean_cash_delta: int,
	category: String,
	detail: String
)

const ATM_DAILY_DEPOSIT_LIMIT := 2500

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
var _atm_deposit_date := ""
var _atm_deposited_today := 0


func _ready() -> void:
	_dirty_cash = maxi(starting_dirty_cash, 0)
	_clean_cash = maxi(starting_clean_cash, 0)
	money_changed.emit(_dirty_cash, _clean_cash)


func can_spend_dirty(amount: int) -> bool:
	return amount >= 0 and _dirty_cash >= amount


func can_spend_clean(amount: int) -> bool:
	return amount >= 0 and _clean_cash >= amount


func spend_dirty(
	amount: int,
	record_transaction := true,
	category := "Dirty Cash Expense",
	detail := "Wallet purchase"
) -> bool:
	if amount < 0 or not can_spend_dirty(amount):
		return false
	if amount == 0:
		return true

	_dirty_cash -= amount
	money_changed.emit(_dirty_cash, _clean_cash)
	if record_transaction:
		transaction_completed.emit(-amount, 0)
		transaction_recorded.emit(-amount, 0, category, detail)
	return true


func add_dirty(
	amount: int,
	record_transaction := true,
	category := "Dirty Cash Income",
	detail := "Wallet income"
) -> bool:
	if amount <= 0:
		return false

	_dirty_cash += amount
	money_changed.emit(_dirty_cash, _clean_cash)
	if record_transaction:
		transaction_completed.emit(amount, 0)
		transaction_recorded.emit(amount, 0, category, detail)
	return true


func add_clean(
	amount: int,
	record_transaction := true,
	category := "Clean Cash Income",
	detail := "Wallet income"
) -> bool:
	if amount <= 0:
		return false

	_clean_cash += amount
	money_changed.emit(_dirty_cash, _clean_cash)
	if record_transaction:
		transaction_completed.emit(0, amount)
		transaction_recorded.emit(0, amount, category, detail)
	return true


func spend_clean(
	amount: int,
	record_transaction := true,
	category := "Clean Cash Expense",
	detail := "Wallet purchase"
) -> bool:
	if amount < 0 or not can_spend_clean(amount):
		return false
	if amount == 0:
		return true
	_clean_cash -= amount
	money_changed.emit(_dirty_cash, _clean_cash)
	if record_transaction:
		transaction_completed.emit(0, -amount)
		transaction_recorded.emit(0, -amount, category, detail)
	return true


func get_atm_deposited_today(date_key: String) -> int:
	_sync_atm_date(date_key)
	return _atm_deposited_today


func get_atm_remaining_limit(date_key: String) -> int:
	return ATM_DAILY_DEPOSIT_LIMIT - get_atm_deposited_today(date_key)


func deposit_dirty_to_clean(requested_amount: int, date_key: String) -> int:
	if requested_amount <= 0 or date_key.is_empty():
		return 0
	_sync_atm_date(date_key)
	var amount := mini(
		requested_amount,
		mini(_dirty_cash, ATM_DAILY_DEPOSIT_LIMIT - _atm_deposited_today)
	)
	if amount <= 0:
		return 0
	_dirty_cash -= amount
	_clean_cash += amount
	_atm_deposited_today += amount
	money_changed.emit(_dirty_cash, _clean_cash)
	transaction_completed.emit(-amount, amount)
	transaction_recorded.emit(-amount, amount, "Cash Transfer", "ATM deposit: Dirty to Clean")
	return amount


func withdraw_clean_to_dirty(requested_amount: int) -> int:
	if requested_amount <= 0:
		return 0
	var amount := mini(requested_amount, _clean_cash)
	if amount <= 0:
		return 0
	_clean_cash -= amount
	_dirty_cash += amount
	money_changed.emit(_dirty_cash, _clean_cash)
	transaction_completed.emit(amount, -amount)
	transaction_recorded.emit(amount, -amount, "Cash Transfer", "ATM withdrawal: Clean to Dirty")
	return amount


func record_transaction(
	dirty_cash_delta: int,
	clean_cash_delta: int,
	category := "Wallet Activity",
	detail := "Recorded transaction"
) -> void:
	if dirty_cash_delta == 0 and clean_cash_delta == 0:
		return
	transaction_completed.emit(dirty_cash_delta, clean_cash_delta)
	transaction_recorded.emit(dirty_cash_delta, clean_cash_delta, category, detail)


func export_save_data() -> Dictionary:
	return {
		"dirty_cash": _dirty_cash,
		"clean_cash": _clean_cash,
		"atm_deposit_date": _atm_deposit_date,
		"atm_deposited_today": _atm_deposited_today,
	}


func import_save_data(data: Dictionary) -> void:
	_dirty_cash = maxi(int(data.get("dirty_cash", starting_dirty_cash)), 0)
	_clean_cash = maxi(int(data.get("clean_cash", starting_clean_cash)), 0)
	_atm_deposit_date = String(data.get("atm_deposit_date", ""))
	_atm_deposited_today = clampi(int(data.get("atm_deposited_today", 0)), 0, ATM_DAILY_DEPOSIT_LIMIT)
	money_changed.emit(_dirty_cash, _clean_cash)


func deduct_percentage(percent: float) -> Dictionary:
	var safe_percent := clampf(percent, 0.0, 1.0)
	var dirty_loss := floori(float(_dirty_cash) * safe_percent)
	var clean_loss := floori(float(_clean_cash) * safe_percent)
	spend_dirty(dirty_loss)
	spend_clean(clean_loss)
	return {"dirty": dirty_loss, "clean": clean_loss}


func reset_to_new_game() -> void:
	import_save_data({})


func _sync_atm_date(date_key: String) -> void:
	if date_key == _atm_deposit_date:
		return
	_atm_deposit_date = date_key
	_atm_deposited_today = 0
