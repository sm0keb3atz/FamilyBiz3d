class_name PlayerStatsComponent
extends Node

signal health_changed(current: float, maximum: float)
signal health_depleted
signal stamina_changed(current: float, maximum: float)
signal experience_changed(current: float, required: float)
signal level_changed(current: int)
signal skill_points_changed(current: int)
signal strength_changed(current: int)
signal aura_changed(current: int)

@export var config: PlayerStatsConfig
@export var appearance_component_path := NodePath("../AppearanceComponent")

var health: float:
	get:
		return _health
var stamina: float:
	get:
		return _stamina
var experience: float:
	get:
		return _experience
var level: int:
	get:
		return _level
var skill_points: int:
	get:
		return _skill_points
var strength: int:
	get:
		return _strength
var aura: int:
	get:
		return _aura

var _health := 0.0
var _stamina := 0.0
var _experience := 0.0
var _level := 1
var _skill_points := 0
var _strength := 1
var _aura := 0
var _time_since_damage := 0.0
var _stamina_consumed_this_frame := false


func _ready() -> void:
	if config == null:
		config = PlayerStatsConfig.new()

	_level = maxi(config.starting_level, 1)
	_strength = maxi(config.starting_strength, 1)
	_skill_points = maxi(config.starting_skill_points, 0)
	_experience = maxf(config.starting_experience, 0.0)
	_health = get_max_health()
	_stamina = get_max_stamina()
	_time_since_damage = config.health_regen_delay
	_process_level_ups()
	_emit_all_stats()
	call_deferred("_connect_appearance")


func _connect_appearance() -> void:
	var appearance := get_node_or_null(appearance_component_path) as PlayerAppearanceComponent
	if appearance == null:
		return
	_aura = appearance.get_current_aura()
	appearance.aura_changed.connect(_on_appearance_aura_changed)
	aura_changed.emit(_aura)


func _on_appearance_aura_changed(current: int) -> void:
	_aura = current
	aura_changed.emit(_aura)


func _process(delta: float) -> void:
	_time_since_damage += delta

	if (
		_health > 0.0
		and
		_health < get_max_health()
		and _time_since_damage >= config.health_regen_delay
	):
		_set_health(_health + config.health_regen_per_second * delta)

	if not _stamina_consumed_this_frame and _stamina < get_max_stamina():
		_set_stamina(_stamina + config.stamina_regen_per_second * delta)

	_stamina_consumed_this_frame = false


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	var was_alive := _health > 0.0
	_time_since_damage = 0.0
	_set_health(_health - amount)

	if was_alive and is_zero_approx(_health):
		health_depleted.emit()


func heal(amount: float) -> void:
	if amount > 0.0:
		_set_health(_health + amount)


func consume_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if amount > _stamina:
		return false

	_stamina_consumed_this_frame = true
	_set_stamina(_stamina - amount)
	return true


func restore_stamina(amount: float) -> void:
	if amount > 0.0:
		_set_stamina(_stamina + amount)


func add_experience(amount: float) -> void:
	if amount <= 0.0:
		return

	_experience += amount
	_process_level_ups()
	experience_changed.emit(
		_experience,
		get_experience_required_for_next_level()
	)


func purchase_strength() -> bool:
	if _skill_points <= 0:
		return false

	var previous_max_health := get_max_health()
	var previous_max_stamina := get_max_stamina()
	_skill_points -= 1
	_strength += 1
	_increase_current_pools(previous_max_health, previous_max_stamina)
	skill_points_changed.emit(_skill_points)
	strength_changed.emit(_strength)
	aura_changed.emit(_aura)
	return true


func get_experience_required_for_next_level() -> float:
	return config.experience_per_level * float(_level)


func get_max_health() -> float:
	return (
		config.base_max_health
		+ float(_strength - 1) * config.health_per_strength
	)


func get_max_stamina() -> float:
	return (
		config.base_max_stamina
		+ float(_strength - 1) * config.stamina_per_strength
		+ float(_level - 1) * config.stamina_per_level
	)


func export_save_data() -> Dictionary:
	return {
		"health": _health,
		"stamina": _stamina,
		"experience": _experience,
		"level": _level,
		"skill_points": _skill_points,
		"strength": _strength,
	}


func import_save_data(data: Dictionary) -> void:
	_level = maxi(int(data.get("level", config.starting_level)), 1)
	_strength = maxi(int(data.get("strength", config.starting_strength)), 1)
	_skill_points = maxi(int(data.get("skill_points", 0)), 0)
	_experience = maxf(float(data.get("experience", 0.0)), 0.0)
	_health = clampf(
		float(data.get("health", get_max_health())), 0.0, get_max_health()
	)
	_stamina = clampf(
		float(data.get("stamina", get_max_stamina())), 0.0, get_max_stamina()
	)
	_time_since_damage = config.health_regen_delay
	_emit_all_stats()


func _process_level_ups() -> void:
	while _experience >= get_experience_required_for_next_level():
		var previous_max_health := get_max_health()
		var previous_max_stamina := get_max_stamina()
		_experience -= get_experience_required_for_next_level()
		_level += 1
		_skill_points += config.skill_points_per_level
		_increase_current_pools(previous_max_health, previous_max_stamina)
		level_changed.emit(_level)
		skill_points_changed.emit(_skill_points)


func _increase_current_pools(
	previous_max_health: float,
	previous_max_stamina: float
) -> void:
	_set_health(_health + get_max_health() - previous_max_health)
	_set_stamina(_stamina + get_max_stamina() - previous_max_stamina)


func _set_health(value: float) -> void:
	var next_health := clampf(value, 0.0, get_max_health())
	if is_equal_approx(next_health, _health):
		return

	_health = next_health
	health_changed.emit(_health, get_max_health())


func _set_stamina(value: float) -> void:
	var next_stamina := clampf(value, 0.0, get_max_stamina())
	if is_equal_approx(next_stamina, _stamina):
		return

	_stamina = next_stamina
	stamina_changed.emit(_stamina, get_max_stamina())


func _emit_all_stats() -> void:
	health_changed.emit(_health, get_max_health())
	stamina_changed.emit(_stamina, get_max_stamina())
	experience_changed.emit(
		_experience,
		get_experience_required_for_next_level()
	)
	level_changed.emit(_level)
	skill_points_changed.emit(_skill_points)
	strength_changed.emit(_strength)
