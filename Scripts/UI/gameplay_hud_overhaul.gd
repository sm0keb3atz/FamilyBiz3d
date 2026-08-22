extends "res://Scripts/UI/player_status_hud_overhaul.gd"

const CLOCK_ICON := preload("res://Assets/UI/PlayerStats/Icons/clock_hud.svg")
const HEAT_SHIELD_ICON := preload("res://Assets/UI/PlayerStats/Icons/heat_shield.svg")
const AMMO_ICON := preload("res://Assets/UI/PlayerStats/Icons/ammo_hud.svg")
const RELOAD_ICON := preload("res://Assets/UI/PlayerStats/Icons/reload_hud.svg")
const INTERACT_ICON := preload("res://Assets/UI/PlayerStats/Icons/interact_hud.svg")
const WEAPON_ICON := preload("res://Assets/UI/Inventory/Icons/weapons.svg")
const HUDMeterEffect := preload("res://Scripts/UI/hud_meter_effect.gd")
const WantedStarDisplay := preload("res://Scripts/UI/wanted_star_display.gd")
const HEAT_PANEL_SHADER := preload("res://Assets/UI/Shaders/heat_panel_fx.gdshader")
const TERRITORY_PANEL_SHADER := preload("res://Assets/UI/Shaders/territory_panel_fx.gdshader")

var _territory_panel_root: PanelContainer
var _territory_panel_material: ShaderMaterial
var _territory_status_panel: PanelContainer
var _territory_layout_tween: Tween
var _territory_target_bottom := 150.0
var _heat_panel_root: PanelContainer
var _heat_panel_material: ShaderMaterial
var _wanted_star_display: HBoxContainer
var _heat_event_tween: Tween
var _heat_layout_tween: Tween
var _heat_target_bottom := 142.0
var _reload_row: HBoxContainer
var _reputation_negative_bar: ProgressBar
var _reputation_positive_bar: ProgressBar


func _ready() -> void:
	_build_remaining_gameplay_hud()
	super._ready()
	_restyle_runtime_hud()
	_update_heat_panel_layout()
	_install_hud_meter_effects()
	_apply_uniform_hud_frame_palette()


func _build_remaining_gameplay_hud() -> void:
	_build_clock_panel()
	_build_territory_panel()
	_build_heat_panel()
	_build_arrest_panel()
	_build_weapon_panel()
	_build_combat_indicators()
	_build_feedback_panel()
	_build_interaction_prompt()
	_build_sale_panel()
	_build_outcome_overlay()


func _remove_legacy_root(node_name: String) -> void:
	var legacy := get_node_or_null(node_name)
	if legacy != null:
		remove_child(legacy)
		legacy.free()


func _build_clock_panel() -> void:
	_remove_legacy_root("TimePanel")
	var panel := _top_panel("TimePanel", 14.0, 14.0, 202.0, 88.0, HUDTokens.AMBER)
	var content := panel.get_meta("content") as VBoxContainer
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	row.add_child(_icon(CLOCK_ICON, Vector2(24, 24)))
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", -2)
	row.add_child(labels)
	date_label = _hud_label("MON • JAN 1 • Y1", 11, HUDTokens.MUTED)
	date_label.name = "DateLabel"
	date_label.unique_name_in_owner = true
	labels.add_child(date_label)
	time_label = _hud_label("8:00 AM", 23, HUDTokens.TEXT)
	time_label.name = "TimeLabel"
	time_label.unique_name_in_owner = true
	time_label.add_theme_color_override("font_shadow_color", HUDTokens.SHADOW)
	time_label.add_theme_constant_override("shadow_offset_x", 1)
	time_label.add_theme_constant_override("shadow_offset_y", 1)
	labels.add_child(time_label)
	court_divider = _hud_divider(HUDTokens.BORDER_SOFT)
	court_divider.name = "CourtDivider"
	court_divider.unique_name_in_owner = true
	court_divider.visible = false
	content.add_child(court_divider)
	court_date_list = VBoxContainer.new()
	court_date_list.name = "CourtDateList"
	court_date_list.unique_name_in_owner = true
	court_date_list.add_theme_constant_override("separation", 5)
	court_date_list.visible = false
	content.add_child(court_date_list)


func _build_territory_panel() -> void:
	_remove_legacy_root("ReputationPanel")
	_territory_panel_root = PanelContainer.new()
	_territory_panel_root.name = "ReputationPanel"
	_territory_panel_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_territory_panel_root.offset_left = -255.0
	_territory_panel_root.offset_top = 14.0
	_territory_panel_root.offset_right = 255.0
	_territory_panel_root.offset_bottom = 150.0
	_territory_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_territory_panel_root.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.011, 0.02, 0.029, 0.965),
			Color(0.24, 0.57, 0.82, 0.86),
			2,
			10,
			Color(0.04, 0.34, 0.62, 0.22),
			10
		)
	)
	add_child(_territory_panel_root)
	var backdrop := ColorRect.new()
	backdrop.name = "TerritoryPanelFX"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color.TRANSPARENT
	_territory_panel_material = ShaderMaterial.new()
	_territory_panel_material.shader = TERRITORY_PANEL_SHADER
	backdrop.material = _territory_panel_material
	_territory_panel_root.add_child(backdrop)
	var margin := _margin(12, 7, 12, 9)
	margin.name = "Margin"
	_territory_panel_root.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.name = "TerritoryHeader"
	header.custom_minimum_size.y = 22
	content.add_child(header)
	reputation_title = _hud_label("HOOD EAST", 17, HUDTokens.TEXT)
	reputation_title.name = "ReputationTitle"
	reputation_title.unique_name_in_owner = true
	reputation_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reputation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reputation_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reputation_title.clip_text = true
	reputation_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(reputation_title)
	reputation_value = _hud_label("0 / 100", 11, HUDTokens.TEXT)
	reputation_value.name = "ReputationValue"
	reputation_value.unique_name_in_owner = true
	reputation_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reputation_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reputation_value.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	reputation_value.add_theme_constant_override("shadow_offset_x", 1)
	reputation_value.add_theme_constant_override("shadow_offset_y", 1)
	reputation_bar = _hud_meter(HUDTokens.BLUE, 26)
	reputation_bar.name = "ReputationBar"
	reputation_bar.unique_name_in_owner = true
	reputation_bar.min_value = -100.0
	reputation_bar.add_theme_stylebox_override(
		"background",
		_stylebox(
			Color(0.015, 0.025, 0.034, 1.0),
			Color(0.24, 0.33, 0.4, 0.95),
			1,
			6
		)
	)
	reputation_bar.add_theme_stylebox_override(
		"fill", _stylebox(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	)
	content.add_child(reputation_bar)
	reputation_value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reputation_value.z_index = 4
	reputation_bar.add_child(reputation_value)
	_build_split_reputation_meter()
	var zero := ColorRect.new()
	zero.name = "ZeroMarker"
	zero.anchor_left = 0.5
	zero.anchor_right = 0.5
	zero.anchor_bottom = 1.0
	zero.offset_left = -2.0
	zero.offset_right = 2.0
	zero.color = Color(0.93, 0.96, 0.98, 0.82)
	zero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zero.z_index = 2
	reputation_bar.add_child(zero)
	_add_reputation_tick(reputation_bar, 0.25)
	_add_reputation_tick(reputation_bar, 0.75)
	_territory_status_panel = PanelContainer.new()
	_territory_status_panel.name = "TerritoryStatus"
	_territory_status_panel.custom_minimum_size.y = 22
	_territory_status_panel.visible = false
	_territory_status_panel.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.055, 0.045, 0.015, 0.82),
			Color(0.9, 0.63, 0.12, 0.42),
			1,
			5
		)
	)
	content.add_child(_territory_status_panel)
	market_quote_row = HBoxContainer.new()
	market_quote_row.name = "MarketQuoteRow"
	market_quote_row.unique_name_in_owner = true
	market_quote_row.custom_minimum_size.y = 58
	market_quote_row.add_theme_constant_override("separation", 8)
	market_quote_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(market_quote_row)


func _build_heat_panel() -> void:
	_remove_legacy_root("HeatPanel")
	_heat_panel_root = PanelContainer.new()
	_heat_panel_root.name = "HeatPanel"
	_heat_panel_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_heat_panel_root.offset_left = -468.0
	_heat_panel_root.offset_top = 14.0
	_heat_panel_root.offset_right = -14.0
	_heat_panel_root.offset_bottom = 142.0
	_heat_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat_panel_root.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.012, 0.015, 0.018, 0.965),
			Color(1.0, 0.63, 0.03, 0.92),
			2,
			10,
			Color(1.0, 0.35, 0.01, 0.22),
			11
		)
	)
	add_child(_heat_panel_root)
	var backdrop := ColorRect.new()
	backdrop.name = "HeatPanelFX"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color.TRANSPARENT
	_heat_panel_material = ShaderMaterial.new()
	_heat_panel_material.shader = HEAT_PANEL_SHADER
	backdrop.material = _heat_panel_material
	_heat_panel_root.add_child(backdrop)
	var decor := Control.new()
	decor.name = "HeatDecor"
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat_panel_root.add_child(decor)
	var top_rail := ColorRect.new()
	top_rail.name = "TopRail"
	top_rail.position = Vector2(18, 0)
	top_rail.size = Vector2(148, 3)
	top_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_rail.color = HUDTokens.AMBER
	decor.add_child(top_rail)
	var warning_marks := _hud_label("///", 16, HUDTokens.AMBER)
	warning_marks.name = "WarningMarks"
	warning_marks.position = Vector2(393, 7)
	warning_marks.size = Vector2(44, 18)
	warning_marks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	decor.add_child(warning_marks)
	var margin := _margin(14, 11, 14, 12)
	margin.name = "Margin"
	_heat_panel_root.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 47
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(47, 47)
	badge.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.075, 0.05, 0.008, 0.92),
			Color(1.0, 0.67, 0.03, 0.72),
			1,
			7
		)
	)
	header.add_child(badge)
	var badge_margin := _margin(4, 4, 4, 4)
	badge.add_child(badge_margin)
	badge_margin.add_child(_icon(HEAT_SHIELD_ICON, Vector2(39, 39)))
	var header_stack := VBoxContainer.new()
	header_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_stack.add_theme_constant_override("separation", -1)
	header.add_child(header_stack)
	var eyebrow := _hud_label("PUBLIC SAFETY NETWORK", 9, HUDTokens.AMBER.darkened(0.12))
	eyebrow.name = "HeatEyebrow"
	header_stack.add_child(eyebrow)
	heat_title = _hud_label("HOOD EAST — HEAT", 15, HUDTokens.TEXT)
	heat_title.name = "HeatTitle"
	heat_title.unique_name_in_owner = true
	heat_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heat_title.clip_text = true
	header_stack.add_child(heat_title)
	var heat_readout := PanelContainer.new()
	heat_readout.custom_minimum_size = Vector2(70, 37)
	heat_readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heat_readout.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.11, 0.055, 0.005, 0.9),
			Color(1.0, 0.49, 0.03, 0.75),
			1,
			5
		)
	)
	header.add_child(heat_readout)
	heat_value = _hud_label("0 / 100", 12, HUDTokens.AMBER)
	heat_value.name = "HeatValue"
	heat_value.unique_name_in_owner = true
	heat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heat_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heat_readout.add_child(heat_value)
	heat_bar = _hud_meter(HUDTokens.ORANGE, 20)
	heat_bar.name = "HeatBar"
	heat_bar.unique_name_in_owner = true
	content.add_child(heat_bar)
	var divider := _hud_divider(Color(1.0, 0.62, 0.02, 0.34))
	divider.name = "HeatDivider"
	content.add_child(divider)
	police_status = _hud_label("POLICE SEARCHING", 14, HUDTokens.AMBER)
	police_status.name = "PoliceStatus"
	police_status.unique_name_in_owner = true
	police_status.custom_minimum_size.y = 26
	police_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	police_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	police_status.add_theme_color_override("font_shadow_color", Color(1.0, 0.28, 0.0, 0.5))
	police_status.add_theme_constant_override("shadow_offset_y", 1)
	police_status.visible = false
	content.add_child(police_status)
	wanted_stars = _hud_label("☆☆☆☆☆☆", 1, Color.TRANSPARENT)
	wanted_stars.name = "WantedStars"
	wanted_stars.unique_name_in_owner = true
	wanted_stars.custom_minimum_size.y = 50
	wanted_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wanted_stars.add_theme_constant_override("outline_size", 0)
	wanted_stars.visible = false
	content.add_child(wanted_stars)
	_wanted_star_display = WantedStarDisplay.new() as HBoxContainer
	_wanted_star_display.name = "WantedStarDisplay"
	_wanted_star_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wanted_stars.add_child(_wanted_star_display)
	escape_panel = _build_escape_panel()
	content.add_child(escape_panel)


func _build_escape_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "EscapePanel"
	panel.unique_name_in_owner = true
	panel.visible = false
	panel.add_theme_stylebox_override(
		"panel",
		_stylebox(
			Color(0.055, 0.04, 0.012, 0.93),
			Color(1.0, 0.64, 0.03, 0.72),
			1,
			7,
			Color(1.0, 0.35, 0.0, 0.14),
			5
		)
	)
	var margin := _margin(10, 7, 10, 8)
	margin.name = "Margin"
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)
	var label := _hud_label("EVADING POLICE  •  BREAK LINE OF SIGHT", 11, HUDTokens.AMBER)
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)
	escape_bar = _hud_meter(HUDTokens.AMBER, 15)
	escape_bar.name = "EscapeBar"
	escape_bar.unique_name_in_owner = true
	escape_bar.max_value = 1.0
	content.add_child(escape_bar)
	escape_time = _hud_label("8.0s", 10, HUDTokens.TEXT)
	escape_time.name = "EscapeTime"
	escape_time.unique_name_in_owner = true
	escape_time.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escape_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	escape_bar.add_child(escape_time)
	return panel


func _build_arrest_panel() -> void:
	_remove_legacy_root("ArrestPanel")
	arrest_panel = PanelContainer.new()
	arrest_panel.name = "ArrestPanel"
	arrest_panel.unique_name_in_owner = true
	arrest_panel.set_anchors_preset(Control.PRESET_CENTER)
	arrest_panel.offset_left = -150.0
	arrest_panel.offset_top = 52.0
	arrest_panel.offset_right = 150.0
	arrest_panel.offset_bottom = 108.0
	arrest_panel.visible = false
	arrest_panel.add_theme_stylebox_override(
		"panel", _card_style(HUDTokens.BLUE, 7, 1, 6)
	)
	add_child(arrest_panel)
	var margin := _margin(10, 7, 10, 7)
	arrest_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	var label := _hud_label("ARREST IN PROGRESS", 12, HUDTokens.BLUE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)
	arrest_bar = _hud_meter(HUDTokens.BLUE, 15)
	arrest_bar.name = "ArrestBar"
	arrest_bar.unique_name_in_owner = true
	arrest_bar.max_value = 1.0
	content.add_child(arrest_bar)


func _build_weapon_panel() -> void:
	_remove_legacy_root("WeaponPanel")
	weapon_panel = PanelContainer.new()
	weapon_panel.name = "WeaponPanel"
	weapon_panel.unique_name_in_owner = true
	weapon_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_panel.offset_left = -188.0
	weapon_panel.offset_top = -102.0
	weapon_panel.offset_right = -14.0
	weapon_panel.offset_bottom = -14.0
	weapon_panel.add_theme_stylebox_override(
		"panel", _card_style(HUDTokens.AMBER)
	)
	add_child(weapon_panel)
	var margin := _margin(10, 8, 10, 8)
	weapon_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	content.add_child(header)
	header.add_child(_icon(WEAPON_ICON, Vector2(16, 16)))
	weapon_name_label = _hud_label("UNARMED", 13, HUDTokens.AMBER)
	weapon_name_label.name = "WeaponNameLabel"
	weapon_name_label.unique_name_in_owner = true
	weapon_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(weapon_name_label)
	var ammo_row := HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 7)
	content.add_child(ammo_row)
	ammo_row.add_child(_icon(AMMO_ICON, Vector2(19, 19)))
	ammo_label = _hud_label("--", 23, HUDTokens.TEXT)
	ammo_label.name = "AmmoLabel"
	ammo_label.unique_name_in_owner = true
	ammo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_row.add_child(ammo_label)
	_reload_row = HBoxContainer.new()
	_reload_row.alignment = BoxContainer.ALIGNMENT_END
	_reload_row.add_theme_constant_override("separation", 5)
	_reload_row.visible = false
	content.add_child(_reload_row)
	_reload_row.add_child(_icon(RELOAD_ICON, Vector2(13, 13)))
	reload_label = _hud_label("RELOADING", 11, HUDTokens.CYAN)
	reload_label.name = "ReloadLabel"
	reload_label.unique_name_in_owner = true
	_reload_row.add_child(reload_label)


func _build_combat_indicators() -> void:
	_remove_legacy_root("Crosshair")
	crosshair = Label.new()
	crosshair.name = "Crosshair"
	crosshair.unique_name_in_owner = true
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-12, -14)
	crosshair.size = Vector2(24, 28)
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 18)
	crosshair.add_theme_color_override("font_color", Color(0.94, 0.98, 1, 0.92))
	crosshair.add_theme_color_override("font_shadow_color", HUDTokens.SHADOW)
	crosshair.add_theme_constant_override("shadow_offset_x", 1)
	crosshair.add_theme_constant_override("shadow_offset_y", 1)
	crosshair.visible = false
	add_child(crosshair)
	_remove_legacy_root("HitMarker")
	hit_marker = ReticleHitmarker.new()
	hit_marker.name = "HitMarker"
	hit_marker.unique_name_in_owner = true
	hit_marker.visible = false
	add_child(hit_marker)


func _build_feedback_panel() -> void:
	_remove_legacy_root("FeedbackPanel")
	feedback_panel = PanelContainer.new()
	feedback_panel.name = "FeedbackPanel"
	feedback_panel.unique_name_in_owner = true
	feedback_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	feedback_panel.offset_left = -245.0
	feedback_panel.offset_top = -286.0
	feedback_panel.offset_right = 245.0
	feedback_panel.offset_bottom = -230.0
	feedback_panel.visible = false
	feedback_panel.add_theme_stylebox_override(
		"panel", _card_style(HUDTokens.BLUE)
	)
	add_child(feedback_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	feedback_panel.add_child(row)
	feedback_accent = ColorRect.new()
	feedback_accent.name = "FeedbackAccent"
	feedback_accent.unique_name_in_owner = true
	feedback_accent.custom_minimum_size.x = 4
	feedback_accent.color = HUDTokens.BLUE
	row.add_child(feedback_accent)
	var margin := _margin(12, 7, 12, 7)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(margin)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	feedback_icon = _hud_label("i", 18, HUDTokens.BLUE)
	feedback_icon.name = "FeedbackIcon"
	feedback_icon.unique_name_in_owner = true
	feedback_icon.custom_minimum_size.x = 24
	feedback_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(feedback_icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", -1)
	content.add_child(text)
	feedback_title = _hud_label("NOTICE", 10, HUDTokens.BLUE)
	feedback_title.name = "FeedbackTitle"
	feedback_title.unique_name_in_owner = true
	text.add_child(feedback_title)
	feedback_label = _hud_label("Feedback", 14, HUDTokens.TEXT)
	feedback_label.name = "FeedbackLabel"
	feedback_label.unique_name_in_owner = true
	feedback_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(feedback_label)


func _build_interaction_prompt() -> void:
	_remove_legacy_root("InteractionPrompt")
	interaction_prompt = Label.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.unique_name_in_owner = true
	interaction_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_prompt.offset_left = -210.0
	interaction_prompt.offset_top = -204.0
	interaction_prompt.offset_right = 210.0
	interaction_prompt.offset_bottom = -160.0
	interaction_prompt.text = "E — INTERACT"
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_prompt.add_theme_font_size_override("font_size", 16)
	interaction_prompt.add_theme_color_override("font_color", HUDTokens.TEXT)
	var style := _stylebox(HUDTokens.SURFACE, HUDTokens.CYAN.darkened(0.35), 1, 7, HUDTokens.SHADOW, 6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	interaction_prompt.add_theme_stylebox_override("normal", style)
	interaction_prompt.visible = false
	add_child(interaction_prompt)


func _build_sale_panel() -> void:
	_remove_legacy_root("SaleInteractionPanel")
	sale_interaction_panel = PanelContainer.new()
	sale_interaction_panel.name = "SaleInteractionPanel"
	sale_interaction_panel.unique_name_in_owner = true
	sale_interaction_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sale_interaction_panel.offset_left = -252.0
	sale_interaction_panel.offset_top = -232.0
	sale_interaction_panel.offset_right = 252.0
	sale_interaction_panel.offset_bottom = -148.0
	sale_interaction_panel.visible = false
	sale_interaction_panel.add_theme_stylebox_override(
		"panel", _card_style(HUDTokens.GREEN, 9, 2, 8)
	)
	add_child(sale_interaction_panel)
	var margin := _margin(11, 8, 11, 8)
	sale_interaction_panel.add_child(margin)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	margin.add_child(content)
	sale_product_icon = TextureRect.new()
	sale_product_icon.name = "SaleProductIcon"
	sale_product_icon.unique_name_in_owner = true
	sale_product_icon.custom_minimum_size = Vector2(48, 48)
	sale_product_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sale_product_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(sale_product_icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	content.add_child(info)
	info.add_child(_hud_label("CUSTOMER ORDER", 10, HUDTokens.MUTED))
	sale_product_name = _hud_label("PRODUCT", 17, HUDTokens.TEXT)
	sale_product_name.name = "SaleProductName"
	sale_product_name.unique_name_in_owner = true
	sale_product_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(sale_product_name)
	content.add_child(_vertical_line(48))
	var action := PanelContainer.new()
	action.custom_minimum_size = Vector2(124, 46)
	action.add_theme_stylebox_override(
		"panel", _stylebox(HUDTokens.SURFACE_SOFT, HUDTokens.GREEN.darkened(0.45), 1, 6)
	)
	content.add_child(action)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 6)
	action.add_child(action_row)
	action_row.add_child(_icon(INTERACT_ICON, Vector2(24, 24)))
	var action_label := _hud_label("COMPLETE", 11, HUDTokens.GREEN)
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_row.add_child(action_label)
	sale_price = _hud_label("$0", 21, HUDTokens.GREEN)
	sale_price.name = "SalePrice"
	sale_price.unique_name_in_owner = true
	sale_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(sale_price)


func _build_outcome_overlay() -> void:
	_remove_legacy_root("OutcomeOverlay")
	outcome_overlay = ColorRect.new()
	outcome_overlay.name = "OutcomeOverlay"
	outcome_overlay.unique_name_in_owner = true
	outcome_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outcome_overlay.color = Color(0.008, 0.014, 0.021, 0.78)
	outcome_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outcome_overlay.visible = false
	outcome_overlay.z_index = 100
	add_child(outcome_overlay)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-230, -72)
	card.size = Vector2(460, 144)
	card.add_theme_stylebox_override(
		"panel", _stylebox(HUDTokens.SURFACE, HUDTokens.RED, 2, 9, Color(HUDTokens.RED.r, HUDTokens.RED.g, HUDTokens.RED.b, 0.2), 14)
	)
	outcome_overlay.add_child(card)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	card.add_child(stack)
	state_label = _hud_label("SMOKED", 38, HUDTokens.RED)
	state_label.name = "StateLabel"
	state_label.unique_name_in_owner = true
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(state_label)
	outcome_subtitle = _hud_label("PARAMEDICS ARE EN ROUTE", 14, HUDTokens.TEXT)
	outcome_subtitle.name = "OutcomeSubtitle"
	outcome_subtitle.unique_name_in_owner = true
	outcome_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(outcome_subtitle)


func _add_court_date_row(legal_case: LegalCase) -> void:
	var card := PanelContainer.new()
	card.name = "CourtDateRow"
	card.add_theme_stylebox_override(
		"panel", HUDTokens.inset_style(4)
	)
	var margin := _margin(6, 4, 6, 4)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	margin.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	var case_label := _hud_label(
		"CASE %s" % legal_case.case_id.trim_prefix("CASE-"),
		9,
		HUDTokens.BLUE
	)
	case_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(case_label)
	heading.add_child(_hud_label(
		legal.get_hearing_countdown_text(legal_case).to_upper(),
		9,
		HUDTokens.AMBER
	))
	stack.add_child(_hud_label(
		_get_compact_hearing_datetime(legal_case),
		10,
		HUDTokens.TEXT
	))
	court_date_list.add_child(card)


func _build_market_quote_row() -> void:
	for child in market_quote_row.get_children():
		child.queue_free()
	_market_price_labels.clear()
	for product in _market_products:
		var accent := _get_product_accent(product)
		var chip := PanelContainer.new()
		chip.name = "%sQuote" % product.get_short_display_name().replace(" ", "")
		chip.custom_minimum_size.y = 58
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.tooltip_text = product.display_name
		chip.add_theme_stylebox_override(
			"panel",
			_stylebox(
				Color(0.022, 0.034, 0.045, 0.97),
				Color(accent.r, accent.g, accent.b, 0.55),
				1,
				7,
				Color(accent.r, accent.g, accent.b, 0.1),
				3
			)
		)
		market_quote_row.add_child(chip)
		var chip_margin := _margin(6, 4, 8, 4)
		chip.add_child(chip_margin)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		chip_margin.add_child(row)
		var icon_badge := PanelContainer.new()
		icon_badge.custom_minimum_size = Vector2(46, 46)
		icon_badge.add_theme_stylebox_override(
			"panel",
			_stylebox(
				Color(accent.r * 0.09, accent.g * 0.09, accent.b * 0.09, 0.96),
				Color(accent.r, accent.g, accent.b, 0.34),
				1,
				6
			)
		)
		row.add_child(icon_badge)
		var icon_margin := _margin(3, 3, 3, 3)
		icon_badge.add_child(icon_margin)
		var icon := TextureRect.new()
		icon.texture = product.icon
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_margin.add_child(icon)
		var label_stack := VBoxContainer.new()
		label_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		label_stack.add_theme_constant_override("separation", -2)
		row.add_child(label_stack)
		var product_name := _hud_label(
			product.get_short_display_name().to_upper(),
			10,
			accent
		)
		product_name.clip_text = true
		product_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label_stack.add_child(product_name)
		var price := _hud_label("$—/G", 17, HUDTokens.TEXT)
		price.add_theme_color_override("font_shadow_color", HUDTokens.SHADOW)
		price.add_theme_constant_override("shadow_offset_x", 1)
		price.add_theme_constant_override("shadow_offset_y", 1)
		label_stack.add_child(price)
		_market_price_labels[product.product_id] = price


func _get_product_accent(product: ProductDefinition) -> Color:
	match product.drug_type:
		ProductDefinition.DrugType.WEED:
			return HUDTokens.GREEN
		ProductDefinition.DrugType.COKE:
			return HUDTokens.CYAN
		ProductDefinition.DrugType.FENT:
			return HUDTokens.ORANGE
	return HUDTokens.AMBER


func _refresh_territory() -> void:
	super._refresh_territory()
	reputation_title.text = reputation_title.text.trim_suffix(" — REPUTATION")
	reputation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh_split_reputation_meter()
	if _territory_panel_material != null:
		_territory_panel_material.set_shader_parameter(
			"influence",
			clampf(float(reputation_bar.value) / 100.0, -1.0, 1.0)
		)
	if _territory_control_label != null:
		if _territory_control_label.get_parent() != _territory_status_panel:
			var old_parent := _territory_control_label.get_parent()
			if old_parent != null:
				old_parent.remove_child(_territory_control_label)
			_territory_status_panel.add_child(_territory_control_label)
		_territory_control_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_territory_control_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_territory_control_label.clip_text = true
		_territory_control_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_territory_control_label.add_theme_font_size_override("font_size", 9)
		_territory_control_label.add_theme_color_override("font_color", HUDTokens.AMBER)
		var show_war_status := (
			not _territory_control_label.text.is_empty()
			and _is_current_territory_gang_war_active()
		)
		_territory_control_label.visible = show_war_status
		_territory_status_panel.visible = _territory_control_label.visible
		_update_territory_panel_layout(show_war_status)
	_update_heat_panel_layout()


func _is_current_territory_gang_war_active() -> bool:
	var encounter := get_tree().get_first_node_in_group(
		&"territory_encounter"
	) as TerritoryEncounterController
	return (
		encounter != null
		and encounter.is_encounter_active()
		and encounter.get_active_territory_id() == _current_territory_id
		and encounter.get_active_encounter_type()
		== TerritoryEncounterController.EncounterType.GANG_WAR
	)


func _update_territory_panel_layout(expanded: bool) -> void:
	if _territory_panel_root == null:
		return
	var target_bottom := 177.0 if expanded else 150.0
	if is_equal_approx(_territory_target_bottom, target_bottom):
		return
	_territory_target_bottom = target_bottom
	if _territory_layout_tween != null and _territory_layout_tween.is_valid():
		_territory_layout_tween.kill()
	if not is_inside_tree():
		_territory_panel_root.offset_bottom = target_bottom
		return
	_territory_layout_tween = create_tween()
	_territory_layout_tween.tween_property(
		_territory_panel_root,
		"offset_bottom",
		target_bottom,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _add_reputation_tick(bar: ProgressBar, anchor: float) -> void:
	var tick := ColorRect.new()
	tick.name = "ReputationTick%d" % roundi(anchor * 100.0)
	tick.anchor_left = anchor
	tick.anchor_right = anchor
	tick.anchor_bottom = 1.0
	tick.offset_left = -0.5
	tick.offset_right = 0.5
	tick.offset_top = 5.0
	tick.offset_bottom = -5.0
	tick.color = Color(0.82, 0.9, 0.96, 0.28)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.z_index = 3
	bar.add_child(tick)


func _build_split_reputation_meter() -> void:
	_reputation_negative_bar = _reputation_half(
		"NegativeReputation", HUDTokens.RED, true
	)
	_reputation_negative_bar.anchor_left = 0.0
	_reputation_negative_bar.anchor_right = 0.5
	_reputation_negative_bar.anchor_bottom = 1.0
	_reputation_negative_bar.offset_left = 2.0
	_reputation_negative_bar.offset_top = 2.0
	_reputation_negative_bar.offset_right = -2.0
	_reputation_negative_bar.offset_bottom = -2.0
	reputation_bar.add_child(_reputation_negative_bar)
	_reputation_positive_bar = _reputation_half(
		"PositiveReputation", HUDTokens.BLUE, false
	)
	_reputation_positive_bar.anchor_left = 0.5
	_reputation_positive_bar.anchor_right = 1.0
	_reputation_positive_bar.anchor_bottom = 1.0
	_reputation_positive_bar.offset_left = 2.0
	_reputation_positive_bar.offset_top = 2.0
	_reputation_positive_bar.offset_right = -2.0
	_reputation_positive_bar.offset_bottom = -2.0
	reputation_bar.add_child(_reputation_positive_bar)


func _reputation_half(
	node_name: String,
	accent: Color,
	reverse_fill: bool
) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.name = node_name
	meter.min_value = 0.0
	meter.max_value = 100.0
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.fill_mode = (
		ProgressBar.FILL_END_TO_BEGIN
		if reverse_fill
		else ProgressBar.FILL_BEGIN_TO_END
	)
	meter.add_theme_stylebox_override(
		"background", _stylebox(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	)
	var fill := _stylebox(accent.darkened(0.08), accent, 1, 5)
	if reverse_fill:
		fill.corner_radius_top_right = 0
		fill.corner_radius_bottom_right = 0
	else:
		fill.corner_radius_top_left = 0
		fill.corner_radius_bottom_left = 0
	meter.add_theme_stylebox_override("fill", fill)
	return meter


func _refresh_split_reputation_meter() -> void:
	if _reputation_negative_bar == null or _reputation_positive_bar == null:
		return
	var reputation := clampf(reputation_bar.value, -100.0, 100.0)
	_reputation_negative_bar.value = maxf(-reputation, 0.0)
	_reputation_positive_bar.value = maxf(reputation, 0.0)
	if reputation < 0.0:
		reputation_value.add_theme_color_override("font_color", HUDTokens.RED)
	elif reputation > 0.0:
		reputation_value.add_theme_color_override("font_color", HUDTokens.BLUE)
	else:
		reputation_value.add_theme_color_override("font_color", HUDTokens.MUTED)


func _on_wanted_level_changed(previous: int, current: int) -> void:
	super._on_wanted_level_changed(previous, current)
	if _wanted_star_display != null:
		_wanted_star_display.call("set_level", current, current > previous)
	if _heat_panel_material != null:
		_heat_panel_material.set_shader_parameter(
			"alert_level",
			clampf(float(current) / float(PlayerWantedComponent.MAX_WANTED_LEVEL), 0.0, 1.0)
		)
	if current > previous:
		_flash_heat_panel()
	_update_heat_panel_layout()


func _on_escape_progress_changed(progress: float, escaping: bool) -> void:
	super._on_escape_progress_changed(progress, escaping)
	_update_heat_panel_layout()


func _on_police_phase_changed(previous: int, current: int) -> void:
	super._on_police_phase_changed(previous, current)
	var phase_color := HUDTokens.ORANGE
	match current:
		PoliceCoordinatorData.WantedPhase.INVESTIGATING:
			phase_color = HUDTokens.AMBER
		PoliceCoordinatorData.WantedPhase.OBSERVED:
			phase_color = HUDTokens.RED
		PoliceCoordinatorData.WantedPhase.SEARCHING:
			phase_color = HUDTokens.ORANGE
		PoliceCoordinatorData.WantedPhase.EVADING:
			phase_color = HUDTokens.AMBER
		PoliceCoordinatorData.WantedPhase.SURRENDERING:
			phase_color = HUDTokens.BLUE
	if police_status != null:
		police_status.add_theme_color_override("font_color", phase_color)
	_update_heat_panel_layout()


func _apply_feedback_color(color: Color) -> void:
	super._apply_feedback_color(color)
	_apply_uniform_panel_style(feedback_panel, false)


func _on_weapon_changed(definition: WeaponDefinition) -> void:
	super._on_weapon_changed(definition)
	if _reload_row != null:
		_reload_row.visible = false


func _on_reload_started() -> void:
	super._on_reload_started()
	_reload_row.visible = true


func _on_reload_completed() -> void:
	super._on_reload_completed()
	_reload_row.visible = false


func _build_vehicle_hud() -> void:
	super._build_vehicle_hud()
	_restyle_vehicle_elements()


func _update_heat_panel_layout() -> void:
	if _heat_panel_root == null:
		return
	var target_bottom := 142.0
	if police_status != null and police_status.visible:
		target_bottom = 177.0
	if wanted_stars != null and wanted_stars.visible:
		target_bottom = 234.0
	if escape_panel != null and escape_panel.visible:
		target_bottom = 305.0
	if is_equal_approx(_heat_target_bottom, target_bottom):
		return
	_heat_target_bottom = target_bottom
	if _heat_layout_tween != null and _heat_layout_tween.is_valid():
		_heat_layout_tween.kill()
	if not is_inside_tree():
		_heat_panel_root.offset_bottom = target_bottom
		return
	_heat_layout_tween = create_tween()
	_heat_layout_tween.tween_property(
		_heat_panel_root,
		"offset_bottom",
		target_bottom,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _flash_heat_panel() -> void:
	if _heat_panel_material == null:
		return
	if _heat_event_tween != null and _heat_event_tween.is_valid():
		_heat_event_tween.kill()
	_heat_panel_material.set_shader_parameter("event_flash", 1.0)
	_heat_panel_root.modulate = Color(1.06, 1.06, 1.06, 1.0)
	_heat_event_tween = create_tween().set_parallel(true)
	_heat_event_tween.tween_method(
		func(value: float) -> void:
			_heat_panel_material.set_shader_parameter("event_flash", value),
		1.0,
		0.0,
		0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_heat_event_tween.tween_property(
		_heat_panel_root,
		"modulate",
		Color.WHITE,
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _install_hud_meter_effects() -> void:
	_experience_bar.custom_minimum_size.y = 11.0
	health_bar.custom_minimum_size.y = 16.0
	stamina_bar.custom_minimum_size.y = 15.0
	reputation_bar.custom_minimum_size.y = 26.0
	heat_bar.custom_minimum_size.y = 20.0
	escape_bar.custom_minimum_size.y = 15.0
	arrest_bar.custom_minimum_size.y = 15.0
	_vehicle_fuel.custom_minimum_size.y = 15.0
	_vehicle_damage.custom_minimum_size.y = 15.0
	_pump_fuel_bar.custom_minimum_size.y = 17.0
	reputation_bar.clip_contents = true
	_attach_meter_effect(
		_experience_bar,
		HUDTokens.AMBER,
		HUDMeterEffect.PROFILE_EXPERIENCE
	)
	_attach_meter_effect(
		health_bar,
		HUDTokens.RED,
		HUDMeterEffect.PROFILE_HEALTH
	)
	_attach_meter_effect(
		stamina_bar,
		HUDTokens.GREEN,
		HUDMeterEffect.PROFILE_STAMINA
	)
	_attach_meter_effect(
		_reputation_negative_bar,
		HUDTokens.RED,
		HUDMeterEffect.PROFILE_REPUTATION,
		true
	)
	_attach_meter_effect(
		_reputation_positive_bar,
		HUDTokens.BLUE,
		HUDMeterEffect.PROFILE_REPUTATION
	)
	_attach_meter_effect(
		heat_bar,
		HUDTokens.ORANGE,
		HUDMeterEffect.PROFILE_HEAT
	)
	_attach_meter_effect(
		escape_bar,
		HUDTokens.AMBER,
		HUDMeterEffect.PROFILE_ESCAPE
	)
	_attach_meter_effect(
		arrest_bar,
		HUDTokens.BLUE,
		HUDMeterEffect.PROFILE_ARREST
	)
	_attach_meter_effect(
		_vehicle_fuel,
		HUDTokens.CYAN,
		HUDMeterEffect.PROFILE_VEHICLE_FUEL
	)
	_attach_meter_effect(
		_vehicle_damage,
		HUDTokens.AMBER,
		HUDMeterEffect.PROFILE_VEHICLE_DAMAGE
	)
	_attach_meter_effect(
		_pump_fuel_bar,
		HUDTokens.CYAN,
		HUDMeterEffect.PROFILE_FUEL_PUMP
	)


func _attach_meter_effect(
	bar: ProgressBar,
	accent: Color,
	profile: StringName,
	reverse_fill: bool = false
) -> void:
	if bar == null:
		return
	var effect_name := "%sFX" % bar.name
	if bar.get_node_or_null(effect_name) != null:
		return
	bar.clip_contents = true
	var effect := HUDMeterEffect.new()
	bar.add_child(effect)
	effect.setup(bar, accent, profile, reverse_fill)
	bar.move_child(effect, 0)


func _restyle_runtime_hud() -> void:
	if _vehicle_service_prompt != null:
		_vehicle_service_prompt.position = Vector2(-220, -190)
		_vehicle_service_prompt.size = Vector2(440, 36)
		_vehicle_service_prompt.add_theme_font_size_override("font_size", 15)
		_vehicle_service_prompt.add_theme_color_override("font_color", HUDTokens.AMBER)
		_vehicle_service_prompt.add_theme_stylebox_override(
			"normal", HUDTokens.frame_style(7, 1, 6)
		)


func _restyle_vehicle_elements() -> void:
	if _vehicle_panel != null:
		_vehicle_panel.add_theme_stylebox_override(
			"panel", _card_style(HUDTokens.CYAN, 9, 1, 8)
		)
	if _fuel_pump_panel != null:
		_fuel_pump_panel.add_theme_stylebox_override(
			"panel", _card_style(HUDTokens.BLUE, 10, 2, 12)
		)


func _top_panel(
	node_name: String,
	left: float,
	top: float,
	right: float,
	bottom: float,
	accent: Color
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.offset_left = left
	panel.offset_top = top
	panel.offset_right = right
	panel.offset_bottom = bottom
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _card_style(accent))
	add_child(panel)
	var margin := _margin(9, 7, 9, 7)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)
	panel.set_meta("content", content)
	return panel


func _card_style(
	_accent: Color,
	radius: int = 8,
	border_width: int = 1,
	shadow_size: int = 7
) -> StyleBoxFlat:
	return HUDTokens.frame_style(radius, border_width, shadow_size)


func _apply_uniform_hud_frame_palette() -> void:
	for child in get_children():
		if child == daily_report_overlay:
			continue
		_apply_uniform_panel_tree(child, false)
	if interaction_prompt != null:
		var prompt_style := HUDTokens.frame_style(7, 1, 6)
		prompt_style.content_margin_left = 14
		prompt_style.content_margin_right = 14
		interaction_prompt.add_theme_stylebox_override("normal", prompt_style)
	if _vehicle_service_prompt != null:
		_vehicle_service_prompt.add_theme_stylebox_override(
			"normal", HUDTokens.frame_style(7, 1, 6)
		)
	if _territory_panel_material != null:
		_territory_panel_material.set_shader_parameter(
			"rival_color", HUDTokens.FRAME_BORDER
		)
		_territory_panel_material.set_shader_parameter(
			"player_color", HUDTokens.FRAME_BORDER
		)
	if _heat_panel_material != null:
		_heat_panel_material.set_shader_parameter(
			"accent_color", HUDTokens.FRAME_BORDER
		)


func _apply_uniform_panel_tree(node: Node, inside_panel: bool) -> void:
	var child_is_inside_panel := inside_panel
	if node is PanelContainer:
		_apply_uniform_panel_style(node as PanelContainer, inside_panel)
		child_is_inside_panel = true
	for child in node.get_children():
		_apply_uniform_panel_tree(child, child_is_inside_panel)


func _apply_uniform_panel_style(
	panel: PanelContainer,
	inside_panel: bool
) -> void:
	var current := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var style := HUDTokens.inset_style()
	if current != null:
		style = current.duplicate() as StyleBoxFlat
	style.bg_color = HUDTokens.SURFACE if inside_panel else HUDTokens.FRAME_SURFACE
	style.border_color = HUDTokens.FRAME_BORDER
	style.set_border_width_all(1 if inside_panel else 2)
	style.shadow_color = Color.TRANSPARENT if inside_panel else HUDTokens.FRAME_SHADOW
	style.shadow_size = 0 if inside_panel else 8
	panel.add_theme_stylebox_override("panel", style)


func _hud_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _hud_meter(accent: Color, height: float) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.custom_minimum_size.y = height
	meter.show_percentage = false
	meter.add_theme_stylebox_override("background", HUDTokens.meter_background(3))
	meter.add_theme_stylebox_override("fill", HUDTokens.meter_fill(accent, 3))
	return meter


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _hud_divider(color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _vertical_line(height: float) -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(1, height)
	line.color = HUDTokens.BORDER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line
