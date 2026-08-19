class_name PlayerScreenFeedbackComponent
extends CanvasLayer

const DAMAGE_SHADER := preload(
	"res://Assets/UI/Shaders/player_damage_overlay.gdshader"
)

@export var camera_path := NodePath("../CameraPivot/SpringArm3D/Camera3D")
@export var stats_component_path := NodePath("../Components/StatsComponent")
@export var health_component_path := NodePath("../Components/HealthComponent")
@export var settings_component_path := NodePath("../Components/GameFeelSettingsComponent")
@export_range(0.05, 1.5, 0.01) var hit_fade_time := 0.46
@export_range(0.05, 1.0, 0.01) var low_health_threshold := 0.30

@onready var camera := get_node(camera_path) as Camera3D
@onready var stats := get_node(stats_component_path) as PlayerStatsComponent
@onready var health := get_node(health_component_path) as PlayerHealthComponent
@onready var settings := get_node(
	settings_component_path
) as GameFeelSettingsComponent

var _overlay: ColorRect
var _material: ShaderMaterial
var _hit_intensity := 0.0
var _low_health_intensity := 0.0
var _hit_direction := Vector2(0.0, -1.0)


func _ready() -> void:
	layer = 24
	_build_overlay()
	stats.health_changed.connect(_on_health_changed)
	health.respawn_started.connect(clear_feedback)
	health.respawn_completed.connect(clear_feedback)
	settings.settings_changed.connect(_sync_settings)
	_on_health_changed(stats.health, stats.get_max_health())
	_sync_settings()


func _process(delta: float) -> void:
	_hit_intensity = move_toward(
		_hit_intensity,
		0.0,
		delta / maxf(hit_fade_time, 0.01)
	)
	_material.set_shader_parameter("hit_intensity", _hit_intensity)


func show_damage(
	world_hit_direction: Vector3,
	fatal := false,
	damage_ratio := 0.0
) -> void:
	var source_direction := -world_hit_direction.normalized()
	if source_direction.is_zero_approx():
		source_direction = -camera.global_basis.z
	var local_direction := camera.global_basis.inverse() * source_direction
	var screen_direction := Vector2(local_direction.x, -local_direction.y)
	if screen_direction.length_squared() < 0.001:
		screen_direction = Vector2(0.0, -1.0 if local_direction.z < 0.0 else 1.0)
	_hit_direction = screen_direction.normalized()
	var strength := clampf(0.48 + damage_ratio * 1.8, 0.48, 0.88)
	if fatal:
		strength = 1.0
	_hit_intensity = minf(maxf(_hit_intensity, strength) + 0.12, 1.0)
	_material.set_shader_parameter("hit_direction", _hit_direction)
	_material.set_shader_parameter("hit_intensity", _hit_intensity)


func clear_feedback() -> void:
	_hit_intensity = 0.0
	_low_health_intensity = 0.0
	if _material != null:
		_material.set_shader_parameter("hit_intensity", 0.0)
		_material.set_shader_parameter("low_health", 0.0)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "DirectionalDamageOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = DAMAGE_SHADER
	_overlay.material = _material
	add_child(_overlay)


func _on_health_changed(current: float, maximum: float) -> void:
	var ratio := current / maxf(maximum, 0.01)
	_low_health_intensity = clampf(
		(low_health_threshold - ratio) / maxf(low_health_threshold, 0.01),
		0.0,
		1.0
	)
	if _material != null:
		_material.set_shader_parameter("low_health", _low_health_intensity)


func _sync_settings() -> void:
	if _material != null:
		_material.set_shader_parameter(
			"effect_intensity",
			settings.damage_flash_intensity
		)
