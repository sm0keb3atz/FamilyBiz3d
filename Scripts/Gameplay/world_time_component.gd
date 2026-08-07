class_name WorldTimeComponent
extends Node

signal time_changed(date_text: String, time_text: String)
signal minute_advanced(absolute_minute: int)
signal night_state_changed(is_night: bool)
signal day_ending(report_date: String)
signal day_ended(report_date: String, earned: int, spent: int)
signal calendar_skipped(from_absolute_minute: int, to_absolute_minute: int, reason: StringName)

const MINUTES_PER_DAY := 1440
const SUNRISE_HOUR := 6.0
const SUNSET_HOUR := 19.5
const MONTH_NAMES := [
	"JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
]
const WEEKDAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const MONTH_LENGTHS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

@export_range(1.0, 3600.0, 1.0) var real_seconds_per_day := 1200.0
@export var sun_path := NodePath("../Environment/Sun")
@export var moon_path := NodePath("../Environment/Moon")
@export var world_environment_path := NodePath("../Environment/WorldEnvironment")

var year := 1
var month := 1
var day := 1
var weekday := 0
var minute_of_day := 8 * 60
var daily_earned := 0
var daily_spent := 0
var active_skip_reason: StringName = &""

var _minute_accumulator := 0.0
var _last_emitted_minute := -1
var _last_night_state := false
var _has_emitted_night_state := false
var _wallet: PlayerWalletComponent
@onready var _sun := get_node_or_null(sun_path) as DirectionalLight3D
@onready var _moon := get_node_or_null(moon_path) as DirectionalLight3D
@onready var _world_environment := get_node_or_null(world_environment_path) as WorldEnvironment


func _ready() -> void:
	add_to_group(&"world_time")
	_configure_environment()
	_update_visuals()
	_emit_night_state_changed()
	_emit_time_changed()


func _process(delta: float) -> void:
	advance_real_seconds(delta, false)
	_update_visuals(_get_fractional_minute_of_day())


func connect_wallet(wallet: PlayerWalletComponent) -> void:
	if _wallet != null and _wallet.transaction_completed.is_connected(_on_transaction_completed):
		_wallet.transaction_completed.disconnect(_on_transaction_completed)
	_wallet = wallet
	if _wallet != null and not _wallet.transaction_completed.is_connected(_on_transaction_completed):
		_wallet.transaction_completed.connect(_on_transaction_completed)


func advance_real_seconds(seconds: float, update_visuals := true) -> void:
	if seconds <= 0.0:
		return
	var seconds_per_minute := real_seconds_per_day / float(MINUTES_PER_DAY)
	_minute_accumulator += seconds
	var elapsed_minutes := floori(_minute_accumulator / seconds_per_minute)
	if elapsed_minutes <= 0:
		if update_visuals:
			_update_visuals(_get_fractional_minute_of_day())
		return
	_minute_accumulator -= float(elapsed_minutes) * seconds_per_minute
	advance_minutes(elapsed_minutes, update_visuals)


func advance_minutes(minutes: int, update_visuals := true) -> void:
	for _index in maxi(minutes, 0):
		minute_of_day += 1
		if minute_of_day >= MINUTES_PER_DAY:
			var report_date := get_formatted_date()
			day_ending.emit(report_date)
			minute_of_day = 0
			_advance_date()
			var earned := daily_earned
			var spent := daily_spent
			daily_earned = 0
			daily_spent = 0
			day_ended.emit(report_date, earned, spent)
		minute_advanced.emit(get_absolute_minute())
	if update_visuals:
		_update_visuals()
	_emit_night_state_changed()
	_emit_time_changed()


func advance_to_next_morning(wake_hour := 8) -> bool:
	if wake_hour < 0 or wake_hour > 23:
		return false
	advance_minutes(MINUTES_PER_DAY - minute_of_day + wake_hour * 60)
	return true


func fast_forward_days(
	days: int,
	reason: StringName,
	process_daily_systems := true
) -> void:
	if days <= 0:
		return
	var from_minute := get_absolute_minute()
	if process_daily_systems:
		active_skip_reason = reason
		advance_minutes(days * MINUTES_PER_DAY)
		active_skip_reason = &""
	else:
		for _index in days:
			_advance_date()
		_update_visuals()
		_emit_night_state_changed()
		_emit_time_changed()
	calendar_skipped.emit(from_minute, get_absolute_minute(), reason)


func fast_forward_years(years_to_advance: int, reason: StringName) -> void:
	if years_to_advance <= 0:
		return
	var from_minute := get_absolute_minute()
	year += years_to_advance
	day = mini(day, _days_in_month(month, year))
	var elapsed_days := (get_absolute_minute() - from_minute) / MINUTES_PER_DAY
	weekday = posmod(weekday + elapsed_days, 7)
	daily_earned = 0
	daily_spent = 0
	_update_visuals()
	_emit_night_state_changed()
	_last_emitted_minute = -1
	_emit_time_changed()
	calendar_skipped.emit(from_minute, get_absolute_minute(), reason)


func get_formatted_date() -> String:
	return "%s %s %d" % [
		WEEKDAY_NAMES[weekday],
		MONTH_NAMES[month - 1],
		day,
	]


func get_formatted_date_with_year() -> String:
	return "%s, %s %d, Y%d" % [
		WEEKDAY_NAMES[weekday],
		MONTH_NAMES[month - 1],
		day,
		year,
	]


func get_formatted_absolute_datetime(absolute_minute: int) -> String:
	var safe_minute := maxi(absolute_minute, 0)
	var absolute_day := safe_minute / MINUTES_PER_DAY
	var date_parts := _date_from_absolute_day(absolute_day)
	return "%s, %s %d, Y%d at %s" % [
		WEEKDAY_NAMES[absolute_day % WEEKDAY_NAMES.size()],
		MONTH_NAMES[int(date_parts.month) - 1],
		int(date_parts.day),
		int(date_parts.year),
		_format_time_of_day(safe_minute % MINUTES_PER_DAY),
	]


func get_date_key() -> String:
	return "%04d-%02d-%02d" % [year, month, day]


func get_absolute_minute() -> int:
	var elapsed_days := 0
	for elapsed_year in range(1, year):
		elapsed_days += 366 if _is_leap_year(elapsed_year) else 365
	for elapsed_month in range(1, month):
		elapsed_days += _days_in_month(elapsed_month, year)
	elapsed_days += day - 1
	return elapsed_days * MINUTES_PER_DAY + minute_of_day


func get_formatted_time() -> String:
	return _format_time_of_day(minute_of_day)


func _format_time_of_day(value: int) -> String:
	var safe_value := posmod(value, MINUTES_PER_DAY)
	var hour_24 := safe_value / 60
	var minute := safe_value % 60
	var suffix := "AM" if hour_24 < 12 else "PM"
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d %s" % [hour_12, minute, suffix]


func is_nighttime() -> bool:
	var hour := float(minute_of_day) / 60.0
	return hour < SUNRISE_HOUR or hour >= SUNSET_HOUR


func set_time_of_day(hour: int, minute: int) -> bool:
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		return false
	var previous_absolute_minute := get_absolute_minute()
	minute_of_day = hour * 60 + minute
	_update_visuals()
	_emit_night_state_changed()
	_emit_time_changed()
	var next_absolute_minute := get_absolute_minute()
	if next_absolute_minute != previous_absolute_minute:
		calendar_skipped.emit(
			previous_absolute_minute,
			next_absolute_minute,
			&"debug_time"
		)
	return true


func set_calendar_date(value_year: int, value_month: int, value_day: int) -> bool:
	if (
		value_year < 1
		or value_month < 1
		or value_month > 12
		or value_day < 1
		or value_day > _days_in_month(value_month, value_year)
	):
		return false
	var previous_absolute_minute := get_absolute_minute()
	year = value_year
	month = value_month
	day = value_day
	weekday = _absolute_day_for_date(year, month, day) % WEEKDAY_NAMES.size()
	_last_emitted_minute = -1
	_update_visuals()
	_emit_night_state_changed()
	_emit_time_changed()
	var next_absolute_minute := get_absolute_minute()
	if next_absolute_minute != previous_absolute_minute:
		calendar_skipped.emit(
			previous_absolute_minute,
			next_absolute_minute,
			&"debug_date"
		)
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
	_emit_night_state_changed()
	_emit_time_changed()


func _on_transaction_completed(dirty_delta: int, clean_delta: int) -> void:
	var total_delta := dirty_delta + clean_delta
	if total_delta > 0:
		daily_earned += total_delta
	elif total_delta < 0:
		daily_spent += -total_delta


func record_external_transaction(dirty_delta: int, clean_delta: int) -> void:
	_on_transaction_completed(dirty_delta, clean_delta)


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
	if value_month == 2 and _is_leap_year(value_year):
		return 29
	return MONTH_LENGTHS[value_month - 1]


func _absolute_day_for_date(
	value_year: int,
	value_month: int,
	value_day: int
) -> int:
	var result := 0
	for elapsed_year in range(1, value_year):
		result += 366 if _is_leap_year(elapsed_year) else 365
	for elapsed_month in range(1, value_month):
		result += _days_in_month(elapsed_month, value_year)
	return result + value_day - 1


func _date_from_absolute_day(absolute_day: int) -> Dictionary:
	var remaining := maxi(absolute_day, 0)
	var result_year := 1
	while true:
		var year_days := 366 if _is_leap_year(result_year) else 365
		if remaining < year_days:
			break
		remaining -= year_days
		result_year += 1
	var result_month := 1
	while true:
		var month_days := _days_in_month(result_month, result_year)
		if remaining < month_days:
			break
		remaining -= month_days
		result_month += 1
	return {
		"year": result_year,
		"month": result_month,
		"day": remaining + 1,
	}


func _is_leap_year(value_year: int) -> bool:
	return value_year % 400 == 0 or (value_year % 4 == 0 and value_year % 100 != 0)


func _emit_time_changed() -> void:
	if _last_emitted_minute == minute_of_day:
		return
	_last_emitted_minute = minute_of_day
	time_changed.emit(get_formatted_date(), get_formatted_time())


func _emit_night_state_changed(force := false) -> void:
	var is_night := is_nighttime()
	if not force and _has_emitted_night_state and _last_night_state == is_night:
		return
	_last_night_state = is_night
	_has_emitted_night_state = true
	night_state_changed.emit(is_night)


func _get_fractional_minute_of_day() -> float:
	var seconds_per_minute := real_seconds_per_day / float(MINUTES_PER_DAY)
	if seconds_per_minute <= 0.0:
		return float(minute_of_day)
	return fposmod(
		float(minute_of_day) + _minute_accumulator / seconds_per_minute,
		float(MINUTES_PER_DAY)
	)


func _configure_environment() -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	var environment := _world_environment.environment
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


func _update_visuals(visual_minute := -1.0) -> void:
	var effective_minute := (
		float(minute_of_day)
		if visual_minute < 0.0
		else visual_minute
	)
	var hour := effective_minute / 60.0
	var daylight_duration := SUNSET_HOUR - SUNRISE_HOUR
	var daylight_progress := clampf((hour - SUNRISE_HOUR) / daylight_duration, 0.0, 1.0)
	var daylight := sin(daylight_progress * PI) if hour >= SUNRISE_HOUR and hour <= SUNSET_HOUR else 0.0
	var night_strength := 1.0 - smoothstep(0.0, 0.22, daylight)
	var sun_arc_progress := daylight_progress
	if hour < SUNRISE_HOUR:
		sun_arc_progress = 1.0 + (hour + 24.0 - SUNSET_HOUR) / (24.0 - SUNSET_HOUR + SUNRISE_HOUR)
	elif hour > SUNSET_HOUR:
		sun_arc_progress = 1.0 + (hour - SUNSET_HOUR) / (24.0 - SUNSET_HOUR + SUNRISE_HOUR)
	if _sun != null:
		# DirectionalLight3D shines down its local -Z axis. Rotating the other
		# way made LIGHT0_DIRECTION negative during the day, so the sky shader
		# rendered stars and night colors while the clock showed morning.
		_sun.rotation_degrees = Vector3(-180.0 * sun_arc_progress, -30.0, 0.0)
		_sun.light_energy = lerpf(0.03, 1.15, pow(daylight, 0.65))
		_sun.light_color = Color(1.0, 0.48, 0.3).lerp(Color(1.0, 0.96, 0.86), daylight)
	if _moon != null:
		var moon_arc_progress := fposmod(sun_arc_progress - 1.0, 2.0)
		_moon.rotation_degrees = Vector3(-180.0 * moon_arc_progress, 28.0, 0.0)
		_moon.light_energy = 0.13 * pow(night_strength, 0.7)
	if _world_environment != null and _world_environment.environment != null:
		var environment := _world_environment.environment
		environment.ambient_light_color = Color(0.18, 0.24, 0.38).lerp(Color(0.72, 0.78, 0.9), daylight)
		environment.ambient_light_energy = lerpf(0.25, 0.75, daylight)
