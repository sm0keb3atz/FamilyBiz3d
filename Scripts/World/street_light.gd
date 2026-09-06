class_name StreetLight
extends Node3D

const DEFAULT_VISUAL_PROFILE := preload(
	"res://Assets/VFX/GrittyCinematicWorldVisualProfile.tres"
)

@export var night_lighting_path := NodePath("NightLighting")
@export var visual_profile: WorldVisualProfile = DEFAULT_VISUAL_PROFILE

@onready var _night_lighting := get_node_or_null(night_lighting_path) as Node3D
@onready var _bulb_glow := get_node_or_null(
	NodePath("NightLighting/BulbGlow")
) as GeometryInstance3D
@onready var _key_light := get_node_or_null(
	NodePath("NightLighting/KeyLight")
) as Light3D
@onready var _fill_light := get_node_or_null(
	NodePath("NightLighting/FillLight")
) as Light3D

var _world_time: WorldTimeComponent
var _night_blend := 0.0
var _target_night_blend := 0.0
var _key_energy := 0.0
var _fill_energy := 0.0


func _ready() -> void:
	_key_energy = _key_light.light_energy if _key_light != null else 0.0
	_fill_energy = _fill_light.light_energy if _fill_light != null else 0.0
	if _night_lighting != null:
		_night_lighting.visible = true
	_apply_night_blend()
	set_process(false)
	call_deferred("_connect_world_time")


func _process(delta: float) -> void:
	var fade_seconds := (
		visual_profile.streetlight_fade_seconds
		if visual_profile != null
		else 1.5
	)
	_night_blend = move_toward(
		_night_blend,
		_target_night_blend,
		delta / maxf(fade_seconds, 0.1)
	)
	_apply_night_blend()
	if is_equal_approx(_night_blend, _target_night_blend):
		set_process(false)


func _connect_world_time() -> void:
	_world_time = get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if _world_time == null:
		push_warning("StreetLight could not find the WorldTimeComponent.")
		return
	if not _world_time.night_state_changed.is_connected(_on_night_state_changed):
		_world_time.night_state_changed.connect(_on_night_state_changed)
	_update_light(_world_time.is_nighttime())


func _exit_tree() -> void:
	if (
		_world_time != null
		and _world_time.night_state_changed.is_connected(_on_night_state_changed)
	):
		_world_time.night_state_changed.disconnect(_on_night_state_changed)


func _on_night_state_changed(is_night: bool) -> void:
	_update_light(is_night)


func _update_light(is_night: bool) -> void:
	_target_night_blend = 1.0 if is_night else 0.0
	if visual_profile != null and not visual_profile.streetlight_fade_enabled:
		_night_blend = _target_night_blend
		_apply_night_blend()
		set_process(false)
		return
	if _night_lighting != null:
		_night_lighting.visible = true
	set_process(not is_equal_approx(_night_blend, _target_night_blend))
	_apply_night_blend()


func _apply_night_blend() -> void:
	var eased_blend := smoothstep(0.0, 1.0, _night_blend)
	if _bulb_glow != null:
		_bulb_glow.transparency = 1.0 - eased_blend
	if _key_light != null:
		_key_light.light_energy = _key_energy * eased_blend
	if _fill_light != null:
		_fill_light.light_energy = _fill_energy * eased_blend
	if _night_lighting != null:
		_night_lighting.visible = eased_blend > 0.001 or _target_night_blend > 0.0
