class_name BusinessManagementPanel
extends VBoxContainer

const PURPLE := Color(0.55, 0.25, 0.82)
const PURPLE_BRIGHT := Color(0.69, 0.36, 0.94)
const GREEN := Color(0.28, 0.72, 0.33)
const BLUE := Color(0.25, 0.62, 0.9)
const GOLD := Color(0.93, 0.68, 0.16)
const TEXT := Color(0.91, 0.9, 0.95)
const MUTED := Color(0.58, 0.58, 0.68)
const PANEL_BG := Color(0.035, 0.034, 0.055, 0.98)
const PANEL_BORDER := Color(0.14, 0.13, 0.21)

class RevenueChart extends Control:
	var values: Array[int] = []
	var labels: Array[String] = []

	func set_chart_data(new_values: Array[int], new_labels: Array[String]) -> void:
		values = new_values
		labels = new_labels
		queue_redraw()

	func _draw() -> void:
		if values.is_empty():
			return
		var font := ThemeDB.fallback_font
		var plot := Rect2(52.0, 16.0, maxf(size.x - 68.0, 20.0), maxf(size.y - 52.0, 20.0))
		var maximum := 1
		for value in values:
			maximum = maxi(maximum, value)
		for line_index in 5:
			var ratio := float(line_index) / 4.0
			var y := plot.end.y - plot.size.y * ratio
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.16, 0.15, 0.23), 1.0)
			var amount := roundi(float(maximum) * ratio)
			draw_string(font, Vector2(4.0, y + 4.0), _compact_money(amount), HORIZONTAL_ALIGNMENT_LEFT, 46.0, 11, MUTED)
		var slot_width := plot.size.x / float(values.size())
		var bar_width := minf(slot_width * 0.55, 54.0)
		for index in values.size():
			var ratio := float(values[index]) / float(maximum)
			var bar_height := maxf(plot.size.y * ratio, 2.0 if values[index] > 0 else 0.0)
			var x := plot.position.x + slot_width * float(index) + (slot_width - bar_width) * 0.5
			var bar := Rect2(x, plot.end.y - bar_height, bar_width, bar_height)
			draw_rect(Rect2(x, plot.position.y, bar_width, plot.size.y), Color(0.075, 0.07, 0.11), true)
			var color := PURPLE_BRIGHT if index == values.size() - 1 else PURPLE
			draw_rect(bar, color, true)
			if values[index] > 0:
				draw_string(font, Vector2(x - 5.0, bar.position.y - 5.0), _compact_money(values[index]), HORIZONTAL_ALIGNMENT_CENTER, bar_width + 10.0, 11, TEXT)
			var label := labels[index] if index < labels.size() else ""
			draw_string(font, Vector2(x - slot_width * 0.2, plot.end.y + 18.0), label, HORIZONTAL_ALIGNMENT_CENTER, bar_width + slot_width * 0.4, 10, MUTED)

	func _compact_money(amount: int) -> String:
		if amount >= 1000000:
			return "$%.1fM" % (float(amount) / 1000000.0)
		if amount >= 1000:
			return "$%.1fK" % (float(amount) / 1000.0)
		return "$%d" % amount

var _property_id: StringName
var _properties: PlayerPropertyComponent
var _wallet: PlayerWalletComponent
var _definition: PropertyDefinition
var _purchase_view: VBoxContainer
var _dashboard: VBoxContainer
var _summary: Label
var _revenue_value: Label
var _revenue_sub: Label
var _profit_value: Label
var _profit_sub: Label
var _sales_value: Label
var _sales_sub: Label
var _margin_value: Label
var _margin_sub: Label
var _chart: RevenueChart
var _business_info: Label
var _stock_value: Label
var _stock_bar: ProgressBar
var _pending_value: Label
var _balances: Label
var _quantity: SpinBox
var _cost: Label
var _purchase_action: Button
var _restock_action: Button
var _feedback: Label
var _configured := false


func setup(property_id: StringName, properties: PlayerPropertyComponent, wallet: PlayerWalletComponent) -> void:
	_property_id = property_id
	_properties = properties
	_wallet = wallet
	_definition = PropertyCatalog.get_by_id(property_id)
	if not _configured:
		_build_ui()
		_configured = true
		_properties.ownership_changed.connect(_on_ownership_changed)
		_properties.business_state_changed.connect(_on_business_state_changed)
		_wallet.money_changed.connect(_on_money_changed)
	refresh()


func refresh() -> void:
	if not _configured or _definition == null:
		return
	var owned := _properties.owns(_property_id)
	_purchase_view.visible = not owned
	_dashboard.visible = owned
	if not owned:
		_refresh_purchase()
		return
	_refresh_dashboard()


func _refresh_purchase() -> void:
	_summary.text = (
		"Purchase this front business to convert abstract stock into daily Clean Cash.\n\n"
		+ "CAPACITY  %d UNITS     RESTOCK  $%s DIRTY / UNIT     REVENUE  $%s CLEAN / SALE\n"
		+ "OPERATING HOURS  %s–%s     SALES EVERY %d MINUTES\n\nPURCHASE PRICE  $%s CLEAN"
	) % [
		_definition.business_stock_capacity,
		_money(_definition.business_restock_unit_cost),
		_money(_definition.business_revenue_per_sale),
		_time_text(_definition.business_open_minute),
		_time_text(_definition.business_close_minute),
		_definition.business_sales_interval_minutes,
		_money(_definition.purchase_price),
	]
	_purchase_action.text = "PURCHASE BUSINESS  $%s CLEAN" % _money(_definition.purchase_price)
	_purchase_action.disabled = not _wallet.can_spend_clean(_definition.purchase_price)


func _refresh_dashboard() -> void:
	var revenue := _properties.get_business_total_earned(_property_id)
	var restock_spent := _properties.get_business_total_restock_spent(_property_id)
	var profit := revenue - restock_spent
	var sales := _properties.get_business_total_sales(_property_id)
	var margin := (float(profit) / float(revenue) * 100.0) if revenue > 0 else 0.0
	var current_day := _get_absolute_minute() / WorldTimeComponent.MINUTES_PER_DAY
	var today := _properties.get_business_daily_revenue(_property_id, current_day)
	_revenue_value.text = "$%s" % _money(revenue)
	_revenue_sub.text = "+ $%s today" % _money(today)
	_profit_value.text = "%s$%s" % ["-" if profit < 0 else "", _money(absi(profit))]
	_profit_sub.text = "$%s total restock cost" % _money(restock_spent)
	_sales_value.text = _money(sales)
	_sales_sub.text = "%d unit%s today" % [today / _definition.business_revenue_per_sale, "" if today == _definition.business_revenue_per_sale else "s"]
	_margin_value.text = "%.0f%%" % margin
	_margin_sub.text = "Revenue after restocking"
	var values: Array[int] = []
	var labels: Array[String] = []
	for offset in range(6, -1, -1):
		var day_index := current_day - offset
		values.append(_properties.get_business_daily_revenue(_property_id, day_index))
		labels.append("TODAY" if offset == 0 else "-%dD" % offset)
	_chart.set_chart_data(values, labels)
	var current_minute := posmod(_get_absolute_minute(), WorldTimeComponent.MINUTES_PER_DAY)
	var is_open := current_minute >= _definition.business_open_minute and current_minute < _definition.business_close_minute
	_business_info.text = (
		"CAPACITY\n  %d units\n\nLOCATION\n  %s\n\nBUSINESS TYPE\n  %s\n\nOPENING HOURS\n  %s–%s\n\nSTATUS\n  %s"
	) % [
		_definition.business_stock_capacity,
		_definition.neighborhood,
		"Clothing Store" if _property_id == PropertyCatalog.CLOTHING_STORE_ID else "Gun Store",
		_time_text(_definition.business_open_minute),
		_time_text(_definition.business_close_minute),
		"OPEN" if is_open else "CLOSED",
	]
	var stock := _properties.get_business_stock(_property_id)
	var remaining := _definition.business_stock_capacity - stock
	_stock_value.text = "%d / %d UNITS" % [stock, _definition.business_stock_capacity]
	_stock_bar.max_value = _definition.business_stock_capacity
	_stock_bar.value = stock
	_pending_value.text = "$%s CLEAN pending for day end" % _money(_properties.get_business_accumulated_earnings(_property_id))
	_balances.text = "DIRTY CASH\n$%s\n\nCLEAN BANK\n$%s" % [_money(_wallet.dirty_cash), _money(_wallet.clean_cash)]
	_quantity.max_value = maxi(remaining, 1)
	_quantity.value = clampi(roundi(_quantity.value), 1, maxi(remaining, 1))
	var units := int(_quantity.value)
	var total_cost := units * _definition.business_restock_unit_cost
	_cost.text = "%d unit%s × $%s = $%s DIRTY" % [units, "" if units == 1 else "s", _money(_definition.business_restock_unit_cost), _money(total_cost)]
	_restock_action.text = "RESTOCK %d UNIT%s" % [units, "" if units == 1 else "S"]
	_restock_action.disabled = remaining <= 0 or not _wallet.can_spend_dirty(total_cost)
	if remaining <= 0:
		_restock_action.text = "STOCK AT CAPACITY"


func _build_ui() -> void:
	name = "BusinessManagementPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	_purchase_view = VBoxContainer.new()
	_purchase_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_purchase_view.alignment = BoxContainer.ALIGNMENT_CENTER
	_purchase_view.add_theme_constant_override("separation", 20)
	add_child(_purchase_view)
	var purchase_heading := Label.new()
	purchase_heading.text = _definition.display_name.to_upper()
	purchase_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purchase_heading.add_theme_font_size_override("font_size", 30)
	purchase_heading.add_theme_color_override("font_color", PURPLE_BRIGHT)
	_purchase_view.add_child(purchase_heading)
	_summary = Label.new()
	_summary.name = "BusinessSummary"
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_font_size_override("font_size", 19)
	_summary.add_theme_color_override("font_color", TEXT)
	_purchase_view.add_child(_summary)
	_purchase_action = Button.new()
	_purchase_action.name = "BusinessActionButton"
	_purchase_action.custom_minimum_size = Vector2(520, 58)
	_purchase_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(_purchase_action, PURPLE)
	_purchase_action.pressed.connect(_on_action_pressed)
	_purchase_view.add_child(_purchase_action)
	_feedback = Label.new()
	_feedback.name = "BusinessFeedback"
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 16)
	_feedback.add_theme_color_override("font_color", GREEN)
	_purchase_view.add_child(_feedback)
	_dashboard = VBoxContainer.new()
	_dashboard.name = "BusinessDashboard"
	_dashboard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dashboard.add_theme_constant_override("separation", 12)
	add_child(_dashboard)
	var metrics := HBoxContainer.new()
	metrics.custom_minimum_size.y = 112
	metrics.add_theme_constant_override("separation", 12)
	_dashboard.add_child(metrics)
	var revenue_card := _metric_card(metrics, "TOTAL REVENUE", GREEN)
	_revenue_value = revenue_card[0]
	_revenue_value.name = "TotalRevenueValue"
	_revenue_sub = revenue_card[1]
	var profit_card := _metric_card(metrics, "TOTAL PROFIT", GREEN)
	_profit_value = profit_card[0]
	_profit_value.name = "TotalProfitValue"
	_profit_sub = profit_card[1]
	var sales_card := _metric_card(metrics, "PRODUCT SALES", BLUE)
	_sales_value = sales_card[0]
	_sales_value.name = "ProductSalesValue"
	_sales_sub = sales_card[1]
	var margin_card := _metric_card(metrics, "NET PROFIT MARGIN", PURPLE_BRIGHT)
	_margin_value = margin_card[0]
	_margin_value.name = "ProfitMarginValue"
	_margin_sub = margin_card[1]
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	_dashboard.add_child(middle)
	var chart_panel := _panel()
	chart_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(chart_panel)
	var chart_box := VBoxContainer.new()
	chart_box.add_theme_constant_override("separation", 2)
	chart_panel.add_child(chart_box)
	chart_box.add_child(_heading("REVENUE OVER TIME", "LAST 7 DAYS"))
	_chart = RevenueChart.new()
	_chart.name = "RevenueChart"
	_chart.custom_minimum_size = Vector2(600, 235)
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_box.add_child(_chart)
	var info_panel := _panel()
	info_panel.custom_minimum_size.x = 300
	middle.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_box)
	info_box.add_child(_heading("BUSINESS INFO", "LIVE OPERATING DETAILS"))
	_business_info = Label.new()
	_business_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_business_info.add_theme_font_size_override("font_size", 15)
	_business_info.add_theme_color_override("font_color", TEXT)
	info_box.add_child(_business_info)
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size.y = 152
	bottom.add_theme_constant_override("separation", 12)
	_dashboard.add_child(bottom)
	var inventory_panel := _panel()
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(inventory_panel)
	var inventory := VBoxContainer.new()
	inventory.add_theme_constant_override("separation", 8)
	inventory_panel.add_child(inventory)
	inventory.add_child(_heading("INVENTORY & RESTOCK", "ABSTRACT BUSINESS STOCK"))
	var stock_row := HBoxContainer.new()
	inventory.add_child(stock_row)
	_stock_value = Label.new()
	_stock_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_value.add_theme_font_size_override("font_size", 18)
	stock_row.add_child(_stock_value)
	_pending_value = Label.new()
	_pending_value.add_theme_color_override("font_color", GREEN)
	stock_row.add_child(_pending_value)
	_stock_bar = ProgressBar.new()
	_stock_bar.show_percentage = false
	_stock_bar.custom_minimum_size.y = 12
	inventory.add_child(_stock_bar)
	var restock_row := HBoxContainer.new()
	restock_row.add_theme_constant_override("separation", 10)
	inventory.add_child(restock_row)
	_quantity = SpinBox.new()
	_quantity.name = "RestockQuantity"
	_quantity.min_value = 1
	_quantity.max_value = 1
	_quantity.step = 1
	_quantity.value = 1
	_quantity.custom_minimum_size = Vector2(110, 42)
	_quantity.value_changed.connect(_on_quantity_changed)
	restock_row.add_child(_quantity)
	_cost = Label.new()
	_cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	restock_row.add_child(_cost)
	_restock_action = Button.new()
	_restock_action.name = "DashboardRestockButton"
	_restock_action.custom_minimum_size = Vector2(210, 42)
	_style_button(_restock_action, PURPLE)
	_restock_action.pressed.connect(_on_action_pressed)
	restock_row.add_child(_restock_action)
	var cash_panel := _panel()
	cash_panel.custom_minimum_size.x = 245
	bottom.add_child(cash_panel)
	var cash_box := VBoxContainer.new()
	cash_panel.add_child(cash_box)
	cash_box.add_child(_heading("CASH POSITION", "CURRENT PLAYER BALANCES"))
	_balances = Label.new()
	_balances.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_balances.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_balances.add_theme_font_size_override("font_size", 18)
	_balances.add_theme_color_override("font_color", GREEN)
	cash_box.add_child(_balances)


func _metric_card(parent: HBoxContainer, title: String, color: Color) -> Array[Label]:
	var panel := _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", TEXT)
	box.add_child(title_label)
	var subtitle := Label.new()
	subtitle.text = "ALL TIME"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", MUTED)
	box.add_child(subtitle)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 27)
	value.add_theme_color_override("font_color", color)
	box.add_child(value)
	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", MUTED)
	box.add_child(detail)
	return [value, detail]


func _heading(title: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", TEXT)
	box.add_child(title_label)
	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", MUTED)
	box.add_child(subtitle_label)
	return box


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _style_button(button: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.45)
	normal.border_color = color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.darkened(0.25)
	button.add_theme_stylebox_override("hover", hover)


func _on_action_pressed() -> void:
	if not _properties.owns(_property_id):
		if _properties.purchase(_property_id, _get_absolute_minute()):
			_feedback.text = "Business purchased. Add stock to begin operating."
		else:
			_feedback.text = "Purchase failed. Check your Clean Cash balance."
	else:
		var units := int(_quantity.value)
		if not _properties.restock_business(_property_id, units):
			return
	refresh()


func _on_quantity_changed(_value: float) -> void:
	refresh()


func _on_ownership_changed(property_id: StringName, _owned: bool) -> void:
	if property_id == _property_id:
		refresh()


func _on_business_state_changed(property_id: StringName) -> void:
	if property_id == _property_id:
		refresh()


func _on_money_changed(_dirty: int, _clean: int) -> void:
	refresh()


func _get_absolute_minute() -> int:
	var world_time := get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	return world_time.get_absolute_minute() if world_time != null else 0


func _time_text(minute: int) -> String:
	var hour_24 := minute / 60
	var suffix := "AM" if hour_24 < 12 else "PM"
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:00 %s" % [hour_12, suffix]


func _money(amount: int) -> String:
	var text := str(amount)
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result
