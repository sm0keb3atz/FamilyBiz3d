class_name WeaponDefinition
extends Resource

@export var weapon_id: StringName
@export var display_name := "Weapon"
@export var visual_scene: PackedScene

@export_category("Store")
@export_multiline var description := ""
@export_range(0, 1000000, 1) var purchase_price := 0
@export_range(1, 9999, 1) var ammo_bundle_amount := 30
@export_range(0, 1000000, 1) var ammo_bundle_price := 100

@export_category("Carry Weight")
@export_range(0, 10000, 1) var carry_weight_grams := 0
@export_range(0, 10000, 1) var sights_weight_grams := 10
@export_range(0, 10000, 1) var laser_weight_grams := 10
@export_range(0, 10000, 1) var switch_weight_grams := 5
@export_range(0, 10000, 1) var extended_weight_grams := 25
@export_range(0, 10000, 1) var drum_weight_grams := 50

@export_category("Combat")
@export_range(0.0, 1000.0, 0.1) var damage := 10.0
@export_range(0.01, 5.0, 0.01) var fire_interval := 0.25
@export_range(0.01, 5.0, 0.01) var full_auto_fire_interval := 0.06
@export_range(0.01, 10.0, 0.01) var reload_duration := 1.5
@export_range(1, 999, 1) var magazine_capacity := 10
@export_range(1, 999, 1) var extended_magazine_capacity := 10
@export_range(1, 999, 1) var drum_magazine_capacity := 10
@export_range(0, 9999, 1) var starting_reserve_ammo := 30
@export_range(0.1, 1000.0, 0.1) var max_range := 50.0
@export var supports_full_auto := false

@export_category("Presentation")
@export var gunshot_sound: AudioStream
@export_range(0.1, 10.0, 0.1) var sights_aim_distance := 0.75
@export var carry_animation: StringName
@export var aim_animation := &"PistolAim"
@export var fire_animation := &"PistolShoot"
@export var reload_animation := &"Pistol_Reload"
@export_range(0.1, 5.0, 0.05) var muzzle_flash_scale := 1.0


func get_capacity_for_magazine_type(magazine_type: int) -> int:
	match magazine_type:
		1:
			return extended_magazine_capacity
		2:
			return drum_magazine_capacity
		_:
			return magazine_capacity


func get_rounds_per_second() -> float:
	return 1.0 / maxf(fire_interval, 0.01)


func get_attachment_weight_grams(attachment_id: StringName) -> int:
	match attachment_id:
		&"sights":
			return sights_weight_grams
		&"laser":
			return laser_weight_grams
		&"switch":
			return switch_weight_grams
		&"extended":
			return extended_weight_grams
		&"drum":
			return drum_weight_grams
		_:
			return 0


func get_carry_weight_grams(attachment_state: Dictionary = {}) -> int:
	var total := carry_weight_grams
	for attachment_id in [&"sights", &"laser", &"switch"]:
		if bool(attachment_state.get(String(attachment_id), false)):
			total += get_attachment_weight_grams(attachment_id)
	match int(attachment_state.get("magazine_type", 0)):
		1:
			total += extended_weight_grams
		2:
			total += drum_weight_grams
	return total
