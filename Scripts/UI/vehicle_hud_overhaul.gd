extends "res://Scripts/UI/player_hud.gd"

const HUDTokens := preload("res://Scripts/UI/hud_visual_tokens.gd")
const VEHICLE_ICON := preload("res://Assets/UI/VehicleHUD/vehicle.svg")
const FUEL_ICON := preload("res://Assets/UI/VehicleHUD/fuel.svg")
const DAMAGE_ICON := preload("res://Assets/UI/VehicleHUD/damage.svg")
const HUD_BLUE := HUDTokens.BLUE
const HUD_TEAL := HUDTokens.CYAN
const HUD_AMBER := HUDTokens.AMBER
const HUD_RED := HUDTokens.RED

var _vehicle_identity: Label
var _fuel_fill_style: StyleBoxFlat
var _damage_fill_style: StyleBoxFlat
var _pump_fuel_bar: ProgressBar
var _pump_fuel_value: Label
var _pump_price_value: Label
var _pump_dispensed_value: Label
var _pump_total_value: Label
var _pump_cash_value: Label
var _pump_rate_label: Label


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
	if not visible:
		return
	_pump_fuel_bar.max_value = maxf(capacity, 0.01)
	_pump_fuel_bar.value = current
	_pump_fuel_value.text = "%.1f / %.0f GAL" % [current, capacity]
	_pump_price_value.text = _format_money(price_per_gallon)
	_pump_dispensed_value.text = "%.2f GAL" % dispensed
	_pump_total_value.text = _format_money(total_cost)
	_pump_cash_value.text = _format_money(clean_cash)
	_pump_rate_label.text = "%s / GAL" % _format_money(price_per_gallon)


func _refresh_vehicle_hud() -> void:
	if _vehicle_panel == null or not vehicle_component.is_driving():
		return
	var current := vehicle_component.get_current_vehicle() as BaseVehicle
	if current == null:
		return
	_vehicle_identity.text = (
		current.definition.display_name.to_upper()
		if current.definition != null
		else "VEHICLE"
	)
	_vehicle_speed.text = "%03d" % roundi(
		current.linear_velocity.length() * 2.236936
	)
	var gear := current.get_current_gear()
	_vehicle_gear.text = "R" if gear < 0 else str(gear)
	var condition := current.condition_component
	var fuel_capacity := condition.get_fuel_capacity()
	_vehicle_fuel.max_value = fuel_capacity
	_vehicle_fuel.value = condition.fuel_gallons
	_vehicle_fuel_value.text = "%.1f / %.0f GAL" % [
		condition.fuel_gallons,
		fuel_capacity,
	]
	_vehicle_damage.value = condition.damage
	_vehicle_damage_value.text = "%d / 100" % roundi(condition.damage)
	var fuel_ratio := condition.fuel_gallons / maxf(fuel_capacity, 0.01)
	_fuel_fill_style.bg_color = (
		HUD_RED
		if fuel_ratio <= 0.15
		else HUD_AMBER if fuel_ratio <= 0.3 else HUD_TEAL
	)
	_damage_fill_style.bg_color = (
		HUD_RED if condition.damage >= 50.0 else HUD_AMBER
	)


func _build_vehicle_hud() -> void:
	# Let the base HUD create its shared service prompt, then replace both of
	# its vehicle-specific cards with the refined dashboard presentation.
	super._build_vehicle_hud()
	var legacy_panel := _vehicle_panel
	remove_child(legacy_panel)
	legacy_panel.queue_free()
	var legacy_pump_panel := _fuel_pump_panel
	remove_child(legacy_pump_panel)
	legacy_pump_panel.queue_free()
	_fuel_pump_label = null
	_build_fuel_pump_card()

	_vehicle_panel = PanelContainer.new()
	_vehicle_panel.name = "VehiclePanel"
	_vehicle_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_vehicle_panel.offset_left = -346.0
	_vehicle_panel.offset_top = -244.0
	_vehicle_panel.offset_right = -14.0
	_vehicle_panel.offset_bottom = -14.0
	_vehicle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vehicle_panel.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.025, 0.035, 0.045, 0.96),
			Color(0.72, 0.78, 0.8, 0.9),
			2,
			14,
			Color(0, 0, 0, 0.48),
			10
		)
	)
	add_child(_vehicle_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_vehicle_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var identity_row := HBoxContainer.new()
	identity_row.custom_minimum_size.y = 28
	identity_row.add_theme_constant_override("separation", 8)
	content.add_child(identity_row)
	identity_row.add_child(_icon(VEHICLE_ICON, Vector2(24, 24)))
	_vehicle_identity = Label.new()
	_vehicle_identity.text = "VEHICLE"
	_vehicle_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vehicle_identity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vehicle_identity.add_theme_font_size_override("font_size", 14)
	_vehicle_identity.add_theme_color_override(
		"font_color", Color(0.86, 0.91, 0.94)
	)
	identity_row.add_child(_vehicle_identity)
	var active_label := Label.new()
	active_label.text = "DRIVING"
	active_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	active_label.add_theme_font_size_override("font_size", 10)
	active_label.add_theme_color_override("font_color", HUD_TEAL)
	identity_row.add_child(active_label)
	content.add_child(_divider())

	var readout := HBoxContainer.new()
	readout.custom_minimum_size.y = 66
	readout.add_theme_constant_override("separation", 12)
	content.add_child(readout)
	var speed_stack := VBoxContainer.new()
	speed_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_stack.add_theme_constant_override("separation", -7)
	readout.add_child(speed_stack)
	_vehicle_speed = Label.new()
	_vehicle_speed.text = "000"
	_vehicle_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vehicle_speed.add_theme_font_size_override("font_size", 42)
	_vehicle_speed.add_theme_color_override(
		"font_color", Color(0.95, 0.98, 1.0)
	)
	_vehicle_speed.add_theme_color_override(
		"font_shadow_color", Color(0, 0, 0, 0.8)
	)
	_vehicle_speed.add_theme_constant_override("shadow_offset_x", 2)
	_vehicle_speed.add_theme_constant_override("shadow_offset_y", 2)
	speed_stack.add_child(_vehicle_speed)
	var speed_unit := Label.new()
	speed_unit.text = "MPH"
	speed_unit.add_theme_font_size_override("font_size", 12)
	speed_unit.add_theme_color_override("font_color", HUD_TEAL)
	speed_stack.add_child(speed_unit)

	var gear_card := PanelContainer.new()
	gear_card.custom_minimum_size = Vector2(96, 58)
	gear_card.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.055, 0.07, 0.082, 0.92),
			Color(0.28, 0.34, 0.37, 0.9),
			1,
			9
		)
	)
	readout.add_child(gear_card)
	var gear_row := HBoxContainer.new()
	gear_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gear_row.add_theme_constant_override("separation", 10)
	gear_card.add_child(gear_row)
	var gear_caption := Label.new()
	gear_caption.text = "GEAR"
	gear_caption.add_theme_font_size_override("font_size", 11)
	gear_caption.add_theme_color_override(
		"font_color", Color(0.62, 0.68, 0.71)
	)
	gear_row.add_child(gear_caption)
	_vehicle_gear = Label.new()
	_vehicle_gear.text = "1"
	_vehicle_gear.add_theme_font_size_override("font_size", 25)
	_vehicle_gear.add_theme_color_override(
		"font_color", Color(0.95, 0.98, 1.0)
	)
	gear_row.add_child(_vehicle_gear)

	var fuel_header := _meter_header(FUEL_ICON, "FUEL", HUD_TEAL)
	content.add_child(fuel_header)
	_vehicle_fuel_value = fuel_header.get_meta("value_label") as Label
	_vehicle_fuel = ProgressBar.new()
	_vehicle_fuel.name = "FuelMeter"
	_vehicle_fuel.show_percentage = false
	_vehicle_fuel.custom_minimum_size.y = 15
	_vehicle_fuel.add_theme_stylebox_override(
		"background", _meter_background()
	)
	_fuel_fill_style = _meter_fill(HUD_TEAL)
	_vehicle_fuel.add_theme_stylebox_override("fill", _fuel_fill_style)
	content.add_child(_vehicle_fuel)

	var damage_header := _meter_header(DAMAGE_ICON, "DAMAGE", HUD_AMBER)
	content.add_child(damage_header)
	_vehicle_damage_value = damage_header.get_meta("value_label") as Label
	_vehicle_damage = ProgressBar.new()
	_vehicle_damage.name = "DamageMeter"
	_vehicle_damage.max_value = 100.0
	_vehicle_damage.show_percentage = false
	_vehicle_damage.custom_minimum_size.y = 15
	_vehicle_damage.add_theme_stylebox_override(
		"background", _meter_background()
	)
	_damage_fill_style = _meter_fill(HUD_AMBER)
	_vehicle_damage.add_theme_stylebox_override("fill", _damage_fill_style)
	content.add_child(_vehicle_damage)
	_vehicle_panel.visible = false


func _build_fuel_pump_card() -> void:
	_fuel_pump_panel = PanelContainer.new()
	_fuel_pump_panel.name = "FuelPumpPanel"
	_fuel_pump_panel.set_anchors_preset(Control.PRESET_CENTER)
	_fuel_pump_panel.position = Vector2(-195, -185)
	_fuel_pump_panel.size = Vector2(390, 370)
	_fuel_pump_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuel_pump_panel.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.02, 0.03, 0.04, 0.98),
			Color(0.24, 0.3, 0.34, 0.96),
			2,
			12,
			Color(0, 0, 0, 0.55),
			12
		)
	)
	add_child(_fuel_pump_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_fuel_pump_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	content.add_child(title_row)
	title_row.add_child(_icon(FUEL_ICON, Vector2(22, 22)))
	var title := Label.new()
	title.text = "86 GASOLINE"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	title_row.add_child(title)
	content.add_child(_divider())

	var fuel_header := HBoxContainer.new()
	content.add_child(fuel_header)
	var fuel_caption := Label.new()
	fuel_caption.text = "FUEL"
	fuel_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fuel_caption.add_theme_font_size_override("font_size", 12)
	fuel_caption.add_theme_color_override("font_color", Color(0.76, 0.82, 0.87))
	fuel_header.add_child(fuel_caption)
	_pump_fuel_value = Label.new()
	_pump_fuel_value.text = "-- / -- GAL"
	_pump_fuel_value.add_theme_font_size_override("font_size", 12)
	_pump_fuel_value.add_theme_color_override("font_color", Color(0.88, 0.92, 0.95))
	fuel_header.add_child(_pump_fuel_value)
	_pump_fuel_bar = ProgressBar.new()
	_pump_fuel_bar.name = "PumpFuelMeter"
	_pump_fuel_bar.custom_minimum_size.y = 17
	_pump_fuel_bar.show_percentage = false
	_pump_fuel_bar.add_theme_stylebox_override("background", _meter_background())
	_pump_fuel_bar.add_theme_stylebox_override("fill", _meter_fill(HUD_BLUE))
	content.add_child(_pump_fuel_bar)

	var metrics := GridContainer.new()
	metrics.columns = 2
	metrics.add_theme_constant_override("h_separation", 8)
	metrics.add_theme_constant_override("v_separation", 8)
	content.add_child(metrics)
	var price_card := _pump_metric_card("PRICE / GAL", HUD_TEAL)
	metrics.add_child(price_card)
	_pump_price_value = price_card.get_meta("value_label") as Label
	var dispensed_card := _pump_metric_card("DISPENSED", HUD_BLUE)
	metrics.add_child(dispensed_card)
	_pump_dispensed_value = dispensed_card.get_meta("value_label") as Label
	var total_card := _pump_metric_card("TOTAL COST", HUD_AMBER)
	metrics.add_child(total_card)
	_pump_total_value = total_card.get_meta("value_label") as Label
	var cash_card := _pump_metric_card("CLEAN CASH", HUD_TEAL)
	metrics.add_child(cash_card)
	_pump_cash_value = cash_card.get_meta("value_label") as Label

	var action_card := PanelContainer.new()
	action_card.custom_minimum_size.y = 68
	action_card.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.035, 0.05, 0.065, 0.98),
			HUD_BLUE,
			2,
			8
		)
	)
	content.add_child(action_card)
	var action_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		action_margin.add_theme_constant_override(side, 9)
	action_card.add_child(action_margin)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	action_margin.add_child(action_row)
	var key_card := PanelContainer.new()
	key_card.custom_minimum_size = Vector2(38, 38)
	key_card.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.84, 0.88, 0.91),
			Color(0.97, 0.99, 1.0),
			1,
			5
		)
	)
	action_row.add_child(key_card)
	var key_label := Label.new()
	key_label.text = "F"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 18)
	key_label.add_theme_color_override("font_color", Color(0.04, 0.06, 0.08))
	key_card.add_child(key_label)
	var action_stack := VBoxContainer.new()
	action_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_stack.add_theme_constant_override("separation", 1)
	action_row.add_child(action_stack)
	var action_label := Label.new()
	action_label.text = "HOLD F TO REFUEL"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 15)
	action_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	action_stack.add_child(action_label)
	_pump_rate_label = Label.new()
	_pump_rate_label.text = "-- / GAL"
	_pump_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pump_rate_label.add_theme_font_size_override("font_size", 11)
	_pump_rate_label.add_theme_color_override("font_color", Color(0.7, 0.77, 0.82))
	action_stack.add_child(_pump_rate_label)
	_fuel_pump_panel.visible = false


func _pump_metric_card(caption_text: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(172, 60)
	card.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.045, 0.06, 0.075, 0.98),
			Color(0.16, 0.21, 0.25, 0.95),
			1,
			6
		)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	var caption := Label.new()
	caption.text = caption_text
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", Color(0.72, 0.77, 0.82))
	stack.add_child(caption)
	var value := Label.new()
	value.text = "--"
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", accent)
	stack.add_child(value)
	card.set_meta("value_label", value)
	return card


func _meter_header(
	icon_texture: Texture2D,
	caption_text: String,
	accent: Color
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 18
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon(icon_texture, Vector2(17, 17)))
	var caption := Label.new()
	caption.text = caption_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", accent)
	row.add_child(caption)
	var value := Label.new()
	value.text = "--"
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override(
		"font_color", Color(0.82, 0.86, 0.88)
	)
	row.add_child(value)
	row.set_meta("value_label", value)
	return row


func _icon(texture: Texture2D, minimum_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1
	divider.color = Color(0.3, 0.36, 0.39, 0.75)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _meter_background() -> StyleBoxFlat:
	return HUDTokens.meter_background(3)


func _meter_fill(color: Color) -> StyleBoxFlat:
	return HUDTokens.meter_fill(color, 3)


func _format_money(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		var split := digits.length() - 3
		grouped = ",%s%s" % [digits.substr(split, 3), grouped]
		digits = digits.substr(0, split)
	return "%s$%s%s" % ["-" if amount < 0 else "", digits, grouped]


func _stylebox(
	background: Color,
	border: Color,
	border_width: int,
	corner_radius: int,
	shadow_color: Color = Color.TRANSPARENT,
	shadow_size: int = 0
) -> StyleBoxFlat:
	return HUDTokens.stylebox(
		background,
		border,
		border_width,
		corner_radius,
		shadow_color,
		shadow_size
	)
