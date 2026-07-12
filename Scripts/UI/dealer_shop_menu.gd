class_name DealerShopMenu
extends CanvasLayer

@export var player_path := NodePath("..")
@export var inventory_component_path := NodePath(
	"../Components/InventoryComponent"
)
@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var menu_root := %MenuRoot as Control
@onready var title_label := %TitleLabel as Label
@onready var level_label := %LevelLabel as Label
@onready var cash_label := %CashLabel as Label
@onready var cooldown_label := %CooldownLabel as Label
@onready var stock_list := %StockList as VBoxContainer
@onready var feedback_label := %FeedbackLabel as Label
@onready var close_button := %CloseButton as Button
@onready var player := get_node(player_path) as CharacterBody3D
@onready var inventory := (
	get_node(inventory_component_path) as PlayerInventoryComponent
)
@onready var wallet := (
	get_node(wallet_component_path) as PlayerWalletComponent
)
@onready var menu_controller := (
	get_node(menu_controller_path) as PlayerMenuController
)

var _dealer: DealerNPC
var _is_open := false


func _ready() -> void:
	menu_root.visible = false
	close_button.pressed.connect(close)
	_style_button(close_button, Color(0.95, 0.32, 0.18, 1.0))
	inventory.quantity_changed.connect(_on_inventory_changed)
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


func open_for(dealer: DealerNPC) -> void:
	if dealer == null:
		return
	if not menu_controller.request_open(&"dealer_shop"):
		return

	_dealer = dealer
	_is_open = true
	menu_root.visible = true
	feedback_label.text = ""
	_refresh()
	close_button.grab_focus()


func close() -> void:
	if not _is_open or not menu_controller.close(&"dealer_shop"):
		return

	_is_open = false
	_dealer = null
	menu_root.visible = false


func _purchase(product: ProductDefinition, amount: int) -> void:
	if _dealer == null:
		return

	feedback_label.text = _dealer.try_purchase(player, product, amount)
	_refresh()


func _refresh() -> void:
	for child in stock_list.get_children():
		child.queue_free()

	if _dealer == null:
		return

	title_label.text = "DEALER"
	level_label.text = _dealer.get_dealer_level_text()
	cash_label.text = "Dirty Cash: $%d" % wallet.dirty_cash
	var cooldown := _dealer.get_cooldown_remaining()
	cooldown_label.visible = cooldown > 0.0
	cooldown_label.text = "Restocking in %ds" % ceili(cooldown)

	var items := _dealer.get_stock_items()
	if items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No stock right now."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stock_list.add_child(empty_label)
		return

	for item in items:
		var product := item.get("product") as ProductDefinition
		if product == null:
			continue
		var quantity := int(item.get("quantity", 0))
		var unit_price := int(item.get("unit_price", product.dealer_price))
		stock_list.add_child(_create_stock_row(product, quantity, unit_price, cooldown))


func _create_stock_row(
	product: ProductDefinition,
	quantity: int,
	unit_price: int,
	cooldown: float
) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.055, 0.062, 0.072, 0.98), Color(1.0, 0.72, 0.18, 0.4))
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 12)
	row.add_child(summary)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = product.icon
	summary.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(text_box)

	var name_label := Label.new()
	name_label.text = product.display_name
	name_label.add_theme_font_size_override("font_size", 20)
	text_box.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = "Stock: %d | Owned: %d | $%d each" % [
		quantity,
		inventory.get_quantity(product),
		unit_price,
	]
	detail_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	text_box.add_child(detail_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	row.add_child(buttons)
	for amount in [1, 5, 10, 20]:
		var button := Button.new()
		button.text = "%d" % amount
		button.custom_minimum_size = Vector2(56, 34)
		button.disabled = (
			cooldown > 0.0
			or quantity < amount
			or not wallet.can_spend_dirty(unit_price * amount)
		)
		_style_button(button, Color(0.95, 0.58, 0.16, 1.0))
		button.pressed.connect(_purchase.bind(product, amount))
		buttons.add_child(button)

	return panel


func _make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_make_panel_style(Color(0.09, 0.085, 0.075, 1.0), accent.darkened(0.25))
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(accent.darkened(0.15), accent.lightened(0.1))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_panel_style(accent.darkened(0.35), accent.lightened(0.2))
	)
	button.add_theme_stylebox_override(
		"disabled",
		_make_panel_style(Color(0.045, 0.048, 0.055, 0.7), Color(0.18, 0.17, 0.15, 0.7))
	)
	button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.43, 0.4, 1.0))


func _on_inventory_changed(
	_product: ProductDefinition,
	_quantity: int
) -> void:
	if _is_open:
		_refresh()


func _on_money_changed(_dirty_cash: int, _clean_cash: int) -> void:
	if _is_open:
		_refresh()
