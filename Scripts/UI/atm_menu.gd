class_name ATMMenu
extends CanvasLayer

const BLUE := Color(0.18, 0.48, 0.95, 1.0)
const GREEN := Color(0.35, 0.78, 0.48, 1.0)

@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController

var _root: Control
var _bank_label: Label
var _cash_label: Label
var _limit_label: Label
var _mode_label: Label
var _amount_label: Label
var _feedback_label: Label
var _confirm_button: Button
var _deposit_button: Button
var _withdraw_button: Button
var _amount_text := ""
var _deposit_mode := true
var _is_open := false


func _ready() -> void:
	_build_ui()
	_root.visible = false
	wallet.money_changed.connect(_on_money_changed)


func _input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open_atm() -> void:
	if not menu_controller.request_open(&"atm"):
		return
	_is_open = true
	_root.visible = true
	_amount_text = ""
	_feedback_label.text = ""
	_refresh()


func close() -> void:
	if not _is_open or not menu_controller.close(&"atm"):
		return
	_is_open = false
	_root.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.008, 0.025, 0.055, 0.96)
	_root.add_child(background)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		outer.add_theme_constant_override(side, 26)
	_root.add_child(outer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.065, 0.125), Color(0.13, 0.28, 0.48), 3, 12))
	outer.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	panel.add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 86
	page.add_child(header)
	var title := Label.new()
	title.text = "ATM"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	header.add_child(title)
	_bank_label = Label.new()
	_bank_label.add_theme_font_size_override("font_size", 25)
	_bank_label.add_theme_color_override("font_color", GREEN)
	_bank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_bank_label)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(70, 54)
	_style_button(close_button, Color(0.8, 0.22, 0.2))
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var balances := HBoxContainer.new()
	balances.add_theme_constant_override("separation", 18)
	page.add_child(balances)
	_cash_label = _info_label()
	_cash_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balances.add_child(_cash_label)
	_limit_label = _info_label()
	_limit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balances.add_child(_limit_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 275
	nav.add_theme_constant_override("separation", 12)
	body.add_child(nav)
	var nav_title := Label.new()
	nav_title.text = "SELECT TRANSACTION"
	nav_title.add_theme_font_size_override("font_size", 18)
	nav.add_child(nav_title)
	_deposit_button = Button.new()
	_deposit_button.text = "DEPOSIT CASH  >"
	_deposit_button.custom_minimum_size.y = 76
	_deposit_button.pressed.connect(_set_mode.bind(true))
	nav.add_child(_deposit_button)
	_withdraw_button = Button.new()
	_withdraw_button.text = "WITHDRAW CASH  >"
	_withdraw_button.custom_minimum_size.y = 76
	_withdraw_button.pressed.connect(_set_mode.bind(false))
	nav.add_child(_withdraw_button)
	var note := Label.new()
	note.text = "Deposits turn cash on hand into clean bank money. Withdrawals return bank money to cash on hand."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.58, 0.68, 0.8))
	nav.add_child(note)

	var transaction := PanelContainer.new()
	transaction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transaction.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.09, 0.17), Color(0.12, 0.28, 0.5), 1, 6))
	body.add_child(transaction)
	var transaction_box := VBoxContainer.new()
	transaction_box.add_theme_constant_override("separation", 14)
	transaction.add_child(transaction_box)
	_mode_label = Label.new()
	_mode_label.add_theme_font_size_override("font_size", 28)
	_mode_label.add_theme_color_override("font_color", Color(0.42, 0.68, 1.0))
	transaction_box.add_child(_mode_label)
	_amount_label = Label.new()
	_amount_label.custom_minimum_size.y = 72
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_amount_label.add_theme_font_size_override("font_size", 38)
	_amount_label.add_theme_color_override("font_color", Color(0.82, 0.91, 1.0))
	_amount_label.add_theme_stylebox_override("normal", _panel_style(Color(0.015, 0.04, 0.08), Color(0.17, 0.36, 0.62), 1, 4))
	transaction_box.add_child(_amount_label)

	var chooser := HBoxContainer.new()
	chooser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chooser.add_theme_constant_override("separation", 12)
	transaction_box.add_child(chooser)
	var left_presets := VBoxContainer.new()
	left_presets.custom_minimum_size.x = 150
	left_presets.add_theme_constant_override("separation", 10)
	chooser.add_child(left_presets)
	_add_preset(left_presets, 100)
	_add_preset(left_presets, 250)
	_add_max(left_presets)
	var keypad := GridContainer.new()
	keypad.columns = 3
	keypad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keypad.add_theme_constant_override("h_separation", 8)
	keypad.add_theme_constant_override("v_separation", 8)
	chooser.add_child(keypad)
	for digit in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLEAR", "0", "<"]:
		var key := Button.new()
		key.text = digit
		key.custom_minimum_size = Vector2(92, 62)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(key, BLUE)
		key.pressed.connect(_press_key.bind(digit))
		keypad.add_child(key)
	var right_presets := VBoxContainer.new()
	right_presets.custom_minimum_size.x = 150
	right_presets.add_theme_constant_override("separation", 10)
	chooser.add_child(right_presets)
	_add_preset(right_presets, 500)
	_add_preset(right_presets, 1000)
	var cancel_amount := Button.new()
	cancel_amount.text = "CANCEL"
	cancel_amount.custom_minimum_size.y = 58
	_style_button(cancel_amount, Color(0.66, 0.2, 0.2))
	cancel_amount.pressed.connect(close)
	right_presets.add_child(cancel_amount)

	_confirm_button = Button.new()
	_confirm_button.text = "CONFIRM"
	_confirm_button.custom_minimum_size.y = 62
	_style_button(_confirm_button, BLUE)
	_confirm_button.pressed.connect(_confirm)
	transaction_box.add_child(_confirm_button)
	_feedback_label = Label.new()
	_feedback_label.custom_minimum_size.y = 36
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 18)
	transaction_box.add_child(_feedback_label)


func _add_preset(parent: VBoxContainer, amount: int) -> void:
	var button := Button.new()
	button.text = "$%d" % amount
	button.custom_minimum_size.y = 64
	_style_button(button, BLUE)
	button.pressed.connect(_set_amount.bind(amount))
	parent.add_child(button)


func _add_max(parent: VBoxContainer) -> void:
	var button := Button.new()
	button.text = "MAX"
	button.custom_minimum_size.y = 64
	_style_button(button, GREEN)
	button.pressed.connect(_set_max)
	parent.add_child(button)


func _set_mode(deposit: bool) -> void:
	_deposit_mode = deposit
	_amount_text = ""
	_feedback_label.text = ""
	_refresh()


func _set_amount(amount: int) -> void:
	_amount_text = str(amount)
	_feedback_label.text = ""
	_refresh_amount()


func _set_max() -> void:
	var maximum := mini(wallet.dirty_cash, wallet.get_atm_remaining_limit(_date_key())) if _deposit_mode else wallet.clean_cash
	_set_amount(maximum)


func _press_key(key: String) -> void:
	if key == "CLEAR":
		_amount_text = ""
	elif key == "<":
		_amount_text = _amount_text.left(-1)
	elif _amount_text.length() < 8:
		_amount_text += key
	_feedback_label.text = ""
	_refresh_amount()


func _confirm() -> void:
	var requested := int(_amount_text) if not _amount_text.is_empty() else 0
	if requested <= 0:
		_show_feedback("Enter an amount greater than $0.", false)
		return
	var processed := wallet.deposit_dirty_to_clean(requested, _date_key()) if _deposit_mode else wallet.withdraw_clean_to_dirty(requested)
	if processed <= 0:
		_show_feedback("Transaction cannot be completed.", false)
		return
	_amount_text = ""
	_show_feedback("Deposited $%d." % processed if _deposit_mode else "Withdrew $%d." % processed, true)
	_refresh()


func _refresh() -> void:
	var remaining := wallet.get_atm_remaining_limit(_date_key())
	_bank_label.text = "AVAILABLE BANK BALANCE  $%d   " % wallet.clean_cash
	_cash_label.text = "CASH ON HAND\n$%d" % wallet.dirty_cash
	_limit_label.text = "TODAY'S DEPOSIT LIMIT\n$%d remaining" % remaining
	_mode_label.text = "DEPOSIT CASH" if _deposit_mode else "WITHDRAW CASH"
	_style_button(_deposit_button, BLUE if _deposit_mode else Color(0.25, 0.34, 0.46))
	_style_button(_withdraw_button, BLUE if not _deposit_mode else Color(0.25, 0.34, 0.46))
	_refresh_amount()


func _refresh_amount() -> void:
	var amount := int(_amount_text) if not _amount_text.is_empty() else 0
	_amount_label.text = "$%d" % amount
	_confirm_button.disabled = amount <= 0 or (_deposit_mode and (wallet.dirty_cash <= 0 or wallet.get_atm_remaining_limit(_date_key()) <= 0)) or (not _deposit_mode and wallet.clean_cash <= 0)


func _date_key() -> String:
	var time := get_tree().current_scene.get_node_or_null("WorldTimeComponent") as WorldTimeComponent
	if time == null:
		return "MON JAN 1 Y1"
	return "%s Y%d" % [time.get_formatted_date(), time.year]


func _on_money_changed(_dirty: int, _clean: int) -> void:
	if _is_open:
		_refresh()


func _show_feedback(message: String, success: bool) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override("font_color", GREEN if success else Color(1.0, 0.38, 0.3))


func _info_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size.y = 70
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_stylebox_override("normal", _panel_style(Color(0.02, 0.055, 0.105), Color(0.1, 0.25, 0.44), 1, 5))
	return label


func _panel_style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	return style


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.045, 0.09, 0.16), accent.darkened(0.38), 1, 5))
	button.add_theme_stylebox_override("hover", _panel_style(accent.darkened(0.4), accent, 1, 5))
	button.add_theme_stylebox_override("pressed", _panel_style(accent.darkened(0.58), accent.lightened(0.12), 1, 5))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.025, 0.045, 0.075), Color(0.1, 0.14, 0.2), 1, 5))
	button.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.35, 0.42, 0.52))
