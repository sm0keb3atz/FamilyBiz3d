class_name DealerShopMenu
extends CanvasLayer

const ACCENT := Color(0.98, 0.7, 0.13, 1.0)
const SUCCESS := Color(0.3, 0.86, 0.38, 1.0)
const DANGER := Color(0.96, 0.28, 0.22, 1.0)
const TEXT := Color(0.94, 0.96, 0.98, 1.0)
const TEXT_MUTED := Color(0.62, 0.66, 0.7, 1.0)

@export var player_path := NodePath("..")
@export var inventory_component_path := NodePath(
	"../Components/InventoryComponent"
)
@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var property_component_path := NodePath("../Components/PropertyComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var menu_root := %MenuRoot as Control
@onready var dimmer := %Dimmer as ColorRect
@onready var panel := %Panel as PanelContainer
@onready var title_label := %TitleLabel as Label
@onready var level_label := %LevelLabel as Label
@onready var cash_label := %CashLabel as Label
@onready var item_count_label := %ItemCountLabel as Label
@onready var context_slot := %ContextSlot as VBoxContainer
@onready var stock_list := %StockList as VBoxContainer
@onready var order_panel := %OrderPanel as PanelContainer
@onready var selected_product_label := %SelectedProductLabel as Label
@onready var unit_price_label := %UnitPriceLabel as Label
@onready var quantity_label := %QuantityLabel as Label
@onready var total_label := %TotalLabel as Label
@onready var purchase_button := %PurchaseButton as Button
@onready var amount_buttons: Array[Button] = [
	%Amount1Button as Button,
	%Amount5Button as Button,
	%Amount10Button as Button,
	%Amount20Button as Button,
]
@onready var territory_value := %TerritoryValue as Label
@onready var dealer_tier_value := %DealerTierValue as Label
@onready var access_value := %AccessValue as Label
@onready var control_value := %ControlValue as Label
@onready var rep_value := %RepValue as Label
@onready var rep_bar := %RepBar as ProgressBar
@onready var products_value := %ProductsValue as Label
@onready var units_value := %UnitsValue as Label
@onready var restock_value := %RestockValue as Label
@onready var stock_status_value := %StockStatusValue as Label
@onready var tip_label := %TipLabel as Label
@onready var feedback_panel := %FeedbackPanel as PanelContainer
@onready var feedback_label := %FeedbackLabel as Label
@onready var close_button := %CloseButton as Button
@onready var player := get_node(player_path) as CharacterBody3D
@onready var inventory := (
	get_node(inventory_component_path) as PlayerInventoryComponent
)
@onready var wallet := (
	get_node(wallet_component_path) as PlayerWalletComponent
)
@onready var properties := (
	get_node(property_component_path) as PlayerPropertyComponent
)
@onready var menu_controller := (
	get_node(menu_controller_path) as PlayerMenuController
)

var _dealer: DealerNPC
var _is_open := false
var _delivery_property_id: StringName = &""
var _selected_product_id: StringName = &""
var _selected_product: ProductDefinition
var _selected_amount := 1
var _selected_stock := 0
var _selected_unit_price := 0
var _product_buttons: Array[Button] = []
var _entrance_tween: Tween


func _ready() -> void:
	menu_root.visible = false
	close_button.pressed.connect(close)
	purchase_button.pressed.connect(_purchase_selected)
	for index in amount_buttons.size():
		amount_buttons[index].pressed.connect(_select_amount_button.bind(index))
	dimmer.gui_input.connect(_on_dimmer_input)
	_style_action_button(purchase_button)
	inventory.quantity_changed.connect(_on_inventory_changed)
	wallet.money_changed.connect(_on_money_changed)


func _input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_for(dealer: DealerNPC) -> void:
	if dealer == null:
		return
	if not menu_controller.request_open(&"dealer_shop"):
		return

	_dealer = dealer
	_is_open = true
	_selected_product_id = &""
	_selected_product = null
	_selected_amount = dealer.get_minimum_purchase_quantity()
	menu_root.visible = true
	var role := _dealer.get_role_component()
	if role != null:
		if not role.stock_changed.is_connected(_on_dealer_stock_changed):
			role.stock_changed.connect(_on_dealer_stock_changed)
		if not role.cooldown_changed.is_connected(_on_cooldown_changed):
			role.cooldown_changed.connect(_on_cooldown_changed)
	_dealer.begin_shop_interaction(player)
	feedback_label.text = "SELECT A PRODUCT AND QUANTITY"
	_set_feedback_tone(TEXT_MUTED)
	_refresh()
	_play_open_animation()
	call_deferred("_focus_initial_control")


func close() -> void:
	if not _is_open or not menu_controller.close(&"dealer_shop"):
		return

	var closing_dealer := _dealer
	_is_open = false
	_dealer = null
	_selected_product = null
	_selected_product_id = &""
	menu_root.visible = false
	if is_instance_valid(closing_dealer):
		var role := closing_dealer.get_role_component()
		if role != null:
			if role.stock_changed.is_connected(_on_dealer_stock_changed):
				role.stock_changed.disconnect(_on_dealer_stock_changed)
			if role.cooldown_changed.is_connected(_on_cooldown_changed):
				role.cooldown_changed.disconnect(_on_cooldown_changed)
		closing_dealer.end_shop_interaction()


func close_if_open_for(dealer: DealerNPC) -> void:
	if _is_open and _dealer == dealer:
		close()


func _purchase_selected() -> void:
	if _dealer == null or _selected_product == null:
		return
	feedback_label.text = _dealer.try_purchase(
		player,
		_selected_product,
		_selected_amount,
		_delivery_property_id if _dealer.is_wholesaler() else &""
	)
	_set_feedback_tone(
		SUCCESS if feedback_label.text.begins_with("Purchased") else DANGER
	)
	_refresh()


func _refresh() -> void:
	_clear_dynamic_content()
	if _dealer == null:
		return

	var role := _dealer.get_role_component()
	var wholesaler := _dealer.is_wholesaler()
	title_label.text = "WHOLESALER" if wholesaler else "DEALER"
	level_label.text = (
		"BULK BRICKS  /  %d MINIMUM" % _dealer.get_minimum_purchase_quantity()
		if wholesaler
		else _dealer.get_dealer_level_text().to_upper()
	)
	cash_label.text = "DIRTY CASH  $%s" % _format_money(wallet.dirty_cash)
	if wholesaler:
		_build_runner_destination_selector()
	if _dealer.can_purchase_territory():
		_build_territory_purchase_button()

	var items := _dealer.get_stock_items()
	item_count_label.text = "%d PRODUCT%s" % [
		items.size(),
		"" if items.size() == 1 else "S",
	]
	_build_stock_items(items, wholesaler)
	_refresh_dealer_stats(items, role, wholesaler)
	_refresh_order_panel(wholesaler)


func _clear_dynamic_content() -> void:
	_product_buttons.clear()
	for child in stock_list.get_children():
		child.queue_free()
	for child in context_slot.get_children():
		child.queue_free()


func _build_stock_items(items: Array[Dictionary], wholesaler: bool) -> void:
	if items.is_empty():
		_selected_product = null
		_selected_product_id = &""
		var empty_panel := PanelContainer.new()
		empty_panel.custom_minimum_size = Vector2(0, 116)
		empty_panel.add_theme_stylebox_override(
			"panel", _make_panel_style(
				Color(0.025, 0.029, 0.035, 0.9),
				Color(0.22, 0.23, 0.24, 0.8),
				8
			)
		)
		var empty_label := Label.new()
		empty_label.text = (
			"SOLD OUT\nNEW WHOLESALE STOCK ARRIVES TOMORROW"
			if wholesaler
			else "NO STOCK RIGHT NOW\nCHECK THE RESTOCK STATUS"
		)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", TEXT_MUTED)
		empty_panel.add_child(empty_label)
		stock_list.add_child(empty_panel)
		return

	var selected_still_exists := false
	for item in items:
		var product := item.get("product") as ProductDefinition
		if product != null and product.product_id == _selected_product_id:
			selected_still_exists = true
	if not selected_still_exists:
		var first_product := items[0].get("product") as ProductDefinition
		_selected_product_id = (
			first_product.product_id if first_product != null else &""
		)

	for item in items:
		var product := item.get("product") as ProductDefinition
		if product == null:
			continue
		var quantity := int(item.get("quantity", 0))
		var unit_price := int(item.get("unit_price", product.dealer_price))
		stock_list.add_child(
			_create_product_card(product, quantity, unit_price, wholesaler)
		)
		if product.product_id == _selected_product_id:
			_selected_product = product
			_selected_stock = quantity
			_selected_unit_price = unit_price


func _create_product_card(
	product: ProductDefinition,
	quantity: int,
	unit_price: int,
	wholesaler: bool
) -> Control:
	var selected := product.product_id == _selected_product_id
	var panel_container := PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(0, 104)
	panel_container.mouse_filter = Control.MOUSE_FILTER_PASS
	panel_container.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.065, 0.058, 0.035, 0.98)
			if selected else Color(0.024, 0.029, 0.035, 0.98),
			ACCENT if selected else Color(0.22, 0.24, 0.25, 0.85),
			8,
			2 if selected else 1
		)
	)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	panel_container.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon_back := PanelContainer.new()
	icon_back.custom_minimum_size = Vector2(78, 78)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override(
		"panel", _make_panel_style(
			Color(0.012, 0.015, 0.019, 1.0),
			Color(0.22, 0.24, 0.25, 1.0),
			6
		)
	)
	row.add_child(icon_back)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = product.icon
	icon_back.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.text = product.display_name.to_upper()
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", TEXT)
	text_box.add_child(name_label)
	var package_label := Label.new()
	package_label.text = (
		"BULK PACKAGE  /  RUNNER DELIVERY"
		if wholesaler
		else "%d GRAM PACKAGE" % product.package_size_grams
	)
	package_label.add_theme_font_size_override("font_size", 13)
	package_label.add_theme_color_override("font_color", TEXT_MUTED)
	text_box.add_child(package_label)
	var stock_label := Label.new()
	stock_label.text = "STOCK  %d     YOU OWN  %d" % [
		quantity,
		_get_owned_quantity(product, wholesaler),
	]
	stock_label.add_theme_font_size_override("font_size", 14)
	stock_label.add_theme_color_override("font_color", ACCENT)
	text_box.add_child(stock_label)

	var price_box := VBoxContainer.new()
	price_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_box.custom_minimum_size = Vector2(112, 0)
	row.add_child(price_box)
	var price_label := Label.new()
	price_label.text = "$%s" % _format_money(unit_price)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.add_theme_font_size_override("font_size", 22)
	price_label.add_theme_color_override("font_color", SUCCESS)
	price_box.add_child(price_label)
	var each_label := Label.new()
	each_label.text = "PER UNIT"
	each_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	each_label.add_theme_font_size_override("font_size", 12)
	each_label.add_theme_color_override("font_color", TEXT_MUTED)
	price_box.add_child(each_label)

	var select_button := Button.new()
	select_button.flat = true
	select_button.focus_mode = Control.FOCUS_ALL
	select_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	select_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	select_button.tooltip_text = "Select %s" % product.display_name
	select_button.add_theme_stylebox_override("focus", _make_panel_style(
		Color(0, 0, 0, 0), ACCENT, 8, 2
	))
	select_button.pressed.connect(_select_product.bind(product.product_id))
	panel_container.add_child(select_button)
	_product_buttons.append(select_button)
	return panel_container


func _refresh_order_panel(wholesaler: bool) -> void:
	order_panel.visible = _selected_product != null
	if _selected_product == null:
		return

	_selected_amount = clampi(
		_selected_amount,
		_dealer.get_minimum_purchase_quantity(),
		maxi(_selected_stock, _dealer.get_minimum_purchase_quantity())
	)
	selected_product_label.text = _selected_product.display_name.to_upper()
	unit_price_label.text = "$%s / UNIT" % _format_money(_selected_unit_price)
	var presets := (
		[10, 25, 50, _selected_stock]
		if wholesaler
		else [1, 5, 10, 20]
	)
	for index in amount_buttons.size():
		var amount := int(presets[index])
		amount_buttons[index].set_meta(&"amount", amount)
		amount_buttons[index].text = (
			"ALL" if wholesaler and index == amount_buttons.size() - 1 else str(amount)
		)
		amount_buttons[index].disabled = (
			amount < _dealer.get_minimum_purchase_quantity()
			or amount > _selected_stock
		)
		_style_quantity_button(amount_buttons[index], amount == _selected_amount)
	_refresh_purchase_summary(wholesaler)


func _refresh_purchase_summary(wholesaler: bool) -> void:
	if _dealer == null or _selected_product == null:
		purchase_button.disabled = true
		return
	var total := _selected_unit_price * _selected_amount
	quantity_label.text = "QUANTITY  %d" % _selected_amount
	total_label.text = "TOTAL  $%s" % _format_money(total)
	var cooldown := _dealer.get_cooldown_remaining()
	var capacity_ok := true
	if wholesaler:
		capacity_ok = (
			not _delivery_property_id.is_empty()
			and properties.get_stash_remaining_capacity(
				_delivery_property_id
			) >= _selected_amount
		)
	purchase_button.disabled = (
		cooldown > 0.0
		or _selected_amount < _dealer.get_minimum_purchase_quantity()
		or _selected_amount > _selected_stock
		or not wallet.can_spend_dirty(total)
		or not capacity_ok
	)
	purchase_button.tooltip_text = _get_purchase_disabled_reason(
		total, cooldown, capacity_ok
	)


func _refresh_dealer_stats(
	items: Array[Dictionary],
	role: DealerRoleComponent,
	wholesaler: bool
) -> void:
	var territory := _get_dealer_territory(role)
	var territory_name := "UNKNOWN"
	var current_rep := 0.0
	var owner_text := "NEUTRAL"
	if territory != null:
		territory_name = territory.display_name.to_upper()
		if territory.stats != null:
			current_rep = territory.stats.reputation
			owner_text = TerritoryStatsComponent.OwnerFaction.keys()[
				int(territory.stats.owner_faction)
			]
	var required_rep := role.get_required_reputation() if role != null else 0.0
	territory_value.text = territory_name
	dealer_tier_value.text = (
		"WHOLESALER" if wholesaler else _dealer.get_dealer_level_text().to_upper()
	)
	access_value.text = "%d REQUIRED" % roundi(required_rep)
	control_value.text = owner_text
	rep_value.text = "%d / 100" % roundi(current_rep)
	rep_bar.value = clampf(current_rep, 0.0, 100.0)

	var total_units := 0
	for item in items:
		total_units += int(item.get("quantity", 0))
	products_value.text = str(items.size())
	units_value.text = str(total_units)
	_refresh_restock_stats(_dealer.get_cooldown_remaining(), wholesaler, total_units)
	tip_label.text = (
		"Wholesale orders are delivered by your runner. Make sure the selected stash has enough free capacity."
		if wholesaler
		else "Build territory reputation to unlock higher-tier dealers and better stock. Purchases use Dirty Cash."
	)


func _refresh_restock_stats(
	remaining: float,
	wholesaler: bool,
	total_units := -1
) -> void:
	if remaining > 0.0:
		restock_value.text = "%s REMAINING" % _format_duration(ceili(remaining))
		restock_value.add_theme_color_override("font_color", DANGER)
		stock_status_value.text = "RESTOCKING"
		stock_status_value.add_theme_color_override("font_color", DANGER)
	elif wholesaler:
		restock_value.text = "NEXT DAY"
		restock_value.add_theme_color_override("font_color", TEXT)
		stock_status_value.text = "AVAILABLE" if total_units != 0 else "SOLD OUT"
		stock_status_value.add_theme_color_override(
			"font_color", SUCCESS if total_units != 0 else DANGER
		)
	else:
		restock_value.text = "READY NOW"
		restock_value.add_theme_color_override("font_color", TEXT)
		stock_status_value.text = "AVAILABLE" if total_units != 0 else "NO STOCK"
		stock_status_value.add_theme_color_override(
			"font_color", SUCCESS if total_units != 0 else TEXT_MUTED
		)


func _build_runner_destination_selector() -> void:
	var destinations := properties.get_runner_stash_definitions()
	var valid_ids: Array[StringName] = []
	for definition in destinations:
		valid_ids.append(definition.property_id)
	if _delivery_property_id not in valid_ids:
		_delivery_property_id = (
			destinations[0].property_id if not destinations.is_empty() else &""
		)

	var panel_container := PanelContainer.new()
	panel_container.add_theme_stylebox_override(
		"panel", _make_panel_style(
			Color(0.025, 0.055, 0.058, 0.96),
			Color(0.16, 0.65, 0.62, 0.8),
			7
		)
	)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	panel_container.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var label := Label.new()
	label.text = "RUNNER DELIVERY"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.84, 1.0))
	row.add_child(label)
	if destinations.is_empty():
		var locked := Label.new()
		locked.text = "INSTALL A RUNNER AT AN OWNED STASH"
		locked.add_theme_color_override("font_color", DANGER)
		row.add_child(locked)
	else:
		var selector := OptionButton.new()
		selector.name = "RunnerDestinationSelector"
		selector.custom_minimum_size = Vector2(280, 36)
		var selected_index := 0
		for definition in destinations:
			selector.add_item("%s  /  %d FREE" % [
				definition.display_name.to_upper(),
				properties.get_stash_remaining_capacity(definition.property_id),
			])
			var index := selector.item_count - 1
			selector.set_item_metadata(index, String(definition.property_id))
			if definition.property_id == _delivery_property_id:
				selected_index = index
		selector.select(selected_index)
		selector.item_selected.connect(
			func(index: int) -> void:
				_delivery_property_id = StringName(
					String(selector.get_item_metadata(index))
				)
				_refresh()
		)
		row.add_child(selector)
	context_slot.add_child(panel_container)


func _build_territory_purchase_button() -> void:
	var takeover_button := Button.new()
	takeover_button.text = "BUY HOOD EAST  /  $100,000 DIRTY CASH"
	takeover_button.custom_minimum_size = Vector2(0, 40)
	takeover_button.disabled = not wallet.can_spend_dirty(100000)
	_style_danger_button(takeover_button)
	takeover_button.pressed.connect(_purchase_territory)
	context_slot.add_child(takeover_button)


func _purchase_territory() -> void:
	if _dealer == null:
		return
	feedback_label.text = _dealer.purchase_territory(player)
	_set_feedback_tone(
		SUCCESS if feedback_label.text.contains("Purchased") else DANGER
	)
	_refresh()


func _select_product(product_id: StringName) -> void:
	_selected_product_id = product_id
	_selected_amount = _dealer.get_minimum_purchase_quantity()
	_refresh()
	call_deferred("_focus_purchase_controls")


func _select_amount_button(index: int) -> void:
	if index < 0 or index >= amount_buttons.size():
		return
	_selected_amount = int(amount_buttons[index].get_meta(&"amount", 1))
	_refresh_order_panel(_dealer != null and _dealer.is_wholesaler())
	purchase_button.grab_focus()


func _get_owned_quantity(product: ProductDefinition, wholesaler: bool) -> int:
	if wholesaler:
		return (
			properties.get_stashed_product_quantity(_delivery_property_id, product)
			if not _delivery_property_id.is_empty() else 0
		)
	return inventory.get_quantity(product)


func _get_purchase_disabled_reason(
	total: int,
	cooldown: float,
	capacity_ok: bool
) -> String:
	if cooldown > 0.0:
		return "Dealer is restocking."
	if _selected_amount > _selected_stock:
		return "Not enough stock."
	if not wallet.can_spend_dirty(total):
		return "Not enough Dirty Cash."
	if not capacity_ok:
		return "The selected stash does not have enough free capacity."
	return "Purchase %d for $%s" % [_selected_amount, _format_money(total)]


func _get_dealer_territory(role: DealerRoleComponent) -> TerritoryBoundary:
	if role != null and not String(role.territory_id).is_empty():
		for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
			var boundary := node as TerritoryBoundary
			if boundary != null and boundary.territory_id == role.territory_id:
				return boundary
	return TerritoryBoundary.find_at_position(get_tree(), _dealer.global_position)


func _format_money(value: int) -> String:
	var digits := str(absi(value))
	var formatted := ""
	while digits.length() > 3:
		formatted = ",%s%s" % [digits.right(3), formatted]
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + formatted


func _format_duration(seconds: int) -> String:
	if seconds >= 60:
		return "%dM %02dS" % [seconds / 60, seconds % 60]
	return "%dS" % seconds


func _play_open_animation() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	dimmer.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.965, 0.965)
	panel.pivot_offset = panel.size * 0.5
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(dimmer, "modulate:a", 1.0, 0.16)
	_entrance_tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	_entrance_tween.tween_property(panel, "scale", Vector2.ONE, 0.2)


func _focus_initial_control() -> void:
	if not _is_open:
		return
	if not _product_buttons.is_empty():
		_product_buttons[0].grab_focus()
	elif not purchase_button.disabled:
		purchase_button.grab_focus()
	else:
		close_button.grab_focus()


func _focus_purchase_controls() -> void:
	if _is_open and not purchase_button.disabled:
		purchase_button.grab_focus()


func _on_dimmer_input(event: InputEvent) -> void:
	if (
		_is_open
		and event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		close()


func _make_panel_style(
	fill: Color,
	border: Color,
	radius := 6,
	border_width := 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style


func _style_quantity_button(button: Button, selected: bool) -> void:
	var normal_fill := (
		Color(0.12, 0.1, 0.045, 1.0)
		if selected else Color(0.035, 0.04, 0.047, 1.0)
	)
	var normal_border := ACCENT if selected else Color(0.25, 0.27, 0.29, 1.0)
	button.add_theme_stylebox_override(
		"normal", _make_panel_style(
			normal_fill, normal_border, 6, 2 if selected else 1
		)
	)
	button.add_theme_stylebox_override(
		"hover", _make_panel_style(Color(0.17, 0.13, 0.04, 1.0), ACCENT, 6)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_panel_style(Color(0.09, 0.07, 0.025, 1.0), ACCENT, 6, 2)
	)
	button.add_theme_stylebox_override(
		"focus", _make_panel_style(normal_fill, ACCENT, 6, 2)
	)
	button.add_theme_stylebox_override(
		"disabled", _make_panel_style(
			Color(0.018, 0.021, 0.025, 0.8),
			Color(0.12, 0.13, 0.14, 0.8), 6
		)
	)
	button.add_theme_color_override("font_color", ACCENT if selected else TEXT)
	button.add_theme_color_override(
		"font_disabled_color", Color(0.3, 0.31, 0.32, 1.0)
	)


func _style_action_button(button: Button) -> void:
	button.add_theme_stylebox_override(
		"normal", _make_panel_style(
			Color(0.92, 0.61, 0.06, 1.0),
			Color(1.0, 0.77, 0.2, 1.0), 7
		)
	)
	button.add_theme_stylebox_override(
		"hover", _make_panel_style(
			Color(1.0, 0.72, 0.12, 1.0),
			Color(1.0, 0.86, 0.48, 1.0), 7, 2
		)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_panel_style(
			Color(0.72, 0.44, 0.03, 1.0),
			Color(1.0, 0.76, 0.18, 1.0), 7, 2
		)
	)
	button.add_theme_stylebox_override(
		"focus", _make_panel_style(
			Color(1.0, 0.72, 0.12, 1.0), Color.WHITE, 7, 2
		)
	)
	button.add_theme_stylebox_override(
		"disabled", _make_panel_style(
			Color(0.08, 0.075, 0.055, 0.8),
			Color(0.2, 0.19, 0.15, 0.8), 7
		)
	)
	button.add_theme_color_override(
		"font_color", Color(0.045, 0.035, 0.012, 1.0)
	)
	button.add_theme_color_override(
		"font_hover_color", Color(0.02, 0.015, 0.005, 1.0)
	)
	button.add_theme_color_override(
		"font_disabled_color", Color(0.36, 0.34, 0.28, 1.0)
	)


func _style_danger_button(button: Button) -> void:
	button.add_theme_stylebox_override(
		"normal", _make_panel_style(
			Color(0.2, 0.045, 0.035, 1.0),
			Color(0.75, 0.16, 0.1, 1.0), 7
		)
	)
	button.add_theme_stylebox_override(
		"hover", _make_panel_style(
			Color(0.34, 0.065, 0.045, 1.0), DANGER, 7, 2
		)
	)
	button.add_theme_stylebox_override(
		"disabled", _make_panel_style(
			Color(0.06, 0.035, 0.033, 0.7),
			Color(0.18, 0.1, 0.09, 0.7), 7
		)
	)
	button.add_theme_color_override(
		"font_color", Color(1.0, 0.66, 0.57, 1.0)
	)
	button.add_theme_color_override(
		"font_disabled_color", Color(0.38, 0.25, 0.23, 1.0)
	)


func _set_feedback_tone(color: Color) -> void:
	feedback_label.add_theme_color_override("font_color", color)
	feedback_panel.add_theme_stylebox_override(
		"panel", _make_panel_style(
			Color(color.r * 0.07, color.g * 0.07, color.b * 0.07, 0.94),
			Color(color.r, color.g, color.b, 0.45), 7
		)
	)


func _on_inventory_changed(
	_product: ProductDefinition,
	_quantity: int
) -> void:
	if _is_open:
		_refresh()


func _on_money_changed(_dirty_cash: int, _clean_cash: int) -> void:
	if _is_open:
		_refresh()


func _on_dealer_stock_changed() -> void:
	if _is_open:
		_refresh()


func _on_cooldown_changed(remaining: float) -> void:
	if not _is_open or _dealer == null:
		return
	var items := _dealer.get_stock_items()
	var total_units := 0
	for item in items:
		total_units += int(item.get("quantity", 0))
	_refresh_restock_stats(remaining, _dealer.is_wholesaler(), total_units)
	_refresh_purchase_summary(_dealer.is_wholesaler())
