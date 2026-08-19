class_name WeatherSystem
extends Node3D

signal weather_changed(previous_weather: StringName, current_weather: StringName)
signal lightning_struck(strength: float, suggested_thunder_delay: float)

const CLEAR := &"clear"
const RAIN := &"rain"
const HEAVY_RAIN := &"heavy_rain"
const THUNDERSTORM := &"thunderstorm"
const VALID_WEATHER := [CLEAR, RAIN, HEAVY_RAIN, THUNDERSTORM]
const SILENT_AMBIENCE_DB := -80.0
const DEFAULT_VISUAL_PROFILE := preload(
	"res://Assets/VFX/GrittyCinematicWorldVisualProfile.tres"
)

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
@export var visual_profile: WorldVisualProfile = DEFAULT_VISUAL_PROFILE

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

@export_category("Ambience Audio")
@export_range(-50.0, 0.0, 0.5) var city_ambience_volume_db := -34.0
@export_range(-50.0, 0.0, 0.5) var rain_ambience_volume_db := -31.0
@export_range(-50.0, 0.0, 0.5) var storm_ambience_volume_db := -33.0
@export_range(1.0, 40.0, 0.5) var ambience_fade_db_per_second := 12.0
@export_range(0.0, 1.0, 0.05) var sheltered_weather_audio_mix := 0.25

@export_category("Shelter Detection")
@export_flags_3d_physics var shelter_collision_mask := 0xFFFFFFFF
@export_range(4.0, 40.0, 0.5) var shelter_check_height := 24.0
@export_range(0.05, 1.0, 0.05) var shelter_check_interval := 0.2
@export_range(1.0, 20.0, 0.5) var shelter_fade_speed := 8.0

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
@onready var _city_ambience := $CityAmbience as AudioStreamPlayer
@onready var _rain_ambience := $RainAmbience as AudioStreamPlayer
@onready var _storm_ambience := $StormAmbience as AudioStreamPlayer

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
var _shelter_visual_scale := 1.0
var _shelter_check_elapsed := 0.0
var _is_sheltered := false
var _roof_meshes: Array[MeshInstance3D] = []


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
	_start_ambience_players()
	call_deferred("_cache_roof_meshes")


func _process(delta: float) -> void:
	_follow_player()
	_update_shelter(delta)
	_update_random_weather(delta)
	_update_weather_blend(delta)
	_update_ambience(delta)
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


func is_player_sheltered() -> bool:
	return _is_sheltered


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
	var local_rain := _get_local_rain_intensity()
	var precipitation_visible := _shelter_visual_scale > 0.02
	_rain_streaks.visible = precipitation_visible
	_near_rain.visible = precipitation_visible
	_ground_mist.visible = precipitation_visible
	_rain_splashes.visible = precipitation_visible
	_rain_streaks.emitting = local_rain > 0.01
	_near_rain.emitting = local_rain > 0.16
	_ground_mist.emitting = local_rain > 0.2
	_rain_splashes.emitting = local_rain > 0.08
	_rain_streaks.amount_ratio = clampf(local_rain, 0.0, 1.0)
	_near_rain.amount_ratio = clampf(
		(local_rain - 0.15) / 0.85,
		0.0,
		1.0
	) * 0.72
	_ground_mist.amount_ratio = clampf(
		(local_rain - 0.18) / 0.82,
		0.0,
		1.0
	) * 0.28
	_rain_splashes.amount_ratio = clampf(local_rain * 0.38, 0.0, 1.0)


func _start_ambience_players() -> void:
	_set_stream_looping(_city_ambience.stream)
	_set_stream_looping(_rain_ambience.stream)
	_set_stream_looping(_storm_ambience.stream)
	_city_ambience.volume_db = city_ambience_volume_db
	_rain_ambience.volume_db = SILENT_AMBIENCE_DB
	_storm_ambience.volume_db = SILENT_AMBIENCE_DB
	_city_ambience.play()
	_rain_ambience.play()
	_storm_ambience.play()


func _set_stream_looping(audio_stream: AudioStream) -> void:
	if audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = true
	elif audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = true


func _update_ambience(delta: float) -> void:
	var storm_mix := (
		_overcast_intensity
		if current_weather == THUNDERSTORM
		else 0.0
	)
	var weather_outdoor_mix := lerpf(
		sheltered_weather_audio_mix,
		1.0,
		_shelter_visual_scale
	)
	# The storm recording already contains rain, so make room for it instead of
	# stacking both weather tracks at full volume.
	var rain_mix := (
		_rain_intensity
		* weather_outdoor_mix
		* lerpf(1.0, 0.55, storm_mix)
	)
	var storm_weather_mix := storm_mix * weather_outdoor_mix
	var city_weather_duck := lerpf(
		1.0,
		0.72,
		maxf(_rain_intensity, storm_mix)
	)
	_move_ambience_volume(
		_city_ambience,
		_volume_for_mix(city_ambience_volume_db, city_weather_duck),
		delta
	)
	_move_ambience_volume(
		_rain_ambience,
		_volume_for_mix(rain_ambience_volume_db, rain_mix),
		delta
	)
	_move_ambience_volume(
		_storm_ambience,
		_volume_for_mix(storm_ambience_volume_db, storm_weather_mix),
		delta
	)


func _volume_for_mix(base_volume_db: float, mix_amount: float) -> float:
	if mix_amount <= 0.001:
		return SILENT_AMBIENCE_DB
	return maxf(
		SILENT_AMBIENCE_DB,
		base_volume_db + linear_to_db(clampf(mix_amount, 0.0, 1.0))
	)


func _move_ambience_volume(
	player: AudioStreamPlayer,
	target_volume_db: float,
	delta: float
) -> void:
	player.volume_db = move_toward(
		player.volume_db,
		target_volume_db,
		delta * ambience_fade_db_per_second
	)


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


func _update_shelter(delta: float) -> void:
	_shelter_check_elapsed -= delta
	if _shelter_check_elapsed <= 0.0:
		_shelter_check_elapsed = shelter_check_interval
		_is_sheltered = _has_overhead_cover()
	var target_scale := 0.0 if _is_sheltered else 1.0
	_shelter_visual_scale = move_toward(
		_shelter_visual_scale,
		target_scale,
		delta * shelter_fade_speed
	)


func _has_overhead_cover() -> bool:
	if not is_instance_valid(_player):
		return false
	var world_3d := _player.get_world_3d()
	if world_3d == null:
		return false
	var excluded_rids: Array[RID] = []
	if _player is CollisionObject3D:
		excluded_rids.append((_player as CollisionObject3D).get_rid())
	var covered_rays := 0
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(0.45, 0.0, 0.0),
		Vector3(-0.45, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.45),
		Vector3(0.0, 0.0, -0.45),
	]
	for offset in offsets:
		var origin := _player.global_position + offset + Vector3.UP * 1.55
		var query := PhysicsRayQueryParameters3D.create(
			origin,
			origin + Vector3.UP * shelter_check_height,
			shelter_collision_mask,
			excluded_rids
		)
		query.collide_with_areas = false
		if not world_3d.direct_space_state.intersect_ray(query).is_empty():
			covered_rays += 1
			if covered_rays >= 2:
				return true
	return _has_cached_roof_cover()


func _cache_roof_meshes() -> void:
	_roof_meshes.clear()
	var scene_root := get_tree().current_scene
	if scene_root != null:
		_collect_roof_meshes(scene_root)


func _collect_roof_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_path := mesh_instance.mesh.resource_path.to_lower()
			if (
				"/buildingtileset/sm_roof" in mesh_path
				or "/buildingtileset/sm_shoptop" in mesh_path
			):
				_roof_meshes.append(mesh_instance)
	for child in node.get_children():
		_collect_roof_meshes(child)


func _has_cached_roof_cover() -> bool:
	var player_position := _player.global_position
	for roof in _roof_meshes:
		if not is_instance_valid(roof) or roof.mesh == null:
			continue
		var world_bounds: AABB = roof.global_transform * roof.mesh.get_aabb()
		var bounds_end := world_bounds.end
		var roof_bottom := world_bounds.position.y
		if (
			player_position.x >= world_bounds.position.x
			and player_position.x <= bounds_end.x
			and player_position.z >= world_bounds.position.z
			and player_position.z <= bounds_end.z
			and roof_bottom > player_position.y + 1.4
			and roof_bottom <= player_position.y + shelter_check_height
		):
			return true
	return false


func _get_local_rain_intensity() -> float:
	return _rain_intensity * _shelter_visual_scale


func _resolve_environment() -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	_environment = _world_environment.environment
	if _environment.sky != null:
		_sky_material = _environment.sky.sky_material as ShaderMaterial


func _apply_visuals() -> void:
	if visual_profile == null:
		return
	if _sky_material != null:
		_sky_material.set_shader_parameter("weather_overcast", _overcast_intensity)
		_sky_material.set_shader_parameter("weather_flash", _lightning_value)
	if _screen_material != null:
		_screen_material.set_shader_parameter(
			"rain_intensity",
			_get_local_rain_intensity()
		)
		_screen_material.set_shader_parameter("lightning", _lightning_value)
	if _environment != null:
		var base_fog_color: Color = _environment.get_meta(
			WorldVisualProfile.META_BASE_FOG_COLOR,
			visual_profile.day_fog_color
		)
		var base_fog_energy := float(_environment.get_meta(
			WorldVisualProfile.META_BASE_FOG_ENERGY,
			visual_profile.day_fog_light_energy
		))
		var base_fog_density := float(_environment.get_meta(
			WorldVisualProfile.META_BASE_FOG_DENSITY,
			visual_profile.clear_fog_density
		))
		var base_fog_aerial := float(_environment.get_meta(
			WorldVisualProfile.META_BASE_FOG_AERIAL,
			visual_profile.clear_fog_aerial_perspective
		))
		var base_fog_sun_scatter := float(_environment.get_meta(
			WorldVisualProfile.META_BASE_FOG_SUN_SCATTER,
			visual_profile.clear_fog_sun_scatter
		))
		var base_volumetric_density := float(_environment.get_meta(
			WorldVisualProfile.META_BASE_VOLUMETRIC_FOG_DENSITY,
			visual_profile.day_volumetric_fog_density
		))
		var base_ambient_color: Color = _environment.get_meta(
			WorldVisualProfile.META_BASE_AMBIENT_COLOR,
			visual_profile.day_ambient_color
		)
		var base_ambient_energy := float(_environment.get_meta(
			WorldVisualProfile.META_BASE_AMBIENT_ENERGY,
			visual_profile.day_ambient_energy
		))
		var storm_fog := base_fog_color.lerp(
			visual_profile.storm_fog_color,
			_overcast_intensity * 0.74
		)
		_environment.fog_enabled = true
		_environment.fog_light_color = storm_fog.lerp(
			visual_profile.lightning_fog_color,
			_lightning_value
		)
		_environment.fog_light_energy = (
			base_fog_energy * lerpf(1.0, 0.82, _overcast_intensity)
			+ _lightning_value * 0.65
		)
		_environment.fog_density = (
			base_fog_density
			+ _fog_intensity * visual_profile.weather_fog_density
		)
		_environment.fog_aerial_perspective = clampf(
			base_fog_aerial
			+ _fog_intensity * visual_profile.weather_fog_aerial_perspective,
			0.0,
			1.0
		)
		_environment.fog_sun_scatter = (
			base_fog_sun_scatter * lerpf(1.0, 0.15, _overcast_intensity)
		)
		_environment.volumetric_fog_density = (
			base_volumetric_density
			+ _fog_intensity * visual_profile.weather_volumetric_fog_density
		)
		_environment.ambient_light_color = base_ambient_color.lerp(
			visual_profile.overcast_ambient_color,
			_overcast_intensity * 0.72
		)
		_environment.ambient_light_energy = (
			base_ambient_energy * lerpf(
				1.0,
				visual_profile.overcast_ambient_multiplier,
				_overcast_intensity
			)
			+ _lightning_value * 0.75
		)
	if _sun != null:
		var base_sun_color: Color = _sun.get_meta(
			WorldVisualProfile.META_BASE_SUN_COLOR,
			visual_profile.day_sun_color
		)
		var base_sun_energy := float(_sun.get_meta(
			WorldVisualProfile.META_BASE_SUN_ENERGY,
			visual_profile.day_sun_energy
		))
		_sun.light_color = base_sun_color.lerp(
			visual_profile.overcast_sun_color,
			_overcast_intensity * 0.78
		)
		_sun.light_energy = (
			base_sun_energy * lerpf(
				1.0,
				visual_profile.overcast_sun_multiplier,
				_overcast_intensity
			)
			+ _lightning_value * 2.8
		)
	if _moon != null:
		var base_moon_energy := float(_moon.get_meta(
			WorldVisualProfile.META_BASE_MOON_ENERGY,
			visual_profile.moon_energy
		))
		_moon.light_energy = base_moon_energy * lerpf(
			1.0,
			0.55,
			_overcast_intensity
		)
