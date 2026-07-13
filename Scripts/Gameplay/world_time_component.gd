class_name WorldTimeComponent
extends Node

signal time_changed(date_text: String, time_text: String)
signal day_ended(report_date: String, earned: int, spent: int)

const MINUTES_PER_DAY := 1440
const MONTH_NAMES := [
	"JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
]
const WEEKDAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const MONTH_LENGTHS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

@export_range(1.0, 3600.0, 1.0) var real_seconds_per_day := 600.0
@export var sun_path := NodePath("../Environment/Sun")
@export var world_environment_path := NodePath("../Environment/WorldEnvironment")

var year := 1
var month := 1
var day := 1
var weekday := 0
var minute_of_day := 8 * 60
var daily_earned := 0
var daily_spent := 0

var _minute_accumulator := 0.0
var _last_emitted_minute := -1
var _wallet: PlayerWalletComponent
@onready var _sun := get_node_or_null(sun_path) as DirectionalLight3D
@onready var _world_environment := get_node_or_null(world_environment_path) as WorldEnvironment


func _ready() -> void:
	_update_visuals()
	_emit_time_changed()


func _process(delta: float) -> void:
	advance_real_seconds(delta)


func connect_wallet(wallet: PlayerWalletComponent) -> void:
	if _wallet != null and _wallet.transaction_completed.is_connected(_on_transaction_completed):
		_wallet.transaction_completed.disconnect(_on_transaction_completed)
	_wallet = wallet
	if _wallet != null and not _wallet.transaction_completed.is_connected(_on_transaction_completed):
		_wallet.transaction_completed.connect(_on_transaction_completed)


func advance_real_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var seconds_per_minute := real_seconds_per_day / float(MINUTES_PER_DAY)
	_minute_accumulator += seconds
	var elapsed_minutes := floori(_minute_accumulator / seconds_per_minute)
	if elapsed_minutes <= 0:
		return
	_minute_accumulator -= float(elapsed_minutes) * seconds_per_minute
	advance_minutes(elapsed_minutes)


func advance_minutes(minutes: int) -> void:
	for _index in maxi(minutes, 0):
		minute_of_day += 1
		if minute_of_day >= MINUTES_PER_DAY:
			var report_date := get_formatted_date()
			minute_of_day = 0
			_advance_date()
			var earned := daily_earned
			var spent := daily_spent
			daily_earned = 0
			daily_spent = 0
			_update_visuals()
			_emit_time_changed()
			day_ended.emit(report_date, earned, spent)
			return
	_update_visuals()
	_emit_time_changed()


func get_formatted_date() -> String:
	return "%s %s %d" % [
		WEEKDAY_NAMES[weekday],
		MONTH_NAMES[month - 1],
		day,
	]


func get_formatted_time() -> String:
	var hour_24 := minute_of_day / 60
	var minute := minute_of_day % 60
	var suffix := "AM" if hour_24 < 12 else "PM"
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d %s" % [hour_12, minute, suffix]


func set_time_of_day(hour: int, minute: int) -> bool:
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		return false
	minute_of_day = hour * 60 + minute
	_update_visuals()
	_emit_time_changed()
	return true


func export_save_data() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"day": day,
		"weekday": weekday,
		"minute_of_day": minute_of_day,
		"minute_accumulator": _minute_accumulator,
		"daily_earned": daily_earned,
		"daily_spent": daily_spent,
	}


func import_save_data(data: Dictionary) -> void:
	year = maxi(int(data.get("year", 1)), 1)
	month = clampi(int(data.get("month", 1)), 1, 12)
	day = clampi(int(data.get("day", 1)), 1, _days_in_month(month, year))
	weekday = posmod(int(data.get("weekday", 0)), 7)
	minute_of_day = clampi(int(data.get("minute_of_day", 8 * 60)), 0, MINUTES_PER_DAY - 1)
	_minute_accumulator = maxf(float(data.get("minute_accumulator", 0.0)), 0.0)
	daily_earned = maxi(int(data.get("daily_earned", 0)), 0)
	daily_spent = maxi(int(data.get("daily_spent", 0)), 0)
	_update_visuals()
	_emit_time_changed()


func _on_transaction_completed(dirty_delta: int, clean_delta: int) -> void:
	var total_delta := dirty_delta + clean_delta
	if total_delta > 0:
		daily_earned += total_delta
	elif total_delta < 0:
		daily_spent += -total_delta


func _advance_date() -> void:
	weekday = (weekday + 1) % 7
	day += 1
	if day <= _days_in_month(month, year):
		return
	day = 1
	month += 1
	if month > 12:
		month = 1
		year += 1


func _days_in_month(value_month: int, value_year: int) -> int:
	if value_month == 2 and (value_year % 400 == 0 or (value_year % 4 == 0 and value_year % 100 != 0)):
		return 29
	return MONTH_LENGTHS[value_month - 1]


func _emit_time_changed() -> void:
	if _last_emitted_minute == minute_of_day:
		return
	_last_emitted_minute = minute_of_day
	time_changed.emit(get_formatted_date(), get_formatted_time())


func _update_visuals() -> void:
	var hour := float(minute_of_day) / 60.0
	var daylight := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
	if _sun != null:
		# DirectionalLight3D shines down its local -Z axis. Rotating the other
		# way made LIGHT0_DIRECTION negative during the day, so the sky shader
		# rendered stars and night colors while the clock showed morning.
		_sun.rotation_degrees = Vector3(90.0 - hour * 15.0, -30.0, 0.0)
		_sun.light_energy = lerpf(0.03, 1.15, pow(daylight, 0.65))
		_sun.light_color = Color(1.0, 0.48, 0.3).lerp(Color(1.0, 0.96, 0.86), daylight)
	if _world_environment != null and _world_environment.environment != null:
		var environment := _world_environment.environment
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.035, 0.055, 0.11).lerp(Color(0.72, 0.78, 0.9), daylight)
		environment.ambient_light_energy = lerpf(0.2, 0.75, daylight)
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
