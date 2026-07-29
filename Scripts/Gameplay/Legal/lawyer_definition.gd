class_name LawyerDefinition
extends Resource

@export var lawyer_id: StringName = &""
@export var display_name: String = ""
@export_range(1, 4, 1) var level: int = 1
@export var retainer_clean: int = 5000
@export var daily_fee_clean: int = 500
@export var defense_min: int = 50
@export var defense_max: int = 300
@export var laundering_daily_limit: int = 10000
@export_range(0.0, 1.0, 0.01) var laundering_cut: float = 0.25
@export var heat_daily_limit: int = 10
@export var heat_cost_per_point: int = 500
