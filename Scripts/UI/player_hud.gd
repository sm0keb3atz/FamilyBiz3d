class_name PlayerHUD
extends CanvasLayer

signal daily_report_closed

@export var stats_component_path := NodePath("../Components/StatsComponent")
@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var weapon_component_path := NodePath("../Components/WeaponComponent")
@export var wanted_component_path := NodePath("../Components/WantedComponent")
@export var arrest_component_path := NodePath("../Components/ArrestComponent")
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
@onready var dirty_cash_label := %DirtyCashLabel as Label
@onready var clean_cash_label := %CleanCashLabel as Label
@onready var money_panel := %MoneyPanel as PanelContainer
@onready var transaction_float_layer := %TransactionFloatLayer as Control
@onready var transaction_audio := %TransactionAudio as AudioStreamPlayer
@onready var date_label := %DateLabel as Label
@onready var time_label := %TimeLabel as Label
@onready var daily_report_overlay := %DailyReportOverlay as Control
@onready var report_date_label := %ReportDateLabel as Label
@onready var report_earned_label := %ReportEarnedLabel as Label
@onready var report_spent_label := %ReportSpentLabel as Label
@onready var report_net_label := %ReportNetLabel as Label
@onready var report_continue_button := %ReportContinueButton as Button
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
@onready var market_quote_row := %MarketQuoteRow as HBoxContainer
@onready var heat_title := %HeatTitle as Label
@onready var heat_bar := %HeatBar as ProgressBar
@onready var heat_value := %HeatValue as Label
@onready var wanted_stars := %WantedStars as Label
@onready var escape_panel := %EscapePanel as PanelContainer
@onready var escape_bar := %EscapeBar as ProgressBar
@onready var arrest_panel := %ArrestPanel as PanelContainer
@onready var arrest_bar := %ArrestBar as ProgressBar
@onready var stats := get_node(stats_component_path) as PlayerStatsComponent
@onready var wallet := (
	get_node(wallet_component_path) as PlayerWalletComponent
)
@onready var weapon := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)
@onready var wanted := (
	get_node(wanted_component_path) as PlayerWantedComponent
)
@onready var arrest := (
	get_node(arrest_component_path) as PlayerArrestComponent
)

var _hit_marker_remaining := 0.0
var _detection_debug_visible := false
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
var _transaction_float_index := 0
var _market_price_labels: Dictionary = {}
var _market_products: Array[ProductDefinition] = []
var _market: TerritoryMarketService
var _current_territory_id: StringName = &""
var _territory_refresh_remaining := 0.0
var _territory_control_label: Label


func _ready() -> void:
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
	wanted.wanted_level_changed.connect(_on_wanted_level_changed)
	wanted.escape_progress_changed.connect(_on_escape_progress_changed)
	arrest.arrest_progress_changed.connect(_on_arrest_progress_changed)
	arrest.arrested.connect(_on_arrested)
	feedback_timer.timeout.connect(_on_feedback_timeout)
	report_continue_button.pressed.connect(_close_daily_report)
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
	_territory_refresh_remaining -= delta
	if _territory_refresh_remaining <= 0.0:
		_territory_refresh_remaining = territory_refresh_interval
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
	if (
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
	interaction_prompt.visible = false
	feedback_label.visible = false
	hit_marker.visible = false
	daily_report_overlay.visible = false
	_on_weapon_changed(weapon.get_equipped_weapon())
	_on_wanted_level_changed(0, wanted.wanted_level)
	_on_escape_progress_changed(
		wanted.escape_progress,
		wanted.is_escaping
	)
	_on_arrest_progress_changed(arrest.progress)


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
	_set_label_text(interaction_prompt, prompt)
	var should_be_visible := not prompt.is_empty()
	if interaction_prompt.visible != should_be_visible:
		interaction_prompt.visible = should_be_visible


func show_feedback(message: String, duration := 2.5) -> void:
	feedback_label.text = message
	feedback_label.visible = not message.is_empty()
	feedback_timer.start(maxf(duration, 0.1))


func update_clock(date_text: String, time_text: String) -> void:
	date_label.text = date_text
	time_label.text = time_text


func show_daily_report(report_date: String, earned: int, spent: int) -> void:
	_was_tree_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	report_date_label.text = report_date
	report_earned_label.text = "MONEY EARNED   $%d" % earned
	report_spent_label.text = "MONEY SPENT    $%d" % spent
	var net := earned - spent
	if net > 0:
		report_net_label.text = "PROFIT   +$%d" % net
		report_net_label.modulate = Color(0.32, 0.9, 0.48)
	elif net < 0:
		report_net_label.text = "LOSS   -$%d" % -net
		report_net_label.modulate = Color(1.0, 0.32, 0.25)
	else:
		report_net_label.text = "BREAK EVEN   $0"
		report_net_label.modulate = Color(0.9, 0.9, 0.9)
	daily_report_overlay.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	report_continue_button.grab_focus()


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


func _on_wanted_level_changed(_previous: int, current: int) -> void:
	var display := ""
	for index in PlayerWantedComponent.MAX_WANTED_LEVEL:
		display += "★" if index < current else "☆"
	wanted_stars.text = display
	wanted_stars.visible = current > 0
	if current != 1:
		arrest_panel.visible = false
	if current == 0:
		escape_panel.visible = false


func _on_escape_progress_changed(
	progress: float,
	escaping: bool
) -> void:
	escape_bar.value = clampf(progress, 0.0, 1.0)
	escape_panel.visible = escaping and wanted.wanted_level > 0


func _on_arrest_progress_changed(progress: float) -> void:
	arrest_bar.value = clampf(progress, 0.0, 1.0)
	arrest_panel.visible = progress > 0.0 and wanted.wanted_level == 1


func _on_arrested() -> void:
	show_feedback("ARRESTED", 2.0)
