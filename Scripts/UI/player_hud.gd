class_name PlayerHUD
extends CanvasLayer

@export var stats_component_path := NodePath("../Components/StatsComponent")
@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var weapon_component_path := NodePath("../Components/WeaponComponent")
@export_range(0.0, 1000.0, 1.0) var debug_damage_amount := 25.0
@export_range(0.05, 1.0, 0.01) var hit_marker_duration := 0.18

@onready var health_bar := %HealthBar as ProgressBar
@onready var health_value := %HealthValue as Label
@onready var stamina_bar := %StaminaBar as ProgressBar
@onready var stamina_value := %StaminaValue as Label
@onready var level_label := %LevelLabel as Label
@onready var experience_label := %ExperienceLabel as Label
@onready var state_label := %StateLabel as Label
@onready var dirty_cash_label := %DirtyCashLabel as Label
@onready var clean_cash_label := %CleanCashLabel as Label
@onready var interaction_prompt := %InteractionPrompt as Label
@onready var feedback_label := %FeedbackLabel as Label
@onready var feedback_timer := %FeedbackTimer as Timer
@onready var crosshair := %Crosshair as Label
@onready var hit_marker := %HitMarker as Label
@onready var weapon_name_label := %WeaponNameLabel as Label
@onready var ammo_label := %AmmoLabel as Label
@onready var reload_label := %ReloadLabel as Label
@onready var reputation_title := %ReputationTitle as Label
@onready var reputation_bar := %ReputationBar as ProgressBar
@onready var reputation_value := %ReputationValue as Label
@onready var heat_title := %HeatTitle as Label
@onready var heat_bar := %HeatBar as ProgressBar
@onready var heat_value := %HeatValue as Label
@onready var stats := get_node(stats_component_path) as PlayerStatsComponent
@onready var wallet := (
	get_node(wallet_component_path) as PlayerWalletComponent
)
@onready var weapon := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)

var _hit_marker_remaining := 0.0


func _ready() -> void:
	reputation_bar.max_value = 100.0
	heat_bar.max_value = 100.0
	stats.health_changed.connect(_on_health_changed)
	stats.stamina_changed.connect(_on_stamina_changed)
	stats.experience_changed.connect(_on_experience_changed)
	stats.level_changed.connect(_on_level_changed)
	stats.health_depleted.connect(_on_health_depleted)
	wallet.money_changed.connect(_on_money_changed)
	weapon.weapon_changed.connect(_on_weapon_changed)
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.hit_confirmed.connect(_on_hit_confirmed)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_completed.connect(_on_reload_completed)
	feedback_timer.timeout.connect(_on_feedback_timeout)
	_refresh_all()


func _process(delta: float) -> void:
	_refresh_territory()
	crosshair.visible = (
		weapon.is_aiming()
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)
	if _hit_marker_remaining <= 0.0:
		return
	_hit_marker_remaining = maxf(_hit_marker_remaining - delta, 0.0)
	hit_marker.modulate.a = _hit_marker_remaining / hit_marker_duration
	if is_zero_approx(_hit_marker_remaining):
		hit_marker.visible = false


func _refresh_territory() -> void:
	var player := get_parent() as CharacterBody3D
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(), player.global_position
	)
	if boundary == null or boundary.stats == null:
		reputation_title.text = "OUTSIDE TERRITORY — REPUTATION"
		heat_title.text = "OUTSIDE TERRITORY — HEAT"
		reputation_bar.value = 0.0
		heat_bar.value = 0.0
		reputation_value.text = "—"
		heat_value.text = "—"
		return
	reputation_title.text = "%s — REPUTATION" % boundary.display_name.to_upper()
	heat_title.text = "%s — HEAT" % boundary.display_name.to_upper()
	reputation_bar.value = boundary.stats.reputation
	heat_bar.value = boundary.stats.heat
	reputation_value.text = "%d / 100" % roundi(boundary.stats.reputation)
	heat_value.text = "%d / 100" % roundi(boundary.stats.heat)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_1
	):
		stats.take_damage(debug_damage_amount)
		get_viewport().set_input_as_handled()


func _refresh_all() -> void:
	_on_health_changed(stats.health, stats.get_max_health())
	_on_stamina_changed(stats.stamina, stats.get_max_stamina())
	_on_experience_changed(
		stats.experience,
		stats.get_experience_required_for_next_level()
	)
	_on_level_changed(stats.level)
	_on_money_changed(wallet.dirty_cash, wallet.clean_cash)
	state_label.visible = is_zero_approx(stats.health)
	interaction_prompt.visible = false
	feedback_label.visible = false
	hit_marker.visible = false
	_on_weapon_changed(weapon.get_equipped_weapon())


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_value.text = "%d / %d" % [roundi(current), roundi(maximum)]
	if current > 0.0:
		state_label.visible = false


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_value.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_experience_changed(current: float, required: float) -> void:
	experience_label.text = "EXP  %d / %d" % [
		roundi(current),
		roundi(required),
	]


func _on_level_changed(current: int) -> void:
	level_label.text = "LEVEL %d" % current


func _on_health_depleted() -> void:
	state_label.visible = true


func set_interaction_prompt(prompt: String) -> void:
	interaction_prompt.text = prompt
	interaction_prompt.visible = not prompt.is_empty()


func show_feedback(message: String, duration := 2.5) -> void:
	feedback_label.text = message
	feedback_label.visible = not message.is_empty()
	feedback_timer.start(maxf(duration, 0.1))


func _on_money_changed(dirty_cash: int, clean_cash: int) -> void:
	dirty_cash_label.text = "DIRTY  $%d" % dirty_cash
	clean_cash_label.text = "CLEAN  $%d" % clean_cash


func _on_feedback_timeout() -> void:
	feedback_label.visible = false


func _on_weapon_changed(definition: WeaponDefinition) -> void:
	reload_label.visible = false
	if definition == null:
		weapon_name_label.text = "UNARMED"
		ammo_label.text = "--"
		return

	weapon_name_label.text = definition.display_name
	_on_ammo_changed(weapon.get_magazine_ammo(), weapon.get_reserve_ammo())


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	if weapon.get_equipped_weapon() == null:
		ammo_label.text = "--"
		return
	ammo_label.text = "%d / %d" % [magazine, reserve]


func _on_reload_started() -> void:
	reload_label.visible = true


func _on_reload_completed() -> void:
	reload_label.visible = false


func _on_hit_confirmed(fatal_hit: bool) -> void:
	_hit_marker_remaining = hit_marker_duration
	hit_marker.modulate = (
		Color(1.0, 0.36, 0.22, 1.0)
		if fatal_hit
		else Color.WHITE
	)
	hit_marker.visible = true
