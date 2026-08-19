extends "res://Scripts/UI/vehicle_hud_overhaul.gd"

const StatusTokens := preload("res://Scripts/UI/hud_visual_tokens.gd")
const HEALTH_ICON := preload("res://Assets/UI/PlayerStats/Icons/heart.svg")
const STAMINA_ICON := preload("res://Assets/UI/PlayerStats/Icons/stamina.svg")
const MONEY_ICON := preload("res://Assets/UI/PlayerStats/Icons/money_hud.svg")
const XP_ICON := preload("res://Assets/UI/PlayerStats/Icons/xp.svg")

const STATUS_TEXT := StatusTokens.TEXT
const STATUS_MUTED := StatusTokens.MUTED
const STATUS_BORDER := StatusTokens.BORDER
const STATUS_DARK := StatusTokens.SURFACE
const DIRTY_ORANGE := StatusTokens.ORANGE
const CLEAN_GREEN := StatusTokens.GREEN
const HEALTH_RED := StatusTokens.RED
const STAMINA_GREEN := StatusTokens.GREEN
const XP_GOLD := StatusTokens.AMBER

var _experience_bar: ProgressBar


func _ready() -> void:
	_build_player_status_hud()
	super._ready()


func _build_player_status_hud() -> void:
	var legacy_stats := get_node_or_null("StatsPanel")
	if legacy_stats != null:
		remove_child(legacy_stats)
		legacy_stats.free()
	var legacy_money := get_node_or_null("MoneyPanel")
	if legacy_money != null:
		remove_child(legacy_money)
		legacy_money.free()

	var cluster := PanelContainer.new()
	cluster.name = "MoneyPanel"
	cluster.unique_name_in_owner = true
	cluster.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cluster.offset_left = 14.0
	cluster.offset_top = -234.0
	cluster.offset_right = 494.0
	cluster.offset_bottom = -14.0
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.add_theme_stylebox_override(
		"panel", StatusTokens.frame_style()
	)
	add_child(cluster)
	money_panel = cluster

	var outer_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		outer_margin.add_theme_constant_override(side, 5)
	cluster.add_child(outer_margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	outer_margin.add_child(stack)
	stack.add_child(_build_money_summary())
	stack.add_child(_build_vitals_summary())


func _build_money_summary() -> Control:
	var card := PanelContainer.new()
	card.name = "MoneySummary"
	card.custom_minimum_size.y = 52
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel", StatusTokens.inset_style()
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	row.add_child(_icon(MONEY_ICON, Vector2(36, 36)))

	var dirty_stack := _money_stack("DIRTY MONEY", DIRTY_ORANGE)
	dirty_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dirty_stack)
	dirty_cash_label = dirty_stack.get_meta("value_label") as Label
	row.add_child(_vertical_divider(36))
	var clean_stack := _money_stack("CLEAN MONEY", CLEAN_GREEN)
	clean_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(clean_stack)
	clean_cash_label = clean_stack.get_meta("value_label") as Label
	return card


func _money_stack(caption_text: String, accent: Color) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -2)
	var caption := Label.new()
	caption.text = caption_text
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", accent)
	stack.add_child(caption)
	var value := Label.new()
	value.text = "$0"
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", accent)
	value.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	value.add_theme_constant_override("shadow_offset_x", 1)
	value.add_theme_constant_override("shadow_offset_y", 1)
	stack.add_child(value)
	stack.set_meta("value_label", value)
	return stack


func _build_vitals_summary() -> Control:
	var card := PanelContainer.new()
	card.name = "StatsPanel"
	card.custom_minimum_size.y = 153
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel", StatusTokens.inset_style()
	)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	card.add_child(margin)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	margin.add_child(body)
	body.add_child(_build_level_sidebar())
	body.add_child(_vertical_divider(132))

	var meters := VBoxContainer.new()
	meters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meters.add_theme_constant_override("separation", 3)
	body.add_child(meters)
	meters.add_child(_build_experience_meter())
	meters.add_child(_horizontal_divider())
	var health_data := _build_vital_meter("HEALTH", HEALTH_ICON, HEALTH_RED)
	meters.add_child(health_data.get("root") as Control)
	health_bar = health_data.get("bar") as ProgressBar
	health_value = health_data.get("value") as Label
	meters.add_child(_horizontal_divider())
	var stamina_data := _build_vital_meter(
		"STAMINA", STAMINA_ICON, STAMINA_GREEN
	)
	meters.add_child(stamina_data.get("root") as Control)
	stamina_bar = stamina_data.get("bar") as ProgressBar
	stamina_value = stamina_data.get("value") as Label
	return card


func _build_level_sidebar() -> Control:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 82
	sidebar.alignment = BoxContainer.ALIGNMENT_CENTER
	sidebar.add_theme_constant_override("separation", 3)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(56, 56)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.025, 0.035, 0.045, 0.98),
			XP_GOLD,
			2,
			28,
			Color(XP_GOLD.r, XP_GOLD.g, XP_GOLD.b, 0.16),
			3
		)
	)
	sidebar.add_child(badge)
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.unique_name_in_owner = true
	level_label.text = "01"
	level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.add_theme_color_override("font_color", STATUS_TEXT)
	level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 1)
	badge.add_child(level_label)
	var caption := Label.new()
	caption.text = "LEVEL"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", XP_GOLD)
	sidebar.add_child(caption)
	var status := Label.new()
	status.text = "PLAYER RANK"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", STATUS_MUTED)
	sidebar.add_child(status)
	return sidebar


func _build_experience_meter() -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 15
	header.add_theme_constant_override("separation", 4)
	stack.add_child(header)
	header.add_child(_icon(XP_ICON, Vector2(14, 14)))
	var caption := Label.new()
	caption.text = "EXPERIENCE"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", STATUS_TEXT)
	header.add_child(caption)
	experience_label = Label.new()
	experience_label.name = "ExperienceLabel"
	experience_label.unique_name_in_owner = true
	experience_label.text = "0 / 100"
	experience_label.add_theme_font_size_override("font_size", 11)
	experience_label.add_theme_color_override("font_color", STATUS_TEXT)
	header.add_child(experience_label)
	_experience_bar = _meter(XP_GOLD, 11)
	_experience_bar.name = "ExperienceBar"
	_experience_bar.unique_name_in_owner = true
	stack.add_child(_experience_bar)
	return stack


func _build_vital_meter(
	caption_text: String,
	icon_texture: Texture2D,
	accent: Color
) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	row.add_theme_constant_override("separation", 7)
	row.add_child(_icon_badge(icon_texture, accent, Vector2(31, 31)))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 2)
	row.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var caption := Label.new()
	caption.text = caption_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", STATUS_TEXT)
	header.add_child(caption)
	var value := Label.new()
	value.text = "100 / 100"
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", STATUS_TEXT)
	header.add_child(value)
	var meter_height := 16.0 if caption_text == "HEALTH" else 15.0
	var bar := _meter(accent, meter_height)
	stack.add_child(bar)
	return {"root": row, "bar": bar, "value": value}


func _meter(accent: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", StatusTokens.meter_background(4))
	bar.add_theme_stylebox_override("fill", StatusTokens.meter_fill(accent, 4))
	_add_meter_ticks(bar)
	return bar


func _add_meter_ticks(bar: ProgressBar) -> void:
	for ratio in [0.25, 0.5, 0.75]:
		var tick := ColorRect.new()
		tick.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		tick.anchor_left = ratio
		tick.anchor_right = ratio
		tick.offset_left = -1.0
		tick.offset_right = 1.0
		tick.color = Color(0.015, 0.022, 0.03, 0.78)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(tick)


func _icon_badge(
	texture: Texture2D,
	accent: Color,
	minimum_size: Vector2
) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = minimum_size
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.025, 0.036, 0.048, 0.98),
			accent.darkened(0.18),
			2,
			roundi(minimum_size.x * 0.5),
			Color(accent.r, accent.g, accent.b, 0.12),
			4
		)
	)
	var center := CenterContainer.new()
	badge.add_child(center)
	center.add_child(_icon(texture, minimum_size * 0.48))
	return badge


func _horizontal_divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1
	divider.color = Color(0.18, 0.23, 0.27, 0.82)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _vertical_divider(height: float) -> ColorRect:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1, height)
	divider.color = Color(0.2, 0.25, 0.29, 0.88)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _on_health_changed(current: float, maximum: float) -> void:
	super._on_health_changed(current, maximum)
	var ratio := current / maxf(maximum, 1.0)
	health_value.add_theme_color_override(
		"font_color", HEALTH_RED if ratio <= 0.3 else STATUS_TEXT
	)


func _on_stamina_changed(current: float, maximum: float) -> void:
	super._on_stamina_changed(current, maximum)


func _on_experience_changed(current: float, required: float) -> void:
	_experience_bar.max_value = maxf(required, 1.0)
	_experience_bar.value = current
	experience_label.text = "%d / %d" % [roundi(current), roundi(required)]


func _on_level_changed(current: int) -> void:
	level_label.text = "%02d" % current


func _set_displayed_dirty_cash(value: float) -> void:
	_displayed_dirty_cash = value
	dirty_cash_label.text = _format_money(roundi(value))


func _set_displayed_clean_cash(value: float) -> void:
	_displayed_clean_cash = value
	clean_cash_label.text = _format_money(roundi(value))
