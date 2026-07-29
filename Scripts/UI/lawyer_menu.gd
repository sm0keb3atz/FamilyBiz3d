class_name LawyerMenu
extends CanvasLayer

const COLOR_MODAL := Color("#09131e")
const COLOR_PANEL := Color("#0d1824")
const COLOR_PANEL_DEEP := Color("#08111b")
const COLOR_BORDER := Color("#25394a")
const COLOR_BORDER_BRIGHT := Color("#2b6685")
const COLOR_CYAN := Color("#42c7ff")
const COLOR_TEXT := Color("#f2f6fa")
const COLOR_MUTED := Color("#98a7b8")
const COLOR_GREEN := Color("#59e083")
const COLOR_RED := Color("#ff5c73")

var _root: Control
var _title: Label
var _lawyer_name: Label
var _tier_name: Label
var _description: Label
var _level_badge: Label
var _seal_label: Label
var _retainer_value: Label
var _daily_fee_value: Label
var _defense_value: Label
var _laundering_value: Label
var _heat_value: Label
var _status_label: Label
var _action: Button
var _current_lawyer_id: StringName = &""
var _legal: PlayerLegalComponent
var _menu_controller: PlayerMenuController


func _ready() -> void:
	layer = 45
	_legal = get_parent().get_node("Components/LegalComponent") as PlayerLegalComponent
	_menu_controller = get_parent().get_node("Components/MenuController") as PlayerMenuController
	_build_ui()
	_root.visible = false


func open_for_lawyer(lawyer_id: StringName) -> void:
	var definition := _legal.get_lawyer_definition(lawyer_id)
	if definition == null or not _menu_controller.request_open(&"lawyer"):
		return

	_current_lawyer_id = lawyer_id
	var accent := _level_color(definition.level)
	var retained := _legal.is_lawyer_retained(lawyer_id)

	_title.text = "ATTORNEY RETAINER"
	_lawyer_name.text = definition.display_name.to_upper()
	_tier_name.text = _tier_title(definition.level)
	_description.text = _tier_description(definition.level)
	_level_badge.text = "LEVEL %d" % definition.level
	_level_badge.add_theme_color_override(&"font_color", accent)
	_seal_label.add_theme_color_override(&"font_color", accent)
	_retainer_value.text = "$%s CLEAN" % _money(definition.retainer_clean)
	_daily_fee_value.text = "$%s / DAY" % _money(definition.daily_fee_clean)
	_defense_value.text = "%s - %s" % [
		_money(definition.defense_min), _money(definition.defense_max)
	]
	_laundering_value.text = "$%s / DAY  •  %d%% CUT" % [
		_money(definition.laundering_daily_limit),
		roundi(definition.laundering_cut * 100.0),
	]
	_heat_value.text = "%d PTS / DAY  •  $%s DIRTY PER POINT" % [
		definition.heat_daily_limit,
		_money(definition.heat_cost_per_point),
	]
	_status_label.text = "CURRENTLY RETAINED" if retained else "AVAILABLE FOR RETAINER"
	_status_label.add_theme_color_override(
		&"font_color", COLOR_GREEN if retained else COLOR_MUTED
	)
	_action.text = "END RETAINER" if retained else "HIRE LAWYER"
	_apply_action_style(COLOR_RED if retained else accent)
	_root.visible = true
	_action.call_deferred("grab_focus")


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "LawyerRetainerOverlay"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dimmer := ColorRect.new()
	dimmer.name = "BackdropDimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.002, 0.006, 0.01, 0.86)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24
	center.offset_top = 24
	center.offset_right = -24
	center.offset_bottom = -24
	_root.add_child(center)

	var modal := PanelContainer.new()
	modal.name = "LawyerRetainerModal"
	modal.custom_minimum_size = Vector2(820, 790)
	var modal_style := _panel_style(COLOR_MODAL, COLOR_BORDER_BRIGHT, 10, 1, 0)
	modal_style.shadow_color = Color(0, 0, 0, 0.75)
	modal_style.shadow_size = 28
	modal_style.shadow_offset = Vector2(0, 12)
	modal.add_theme_stylebox_override(&"panel", modal_style)
	center.add_child(modal)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 28)
	margin.add_theme_constant_override(&"margin_top", 22)
	margin.add_theme_constant_override(&"margin_right", 28)
	margin.add_theme_constant_override(&"margin_bottom", 22)
	modal.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 14)
	margin.add_child(layout)
	layout.add_child(_build_header())
	layout.add_child(_separator(COLOR_BORDER_BRIGHT))
	layout.add_child(_build_attorney_profile())
	layout.add_child(_build_services_card())
	layout.add_child(_build_status_strip())
	layout.add_child(_build_actions())
	layout.add_child(_build_terms_footer())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 76
	header.add_theme_constant_override(&"separation", 16)

	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(64, 64)
	seal.add_theme_stylebox_override(
		&"panel", _panel_style(Color("#0a1824"), COLOR_CYAN, 32, 1, 0)
	)
	_seal_label = _label("\u2696", 33, COLOR_CYAN)
	_seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(_seal_label)
	header.add_child(seal)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override(&"separation", 1)
	_title = _label("ATTORNEY RETAINER", 28, COLOR_TEXT)
	_title.add_theme_constant_override(&"outline_size", 4)
	_title.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.55))
	title_box.add_child(_title)
	var subtitle := _label(
		"Secure legal counsel before your next court appearance.", 13, COLOR_MUTED
	)
	title_box.add_child(subtitle)
	header.add_child(title_box)

	var close_button := Button.new()
	close_button.text = "\u00d7"
	close_button.tooltip_text = "Close"
	close_button.flat = true
	close_button.custom_minimum_size = Vector2(44, 44)
	close_button.add_theme_font_size_override(&"font_size", 30)
	close_button.add_theme_color_override(&"font_color", Color("#6f7e8e"))
	close_button.add_theme_color_override(&"font_hover_color", COLOR_TEXT)
	close_button.pressed.connect(_close)
	header.add_child(close_button)
	return header


func _build_attorney_profile() -> PanelContainer:
	var profile := PanelContainer.new()
	profile.custom_minimum_size.y = 150
	profile.add_theme_stylebox_override(
		&"panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 8, 1, 20)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 20)
	profile.add_child(row)

	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(104, 104)
	portrait.add_theme_stylebox_override(
		&"panel", _panel_style(Color("#0a1722"), COLOR_BORDER_BRIGHT, 52, 1, 0)
	)
	var portrait_symbol := _label("\u2696", 48, Color("#d8e3ec"))
	portrait_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(portrait_symbol)
	row.add_child(portrait)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override(&"separation", 4)
	_lawyer_name = _label("ATTORNEY NAME", 25, COLOR_TEXT)
	identity.add_child(_lawyer_name)
	_tier_name = _label("LEGAL COUNSEL", 13, COLOR_CYAN)
	identity.add_child(_tier_name)
	_description = _label("", 12, COLOR_MUTED)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(_description)
	row.add_child(identity)

	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(108, 40)
	badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_panel.add_theme_stylebox_override(
		&"panel", _panel_style(Color("#0a1b28"), COLOR_BORDER, 20, 1, 5)
	)
	_level_badge = _label("LEVEL 1", 15, COLOR_CYAN)
	_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_panel.add_child(_level_badge)
	row.add_child(badge_panel)
	return profile


func _build_services_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		&"panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 8, 1, 18)
	)

	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 8)
	card.add_child(content)

	var heading := _label("RETAINER & SERVICES", 17, Color("#88ddff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size.y = 32
	content.add_child(heading)

	var retainer_panel := PanelContainer.new()
	retainer_panel.custom_minimum_size.y = 62
	retainer_panel.add_theme_stylebox_override(
		&"panel", _panel_style(Color("#0b1c27"), COLOR_BORDER_BRIGHT, 6, 1, 14)
	)
	var retainer_row := HBoxContainer.new()
	retainer_row.add_theme_constant_override(&"separation", 12)
	retainer_panel.add_child(retainer_row)
	var retainer_icon := _label("$", 21, COLOR_GREEN)
	retainer_icon.custom_minimum_size.x = 28
	retainer_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retainer_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	retainer_row.add_child(retainer_icon)
	var retainer_title := _label("RETAINER FEE", 13, COLOR_TEXT)
	retainer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retainer_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	retainer_row.add_child(retainer_title)
	_retainer_value = _label("$0 CLEAN", 19, COLOR_GREEN)
	_retainer_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	retainer_row.add_child(_retainer_value)
	content.add_child(retainer_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 1)
	content.add_child(rows)
	_daily_fee_value = _add_service_row(rows, "\u25f7", "DAILY FEE", COLOR_GREEN)
	_defense_value = _add_service_row(rows, "\u25c8", "DEFENSE RANGE", COLOR_CYAN)
	_laundering_value = _add_service_row(
		rows, "\u21c4", "LAUNDERING SERVICE", COLOR_CYAN
	)
	_heat_value = _add_service_row(rows, "\u2668", "HEAT SERVICE", COLOR_CYAN)
	return card


func _build_status_strip() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 42
	panel.add_theme_stylebox_override(
		&"panel", _panel_style(COLOR_PANEL_DEEP, COLOR_BORDER, 6, 1, 8)
	)
	_status_label = _label("AVAILABLE FOR RETAINER", 11, COLOR_MUTED)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(_status_label)
	return panel


func _build_actions() -> Control:
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 8)

	_action = Button.new()
	_action.text = "HIRE LAWYER"
	_action.custom_minimum_size.y = 54
	_action.add_theme_font_size_override(&"font_size", 15)
	_action.pressed.connect(_on_action)
	actions.add_child(_action)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size.y = 44
	close_button.add_theme_font_size_override(&"font_size", 13)
	close_button.add_theme_color_override(&"font_color", Color("#c0cad4"))
	close_button.add_theme_color_override(&"font_hover_color", COLOR_TEXT)
	close_button.add_theme_stylebox_override(
		&"normal", _button_style(Color("#151f2a"), Color("#1f2d3a"), 1)
	)
	close_button.add_theme_stylebox_override(
		&"hover", _button_style(Color("#1b2936"), COLOR_BORDER_BRIGHT, 1)
	)
	close_button.add_theme_stylebox_override(
		&"pressed", _button_style(Color("#101923"), COLOR_BORDER_BRIGHT, 1)
	)
	close_button.pressed.connect(_close)
	actions.add_child(close_button)
	return actions


func _build_terms_footer() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 36
	panel.add_theme_stylebox_override(
		&"panel", _panel_style(Color("#08121c"), Color("#172c3b"), 6, 1, 6)
	)
	var label := _label(
		"Retainer payment is immediate. Daily fees are deducted automatically.",
		11,
		Color("#8296a8")
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _add_service_row(
	parent: VBoxContainer,
	icon_text: String,
	title: String,
	value_color: Color
) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 43
	panel.add_theme_stylebox_override(
		&"panel", _panel_style(Color("#0a141e"), Color.TRANSPARENT, 0, 0, 10)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	panel.add_child(row)

	var icon := _label(icon_text, 18, value_color)
	icon.custom_minimum_size.x = 40
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)

	var title_label := _label(title, 12, COLOR_MUTED)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)

	var value_label := _label("", 12, value_color)
	value_label.custom_minimum_size.x = 320
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	parent.add_child(panel)
	return value_label


func _apply_action_style(accent: Color) -> void:
	var normal := Color(accent, 0.33)
	var hover := Color(accent, 0.5)
	var pressed := Color(accent, 0.22)
	_action.add_theme_color_override(&"font_color", COLOR_TEXT)
	_action.add_theme_color_override(&"font_hover_color", Color.WHITE)
	_action.add_theme_stylebox_override(
		&"normal", _button_style(normal, accent, 1)
	)
	_action.add_theme_stylebox_override(
		&"hover", _button_style(hover, accent.lightened(0.18), 1)
	)
	_action.add_theme_stylebox_override(
		&"pressed", _button_style(pressed, accent, 1)
	)
	_action.add_theme_stylebox_override(
		&"focus", _button_style(normal, accent.lightened(0.35), 3)
	)


func _on_action() -> void:
	if _legal.is_lawyer_retained(_current_lawyer_id):
		_legal.terminate_lawyer(_current_lawyer_id)
		_close()
		return
	if _legal.hire_lawyer(_current_lawyer_id):
		_close()
	else:
		_status_label.text = "NOT ENOUGH CLEAN MONEY FOR THIS RETAINER"
		_status_label.add_theme_color_override(&"font_color", COLOR_RED)


func _close() -> void:
	if _menu_controller.close(&"lawyer"):
		_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if (
		_root.visible and event is InputEventKey and event.pressed
		and not event.echo and event.physical_keycode == KEY_ESCAPE
	):
		_close()
		get_viewport().set_input_as_handled()


func _tier_title(level: int) -> String:
	match level:
		1:
			return "PUBLIC DEFENSE COUNSEL"
		2:
			return "ASSOCIATE ATTORNEY"
		3:
			return "SENIOR COUNSEL"
		_:
			return "TOP-TIER ATTORNEY"


func _tier_description(level: int) -> String:
	match level:
		1:
			return "Straightforward legal defense for lower-severity cases."
		2:
			return "Experienced representation with stronger courtroom defense."
		3:
			return "Senior representation for serious and high-risk charges."
		_:
			return "Elite legal counsel for the toughest cases in Liberty County."


func _level_color(level: int) -> Color:
	match level:
		1:
			return Color("#b8c4ce")
		2:
			return Color("#42c7ff")
		3:
			return Color("#b875ff")
		_:
			return Color("#f2b94b")


func _separator(color: Color) -> HSeparator:
	var separator := HSeparator.new()
	separator.custom_minimum_size.y = 1
	var style := StyleBoxFlat.new()
	style.bg_color = color
	separator.add_theme_stylebox_override(&"separator", style)
	return separator


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _panel_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int,
	padding: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


func _button_style(
	background: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := _panel_style(background, border, 6, border_width, 10)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	return style


func _money(amount: int) -> String:
	var text := str(abs(amount))
	var formatted := ""
	while text.length() > 3:
		formatted = "," + text.right(3) + formatted
		text = text.left(text.length() - 3)
	formatted = text + formatted
	return ("-" if amount < 0 else "") + formatted
