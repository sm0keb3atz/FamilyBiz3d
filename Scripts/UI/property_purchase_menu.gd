class_name PropertyPurchaseMenu
extends CanvasLayer

const ACCENT := Color(0.2, 0.78, 0.65)

@export var property_component_path := NodePath("../Components/PropertyComponent")
@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var properties := get_node(property_component_path) as PlayerPropertyComponent
@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController

var _root: Control
var _title: Label
var _details: Label
var _balance: Label
var _confirm: Button
var _property_id: StringName
var _is_open := false


func _ready() -> void:
	_build_ui()
	_root.visible = false
	wallet.money_changed.connect(_on_money_changed)


func _input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open_property(property_id: StringName) -> void:
	var definition := PropertyCatalog.get_by_id(property_id)
	if definition == null or properties.owns(property_id):
		return
	if not menu_controller.request_open(&"property_purchase"):
		return
	_property_id = property_id
	_is_open = true
	_root.visible = true
	_refresh()


func close() -> void:
	if not _is_open or not menu_controller.close(&"property_purchase"):
		return
	_is_open = false
	_root.visible = false


func _confirm_purchase() -> void:
	var definition := PropertyCatalog.get_by_id(_property_id)
	if definition == null:
		return
	if properties.purchase(_property_id):
		(get_parent().get_node("PlayerHUD") as PlayerHUD).show_feedback("Purchased %s." % definition.display_name)
		close()
	else:
		_refresh()


func _refresh() -> void:
	var definition := PropertyCatalog.get_by_id(_property_id)
	if definition == null:
		return
	_title.text = definition.display_name.to_upper()
	_details.text = "%s\n\nSafehouse amenities:\n• Bed and morning save point\n• Owned-clothing wardrobe\n• Private dirty cash, drug, and weapon stash\n\nPurchase price: $%s CLEAN" % [definition.neighborhood, _money(definition.purchase_price)]
	_balance.text = "Available clean money: $%s" % _money(wallet.clean_cash)
	_confirm.disabled = not wallet.can_spend_clean(definition.purchase_price)
	_confirm.text = "CONFIRM PURCHASE" if not _confirm.disabled else "NOT ENOUGH CLEAN MONEY"


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.01, 0.015, 0.02, 0.88)
	_root.add_child(dimmer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310, -245)
	panel.size = Vector2(620, 490)
	panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", ACCENT)
	box.add_child(_title)
	_details = Label.new()
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_font_size_override("font_size", 18)
	box.add_child(_details)
	_balance = Label.new()
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance.add_theme_font_size_override("font_size", 19)
	box.add_child(_balance)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size.y = 52
	cancel.pressed.connect(close)
	actions.add_child(cancel)
	_confirm = Button.new()
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.custom_minimum_size.y = 52
	_confirm.pressed.connect(_confirm_purchase)
	actions.add_child(_confirm)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.065)
	style.border_color = ACCENT.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style


func _money(amount: int) -> String:
	var text := str(amount)
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result


func _on_money_changed(_dirty: int, _clean: int) -> void:
	if _is_open:
		_refresh()
