class_name WeaponDefinition
extends Resource

@export var weapon_id: StringName
@export var display_name := "Weapon"

@export_category("Combat")
@export_range(0.0, 1000.0, 0.1) var damage := 10.0
@export_range(0.01, 5.0, 0.01) var fire_interval := 0.25
@export_range(0.01, 10.0, 0.01) var reload_duration := 1.5
@export_range(1, 999, 1) var magazine_capacity := 10
@export_range(0, 9999, 1) var starting_reserve_ammo := 30
@export_range(0.1, 1000.0, 0.1) var max_range := 50.0
