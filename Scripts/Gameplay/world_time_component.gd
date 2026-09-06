class_name WorldTimeComponent
extends Node

signal time_changed(date_text: String, time_text: String)
signal minute_advanced(absolute_minute: int)
signal night_state_changed(is_night: bool)
signal day_ending(report_date: String)
signal day_ended(report_date: String, earned: int, spent: int)
signal calendar_skipped(from_absolute_minute: int, to_absolute_minute: int, reason: StringName)

const MINUTES_PER_DAY := 1440
const REPORT_HISTORY_LIMIT := 30
const SUNRISE_HOUR := 6.0
const SUNSET_HOUR := 19.5
const DEFAULT_VISUAL_PROFILE := preload(
	"res://Assets/VFX/GrittyCinematicWorldVisualProfile.tres"
)
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
@export var visual_profile: WorldVisualProfile = DEFAULT_VISUAL_PROFILE

var year := 1
var month := 1
var day := 1
var weekday := 0
var minute_of_day := 8 * 60
var daily_earned := 0
var daily_spent := 0
var daily_transactions: Array[Dictionary] = []
var daily_report_history: Array[Dictionary] = []
var active_skip_reason: StringName = &""

var _minute_accumulator := 0.0
var _last_emitted_minute := -1
var _last_night_state := false
var _has_emitted_night_state := false
var _wallet: PlayerWalletComponent
var _last_day_transactions: Array[Dictionary] = []
var _color_correction_texture: GradientTexture1D
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
	if _wallet != null and _wallet.transaction_recorded.is_connected(_on_transaction_recorded):
		_wallet.transaction_recorded.disconnect(_on_transaction_recorded)
	_wallet = wallet
	if _wallet != null and not _wallet.transaction_recorded.is_connected(_on_transaction_recorded):
		_wallet.transaction_recorded.connect(_on_transaction_recorded)


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
			_last_day_transactions = daily_transactions.duplicate(true)
			_append_daily_report(report_date, earned, spent)
			daily_earned = 0
			daily_spent = 0
			daily_transactions.clear()
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
	daily_transactions.clear()
	_last_day_transactions.clear()
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
		"daily_transactions": daily_transactions.duplicate(true),
		"daily_report_history": daily_report_history.duplicate(true),
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
	daily_transactions.clear()
	_last_day_transactions.clear()
	var saved_transactions := data.get("daily_transactions", []) as Array
	for entry in saved_transactions:
		if entry is Dictionary:
			daily_transactions.append((entry as Dictionary).duplicate(true))
	daily_report_history.clear()
	var saved_history := data.get("daily_report_history", []) as Array
	for entry in saved_history:
		if entry is not Dictionary:
			continue
		var report := entry as Dictionary
		daily_report_history.append({
			"date": String(report.get("date", "DAY")),
			"earned": maxi(int(report.get("earned", 0)), 0),
			"spent": maxi(int(report.get("spent", 0)), 0),
		})
	while daily_report_history.size() > REPORT_HISTORY_LIMIT:
		daily_report_history.pop_front()
	_update_visuals()
	_emit_night_state_changed()
	_emit_time_changed()


func _on_transaction_recorded(
	dirty_delta: int,
	clean_delta: int,
	category: String,
	detail: String
) -> void:
	var total_delta := dirty_delta + clean_delta
	if total_delta > 0:
		daily_earned += total_delta
	elif total_delta < 0:
		daily_spent += -total_delta
	if total_delta == 0:
		return
	daily_transactions.append({
		"minute": minute_of_day,
		"amount": absi(total_delta),
		"direction": "income" if total_delta > 0 else "expense",
		"category": category if not category.is_empty() else "Wallet Activity",
		"detail": detail if not detail.is_empty() else "Transaction",
		"cash_type": "Dirty" if dirty_delta != 0 else "Clean",
	})


func record_external_transaction(
	dirty_delta: int,
	clean_delta: int,
	category := "Business Income",
	detail := "Off-site earnings"
) -> void:
	_on_transaction_recorded(dirty_delta, clean_delta, category, detail)


func get_last_day_transactions() -> Array[Dictionary]:
	return _last_day_transactions.duplicate(true)


func get_daily_report_history(limit := 7) -> Array[Dictionary]:
	var safe_limit := clampi(limit, 1, REPORT_HISTORY_LIMIT)
	var start := maxi(daily_report_history.size() - safe_limit, 0)
	var result: Array[Dictionary] = []
	for index in range(start, daily_report_history.size()):
		result.append(daily_report_history[index].duplicate(true))
	return result


func _append_daily_report(report_date: String, earned: int, spent: int) -> void:
	daily_report_history.append({
		"date": report_date,
		"earned": maxi(earned, 0),
		"spent": maxi(spent, 0),
	})
	while daily_report_history.size() > REPORT_HISTORY_LIMIT:
		daily_report_history.pop_front()


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
	if visual_profile == null:
		return
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = visual_profile.tonemap_exposure
	environment.tonemap_agx_contrast = visual_profile.agx_contrast
	environment.tonemap_agx_white = visual_profile.agx_white
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.0
	environment.adjustment_saturation = visual_profile.saturation
	_color_correction_texture = visual_profile.create_color_correction_texture()
	environment.adjustment_color_correction = _color_correction_texture
	environment.ssao_enabled = true
	environment.ssao_radius = 1.25
	environment.ssao_intensity = 1.15
	environment.ssao_power = 1.35
	environment.ssao_detail = 0.55
	environment.ssao_horizon = 0.08
	environment.ssao_sharpness = 0.92
	environment.ssao_light_affect = 0.12
	environment.ssil_enabled = visual_profile.ssil_enabled
	environment.ssil_radius = visual_profile.ssil_radius
	environment.ssil_intensity = visual_profile.ssil_intensity
	environment.ssil_sharpness = visual_profile.ssil_sharpness
	environment.ssil_normal_rejection = visual_profile.ssil_normal_rejection
	environment.ssr_enabled = false
	environment.sdfgi_enabled = false
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = (
		visual_profile.day_volumetric_fog_density
	)
	environment.volumetric_fog_length = visual_profile.volumetric_fog_length
	environment.volumetric_fog_anisotropy = (
		visual_profile.volumetric_fog_anisotropy
	)
	environment.volumetric_fog_ambient_inject = (
		visual_profile.volumetric_fog_ambient_inject
	)
	environment.volumetric_fog_sky_affect = (
		visual_profile.volumetric_fog_sky_affect
	)
	environment.volumetric_fog_temporal_reprojection_enabled = true
	environment.volumetric_fog_temporal_reprojection_amount = 0.82
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = visual_profile.glow_intensity
	environment.glow_bloom = visual_profile.glow_bloom
	environment.glow_hdr_threshold = visual_profile.glow_hdr_threshold
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.fog_enabled = true
	environment.fog_density = visual_profile.clear_fog_density
	environment.fog_aerial_perspective = (
		visual_profile.clear_fog_aerial_perspective
	)
	environment.fog_sun_scatter = visual_profile.clear_fog_sun_scatter
	environment.fog_sky_affect = visual_profile.day_fog_sky_affect


func _update_visuals(visual_minute := -1.0) -> void:
	if visual_profile == null:
		return
	var effective_minute := (
		float(minute_of_day)
		if visual_minute < 0.0
		else visual_minute
	)
	var hour := effective_minute / 60.0
	var daylight_duration := SUNSET_HOUR - SUNRISE_HOUR
	var daylight_progress := clampf((hour - SUNRISE_HOUR) / daylight_duration, 0.0, 1.0)
	var daylight := sin(daylight_progress * PI) if hour >= SUNRISE_HOUR and hour <= SUNSET_HOUR else 0.0
	var daylight_strength := smoothstep(0.0, 0.28, daylight)
	var night_strength := 1.0 - daylight_strength
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
		var sun_energy := lerpf(
			visual_profile.night_sun_energy,
			visual_profile.day_sun_energy,
			pow(daylight, 0.65)
		)
		var sun_color := visual_profile.sunrise_sun_color.lerp(
			visual_profile.day_sun_color,
			pow(daylight, 0.55)
		)
		_sun.light_energy = sun_energy
		_sun.light_color = sun_color
		_sun.set_meta(WorldVisualProfile.META_BASE_SUN_ENERGY, sun_energy)
		_sun.set_meta(WorldVisualProfile.META_BASE_SUN_COLOR, sun_color)
	if _moon != null:
		var moon_arc_progress := fposmod(sun_arc_progress - 1.0, 2.0)
		_moon.rotation_degrees = Vector3(-180.0 * moon_arc_progress, 28.0, 0.0)
		var moon_energy := visual_profile.moon_energy * pow(night_strength, 0.7)
		_moon.light_energy = moon_energy
		_moon.set_meta(WorldVisualProfile.META_BASE_MOON_ENERGY, moon_energy)
	if _world_environment != null and _world_environment.environment != null:
		var environment := _world_environment.environment
		var grade_state := _get_time_grade_state(hour)
		var grade_colors: PackedColorArray = grade_state["colors"]
		if (
			_color_correction_texture == null
			or _color_correction_texture.gradient == null
		):
			_color_correction_texture = (
				visual_profile.create_color_correction_texture(grade_colors)
			)
		else:
			_color_correction_texture.gradient.colors = grade_colors
		environment.adjustment_color_correction = _color_correction_texture
		environment.adjustment_saturation = float(grade_state["saturation"])
		environment.glow_intensity = float(grade_state["glow"])
		environment.set_meta(
			WorldVisualProfile.META_BASE_GRADE_COLORS,
			grade_colors
		)
		environment.set_meta(
			WorldVisualProfile.META_BASE_SATURATION,
			environment.adjustment_saturation
		)
		environment.set_meta(
			WorldVisualProfile.META_BASE_GLOW_INTENSITY,
			environment.glow_intensity
		)
		var ambient_color := visual_profile.night_ambient_color.lerp(
			visual_profile.day_ambient_color,
			daylight_strength
		)
		var ambient_energy := lerpf(
			visual_profile.night_ambient_energy,
			visual_profile.day_ambient_energy,
			daylight_strength
		)
		var fog_color := visual_profile.night_fog_color.lerp(
			visual_profile.day_fog_color,
			daylight_strength
		)
		var fog_energy := lerpf(
			visual_profile.night_fog_light_energy,
			visual_profile.day_fog_light_energy,
			daylight_strength
		)
		var volumetric_fog_density := lerpf(
			visual_profile.night_volumetric_fog_density,
			visual_profile.day_volumetric_fog_density,
			daylight_strength
		)
		var fog_sky_affect := lerpf(
			visual_profile.night_fog_sky_affect,
			visual_profile.day_fog_sky_affect,
			daylight_strength
		)
		var volumetric_fog_sky_affect := lerpf(
			visual_profile.night_volumetric_fog_sky_affect,
			visual_profile.volumetric_fog_sky_affect,
			daylight_strength
		)
		environment.ambient_light_color = ambient_color
		environment.ambient_light_energy = ambient_energy
		environment.fog_enabled = true
		environment.fog_light_color = fog_color
		environment.fog_light_energy = fog_energy
		environment.fog_density = visual_profile.clear_fog_density
		environment.fog_aerial_perspective = (
			visual_profile.clear_fog_aerial_perspective
		)
		environment.fog_sun_scatter = (
			visual_profile.clear_fog_sun_scatter * daylight_strength
		)
		environment.fog_sky_affect = fog_sky_affect
		environment.volumetric_fog_density = volumetric_fog_density
		environment.volumetric_fog_sky_affect = volumetric_fog_sky_affect
		environment.set_meta(
			WorldVisualProfile.META_BASE_AMBIENT_COLOR,
			ambient_color
		)
		environment.set_meta(
			WorldVisualProfile.META_BASE_AMBIENT_ENERGY,
			ambient_energy
		)
		environment.set_meta(WorldVisualProfile.META_BASE_FOG_COLOR, fog_color)
		environment.set_meta(WorldVisualProfile.META_BASE_FOG_ENERGY, fog_energy)
		environment.set_meta(
			WorldVisualProfile.META_BASE_FOG_DENSITY,
			visual_profile.clear_fog_density
		)
		environment.set_meta(
			WorldVisualProfile.META_BASE_VOLUMETRIC_FOG_DENSITY,
			volumetric_fog_density
		)
		environment.set_meta(
			WorldVisualProfile.META_BASE_FOG_AERIAL,
			visual_profile.clear_fog_aerial_perspective
		)
		environment.set_meta(
			WorldVisualProfile.META_BASE_FOG_SUN_SCATTER,
			visual_profile.clear_fog_sun_scatter * daylight_strength
		)


func _get_time_grade_state(hour: float) -> Dictionary:
	var day_colors := visual_profile.get_day_grade_colors()
	if not visual_profile.dynamic_color_grading_enabled:
		return {
			"colors": day_colors,
			"saturation": visual_profile.saturation,
			"glow": visual_profile.glow_intensity,
		}
	var golden_colors := visual_profile.get_golden_grade_colors()
	var night_colors := visual_profile.get_night_grade_colors()
	var half_window := maxf(visual_profile.golden_transition_hours * 0.5, 0.125)
	var morning_start := SUNRISE_HOUR - half_window
	var morning_end := SUNRISE_HOUR + half_window
	var evening_start := SUNSET_HOUR - half_window
	var evening_end := SUNSET_HOUR + half_window
	if hour < morning_start or hour >= evening_end:
		return {
			"colors": night_colors,
			"saturation": visual_profile.night_saturation,
			"glow": visual_profile.night_glow_intensity,
		}
	if hour < SUNRISE_HOUR:
		var dawn_weight := smoothstep(morning_start, SUNRISE_HOUR, hour)
		return {
			"colors": visual_profile.blend_grade_colors(
				night_colors,
				golden_colors,
				dawn_weight
			),
			"saturation": lerpf(
				visual_profile.night_saturation,
				visual_profile.golden_saturation,
				dawn_weight
			),
			"glow": lerpf(
				visual_profile.night_glow_intensity,
				visual_profile.golden_glow_intensity,
				dawn_weight
			),
		}
	if hour < morning_end:
		var morning_weight := smoothstep(SUNRISE_HOUR, morning_end, hour)
		return {
			"colors": visual_profile.blend_grade_colors(
				golden_colors,
				day_colors,
				morning_weight
			),
			"saturation": lerpf(
				visual_profile.golden_saturation,
				visual_profile.saturation,
				morning_weight
			),
			"glow": lerpf(
				visual_profile.golden_glow_intensity,
				visual_profile.day_glow_intensity,
				morning_weight
			),
		}
	if hour < evening_start:
		return {
			"colors": day_colors,
			"saturation": visual_profile.saturation,
			"glow": visual_profile.day_glow_intensity,
		}
	if hour < SUNSET_HOUR:
		var evening_weight := smoothstep(evening_start, SUNSET_HOUR, hour)
		return {
			"colors": visual_profile.blend_grade_colors(
				day_colors,
				golden_colors,
				evening_weight
			),
			"saturation": lerpf(
				visual_profile.saturation,
				visual_profile.golden_saturation,
				evening_weight
			),
			"glow": lerpf(
				visual_profile.day_glow_intensity,
				visual_profile.golden_glow_intensity,
				evening_weight
			),
		}
	var dusk_weight := smoothstep(SUNSET_HOUR, evening_end, hour)
	return {
		"colors": visual_profile.blend_grade_colors(
			golden_colors,
			night_colors,
			dusk_weight
		),
		"saturation": lerpf(
			visual_profile.golden_saturation,
			visual_profile.night_saturation,
			dusk_weight
		),
		"glow": lerpf(
			visual_profile.golden_glow_intensity,
			visual_profile.night_glow_intensity,
			dusk_weight
		),
	}
