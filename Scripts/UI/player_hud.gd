class_name PlayerHUD
extends CanvasLayer

const PoliceCoordinatorData := preload("res://Scripts/Gameplay/police_coordinator.gd")

signal daily_report_closed

@export var stats_component_path := NodePath("../Components/StatsComponent")
@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var weapon_component_path := NodePath("../Components/WeaponComponent")
@export var vehicle_component_path := NodePath("../Components/VehicleComponent")
@export var wanted_component_path := NodePath("../Components/WantedComponent")
@export var arrest_component_path := NodePath("../Components/ArrestComponent")
@export var health_component_path := NodePath("../Components/HealthComponent")
@export var legal_component_path := NodePath("../Components/LegalComponent")
@export_range(0.0, 1000.0, 1.0) var debug_damage_amount := 25.0
@export_range(0.05, 1.0, 0.01) var hit_marker_duration := 0.18
@export_range(0.05, 1.0, 0.01) var cash_roll_duration := 0.35
@export_range(0.1, 2.0, 0.05) var transaction_float_duration := 0.8
@export_range(0.05, 1.0, 0.05) var territory_refresh_interval := 0.1

@onready var health_bar := %HealthBar as ProgressBar
@onready var health_value := %HealthValue as Label
@onready var stamina_bar := %StaminaBar as ProgressBar
@onready var stamina_value := %StaminaValue as Label
@onready var level_label := %LevelLabel as Label
@onready var experience_label := %ExperienceLabel as Label
@onready var state_label := %StateLabel as Label
@onready var outcome_overlay := %OutcomeOverlay as ColorRect
@onready var outcome_subtitle := %OutcomeSubtitle as Label
@onready var dirty_cash_label := %DirtyCashLabel as Label
@onready var clean_cash_label := %CleanCashLabel as Label
@onready var money_panel := %MoneyPanel as PanelContainer
@onready var transaction_float_layer := %TransactionFloatLayer as Control
@onready var transaction_audio := %TransactionAudio as AudioStreamPlayer
@onready var date_label := %DateLabel as Label
@onready var time_label := %TimeLabel as Label
@onready var court_divider := %CourtDivider as ColorRect
@onready var court_date_list := %CourtDateList as VBoxContainer
@onready var daily_report_overlay := %DailyReportOverlay as DailyFinancialReport
@onready var interaction_prompt := %InteractionPrompt as Label
@onready var sale_interaction_panel := %SaleInteractionPanel as PanelContainer
@onready var sale_product_icon := %SaleProductIcon as TextureRect
@onready var sale_product_name := %SaleProductName as Label
@onready var sale_price := %SalePrice as Label
@onready var feedback_panel := %FeedbackPanel as PanelContainer
@onready var feedback_accent := %FeedbackAccent as ColorRect
@onready var feedback_icon := %FeedbackIcon as Label
@onready var feedback_title := %FeedbackTitle as Label
@onready var feedback_label := %FeedbackLabel as Label
@onready var feedback_timer := %FeedbackTimer as Timer
@onready var crosshair := %Crosshair as Label
@onready var hit_marker := %HitMarker as Control
@onready var weapon_name_label := %WeaponNameLabel as Label
@onready var ammo_label := %AmmoLabel as Label
@onready var reload_label := %ReloadLabel as Label
@onready var weapon_panel := get_node("WeaponPanel") as PanelContainer
@onready var reputation_title := %ReputationTitle as Label
@onready var reputation_bar := %ReputationBar as ProgressBar
@onready var reputation_value := %ReputationValue as Label
@onready var market_quote_row := %MarketQuoteRow as HBoxContainer
@onready var heat_title := %HeatTitle as Label
@onready var heat_bar := %HeatBar as ProgressBar
@onready var heat_value := %HeatValue as Label
@onready var wanted_stars := %WantedStars as Label
@onready var police_status := %PoliceStatus as Label
@onready var escape_panel := %EscapePanel as PanelContainer
@onready var escape_bar := %EscapeBar as ProgressBar
@onready var escape_time := %EscapeTime as Label
@onready var arrest_panel := %ArrestPanel as PanelContainer
@onready var arrest_bar := %ArrestBar as ProgressBar
@onready var stats := get_node(stats_component_path) as PlayerStatsComponent
@onready var wallet := (
	get_node(wallet_component_path) as PlayerWalletComponent
)
@onready var weapon := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)
@onready var vehicle_component := (
	get_node(vehicle_component_path) as PlayerVehicleComponent
)
@onready var wanted := (
	get_node(wanted_component_path) as PlayerWantedComponent
)
@onready var arrest := (
	get_node(arrest_component_path) as PlayerArrestComponent
)
@onready var health := (
	get_node(health_component_path) as PlayerHealthComponent
)
@onready var legal := get_node_or_null(legal_component_path) as PlayerLegalComponent

var _hit_marker_remaining := 0.0
var _detection_debug_visible := false
var _police_coordinator: Node
var _was_tree_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _displayed_dirty_cash := 0.0
var _displayed_clean_cash := 0.0
var _pending_dirty_cash := 0
var _pending_clean_cash := 0
var _pending_money_refresh := false
var _dirty_cash_tween: Tween
var _clean_cash_tween: Tween
var _dirty_cash_pulse_tween: Tween
var _clean_cash_pulse_tween: Tween
var _feedback_tween: Tween
var _outcome_tween: Tween
var _transaction_float_index := 0
var _market_price_labels: Dictionary = {}
var _market_products: Array[ProductDefinition] = []
var _market: TerritoryMarketService
var _current_territory_id: StringName = &""
var _territory_refresh_remaining := 0.0
var _territory_control_label: Label
var _court_date_refresh_remaining := 0.0
var _vehicle_panel: PanelContainer
var _vehicle_speed: Label
var _vehicle_gear: Label
var _vehicle_fuel: ProgressBar
var _vehicle_fuel_value: Label
var _vehicle_damage: ProgressBar
var _vehicle_damage_value: Label
var _vehicle_service_prompt: Label
var _fuel_pump_panel: PanelContainer
var _fuel_pump_label: Label


func _ready() -> void:
	_build_vehicle_hud()
	reputation_bar.min_value = -100.0
	reputation_bar.max_value = 100.0
	heat_bar.max_value = 100.0
	stats.health_changed.connect(_on_health_changed)
	stats.stamina_changed.connect(_on_stamina_changed)
	stats.experience_changed.connect(_on_experience_changed)
	stats.level_changed.connect(_on_level_changed)
	stats.health_depleted.connect(_on_health_depleted)
	wallet.money_changed.connect(_on_money_changed)
	wallet.transaction_completed.connect(_on_transaction_completed)
	weapon.weapon_changed.connect(_on_weapon_changed)
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.hit_confirmed.connect(_on_hit_confirmed)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_completed.connect(_on_reload_completed)
	vehicle_component.vehicle_entered.connect(_on_vehicle_entered)
	vehicle_component.vehicle_exited.connect(_on_vehicle_exited)
	wanted.wanted_level_changed.connect(_on_wanted_level_changed)
	wanted.escape_progress_changed.connect(_on_escape_progress_changed)
	call_deferred(&"_connect_police_coordinator")
	arrest.arrest_progress_changed.connect(_on_arrest_progress_changed)
	arrest.arrested.connect(_on_arrested)
	health.respawn_completed.connect(_hide_outcome)
	feedback_timer.timeout.connect(_on_feedback_timeout)
	daily_report_overlay.continue_requested.connect(_close_daily_report)
	if legal != null:
		legal.legal_state_changed.connect(_refresh_court_dates)
	_refresh_court_dates()
	_market_products = EconomyCatalog.get_gram_products()
	_build_market_quote_row()
	_territory_control_label = Label.new()
	_territory_control_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_territory_control_label.add_theme_font_size_override("font_size", 14)
	_territory_control_label.add_theme_color_override(
		"font_color", Color(1.0, 0.72, 0.22)
	)
	reputation_title.get_parent().add_child(_territory_control_label)
	_refresh_all()
	_refresh_territory()


func _process(delta: float) -> void:
	_court_date_refresh_remaining -= delta
	if _court_date_refresh_remaining <= 0.0:
		_court_date_refresh_remaining = 1.0
		_refresh_court_dates()
	_territory_refresh_remaining -= delta
	if _territory_refresh_remaining <= 0.0:
		_territory_refresh_remaining = territory_refresh_interval
		_refresh_territory()
	crosshair.visible = (
		not vehicle_component.is_driving()
		and
		weapon.is_aiming()
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)
	_refresh_vehicle_hud()
	if hit_marker != null and not hit_marker.has_method(&"trigger"):
		if _hit_marker_remaining > 0.0:
			_hit_marker_remaining = maxf(_hit_marker_remaining - delta, 0.0)
			hit_marker.modulate.a = _hit_marker_remaining / hit_marker_duration
			if is_zero_approx(_hit_marker_remaining):
				hit_marker.visible = false


func _refresh_court_dates() -> void:
	for child in court_date_list.get_children():
		court_date_list.remove_child(child)
		child.queue_free()
	if legal == null:
		court_divider.visible = false
		court_date_list.visible = false
		return
	var pending := legal.get_pending_cases()
	var has_court_dates := not pending.is_empty()
	court_divider.visible = has_court_dates
	court_date_list.visible = has_court_dates
	for legal_case in pending:
		_add_court_date_row(legal_case)


func _add_court_date_row(legal_case: LegalCase) -> void:
	var row := VBoxContainer.new()
	row.name = "CourtDateRow"
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var case_label := Label.new()
	case_label.text = "CASE: %s" % legal_case.case_id.trim_prefix("CASE-")
	case_label.add_theme_color_override("font_color", Color(0.42, 0.74, 0.95))
	case_label.add_theme_font_size_override("font_size", 11)
	row.add_child(case_label)
	var hearing_label := Label.new()
	hearing_label.text = _get_compact_hearing_datetime(legal_case)
	hearing_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	hearing_label.add_theme_font_size_override("font_size", 13)
	row.add_child(hearing_label)
	var countdown_label := Label.new()
	countdown_label.text = legal.get_hearing_countdown_text(legal_case).to_upper()
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	countdown_label.add_theme_font_size_override("font_size", 13)
	row.add_child(countdown_label)
	court_date_list.add_child(row)


func _get_compact_hearing_datetime(legal_case: LegalCase) -> String:
	var full_text := legal.get_hearing_datetime_text(legal_case).to_upper()
	var date_and_time := full_text.split(" AT ", false, 1)
	if date_and_time.size() < 2:
		return full_text
	var date_parts := date_and_time[0].split(", ")
	var month_and_day := date_parts[1] if date_parts.size() > 1 else date_and_time[0]
	return "%s  •  %s" % [month_and_day, date_and_time[1]]


func _refresh_territory() -> void:
	var player := get_parent() as CharacterBody3D
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(), player.global_position
	)
	if boundary == null or boundary.stats == null:
		_set_label_text(reputation_title, "OUTSIDE TERRITORY — REPUTATION")
		_set_label_text(heat_title, "OUTSIDE TERRITORY — HEAT")
		reputation_bar.value = 0.0
		heat_bar.value = 0.0
		_set_label_text(_territory_control_label, "")
		_set_label_text(reputation_value, "—")
		_set_label_text(heat_value, "—")
		if not _current_territory_id.is_empty():
			_current_territory_id = &""
			_refresh_market_quotes(&"")
		return
	_set_label_text(
		reputation_title,
		"%s — REPUTATION" % boundary.display_name.to_upper()
	)
	_set_label_text(
		heat_title,
		"%s — HEAT" % boundary.display_name.to_upper()
	)
	reputation_bar.value = boundary.stats.reputation
	heat_bar.value = boundary.stats.heat
	var reputation_number := roundi(boundary.stats.reputation)
	var reputation_text := str(reputation_number)
	if reputation_number > 0:
		reputation_text = "+%d" % reputation_number
	_set_label_text(reputation_value, "%s / 100" % reputation_text)
	_set_label_text(heat_value, "%d / 100" % roundi(boundary.stats.heat))
	_refresh_territory_control(boundary)
	var territory_changed := boundary.territory_id != _current_territory_id
	var market_was_missing := not is_instance_valid(_market)
	_current_territory_id = boundary.territory_id
	var market := _get_market()
	if territory_changed or (market_was_missing and market != null):
		_refresh_market_quotes(_current_territory_id)


func _refresh_territory_control(boundary: TerritoryBoundary) -> void:
	var owner_names := ["NEUTRAL", "RIVAL", "PLAYER"]
	var text := "OWNER: %s" % owner_names[int(boundary.stats.owner_faction)]
	var encounter := get_tree().get_first_node_in_group(
		&"territory_encounter"
	) as TerritoryEncounterController
	if encounter != null and encounter.is_encounter_active():
		if encounter.get_active_territory_id() == boundary.territory_id:
			if (
				encounter.get_active_encounter_type()
				== TerritoryEncounterController.EncounterType.GANG_WAR
			):
				text += "  |  GANG WAR: %ds" % ceili(
					encounter.get_encounter_remaining()
				)
			elif (
				encounter.get_active_encounter_type()
				== TerritoryEncounterController.EncounterType.ROBBERY
			):
				var phase_text := (
					"THIEF APPROACHING"
					if encounter.get_active_phase()
					== TerritoryEncounterController.RobberyPhase.APPROACH
					else "CATCH THE THIEF"
				)
				text += "  |  ROBBERY: %s %ds" % [
					phase_text,
					ceili(encounter.get_encounter_remaining()),
				]
	elif (
		encounter != null
		and boundary.territory_id == TerritoryEncounterController.TARGET_TERRITORY
	):
		if encounter.is_war_active(boundary.territory_id):
			text += "  |  GANG WAR: %ds" % ceili(
				encounter.get_war_remaining()
			)
		else:
			var tier := encounter.get_risk_tier(boundary.stats.reputation)
			var risk_names := ["NONE", "VERY LOW", "LOW", "MEDIUM", "HIGH"]
			text += "  |  WAR RISK: %s  |  WINS: %d/3" % [
				risk_names[tier],
				encounter.get_war_wins(boundary.territory_id),
			]
			var cooldown := encounter.get_cooldown_minutes(
				boundary.territory_id
			)
			if cooldown > 0:
				text += "  |  COOLDOWN: %dh %02dm" % [
					cooldown / 60,
					cooldown % 60,
				]
	_set_label_text(_territory_control_label, text)


func _build_market_quote_row() -> void:
	for child in market_quote_row.get_children():
		child.queue_free()
	_market_price_labels.clear()
	for product in _market_products:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 5)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.alignment = BoxContainer.ALIGNMENT_CENTER
		entry.tooltip_text = product.display_name
		market_quote_row.add_child(entry)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(25, 25)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = product.icon
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(icon)

		var price_label := Label.new()
		price_label.text = "$—/g"
		price_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.9, 0.55, 1.0)
		)
		price_label.add_theme_font_size_override("font_size", 14)
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(price_label)
		_market_price_labels[product.product_id] = price_label


func _refresh_market_quotes(territory_id: StringName) -> void:
	var market := _get_market()
	for product in _market_products:
		var label := _market_price_labels.get(product.product_id) as Label
		if label == null:
			continue
		var next_text := "$—/g"
		if not territory_id.is_empty() and market != null:
			next_text = "$%d/g" % market.get_buy_quote(
				territory_id,
				product
			)
		_set_label_text(label, next_text)


func _get_market() -> TerritoryMarketService:
	if is_instance_valid(_market):
		return _market
	_market = TerritoryMarketService.find(get_tree())
	if (
		_market != null
		and not _market.market_changed.is_connected(_on_market_changed)
	):
		_market.market_changed.connect(_on_market_changed)
	return _market


func _on_market_changed(_date_key: String) -> void:
	_refresh_market_quotes(_current_territory_id)


func _set_label_text(label: Label, value: String) -> void:
	if label.text != value:
		label.text = value


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
	):
		if event.physical_keycode == KEY_0:
			_detection_debug_visible = not _detection_debug_visible
			PolicePerceptionComponent.debug_draw_enabled = (
				_detection_debug_visible
			)
			get_tree().call_group(
				&"police_npc",
				&"set_detection_debug_visible",
				_detection_debug_visible
			)
			show_feedback(
				"POLICE DETECTION DEBUG: %s"
				% ("ON" if _detection_debug_visible else "OFF"),
				1.5
			)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_1:
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
	_set_displayed_money(wallet.dirty_cash, wallet.clean_cash)
	state_label.visible = is_zero_approx(stats.health)
	outcome_overlay.visible = false
	interaction_prompt.visible = false
	sale_interaction_panel.visible = false
	feedback_panel.visible = false
	hit_marker.visible = false
	daily_report_overlay.visible = false
	_on_weapon_changed(weapon.get_equipped_weapon())
	_on_wanted_level_changed(0, wanted.wanted_level)
	_on_escape_progress_changed(
		wanted.escape_progress,
		wanted.is_escaping
	)
	_on_arrest_progress_changed(arrest.progress)
	_on_vehicle_exited(null)


func set_vehicle_service_prompt(prompt: String) -> void:
	if _vehicle_service_prompt == null:
		return
	_vehicle_service_prompt.text = prompt
	_vehicle_service_prompt.visible = not prompt.is_empty()


func update_fuel_pump(
	visible: bool,
	current: float = 0.0,
	capacity: float = 0.0,
	dispensed: float = 0.0,
	price_per_gallon: int = 0,
	total_cost: int = 0,
	clean_cash: int = 0
) -> void:
	if _fuel_pump_panel == null:
		return
	_fuel_pump_panel.visible = visible
	if visible:
		_fuel_pump_label.text = (
			"FUEL  %.2f / %.0f GAL\n"
			+ "DISPENSED  %.2f GAL   @ $%d/GAL\n"
			+ "TOTAL  $%d   |   CLEAN  $%d\nHOLD F TO REFUEL"
		) % [current, capacity, dispensed, price_per_gallon, total_cost, clean_cash]


func _on_vehicle_entered(vehicle: Node) -> void:
	weapon_panel.visible = false
	_vehicle_panel.visible = true
	crosshair.visible = false
	hit_marker.visible = false
	var base_vehicle := vehicle as BaseVehicle
	if (
		base_vehicle != null
		and not base_vehicle.condition_component.fuel_empty.is_connected(
			_on_vehicle_fuel_empty
		)
	):
		base_vehicle.condition_component.fuel_empty.connect(_on_vehicle_fuel_empty)
	if base_vehicle != null and not base_vehicle.condition_component.has_fuel():
		_on_vehicle_fuel_empty()
	_refresh_vehicle_hud()


func _on_vehicle_exited(vehicle: Node) -> void:
	var base_vehicle := vehicle as BaseVehicle
	if (
		base_vehicle != null
		and base_vehicle.condition_component.fuel_empty.is_connected(
			_on_vehicle_fuel_empty
		)
	):
		base_vehicle.condition_component.fuel_empty.disconnect(_on_vehicle_fuel_empty)
	weapon_panel.visible = true
	_vehicle_panel.visible = false
	crosshair.visible = (
		weapon.is_aiming()
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)
	hit_marker.visible = _hit_marker_remaining > 0.0
	set_vehicle_service_prompt("")
	update_fuel_pump(false)


func _on_vehicle_fuel_empty() -> void:
	show_feedback("OUT OF FUEL - PROPULSION DISABLED", 3.5)


func _refresh_vehicle_hud() -> void:
	if _vehicle_panel == null or not vehicle_component.is_driving():
		return
	var current := vehicle_component.get_current_vehicle() as BaseVehicle
	if current == null:
		return
	_vehicle_speed.text = "%03d MPH" % roundi(current.linear_velocity.length() * 2.236936)
	var gear := current.get_current_gear()
	_vehicle_gear.text = "GEAR  %s" % ("R" if gear < 0 else str(gear))
	var condition := current.condition_component
	_vehicle_fuel.max_value = condition.get_fuel_capacity()
	_vehicle_fuel.value = condition.fuel_gallons
	_vehicle_fuel_value.text = "%.1f / %.0f GAL" % [condition.fuel_gallons, condition.get_fuel_capacity()]
	_vehicle_damage.value = condition.damage
	_vehicle_damage_value.text = "%d / 100" % roundi(condition.damage)
	var damage_color := Color(0.95, 0.28, 0.2) if condition.damage >= 50.0 else Color(0.96, 0.65, 0.18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = damage_color
	fill.set_corner_radius_all(3)
	_vehicle_damage.add_theme_stylebox_override("fill", fill)


func _build_vehicle_hud() -> void:
	_vehicle_panel = PanelContainer.new()
	_vehicle_panel.name = "VehiclePanel"
	_vehicle_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var right_offset := weapon_panel.offset_right if weapon_panel != null else -20.0
	var bottom_offset := weapon_panel.offset_bottom if weapon_panel != null else -20.0
	_vehicle_panel.offset_left = right_offset - 270.0
	_vehicle_panel.offset_top = bottom_offset - 186.0
	_vehicle_panel.offset_right = right_offset
	_vehicle_panel.offset_bottom = bottom_offset
	if weapon_panel != null:
		_vehicle_panel.add_theme_stylebox_override(
			"panel", weapon_panel.get_theme_stylebox("panel")
		)
	add_child(_vehicle_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	_vehicle_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_vehicle_speed = Label.new()
	_vehicle_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vehicle_speed.add_theme_font_size_override("font_size", 25)
	header.add_child(_vehicle_speed)
	_vehicle_gear = Label.new()
	_vehicle_gear.add_theme_font_size_override("font_size", 18)
	header.add_child(_vehicle_gear)
	content.add_child(_vehicle_meter_label("FUEL", Color(0.25, 0.82, 0.48)))
	_vehicle_fuel = ProgressBar.new()
	_vehicle_fuel.show_percentage = false
	_vehicle_fuel.custom_minimum_size.y = 18
	content.add_child(_vehicle_fuel)
	_vehicle_fuel_value = _overlay_value(_vehicle_fuel)
	content.add_child(_vehicle_meter_label("DAMAGE", Color(0.96, 0.65, 0.18)))
	_vehicle_damage = ProgressBar.new()
	_vehicle_damage.max_value = 100.0
	_vehicle_damage.show_percentage = false
	_vehicle_damage.custom_minimum_size.y = 18
	content.add_child(_vehicle_damage)
	_vehicle_damage_value = _overlay_value(_vehicle_damage)
	_vehicle_panel.visible = false
	_vehicle_service_prompt = Label.new()
	_vehicle_service_prompt.name = "VehicleServicePrompt"
	_vehicle_service_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_vehicle_service_prompt.position = Vector2(-220, -120)
	_vehicle_service_prompt.size = Vector2(440, 34)
	_vehicle_service_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vehicle_service_prompt.add_theme_font_size_override("font_size", 18)
	_vehicle_service_prompt.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	add_child(_vehicle_service_prompt)
	_vehicle_service_prompt.visible = false
	_fuel_pump_panel = PanelContainer.new()
	_fuel_pump_panel.name = "FuelPumpPanel"
	_fuel_pump_panel.set_anchors_preset(Control.PRESET_CENTER)
	_fuel_pump_panel.position = Vector2(-190, -110)
	_fuel_pump_panel.size = Vector2(380, 220)
	add_child(_fuel_pump_panel)
	var pump_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		pump_margin.add_theme_constant_override(side, 18)
	_fuel_pump_panel.add_child(pump_margin)
	_fuel_pump_label = Label.new()
	_fuel_pump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fuel_pump_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fuel_pump_label.add_theme_font_size_override("font_size", 18)
	pump_margin.add_child(_fuel_pump_label)
	_fuel_pump_panel.visible = false


func _vehicle_meter_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label


func _overlay_value(bar: ProgressBar) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(label)
	return label


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
	_show_outcome(
		"SMOKED",
		"PARAMEDICS ARE EN ROUTE",
		Color(0.9, 0.08, 0.1, 1.0)
	)


func set_interaction_prompt(prompt: String, sale_data: Dictionary = {}) -> void:
	var show_sale_card := not sale_data.is_empty()
	sale_interaction_panel.visible = show_sale_card
	if show_sale_card:
		sale_product_icon.texture = sale_data.get("icon") as Texture2D
		var grams := int(sale_data.get("grams", 1))
		sale_product_name.text = "%s %d%s" % [
			String(sale_data.get("product_name", "PRODUCT")).to_upper(),
			grams,
			"G" if grams == 1 else "GS",
		]
		sale_price.text = "$%d" % int(sale_data.get("payout", 0))
	_set_label_text(interaction_prompt, prompt)
	var should_be_visible := not prompt.is_empty() and not show_sale_card
	if interaction_prompt.visible != should_be_visible:
		interaction_prompt.visible = should_be_visible


func show_feedback(message: String, duration := 2.5) -> void:
	if message.is_empty():
		feedback_panel.visible = false
		feedback_timer.stop()
		return
	var presentation := _get_feedback_presentation(message)
	feedback_label.text = message
	feedback_title.text = presentation.title
	feedback_icon.text = presentation.icon
	_apply_feedback_color(presentation.color)
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	feedback_panel.visible = true
	feedback_panel.modulate.a = 0.0
	feedback_panel.scale = Vector2(0.97, 0.97)
	feedback_panel.pivot_offset = feedback_panel.size * 0.5
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.tween_property(
		feedback_panel, "modulate:a", 1.0, 0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(
		feedback_panel, "scale", Vector2.ONE, 0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	feedback_timer.start(maxf(duration, 0.1))


func _get_feedback_presentation(message: String) -> Dictionary:
	var lower := message.to_lower()
	if lower.begins_with("sold "):
		return {
			"title": "SALE COMPLETE",
			"icon": "$",
			"color": Color(0.25, 0.86, 0.45),
		}
	if "customer is coming" in lower or "customers are coming" in lower:
		return {
			"title": "CUSTOMER INBOUND",
			"icon": ">",
			"color": Color(0.25, 0.68, 1.0),
		}
	if "no customers" in lower:
		return {
			"title": "NO BUYERS",
			"icon": "!",
			"color": Color(1.0, 0.72, 0.22),
		}
	var warning_words := [
		"failed", "could not", "damaged", "not enough", "rejected",
		"died", "killed", "arrested", "broke up", "no save",
	]
	for word in warning_words:
		if word in lower:
			return {
				"title": "WARNING",
				"icon": "!",
				"color": Color(1.0, 0.35, 0.25),
			}
	var success_words := [
		"saved", "loaded", "purchased", "claimed", "appreciated",
		"i'd love to", "hired", "upgraded",
	]
	for word in success_words:
		if word in lower:
			return {
				"title": "SUCCESS",
				"icon": "+",
				"color": Color(0.25, 0.86, 0.45),
			}
	return {
		"title": "NOTICE",
		"icon": "i",
		"color": Color(0.35, 0.68, 1.0),
	}


func _apply_feedback_color(color: Color) -> void:
	feedback_accent.color = color
	feedback_icon.add_theme_color_override("font_color", color)
	feedback_title.add_theme_color_override("font_color", color)
	var style := feedback_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = Color(color.r, color.g, color.b, 0.82)
	style.shadow_color = Color(color.r, color.g, color.b, 0.16)
	feedback_panel.add_theme_stylebox_override("panel", style)


func update_clock(date_text: String, time_text: String) -> void:
	var clock_date := date_text
	var world_time := (
		get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	)
	if world_time != null:
		var date_parts := date_text.split(" ", false, 1)
		if date_parts.size() > 1:
			clock_date = "%s • %s • Y%d" % [
				date_parts[0], date_parts[1], world_time.year,
			]
		else:
			clock_date = "%s • Y%d" % [date_text, world_time.year]
	date_label.text = clock_date
	time_label.text = time_text


func show_daily_report(report_date: String, earned: int, spent: int) -> void:
	_was_tree_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	var transactions: Array[Dictionary] = []
	var daily_history: Array[Dictionary] = []
	var world_time := get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if world_time != null:
		transactions = world_time.get_last_day_transactions()
		daily_history = world_time.get_daily_report_history(7)
	daily_report_overlay.show_report(
		report_date,
		earned,
		spent,
		transactions,
		wallet.dirty_cash + wallet.clean_cash,
		daily_history
	)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_daily_report() -> void:
	if not daily_report_overlay.visible:
		return
	daily_report_overlay.visible = false
	Input.mouse_mode = _previous_mouse_mode
	get_tree().paused = _was_tree_paused
	daily_report_closed.emit()


func _on_money_changed(dirty_cash: int, clean_cash: int) -> void:
	_pending_dirty_cash = dirty_cash
	_pending_clean_cash = clean_cash
	if _pending_money_refresh:
		return
	_pending_money_refresh = true
	call_deferred("_apply_pending_money_without_feedback")


func _on_transaction_completed(
	dirty_cash_delta: int,
	clean_cash_delta: int
) -> void:
	_pending_money_refresh = false
	if dirty_cash_delta != 0:
		_animate_dirty_cash(float(wallet.dirty_cash))
		_pulse_cash_label(dirty_cash_label, true)
		_spawn_transaction_float(dirty_cash_delta)
	else:
		_set_displayed_dirty_cash(float(wallet.dirty_cash))
	if clean_cash_delta != 0:
		_animate_clean_cash(float(wallet.clean_cash))
		_pulse_cash_label(clean_cash_label, false)
		_spawn_transaction_float(clean_cash_delta)
	else:
		_set_displayed_clean_cash(float(wallet.clean_cash))
	transaction_audio.play()


func _apply_pending_money_without_feedback() -> void:
	if not _pending_money_refresh:
		return
	_pending_money_refresh = false
	_set_displayed_money(_pending_dirty_cash, _pending_clean_cash)


func _set_displayed_money(dirty_cash: int, clean_cash: int) -> void:
	if _dirty_cash_tween != null and _dirty_cash_tween.is_valid():
		_dirty_cash_tween.kill()
	if _clean_cash_tween != null and _clean_cash_tween.is_valid():
		_clean_cash_tween.kill()
	_set_displayed_dirty_cash(float(dirty_cash))
	_set_displayed_clean_cash(float(clean_cash))


func _animate_dirty_cash(target: float) -> void:
	if _dirty_cash_tween != null and _dirty_cash_tween.is_valid():
		_dirty_cash_tween.kill()
	_dirty_cash_tween = create_tween()
	_dirty_cash_tween.tween_method(
		_set_displayed_dirty_cash,
		_displayed_dirty_cash,
		target,
		cash_roll_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_clean_cash(target: float) -> void:
	if _clean_cash_tween != null and _clean_cash_tween.is_valid():
		_clean_cash_tween.kill()
	_clean_cash_tween = create_tween()
	_clean_cash_tween.tween_method(
		_set_displayed_clean_cash,
		_displayed_clean_cash,
		target,
		cash_roll_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_displayed_dirty_cash(value: float) -> void:
	_displayed_dirty_cash = value
	dirty_cash_label.text = "DIRTY  $%d" % roundi(value)


func _set_displayed_clean_cash(value: float) -> void:
	_displayed_clean_cash = value
	clean_cash_label.text = "CLEAN  $%d" % roundi(value)


func _pulse_cash_label(label: Label, dirty: bool) -> void:
	var active_tween := (
		_dirty_cash_pulse_tween if dirty else _clean_cash_pulse_tween
	)
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.09)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	if dirty:
		_dirty_cash_pulse_tween = tween
	else:
		_clean_cash_pulse_tween = tween


func _spawn_transaction_float(delta: int) -> void:
	var label := Label.new()
	label.text = "+$%d" % delta if delta > 0 else "-$%d" % -delta
	label.modulate = (
		Color(0.32, 0.95, 0.48, 1.0)
		if delta > 0
		else Color(1.0, 0.3, 0.24, 1.0)
	)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.size = Vector2(150.0, 32.0)
	label.position = (
		money_panel.position
		+ Vector2(18.0 + float(_transaction_float_index % 3) * 12.0, -8.0)
	)
	_transaction_float_index += 1
	transaction_float_layer.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		label,
		"position:y",
		label.position.y - 48.0,
		transaction_float_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		transaction_float_duration * 0.55
	).set_delay(transaction_float_duration * 0.45)
	tween.chain().tween_callback(label.queue_free)


func _on_feedback_timeout() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.tween_property(
		feedback_panel, "modulate:a", 0.0, 0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_feedback_tween.tween_property(
		feedback_panel, "scale", Vector2(0.98, 0.98), 0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_feedback_tween.chain().tween_callback(
		func() -> void: feedback_panel.visible = false
	)


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
	if hit_marker != null and hit_marker.has_method(&"trigger"):
		hit_marker.call(&"trigger", fatal_hit, hit_marker_duration)
	elif hit_marker != null:
		_hit_marker_remaining = hit_marker_duration
		hit_marker.modulate = (
			Color(1.0, 0.36, 0.22, 1.0)
			if fatal_hit
			else Color.WHITE
		)
		hit_marker.visible = true
	if fatal_hit:
		_trigger_kill_hitstop()


func _trigger_kill_hitstop() -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(0.025, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0
	)


func _on_wanted_level_changed(_previous: int, current: int) -> void:
	var display := ""
	for index in PlayerWantedComponent.MAX_WANTED_LEVEL:
		display += "★" if index < current else "☆"
	wanted_stars.text = display
	wanted_stars.visible = current > 0
	police_status.visible = current > 0 or (
		_police_coordinator != null
		and _police_coordinator.phase == PoliceCoordinatorData.WantedPhase.INVESTIGATING
	)
	if current == 0 or not wanted.can_attempt_arrest():
		arrest_panel.visible = false
	if current == 0:
		escape_panel.visible = false


func _on_escape_progress_changed(
	progress: float,
	escaping: bool
) -> void:
	escape_bar.value = clampf(progress, 0.0, 1.0)
	escape_panel.visible = escaping and wanted.wanted_level > 0
	escape_time.text = "%.1fs" % (
		wanted.get_evasion_segment_seconds() * clampf(progress, 0.0, 1.0)
	)


func _connect_police_coordinator() -> void:
	_police_coordinator = get_tree().get_first_node_in_group(
		&"police_coordinator"
	)
	if _police_coordinator == null:
		return
	if not _police_coordinator.phase_changed.is_connected(_on_police_phase_changed):
		_police_coordinator.phase_changed.connect(_on_police_phase_changed)
	_on_police_phase_changed(_police_coordinator.phase, _police_coordinator.phase)


func _on_police_phase_changed(_previous: int, current: int) -> void:
	match current:
		PoliceCoordinatorData.WantedPhase.INVESTIGATING:
			police_status.text = "POLICE INVESTIGATING"
		PoliceCoordinatorData.WantedPhase.OBSERVED:
			police_status.text = "OBSERVED"
		PoliceCoordinatorData.WantedPhase.SEARCHING:
			police_status.text = "POLICE SEARCHING"
		PoliceCoordinatorData.WantedPhase.EVADING:
			police_status.text = "SEARCHING — EVADE"
		PoliceCoordinatorData.WantedPhase.SURRENDERING:
			police_status.text = "SURRENDERING"
		_:
			police_status.text = ""
	police_status.visible = current != PoliceCoordinatorData.WantedPhase.CLEAR


func _on_arrest_progress_changed(progress: float) -> void:
	arrest_bar.value = clampf(progress, 0.0, 1.0)
	arrest_panel.visible = (
		progress > 0.0
		and wanted.wanted_level > 0
		and wanted.can_attempt_arrest()
	)


func _on_arrested() -> void:
	_show_outcome(
		"BOOKED",
		"RELEASE PENDING",
		Color(0.25, 0.55, 1.0, 1.0)
	)


func _show_outcome(
	title: String,
	subtitle: String,
	accent: Color
) -> void:
	if _outcome_tween != null and _outcome_tween.is_valid():
		_outcome_tween.kill()
	state_label.text = title
	state_label.add_theme_color_override("font_color", accent)
	outcome_subtitle.text = subtitle
	outcome_subtitle.add_theme_color_override("font_color", accent.lightened(0.3))
	outcome_overlay.visible = true
	outcome_overlay.color.a = 0.0
	state_label.visible = true
	state_label.modulate.a = 0.0
	outcome_subtitle.modulate.a = 0.0
	_outcome_tween = create_tween().set_parallel(true)
	_outcome_tween.tween_property(
		outcome_overlay, "color:a", 0.68, 0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_outcome_tween.tween_property(
		state_label, "modulate:a", 1.0, 0.25
	).set_delay(0.12)
	_outcome_tween.tween_property(
		outcome_subtitle, "modulate:a", 1.0, 0.25
	).set_delay(0.28)


func _hide_outcome() -> void:
	if _outcome_tween != null and _outcome_tween.is_valid():
		_outcome_tween.kill()
	state_label.visible = false
	outcome_overlay.visible = false
