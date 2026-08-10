class_name WeatherSystem
extends Node3D

signal weather_changed(previous_weather: StringName, current_weather: StringName)
signal lightning_struck(strength: float, suggested_thunder_delay: float)

const CLEAR := &"clear"
const RAIN := &"rain"
const HEAVY_RAIN := &"heavy_rain"
const THUNDERSTORM := &"thunderstorm"
const VALID_WEATHER := [CLEAR, RAIN, HEAVY_RAIN, THUNDERSTORM]

const WEATHER_PROFILES := {
	CLEAR: {"rain": 0.0, "overcast": 0.0, "fog": 0.0, "wind": 0.05},
	RAIN: {"rain": 0.42, "overcast": 0.55, "fog": 0.12, "wind": 0.22},
	HEAVY_RAIN: {"rain": 0.78, "overcast": 0.82, "fog": 0.28, "wind": 0.48},
	THUNDERSTORM: {"rain": 1.0, "overcast": 1.0, "fog": 0.42, "wind": 0.72},
}

@export_category("World References")
@export var player_path := NodePath("../Gameplay/Player")
@export var world_environment_path := NodePath("../Environment/WorldEnvironment")
@export var sun_path := NodePath("../Environment/Sun")
@export var moon_path := NodePath("../Environment/Moon")

@export_category("Random Weather")
@export var random_weather_enabled := true
@export_range(10.0, 3600.0, 1.0) var clear_break_min_seconds := 90.0
@export_range(10.0, 3600.0, 1.0) var clear_break_max_seconds := 240.0
@export_range(10.0, 3600.0, 1.0) var weather_duration_min_seconds := 120.0
@export_range(10.0, 3600.0, 1.0) var weather_duration_max_seconds := 300.0

@export_category("Presentation")
@export_range(0.1, 60.0, 0.1) var transition_seconds := 10.0
@export_range(2.0, 30.0, 0.5) var rain_emitter_height := 12.0
@export var follow_player_height := true

@onready var _player := get_node_or_null(player_path) as Node3D
@onready var _world_environment := get_node_or_null(world_environment_path) as WorldEnvironment
@onready var _sun := get_node_or_null(sun_path) as DirectionalLight3D
@onready var _moon := get_node_or_null(moon_path) as DirectionalLight3D
@onready var _rain_streaks := $RainStreaks as GPUParticles3D
@onready var _near_rain := $NearRain as GPUParticles3D
@onready var _ground_mist := $GroundMist as GPUParticles3D
@onready var _rain_splashes := $RainSplashes as GPUParticles3D
@onready var _rain_process_material := _rain_streaks.process_material as ParticleProcessMaterial
@onready var _near_rain_process_material := _near_rain.process_material as ParticleProcessMaterial
@onready var _screen_material := $RainScreenOverlay/WeatherOverlay.material as ShaderMaterial

var current_weather: StringName = CLEAR
var _rain_intensity := 0.0
var _overcast_intensity := 0.0
var _fog_intensity := 0.0
var _wind_intensity := 0.0
var _target_rain := 0.0
var _target_overcast := 0.0
var _target_fog := 0.0
var _target_wind := 0.0
var _event_seconds_remaining := 0.0
var _lightning_seconds_remaining := 0.0
var _lightning_elapsed := -1.0
var _lightning_peak := 0.0
var _lightning_value := 0.0
var _wind_direction := Vector2.ZERO
var _target_wind_direction := Vector2.ZERO
var _sky_material: ShaderMaterial
var _environment: Environment
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"weather_system")
	# WorldTimeComponent writes its day/night lighting first. Weather then
	# applies a non-destructive tint and energy multiplier to those values.
	process_priority = 100
	_rng.randomize()
	_resolve_environment()
	_schedule_clear_break()
	_apply_profile(CLEAR, true)
	_rain_streaks.emitting = false
	_near_rain.emitting = false
	_ground_mist.emitting = false
	_rain_splashes.emitting = false


func _process(delta: float) -> void:
	_follow_player()
	_update_random_weather(delta)
	_update_weather_blend(delta)
	_update_lightning(delta)
	_update_wind(delta)
	_apply_visuals()


func set_weather(weather_name: StringName, immediate := false) -> bool:
	var normalized := _normalize_weather_name(weather_name)
	if normalized not in VALID_WEATHER:
		return false
	var previous := current_weather
	current_weather = normalized
	_apply_profile(normalized, immediate)
	if normalized == CLEAR:
		_schedule_clear_break()
	else:
		_event_seconds_remaining = _rng.randf_range(
			weather_duration_min_seconds,
			maxf(weather_duration_min_seconds, weather_duration_max_seconds)
		)
		_pick_wind_direction()
		if normalized == THUNDERSTORM:
			_schedule_lightning(true)
	if previous != current_weather:
		weather_changed.emit(previous, current_weather)
	return true


func debug_set_weather(weather_name: StringName) -> bool:
	var normalized := _normalize_weather_name(weather_name)
	if normalized not in VALID_WEATHER:
		return false
	random_weather_enabled = false
	return set_weather(normalized)


func set_random_weather_enabled(enabled: bool) -> void:
	random_weather_enabled = enabled
	if enabled:
		if current_weather == CLEAR:
			_schedule_clear_break()
		else:
			_event_seconds_remaining = _rng.randf_range(
				weather_duration_min_seconds,
				maxf(weather_duration_min_seconds, weather_duration_max_seconds)
			)


func force_random_weather() -> StringName:
	random_weather_enabled = true
	var roll := _rng.randf()
	var next_weather := RAIN
	if roll >= 0.82:
		next_weather = THUNDERSTORM
	elif roll >= 0.48:
		next_weather = HEAVY_RAIN
	set_weather(next_weather)
	return next_weather


func debug_trigger_lightning() -> void:
	_trigger_lightning()


func get_status_text() -> String:
	var mode := "random" if random_weather_enabled else "manual"
	return "%s (%s), rain %d%%, overcast %d%%" % [
		String(current_weather).replace("_", " ").capitalize(),
		mode,
		roundi(_rain_intensity * 100.0),
		roundi(_overcast_intensity * 100.0),
	]


func _normalize_weather_name(weather_name: StringName) -> StringName:
	var text := String(weather_name).strip_edges().to_lower().replace(" ", "_")
	match text:
		"heavy", "downpour":
			return HEAVY_RAIN
		"storm", "thunder", "thunder_storm":
			return THUNDERSTORM
		_:
			return StringName(text)


func _apply_profile(weather_name: StringName, immediate: bool) -> void:
	var profile := WEATHER_PROFILES[weather_name] as Dictionary
	_target_rain = float(profile["rain"])
	_target_overcast = float(profile["overcast"])
	_target_fog = float(profile["fog"])
	_target_wind = float(profile["wind"])
	if immediate:
		_rain_intensity = _target_rain
		_overcast_intensity = _target_overcast
		_fog_intensity = _target_fog
		_wind_intensity = _target_wind


func _update_random_weather(delta: float) -> void:
	if not random_weather_enabled:
		return
	_event_seconds_remaining -= delta
	if _event_seconds_remaining > 0.0:
		return
	if current_weather == CLEAR:
		force_random_weather()
	else:
		set_weather(CLEAR)


func _update_weather_blend(delta: float) -> void:
	var step := delta / maxf(transition_seconds, 0.1)
	_rain_intensity = move_toward(_rain_intensity, _target_rain, step)
	_overcast_intensity = move_toward(_overcast_intensity, _target_overcast, step)
	_fog_intensity = move_toward(_fog_intensity, _target_fog, step)
	_wind_intensity = move_toward(_wind_intensity, _target_wind, step)
	_rain_streaks.emitting = _rain_intensity > 0.01
	_near_rain.emitting = _rain_intensity > 0.16
	_ground_mist.emitting = _rain_intensity > 0.2
	_rain_splashes.emitting = _rain_intensity > 0.08
	_rain_streaks.amount_ratio = clampf(_rain_intensity, 0.0, 1.0)
	_near_rain.amount_ratio = clampf(
		(_rain_intensity - 0.15) / 0.85,
		0.0,
		1.0
	) * 0.72
	_ground_mist.amount_ratio = clampf((_rain_intensity - 0.18) / 0.82, 0.0, 1.0)
	_rain_splashes.amount_ratio = clampf(_rain_intensity * 0.88, 0.0, 1.0)


func _update_wind(delta: float) -> void:
	_wind_direction = _wind_direction.move_toward(_target_wind_direction, delta * 0.12)
	if _rain_process_material == null:
		return
	var slant := _wind_direction * _wind_intensity * 0.8
	var rain_direction := Vector3(slant.x, -1.0, slant.y).normalized()
	_rain_process_material.direction = rain_direction
	if _near_rain_process_material != null:
		_near_rain_process_material.direction = rain_direction


func _update_lightning(delta: float) -> void:
	if current_weather == THUNDERSTORM and _overcast_intensity > 0.55:
		_lightning_seconds_remaining -= delta
		if _lightning_seconds_remaining <= 0.0 and _lightning_elapsed < 0.0:
			_trigger_lightning()
	else:
		_lightning_seconds_remaining = maxf(_lightning_seconds_remaining, 1.0)
	if _lightning_elapsed < 0.0:
		_lightning_value = move_toward(_lightning_value, 0.0, delta * 5.0)
		return
	_lightning_elapsed += delta
	if _lightning_elapsed < 0.07:
		_lightning_value = _lightning_peak
	elif _lightning_elapsed < 0.15:
		_lightning_value = 0.06
	elif _lightning_elapsed < 0.23:
		_lightning_value = _lightning_peak * 0.72
	elif _lightning_elapsed < 0.72:
		_lightning_value = lerpf(
			_lightning_peak * 0.72,
			0.0,
			(_lightning_elapsed - 0.23) / 0.49
		)
	else:
		_lightning_value = 0.0
		_lightning_elapsed = -1.0


func _trigger_lightning() -> void:
	_lightning_peak = _rng.randf_range(0.72, 1.0)
	_lightning_elapsed = 0.0
	_lightning_value = _lightning_peak
	_schedule_lightning(false)
	lightning_struck.emit(_lightning_peak, _rng.randf_range(0.7, 3.5))


func _schedule_lightning(first_strike: bool) -> void:
	_lightning_seconds_remaining = (
		_rng.randf_range(2.5, 7.0)
		if first_strike
		else _rng.randf_range(6.0, 18.0)
	)


func _schedule_clear_break() -> void:
	_event_seconds_remaining = _rng.randf_range(
		clear_break_min_seconds,
		maxf(clear_break_min_seconds, clear_break_max_seconds)
	)


func _pick_wind_direction() -> void:
	_target_wind_direction = Vector2.from_angle(_rng.randf_range(0.0, TAU))


func _follow_player() -> void:
	if not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node3D
	var camera := get_viewport().get_camera_3d()
	if camera == null and _player == null:
		return
	var anchor := camera.global_position if camera != null else _player.global_position
	if follow_player_height and _player != null:
		anchor.y = _player.global_position.y
	global_position = anchor
	_rain_streaks.position.y = rain_emitter_height
	_near_rain.position.y = rain_emitter_height * 0.72


func _resolve_environment() -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	_environment = _world_environment.environment
	if _environment.sky != null:
		_sky_material = _environment.sky.sky_material as ShaderMaterial


func _apply_visuals() -> void:
	if _sky_material != null:
		_sky_material.set_shader_parameter("weather_overcast", _overcast_intensity)
		_sky_material.set_shader_parameter("weather_flash", _lightning_value)
	if _screen_material != null:
		_screen_material.set_shader_parameter("rain_intensity", _rain_intensity)
		_screen_material.set_shader_parameter("lightning", _lightning_value)
	if _environment != null:
		_environment.fog_enabled = _fog_intensity > 0.01
		_environment.fog_light_color = Color(0.34, 0.39, 0.48).lerp(
			Color(0.62, 0.7, 0.88),
			_lightning_value
		)
		_environment.fog_light_energy = 0.62 + _lightning_value * 0.65
		_environment.fog_density = _fog_intensity * 0.018
		_environment.fog_aerial_perspective = _fog_intensity * 0.72
		_environment.ambient_light_color = _environment.ambient_light_color.lerp(
			Color(0.25, 0.3, 0.4),
			_overcast_intensity * 0.72
		)
		_environment.ambient_light_energy = (
			_environment.ambient_light_energy * lerpf(1.0, 0.68, _overcast_intensity)
			+ _lightning_value * 0.75
		)
	if _sun != null:
		_sun.light_color = _sun.light_color.lerp(
			Color(0.62, 0.69, 0.8),
			_overcast_intensity * 0.78
		)
		_sun.light_energy = (
			_sun.light_energy * lerpf(1.0, 0.32, _overcast_intensity)
			+ _lightning_value * 2.8
		)
	if _moon != null:
		_moon.light_energy *= lerpf(1.0, 0.55, _overcast_intensity)
