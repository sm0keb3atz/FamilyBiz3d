class_name PlayerStatsMenu
extends CanvasLayer

const LOCK_ICON: Texture2D = preload(
	"res://Assets/UI/PlayerStats/Icons/lock.svg"
)
const MOTION_ICON: Texture2D = preload(
	"res://Assets/UI/PlayerStats/Icons/motion.svg"
)

@export_category("Scene References")
@export var stats_component_path := NodePath("../Components/StatsComponent")
@export var health_component_path := NodePath("../Components/HealthComponent")
@export var movement_component_path := NodePath(
	"../Components/MovementComponent"
)
@export var menu_controller_path := NodePath("../Components/MenuController")
@export var appearance_component_path := NodePath("../Components/AppearanceComponent")
@export var entourage_component_path := NodePath("../Components/EntourageComponent")

@export_category("Debug")
@export_range(1.0, 100000.0, 1.0) var debug_experience_amount := 100.0

@onready var menu_root := %MenuRoot as Control
@onready var panel := %Panel as PanelContainer
@onready var backdrop := menu_root.get_node("Backdrop") as ColorRect
@onready var level_value := %LevelValue as Label
@onready var experience_value := %ExperienceValue as Label
@onready var experience_bar := %ExperienceBar as ProgressBar
@onready var skill_points_value := %SkillPointsValue as Label
@onready var strength_value := %StrengthValue as Label
@onready var hustle_value := %HustleValue as Label
@onready var health_value := %HealthValue as Label
@onready var stamina_value := %StaminaValue as Label
@onready var aura_value := %AuraValue as Label
@onready var customer_capacity_value := %CustomerCapacityValue as Label
@onready var sale_bonus_value := %SaleBonusValue as Label
@onready var experience_bonus_value := %ExperienceBonusValue as Label
@onready var strength_description := %StrengthDescription as Label
@onready var hustle_description := %HustleDescription as Label
@onready var purchase_strength_button := %PurchaseStrengthButton as Button
@onready var purchase_hustle_button := %PurchaseHustleButton as Button
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
@onready var entourage := get_node_or_null(
	entourage_component_path
) as PlayerEntourageComponent

var _is_open := false
var _open_tween: Tween
var motion_value: Label
var motion_capacity_value: Label
var motion_active_value: Label
var motion_loyalty_value: Label
var purchase_motion_button: Button
var carry_weight_value: Label


func _ready() -> void:
	_build_motion_interface()
	_build_carry_weight_metric()
	stats.health_changed.connect(_on_pool_changed)
	stats.stamina_changed.connect(_on_pool_changed)
	stats.experience_changed.connect(_on_experience_changed)
	stats.level_changed.connect(_on_level_changed)
	stats.skill_points_changed.connect(_on_skill_points_changed)
	stats.strength_changed.connect(_on_strength_changed)
	stats.hustle_changed.connect(_on_hustle_changed)
	stats.motion_changed.connect(_on_motion_changed)
	stats.aura_changed.connect(_on_aura_changed)
	if entourage != null:
		entourage.capacity_changed.connect(_on_entourage_capacity_changed)
	purchase_strength_button.pressed.connect(_purchase_strength)
	purchase_hustle_button.pressed.connect(_purchase_hustle)
	purchase_motion_button.pressed.connect(_purchase_motion)
	purchase_strength_button.tooltip_text = (
		"Spend one skill point to improve maximum Health and Stamina."
	)
	purchase_hustle_button.tooltip_text = (
		"Spend one skill point to improve customers, sale value, and experience."
	)
	purchase_motion_button.tooltip_text = (
		"Spend one skill point to add a follower slot and improve girlfriend loyalty."
	)
	menu_root.visible = false
	_refresh()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not _is_open and not menu_controller.active_menu.is_empty():
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
	if _is_open:
		menu_root.visible = true
		_refresh()
		_play_open_animation()
	else:
		if is_instance_valid(_open_tween):
			_open_tween.kill()
		menu_root.visible = false


func _purchase_strength() -> void:
	stats.purchase_strength()


func _purchase_hustle() -> void:
	stats.purchase_hustle()


func _purchase_motion() -> void:
	stats.purchase_motion()


func _refresh() -> void:
	var required_experience := stats.get_experience_required_for_next_level()
	level_value.text = str(stats.level)
	experience_value.text = "%d / %d" % [
		roundi(stats.experience),
		roundi(required_experience),
	]
	experience_bar.max_value = required_experience
	experience_bar.value = stats.experience
	skill_points_value.text = str(stats.skill_points)
	strength_value.text = str(stats.strength)
	hustle_value.text = str(stats.hustle)
	motion_value.text = str(stats.motion)
	health_value.text = "%d" % roundi(stats.get_max_health())
	stamina_value.text = "%d" % roundi(stats.get_max_stamina())
	carry_weight_value.text = "%dg" % stats.get_max_carry_weight_grams()
	aura_value.text = str(stats.aura)
	customer_capacity_value.text = "%d / %d" % [
		stats.get_hustle_customer_limit(),
		stats.config.max_solicitation_customer_limit,
	]
	sale_bonus_value.text = "%.2fx" % stats.get_hustle_sale_multiplier()
	experience_bonus_value.text = "+%d%%" % roundi(
		(stats.get_hustle_experience_multiplier() - 1.0) * 100.0
	)
	motion_capacity_value.text = "%d / %d" % [
		stats.get_motion_follower_limit(),
		stats.config.max_motion,
	]
	var active_followers := entourage.get_active_count() if entourage != null else 0
	motion_active_value.text = "%d / %d" % [
		active_followers,
		stats.get_motion_follower_limit(),
	]
	motion_loyalty_value.text = "%.2fx" % stats.get_motion_loyalty_multiplier()
	strength_description.text = (
		"Each point grants +%d maximum Health, +%d maximum Stamina, "
		+ "and +%dg carry weight."
	) % [
		roundi(stats.config.health_per_strength),
		roundi(stats.config.stamina_per_strength),
		stats.config.carry_weight_per_strength,
	]
	hustle_description.text = (
		"Attract more customers, improve buyer quality, and add %d%% sale cash "
		+ "and experience per point. Customer capacity is capped at %d."
	) % [
		roundi(stats.config.sale_bonus_per_hustle * 100.0),
		stats.config.max_solicitation_customer_limit,
	]
	purchase_strength_button.disabled = stats.skill_points <= 0
	purchase_strength_button.icon = (
		LOCK_ICON if purchase_strength_button.disabled else null
	)
	purchase_strength_button.text = (
		"Requires 1 Skill Point"
		if stats.skill_points <= 0
		else "Upgrade Strength  -  1 Point"
	)
	var hustle_capped := stats.hustle >= stats.config.max_hustle
	purchase_hustle_button.disabled = stats.skill_points <= 0 or hustle_capped
	purchase_hustle_button.icon = (
		LOCK_ICON if purchase_hustle_button.disabled else null
	)
	if hustle_capped:
		purchase_hustle_button.text = "Hustle Maxed"
	elif stats.skill_points <= 0:
		purchase_hustle_button.text = "Requires 1 Skill Point"
	else:
		purchase_hustle_button.text = "Upgrade Hustle  -  1 Point"
	var motion_capped := stats.motion >= stats.config.max_motion
	purchase_motion_button.disabled = stats.skill_points <= 0 or motion_capped
	purchase_motion_button.icon = (
		LOCK_ICON if purchase_motion_button.disabled else null
	)
	if motion_capped:
		purchase_motion_button.text = "Motion Maxed"
	elif stats.skill_points <= 0:
		purchase_motion_button.text = "Requires 1 Skill Point"
	else:
		purchase_motion_button.text = "Upgrade Motion  -  1 Point"


func _play_open_animation() -> void:
	if is_instance_valid(_open_tween):
		_open_tween.kill()
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.975, 0.975)
	backdrop.modulate.a = 0.0
	_open_tween = create_tween().set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(backdrop, "modulate:a", 1.0, 0.16)
	_open_tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	_open_tween.tween_property(panel, "scale", Vector2.ONE, 0.22)


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


func _on_hustle_changed(_current: int) -> void:
	_refresh()


func _on_motion_changed(_current: int) -> void:
	_refresh()


func _on_entourage_capacity_changed(_active: int, _maximum: int) -> void:
	_refresh()


func _on_aura_changed(_current: int) -> void:
	_refresh()


func _build_motion_interface() -> void:
	var content := $MenuRoot/Panel/Margin/Content as VBoxContainer
	var strength_card := content.get_node("StrengthCard") as Control
	var hustle_card := content.get_node("HustleCard") as Control
	var footer := content.get_node("Footer") as Control
	var scroll := ScrollContainer.new()
	scroll.name = "AttributesScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var stack := VBoxContainer.new()
	stack.name = "AttributeCards"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 11)
	content.add_child(scroll)
	content.move_child(scroll, footer.get_index())
	scroll.add_child(stack)
	content.remove_child(strength_card)
	content.remove_child(hustle_card)
	stack.add_child(strength_card)
	stack.add_child(hustle_card)
	stack.add_child(_create_motion_card())
	purchase_strength_button.focus_neighbor_bottom = (
		purchase_strength_button.get_path_to(purchase_hustle_button)
	)
	purchase_hustle_button.focus_neighbor_top = (
		purchase_hustle_button.get_path_to(purchase_strength_button)
	)
	purchase_hustle_button.focus_neighbor_bottom = (
		purchase_hustle_button.get_path_to(purchase_motion_button)
	)
	purchase_motion_button.focus_neighbor_top = (
		purchase_motion_button.get_path_to(purchase_hustle_button)
	)


func _build_carry_weight_metric() -> void:
	var purchase_button := purchase_strength_button
	var body := purchase_button.get_parent() as VBoxContainer
	var row := HBoxContainer.new()
	row.name = "CarryWeightRow"
	row.custom_minimum_size.y = 24
	body.add_child(row)
	body.move_child(row, purchase_button.get_index())
	var label := Label.new()
	label.text = "Carry Weight"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.76, 0.79, 0.83))
	row.add_child(label)
	carry_weight_value = Label.new()
	carry_weight_value.name = "CarryWeightValue"
	carry_weight_value.custom_minimum_size.x = 88
	carry_weight_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	carry_weight_value.add_theme_font_size_override("font_size", 14)
	carry_weight_value.add_theme_color_override(
		"font_color",
		Color(0.28, 0.82, 0.86)
	)
	row.add_child(carry_weight_value)


func _create_motion_card() -> PanelContainer:
	var accent := Color(0.42, 0.72, 1.0)
	var card := PanelContainer.new()
	card.name = "MotionCard"
	card.custom_minimum_size = Vector2(0, 260)
	card.add_theme_stylebox_override(
		"panel", _motion_style(Color(0.044, 0.053, 0.064, 0.96), accent, 12)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 21)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.texture = MOTION_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	row.add_child(body)
	var heading := HBoxContainer.new()
	heading.custom_minimum_size.y = 32
	heading.add_theme_constant_override("separation", 10)
	body.add_child(heading)
	var title := Label.new()
	title.text = "MOTION"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.985, 1))
	heading.add_child(title)
	var current := Label.new()
	current.text = "CURRENT"
	current.add_theme_font_size_override("font_size", 12)
	current.add_theme_color_override("font_color", Color(0.58, 0.63, 0.69))
	current.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(current)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(38, 30)
	badge.add_theme_stylebox_override(
		"panel", _motion_style(Color(0.07, 0.18, 0.3, 0.78), accent, 8)
	)
	heading.add_child(badge)
	motion_value = Label.new()
	motion_value.name = "MotionValue"
	motion_value.unique_name_in_owner = true
	motion_value.text = "1"
	motion_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motion_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	motion_value.add_theme_font_size_override("font_size", 18)
	motion_value.add_theme_color_override("font_color", accent.lightened(0.2))
	badge.add_child(motion_value)
	var description := Label.new()
	description.text = (
		"Controls the size of your called crew and strengthens girlfriend loyalty."
	)
	description.custom_minimum_size.y = 38
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	body.add_child(description)
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1
	divider.color = Color(0.2, 0.24, 0.29, 0.82)
	body.add_child(divider)
	motion_capacity_value = _add_motion_metric(
		body, "Follower Capacity", accent
	)
	motion_active_value = _add_motion_metric(
		body, "Active Followers", Color(0.54, 0.84, 1.0)
	)
	motion_loyalty_value = _add_motion_metric(
		body, "Loyalty Multiplier", Color(0.77, 0.58, 1.0)
	)
	purchase_motion_button = Button.new()
	purchase_motion_button.name = "PurchaseMotionButton"
	purchase_motion_button.unique_name_in_owner = true
	purchase_motion_button.custom_minimum_size.y = 42
	purchase_motion_button.text = "Requires 1 Skill Point"
	purchase_motion_button.disabled = true
	purchase_motion_button.expand_icon = true
	purchase_motion_button.add_theme_font_size_override("font_size", 15)
	purchase_motion_button.add_theme_color_override(
		"font_color", Color(0.82, 0.92, 1.0)
	)
	purchase_motion_button.add_theme_stylebox_override(
		"normal", _motion_style(Color(0.05, 0.16, 0.26, 0.96), accent, 9)
	)
	purchase_motion_button.add_theme_stylebox_override(
		"hover", _motion_style(Color(0.07, 0.24, 0.38, 0.98), accent.lightened(0.2), 9)
	)
	purchase_motion_button.add_theme_stylebox_override(
		"pressed", _motion_style(Color(0.035, 0.12, 0.2, 1.0), accent, 9)
	)
	purchase_motion_button.add_theme_stylebox_override(
		"disabled", _motion_style(Color(0.055, 0.065, 0.078, 0.9), Color(0.2, 0.24, 0.29), 9)
	)
	purchase_motion_button.add_theme_stylebox_override(
		"focus", _motion_style(Color(0, 0, 0, 0), accent.lightened(0.32), 9)
	)
	body.add_child(purchase_motion_button)
	return card


func _add_motion_metric(
	parent: VBoxContainer,
	caption: String,
	accent: Color
) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 21
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.76, 0.79, 0.83))
	row.add_child(name_label)
	var value := Label.new()
	value.custom_minimum_size.x = 88
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", accent)
	row.add_child(value)
	return value


func _motion_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style
