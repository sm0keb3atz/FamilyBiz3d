class_name ConsumableDefinition
extends Resource

@export var item_id: StringName
@export var display_name := "Supply"
@export_multiline var description := ""
@export_range(0, 1000000, 1) var price := 0
@export_range(1, 10000, 1) var weight_grams := 1
@export_range(0.0, 1000.0, 1.0) var health_restore := 0.0
@export_range(0.0, 1000.0, 1.0) var stamina_restore := 0.0
@export_range(1.0, 10.0, 0.1) var health_regen_multiplier := 1.0
@export_range(1.0, 10.0, 0.1) var stamina_regen_multiplier := 1.0
@export_range(0, 1440, 1) var duration_game_minutes := 0
@export_range(0.0, 50.0, 0.1) var vehicle_fuel_gallons := 0.0
@export var icon: Texture2D


func has_timed_effect() -> bool:
	return duration_game_minutes > 0 and (
		health_regen_multiplier > 1.0 or stamina_regen_multiplier > 1.0
	)


func is_valid() -> bool:
	return (
		not item_id.is_empty()
		and not display_name.strip_edges().is_empty()
		and price >= 0
		and weight_grams > 0
		and (
			health_restore > 0.0
			or stamina_restore > 0.0
			or vehicle_fuel_gallons > 0.0
			or has_timed_effect()
		)
	)
