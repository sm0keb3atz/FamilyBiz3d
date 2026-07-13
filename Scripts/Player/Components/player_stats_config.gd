class_name PlayerStatsConfig
extends Resource

@export_category("Starting Values")
@export_range(1.0, 10000.0, 1.0) var base_max_health := 100.0
@export_range(1.0, 10000.0, 1.0) var base_max_stamina := 100.0
@export_range(1, 1000, 1) var starting_level := 1
@export_range(1, 1000, 1) var starting_strength := 1
@export_range(1, 10, 1) var starting_hustle := 1
@export_range(0.0, 1000000.0, 1.0) var starting_experience := 0.0
@export_range(0, 1000, 1) var starting_skill_points := 0

@export_category("Regeneration")
@export_range(0.0, 1000.0, 0.1) var health_regen_per_second := 1.0
@export_range(0.0, 60.0, 0.1) var health_regen_delay := 5.0
@export_range(0.0, 1000.0, 0.1) var stamina_regen_per_second := 15.0

@export_category("Progression")
@export_range(1.0, 100000.0, 1.0) var experience_per_level := 100.0
@export_range(0, 100, 1) var skill_points_per_level := 1
@export_range(0.0, 1000.0, 0.1) var health_per_strength := 10.0
@export_range(0.0, 1000.0, 0.1) var stamina_per_strength := 5.0
@export_range(0.0, 1000.0, 0.1) var stamina_per_level := 2.0
@export_range(1, 10, 1) var max_hustle := 10
@export_range(0.0, 1.0, 0.01) var sale_bonus_per_hustle := 0.05
@export_range(1, 10, 1) var base_solicitation_customer_limit := 2
@export_range(1, 20, 1) var max_solicitation_customer_limit := 6
