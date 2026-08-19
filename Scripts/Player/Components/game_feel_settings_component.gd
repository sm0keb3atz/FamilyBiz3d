class_name GameFeelSettingsComponent
extends Node

signal settings_changed

const SETTINGS_PATH := "user://game_feel.cfg"
const SETTINGS_SECTION := "game_feel"

var movement_bob_intensity := 1.0
var camera_shake_intensity := 1.0
var damage_flash_intensity := 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		settings_changed.emit()
		return
	movement_bob_intensity = _read_intensity(
		config, "movement_bob", movement_bob_intensity
	)
	camera_shake_intensity = _read_intensity(
		config, "camera_shake", camera_shake_intensity
	)
	damage_flash_intensity = _read_intensity(
		config, "damage_flash", damage_flash_intensity
	)
	settings_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "movement_bob", movement_bob_intensity)
	config.set_value(SETTINGS_SECTION, "camera_shake", camera_shake_intensity)
	config.set_value(SETTINGS_SECTION, "damage_flash", damage_flash_intensity)
	config.save(SETTINGS_PATH)


func set_movement_bob_intensity(value: float) -> void:
	var next_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(next_value, movement_bob_intensity):
		return
	movement_bob_intensity = next_value
	settings_changed.emit()


func set_camera_shake_intensity(value: float) -> void:
	var next_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(next_value, camera_shake_intensity):
		return
	camera_shake_intensity = next_value
	settings_changed.emit()


func set_damage_flash_intensity(value: float) -> void:
	var next_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(next_value, damage_flash_intensity):
		return
	damage_flash_intensity = next_value
	settings_changed.emit()


func _read_intensity(
	config: ConfigFile,
	key: String,
	fallback: float
) -> float:
	return clampf(
		float(config.get_value(SETTINGS_SECTION, key, fallback)),
		0.0,
		1.0
	)
