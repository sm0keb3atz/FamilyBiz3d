class_name ATMMenu
extends CanvasLayer

const GREEN := Color("#70ef69")
const GREEN_SOFT := Color("#4fcf6a")
const BLUE := Color("#75b8ff")
const WHITE := Color("#eef4fb")
const MUTED := Color("#91a5bd")
const DIM := Color("#53687f")
const RED := Color("#f05b67")
const SCREEN_BG := Color("#050a11")
const SURFACE := Color("#08111d")
const SURFACE_2 := Color("#0b1726")
const SURFACE_3 := Color("#0d1c2d")
const BORDER := Color("#20344b")

const ICON_DEPOSIT: Texture2D = preload("res://Assets/UI/ATM/Icons/deposit.svg")
const ICON_WITHDRAW: Texture2D = preload("res://Assets/UI/ATM/Icons/withdraw.svg")
const ICON_WALLET: Texture2D = preload("res://Assets/UI/ATM/Icons/wallet.svg")
const ICON_CALENDAR: Texture2D = preload("res://Assets/UI/ATM/Icons/calendar.svg")
const ICON_INFO: Texture2D = preload("res://Assets/UI/ATM/Icons/info.svg")
const ICON_SHIELD: Texture2D = preload("res://Assets/UI/ATM/Icons/shield.svg")
const ICON_CHECK: Texture2D = preload("res://Assets/UI/ATM/Icons/check.svg")
const ICON_BACKSPACE: Texture2D = preload("res://Assets/UI/ATM/Icons/backspace.svg")
const ICON_LOCK: Texture2D = preload("res://Assets/UI/ATM/Icons/lock.svg")
const ICON_MONEY: Texture2D = preload("res://Assets/UI/PlayerStats/Icons/money_hud.svg")
const MONITOR_SHADER: Shader = preload("res://Assets/UI/ATM/atm_monitor_fx.gdshader")

@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController

var _root: Control
var _main_surface: Control
var _startup_overlay: Control
var _startup_line: ColorRect
var _startup_glow: ColorRect
var _startup_status: Label
var _startup_tween: Tween
var _bank_label: Label
var _cash_label: Label
var _limit_label: Label
var _mode_label: Label
var _mode_subtitle: Label
var _mode_icon: TextureRect
var _instructions_title: Label
var _instructions_label: Label
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
	if (
		_is_open
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_ESCAPE
	):
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
	_play_startup_animation()


func close() -> void:
	if not _is_open or not menu_controller.close(&"atm"):
		return
	_is_open = false
	if _startup_tween != null:
		_startup_tween.kill()
	_startup_overlay.visible = false
	_root.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "ATMInterface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = SCREEN_BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		outer.add_theme_constant_override(side, 14)
	_root.add_child(outer)

	var screen := PanelContainer.new()
	screen.name = "TerminalScreen"
	screen.add_theme_stylebox_override(
		"panel", _panel_style(Color("#060d16"), Color("#263a50"), 1, 14, 24, true)
	)
	outer.add_child(screen)
	_main_surface = screen

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	screen.add_child(page)
	_build_header(page)
	_build_stat_cards(page)
	_build_transaction_area(page)

	var monitor_fx := ColorRect.new()
	monitor_fx.name = "MonitorEffect"
	monitor_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	monitor_fx.color = Color.WHITE
	monitor_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var monitor_material := ShaderMaterial.new()
	monitor_material.shader = MONITOR_SHADER
	monitor_fx.material = monitor_material
	_root.add_child(monitor_fx)

	_build_startup_overlay()


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 94
	header.add_theme_constant_override("separation", 22)
	parent.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", -2)
	header.add_child(title_stack)

	var title := _label("ATM", 48, WHITE)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color("#1a2a3c"))
	title_stack.add_child(title)
	var subtitle := _label("A U T O M A T E D   T E L L E R   M A C H I N E", 13, BLUE)
	title_stack.add_child(subtitle)

	var balance_box := HBoxContainer.new()
	balance_box.custom_minimum_size.x = 445
	balance_box.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_box.add_theme_constant_override("separation", 18)
	header.add_child(balance_box)
	_add_icon(balance_box, ICON_MONEY, Vector2(55, 55), GREEN)
	var balance_text := VBoxContainer.new()
	balance_text.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_text.add_theme_constant_override("separation", 1)
	balance_box.add_child(balance_text)
	balance_text.add_child(_label("AVAILABLE BANK BALANCE", 15, MUTED))
	_bank_label = _label("$0", 31, GREEN)
	_bank_label.add_theme_constant_override("outline_size", 6)
	_bank_label.add_theme_color_override("font_outline_color", Color(0.1, 0.7, 0.28, 0.15))
	balance_text.add_child(_bank_label)

	var close_button := Button.new()
	close_button.name = "ExitButton"
	close_button.text = "×\nEXIT"
	close_button.tooltip_text = "Exit terminal"
	close_button.custom_minimum_size = Vector2(78, 74)
	close_button.add_theme_font_size_override("font_size", 17)
	close_button.add_theme_constant_override("line_spacing", -3)
	_style_button(close_button, Color("#5e7897"), SURFACE_2, WHITE, 8)
	close_button.pressed.connect(close)
	header.add_child(close_button)


func _build_stat_cards(parent: VBoxContainer) -> void:
	var cards := HBoxContainer.new()
	cards.custom_minimum_size.y = 91
	cards.add_theme_constant_override("separation", 14)
	parent.add_child(cards)
	_cash_label = _add_stat_card(cards, ICON_WALLET, "CASH ON HAND")
	_limit_label = _add_stat_card(cards, ICON_CALENDAR, "TODAY'S DEPOSIT LIMIT")


func _build_transaction_area(parent: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	parent.add_child(body)
	_build_sidebar(body)
	_build_transaction_panel(body)


func _build_sidebar(parent: HBoxContainer) -> void:
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 340
	sidebar.add_theme_stylebox_override(
		"panel", _panel_style(Color("#07101a"), BORDER, 1, 10, 18)
	)
	parent.add_child(sidebar)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	sidebar.add_child(content)
	content.add_child(_label("TRANSACTIONS", 17, WHITE))
	var accent_rule := ColorRect.new()
	accent_rule.custom_minimum_size = Vector2(34, 2)
	accent_rule.color = GREEN
	accent_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(accent_rule)
	var rule_space := Control.new()
	rule_space.custom_minimum_size.y = 12
	content.add_child(rule_space)

	_deposit_button = _nav_button("DEPOSIT CASH", ICON_DEPOSIT)
	_deposit_button.pressed.connect(_set_mode.bind(true))
	content.add_child(_deposit_button)
	_withdraw_button = _nav_button("WITHDRAW CASH", ICON_WITHDRAW)
	_withdraw_button.pressed.connect(_set_mode.bind(false))
	content.add_child(_withdraw_button)

	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size.y = 228
	info_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("#0a1521"), Color("#172b3d"), 1, 9, 18)
	)
	content.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_box)
	var info_header := HBoxContainer.new()
	info_header.add_theme_constant_override("separation", 9)
	info_box.add_child(info_header)
	_add_icon(info_header, ICON_INFO, Vector2(25, 25), GREEN)
	_instructions_title = _label("DEPOSIT CASH", 16, GREEN)
	_instructions_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_header.add_child(_instructions_title)
	_instructions_label = _label("", 14, MUTED)
	_instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instructions_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_instructions_label.add_theme_constant_override("line_spacing", 8)
	info_box.add_child(_instructions_label)

	var flexible_space := Control.new()
	flexible_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(flexible_space)
	var secure := HBoxContainer.new()
	secure.add_theme_constant_override("separation", 12)
	content.add_child(secure)
	var shield_badge := PanelContainer.new()
	shield_badge.custom_minimum_size = Vector2(55, 55)
	shield_badge.add_theme_stylebox_override(
		"panel", _panel_style(Color("#081421"), Color("#28415b"), 1, 28, 11)
	)
	secure.add_child(shield_badge)
	_add_icon(shield_badge, ICON_SHIELD, Vector2(31, 31), Color("#90acd0"))
	var secure_copy := VBoxContainer.new()
	secure_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	secure.add_child(secure_copy)
	secure_copy.add_child(_label("SECURE TRANSACTION", 12, MUTED))
	var secure_text := _label("Protected by bank-level encryption.", 12, DIM)
	secure_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	secure_copy.add_child(secure_text)


func _build_transaction_panel(parent: HBoxContainer) -> void:
	var transaction := PanelContainer.new()
	transaction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transaction.add_theme_stylebox_override(
		"panel", _panel_style(Color("#07111d"), Color("#233a52"), 1, 10, 22)
	)
	parent.add_child(transaction)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	transaction.add_child(content)

	var mode_header := HBoxContainer.new()
	mode_header.custom_minimum_size.y = 58
	mode_header.add_theme_constant_override("separation", 14)
	content.add_child(mode_header)
	_mode_icon = _add_icon(mode_header, ICON_DEPOSIT, Vector2(43, 43), GREEN)
	var mode_copy := VBoxContainer.new()
	mode_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_copy.add_theme_constant_override("separation", 0)
	mode_header.add_child(mode_copy)
	_mode_label = _label("DEPOSIT CASH", 25, GREEN)
	mode_copy.add_child(_mode_label)
	_mode_subtitle = _label("Enter the amount you would like to deposit.", 15, MUTED)
	mode_copy.add_child(_mode_subtitle)
	_add_rule(content, Color("#2d5945"))

	var amount_panel := PanelContainer.new()
	amount_panel.custom_minimum_size.y = 122
	amount_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("#0c1a2a"), Color("#102337"), 1, 8, 12)
	)
	content.add_child(amount_panel)
	var amount_stack := VBoxContainer.new()
	amount_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	amount_stack.add_theme_constant_override("separation", 0)
	amount_panel.add_child(amount_stack)
	var amount_caption := _label("TRANSACTION AMOUNT", 14, MUTED)
	amount_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_stack.add_child(amount_caption)
	_amount_label = _label("$0", 48, WHITE)
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_label.add_theme_constant_override("outline_size", 7)
	_amount_label.add_theme_color_override("font_outline_color", Color(0.35, 0.55, 0.75, 0.11))
	amount_stack.add_child(_amount_label)

	var keypad := GridContainer.new()
	keypad.name = "Keypad"
	keypad.columns = 5
	keypad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keypad.add_theme_constant_override("h_separation", 7)
	keypad.add_theme_constant_override("v_separation", 7)
	content.add_child(keypad)
	var keys: Array = [
		["$100", "preset", 100], ["1", "digit", "1"], ["2", "digit", "2"], ["3", "digit", "3"], ["$500", "preset", 500],
		["$250", "preset", 250], ["4", "digit", "4"], ["5", "digit", "5"], ["6", "digit", "6"], ["$1,000", "preset", 1000],
		["$500", "preset", 500], ["7", "digit", "7"], ["8", "digit", "8"], ["9", "digit", "9"], ["$2,500", "preset", 2500],
		["MAX", "max", 0], ["CLEAR", "clear", 0], ["0", "digit", "0"], ["", "backspace", 0], ["CANCEL", "cancel", 0],
	]
	for entry: Array in keys:
		_add_keypad_button(keypad, String(entry[0]), String(entry[1]), entry[2])

	_add_rule(content, Color("#172b3e"))
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.text = "CONFIRM DEPOSIT"
	_confirm_button.icon = ICON_CHECK
	_confirm_button.add_theme_constant_override("icon_max_width", 31)
	_confirm_button.expand_icon = true
	_confirm_button.custom_minimum_size.y = 72
	_confirm_button.add_theme_font_size_override("font_size", 19)
	_confirm_button.pressed.connect(_confirm)
	content.add_child(_confirm_button)

	_feedback_label = _label("", 15, MUTED)
	_feedback_label.custom_minimum_size.y = 23
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_feedback_label)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 9)
	content.add_child(footer)
	_add_icon(footer, ICON_LOCK, Vector2(18, 18), DIM)
	footer.add_child(_label("Thank you for banking with us.", 13, DIM))


func _build_startup_overlay() -> void:
	_startup_overlay = Control.new()
	_startup_overlay.name = "StartupSequence"
	_startup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_startup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_startup_overlay)
	var blackout := ColorRect.new()
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout.color = Color("#020507")
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_startup_overlay.add_child(blackout)
	_startup_glow = ColorRect.new()
	_startup_glow.set_anchors_preset(Control.PRESET_CENTER)
	_startup_glow.offset_left = -1
	_startup_glow.offset_right = 1
	_startup_glow.offset_top = -1
	_startup_glow.offset_bottom = 1
	_startup_glow.color = Color(0.25, 1.0, 0.55, 0.06)
	_startup_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_startup_overlay.add_child(_startup_glow)
	_startup_line = ColorRect.new()
	_startup_line.set_anchors_preset(Control.PRESET_CENTER)
	_startup_line.offset_top = -1
	_startup_line.offset_bottom = 1
	_startup_line.color = Color(0.55, 1.0, 0.72, 0.9)
	_startup_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_startup_overlay.add_child(_startup_line)
	_startup_status = _label("FB FINANCIAL NETWORK  /  SECURE LINK ESTABLISHED", 14, GREEN)
	_startup_status.set_anchors_preset(Control.PRESET_CENTER)
	_startup_status.position = Vector2(-235, 38)
	_startup_status.size = Vector2(470, 28)
	_startup_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_startup_overlay.add_child(_startup_status)
	_startup_overlay.visible = false


func _play_startup_animation() -> void:
	if _startup_tween != null:
		_startup_tween.kill()
	_startup_overlay.visible = true
	_startup_overlay.modulate = Color.WHITE
	_startup_status.modulate = Color(1, 1, 1, 0)
	_main_surface.pivot_offset = _main_surface.size * 0.5
	_main_surface.scale = Vector2(1.0, 0.006)
	_main_surface.modulate = Color(0.45, 1.0, 0.65, 0.05)
	_startup_line.offset_left = 0
	_startup_line.offset_right = 0
	_startup_glow.offset_left = -1
	_startup_glow.offset_right = 1
	_startup_glow.offset_top = -1
	_startup_glow.offset_bottom = 1
	var half_width := _root.size.x * 0.43
	var half_height := _root.size.y * 0.47
	_startup_tween = create_tween()
	_startup_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_startup_tween.set_trans(Tween.TRANS_CUBIC)
	_startup_tween.set_ease(Tween.EASE_OUT)
	_startup_tween.set_parallel(true)
	_startup_tween.tween_property(_startup_line, "offset_left", -half_width, 0.20)
	_startup_tween.tween_property(_startup_line, "offset_right", half_width, 0.20)
	_startup_tween.set_parallel(false)
	_startup_tween.tween_interval(0.05)
	_startup_tween.set_parallel(true)
	_startup_tween.tween_property(_main_surface, "scale", Vector2.ONE, 0.32)
	_startup_tween.tween_property(_main_surface, "modulate", Color(0.72, 1.0, 0.82, 0.75), 0.25)
	_startup_tween.tween_property(_startup_glow, "offset_left", -half_width, 0.32)
	_startup_tween.tween_property(_startup_glow, "offset_right", half_width, 0.32)
	_startup_tween.tween_property(_startup_glow, "offset_top", -half_height, 0.32)
	_startup_tween.tween_property(_startup_glow, "offset_bottom", half_height, 0.32)
	_startup_tween.set_parallel(false)
	_startup_tween.tween_property(_startup_status, "modulate", Color.WHITE, 0.12)
	_startup_tween.tween_interval(0.16)
	_startup_tween.set_parallel(true)
	_startup_tween.tween_property(_startup_overlay, "modulate", Color(1, 1, 1, 0), 0.28)
	_startup_tween.tween_property(_main_surface, "modulate", Color.WHITE, 0.28)
	_startup_tween.set_parallel(false)
	_startup_tween.tween_callback(_finish_startup_animation)


func _finish_startup_animation() -> void:
	_main_surface.scale = Vector2.ONE
	_main_surface.modulate = Color.WHITE
	_startup_overlay.visible = false


func _add_stat_card(parent: HBoxContainer, icon: Texture2D, caption: String) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel", _panel_style(Color("#0a1421"), Color("#1c3045"), 1, 9, 18)
	)
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(56, 56)
	badge.add_theme_stylebox_override(
		"panel", _panel_style(Color("#101d2d"), Color("#37516e"), 1, 10, 10)
	)
	row.add_child(badge)
	_add_icon(badge, icon, Vector2(34, 34), WHITE)
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	copy.add_child(_label(caption, 14, MUTED))
	var value := _label("$0", 23, WHITE)
	copy.add_child(value)
	return value


func _nav_button(text: String, icon: Texture2D) -> Button:
	var button := Button.new()
	button.text = "  %s          ›" % text
	button.icon = icon
	button.add_theme_constant_override("icon_max_width", 32)
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 76
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_constant_override("h_separation", 15)
	return button


func _add_keypad_button(parent: GridContainer, text: String, kind: String, value: Variant) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 57)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	match kind:
		"digit":
			_style_button(button, Color("#42698d"), Color("#0d1b2b"), WHITE, 4)
			button.pressed.connect(_press_key.bind(String(value)))
		"preset":
			_style_button(button, Color("#31577a"), Color("#0b1928"), BLUE, 4)
			button.pressed.connect(_set_amount.bind(int(value)))
		"max":
			_style_button(button, GREEN_SOFT, Color("#10241d"), GREEN, 4)
			button.pressed.connect(_set_max)
		"clear":
			_style_button(button, Color("#42698d"), Color("#0d1b2b"), WHITE, 4)
			button.pressed.connect(_press_key.bind("CLEAR"))
		"backspace":
			button.icon = ICON_BACKSPACE
			button.add_theme_constant_override("icon_max_width", 26)
			button.expand_icon = true
			_style_button(button, Color("#42698d"), Color("#0d1b2b"), WHITE, 4)
			button.pressed.connect(_press_key.bind("<"))
		"cancel":
			_style_button(button, RED, Color("#241218"), RED, 4)
			button.pressed.connect(_clear_amount)
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
	var maximum := (
		mini(wallet.dirty_cash, wallet.get_atm_remaining_limit(_date_key()))
		if _deposit_mode
		else wallet.clean_cash
	)
	_set_amount(maximum)


func _clear_amount() -> void:
	_amount_text = ""
	_feedback_label.text = ""
	_refresh_amount()


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
		_show_feedback("ENTER AN AMOUNT GREATER THAN $0", false)
		return
	var processed := (
		wallet.deposit_dirty_to_clean(requested, _date_key())
		if _deposit_mode
		else wallet.withdraw_clean_to_dirty(requested)
	)
	if processed <= 0:
		_show_feedback("TRANSACTION COULD NOT BE COMPLETED", false)
		return
	_amount_text = ""
	_show_feedback(
		"DEPOSIT COMPLETE  •  $%d" % processed
		if _deposit_mode
		else "WITHDRAWAL COMPLETE  •  $%d" % processed,
		true
	)
	_refresh()


func _refresh() -> void:
	var remaining := wallet.get_atm_remaining_limit(_date_key())
	_bank_label.text = "$%s" % _format_money(wallet.clean_cash)
	_cash_label.text = "$%s" % _format_money(wallet.dirty_cash)
	_limit_label.text = "$%s  REMAINING" % _format_money(remaining)
	if _deposit_mode:
		_mode_label.text = "DEPOSIT CASH"
		_mode_label.add_theme_color_override("font_color", GREEN)
		_mode_subtitle.text = "Enter the amount you would like to deposit."
		_mode_icon.texture = ICON_DEPOSIT
		_mode_icon.modulate = GREEN
		_instructions_title.text = "DEPOSIT CASH"
		_instructions_title.add_theme_color_override("font_color", GREEN)
		_instructions_label.text = (
			"Insert cash into the machine.\n\n"
			+ "The ATM will count and verify your deposit.\n\n"
			+ "Funds are added to your available balance."
		)
		_confirm_button.text = "CONFIRM DEPOSIT"
		_style_button(_confirm_button, GREEN, Color("#112b1f"), GREEN, 6, true)
	else:
		_mode_label.text = "WITHDRAW CASH"
		_mode_label.add_theme_color_override("font_color", BLUE)
		_mode_subtitle.text = "Enter the amount you would like to withdraw."
		_mode_icon.texture = ICON_WITHDRAW
		_mode_icon.modulate = BLUE
		_instructions_title.text = "WITHDRAW CASH"
		_instructions_title.add_theme_color_override("font_color", BLUE)
		_instructions_label.text = (
			"Choose an amount to withdraw.\n\n"
			+ "Funds move from your bank balance to cash on hand.\n\n"
			+ "Collect your cash before leaving."
		)
		_confirm_button.text = "CONFIRM WITHDRAWAL"
		_style_button(_confirm_button, BLUE, Color("#102438"), BLUE, 6, true)
	_style_nav_button(_deposit_button, _deposit_mode, GREEN if _deposit_mode else BLUE)
	_style_nav_button(_withdraw_button, not _deposit_mode, BLUE)
	_refresh_amount()


func _refresh_amount() -> void:
	var amount := int(_amount_text) if not _amount_text.is_empty() else 0
	_amount_label.text = "$%s" % _format_money(amount)
	_confirm_button.disabled = (
		amount <= 0
		or (_deposit_mode and (wallet.dirty_cash <= 0 or wallet.get_atm_remaining_limit(_date_key()) <= 0))
		or (not _deposit_mode and wallet.clean_cash <= 0)
	)


func _date_key() -> String:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return "MON JAN 1 Y1"
	var time := current_scene.get_node_or_null("WorldTimeComponent") as WorldTimeComponent
	if time == null:
		return "MON JAN 1 Y1"
	return "%s Y%d" % [time.get_formatted_date(), time.year]


func _on_money_changed(_dirty: int, _clean: int) -> void:
	if _is_open:
		_refresh()


func _show_feedback(message: String, success: bool) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override("font_color", GREEN if success else RED)


func _format_money(amount: int) -> String:
	var digits := str(maxi(amount, 0))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return formatted


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _add_icon(parent: Node, texture: Texture2D, size: Vector2, tint: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


func _add_rule(parent: Node, color: Color) -> void:
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1
	rule.color = color
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)


func _panel_style(
	fill: Color,
	border: Color,
	width: int,
	radius: int,
	content_margin: int = 14,
	shadow: bool = false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	if shadow:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
		style.shadow_size = 9
	return style


func _style_nav_button(button: Button, selected: bool, accent: Color) -> void:
	var fill := Color("#10201f") if selected else Color("#0a1725")
	var border := accent if selected else Color("#28435d")
	var text_color := accent if selected else BLUE
	_style_button(button, border, fill, text_color, 5, selected)
	button.add_theme_color_override("icon_normal_color", text_color)
	button.add_theme_color_override("icon_hover_color", accent)


func _style_button(
	button: Button,
	accent: Color,
	fill: Color,
	font_color: Color,
	radius: int = 5,
	glow: bool = false
) -> void:
	button.add_theme_stylebox_override(
		"normal", _button_style(fill, accent.darkened(0.30), 1, radius, glow)
	)
	button.add_theme_stylebox_override(
		"hover", _button_style(fill.lightened(0.055), accent, 1, radius, true)
	)
	button.add_theme_stylebox_override(
		"pressed", _button_style(accent.darkened(0.72), accent.lightened(0.10), 1, radius, true)
	)
	button.add_theme_stylebox_override(
		"disabled", _button_style(Color("#07101a"), Color("#172231"), 1, radius)
	)
	button.add_theme_stylebox_override(
		"focus", _button_style(Color(0, 0, 0, 0), accent.lightened(0.15), 1, radius, true)
	)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.13))
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#405064"))
	button.add_theme_color_override("icon_normal_color", font_color)
	button.add_theme_color_override("icon_hover_color", font_color.lightened(0.13))
	button.add_theme_color_override("icon_pressed_color", WHITE)
	button.add_theme_color_override("icon_disabled_color", Color("#405064"))


func _button_style(
	fill: Color,
	border: Color,
	width: int,
	radius: int,
	glow: bool = false
) -> StyleBoxFlat:
	var style := _panel_style(fill, border, width, radius, 10)
	if glow:
		style.shadow_color = Color(border.r, border.g, border.b, 0.22)
		style.shadow_size = 6
	return style
