class_name PlayerStatsMenu
extends CanvasLayer

@export_category("Scene References")
@export var stats_component_path := NodePath("../Components/StatsComponent")
@export var health_component_path := NodePath("../Components/HealthComponent")
@export var movement_component_path := NodePath(
	"../Components/MovementComponent"
)
@export var menu_controller_path := NodePath("../Components/MenuController")
@export var appearance_component_path := NodePath("../Components/AppearanceComponent")

@export_category("Debug")
@export_range(1.0, 100000.0, 1.0) var debug_experience_amount := 100.0

@onready var menu_root := %MenuRoot as Control
@onready var level_value := %LevelValue as Label
@onready var experience_value := %ExperienceValue as Label
@onready var skill_points_value := %SkillPointsValue as Label
@onready var strength_value := %StrengthValue as Label
@onready var health_value := %HealthValue as Label
@onready var stamina_value := %StaminaValue as Label
@onready var aura_value := %AuraValue as Label
@onready var purchase_strength_button := %PurchaseStrengthButton as Button
@onready var stats := get_node(stats_component_path) as PlayerStatsComponent
@onready var health_component := (
	get_node(health_component_path) as PlayerHealthComponent
)
@onready var movement_component := (
	get_node(movement_component_path) as PlayerMovementComponent
)
@onready var menu_controller := (
	get_node(menu_controller_path) as PlayerMenuController
)
@onready var appearance := get_node(appearance_component_path) as PlayerAppearanceComponent

var _is_open := false


func _ready() -> void:
	stats.health_changed.connect(_on_pool_changed)
	stats.stamina_changed.connect(_on_pool_changed)
	stats.experience_changed.connect(_on_experience_changed)
	stats.level_changed.connect(_on_level_changed)
	stats.skill_points_changed.connect(_on_skill_points_changed)
	stats.strength_changed.connect(_on_strength_changed)
	stats.aura_changed.connect(_on_aura_changed)
	purchase_strength_button.pressed.connect(_purchase_strength)
	menu_root.visible = false
	_refresh()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.physical_keycode == KEY_TAB:
		set_menu_open(not _is_open)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_2:
		stats.add_experience(debug_experience_amount)
		get_viewport().set_input_as_handled()


func set_menu_open(open: bool) -> void:
	if open:
		if not menu_controller.request_open(&"stats"):
			return
	elif not menu_controller.close(&"stats"):
		return

	_is_open = open
	menu_root.visible = _is_open
	if _is_open:
		_refresh()


func _purchase_strength() -> void:
	stats.purchase_strength()


func _refresh() -> void:
	level_value.text = str(stats.level)
	experience_value.text = "%d / %d" % [
		roundi(stats.experience),
		roundi(stats.get_experience_required_for_next_level()),
	]
	skill_points_value.text = str(stats.skill_points)
	strength_value.text = str(stats.strength)
	health_value.text = "%d" % roundi(stats.get_max_health())
	stamina_value.text = "%d" % roundi(stats.get_max_stamina())
	aura_value.text = str(stats.aura)
	purchase_strength_button.disabled = stats.skill_points <= 0
	purchase_strength_button.text = (
		"Requires 1 Skill Point"
		if stats.skill_points <= 0
		else "Purchase Strength — 1 Point"
	)


func _on_pool_changed(_current: float, _maximum: float) -> void:
	_refresh()


func _on_experience_changed(_current: float, _required: float) -> void:
	_refresh()


func _on_level_changed(_current: int) -> void:
	_refresh()


func _on_skill_points_changed(_current: int) -> void:
	_refresh()


func _on_strength_changed(_current: int) -> void:
	_refresh()


func _on_aura_changed(_current: int) -> void:
	_refresh()
