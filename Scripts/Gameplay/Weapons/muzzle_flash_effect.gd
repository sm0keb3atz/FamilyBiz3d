class_name MuzzleFlashEffect
extends Node3D

@export_range(0.01, 0.2, 0.005) var light_duration := 0.065
@export_range(0.0, 16.0, 0.1) var light_energy_min := 5.5
@export_range(0.0, 16.0, 0.1) var light_energy_max := 7.5

@onready var _particles := $MuzzlePlanes as GPUParticles3D
@onready var _light := $FlashLight as OmniLight3D

var _light_time_remaining := 0.0
var _peak_light_energy := 0.0
var _particle_base_scale := Vector3.ONE


func _ready() -> void:
	_particle_base_scale = _particles.scale
	_light.visible = false
	set_process(false)


func play_flash(energy_multiplier := 1.0) -> void:
	rotation.z = randf_range(0.0, TAU)
	var scale_variation := randf_range(0.88, 1.12)
	_particles.scale = _particle_base_scale * scale_variation
	_particles.restart()
	_peak_light_energy = (
		randf_range(light_energy_min, light_energy_max)
		* maxf(energy_multiplier, 0.0)
	)
	_light.light_energy = _peak_light_energy
	_light.visible = true
	_light_time_remaining = light_duration
	set_process(true)


func _process(delta: float) -> void:
	_light_time_remaining = maxf(_light_time_remaining - delta, 0.0)
	if _light_time_remaining <= 0.0:
		_light.visible = false
		set_process(false)
		return
	var life_ratio := _light_time_remaining / light_duration
	_light.light_energy = _peak_light_energy * life_ratio * life_ratio
