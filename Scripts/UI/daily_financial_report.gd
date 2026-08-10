class_name DailyFinancialReport
extends Control

signal continue_requested

const GREEN := Color(0.25, 0.93, 0.39)
const RED := Color(1.0, 0.28, 0.16)
const BLUE := Color(0.25, 0.72, 1.0)
const TEXT := Color(0.82, 0.88, 0.94)
const MUTED := Color(0.48, 0.57, 0.66)
const GRID := Color(0.16, 0.25, 0.31, 0.78)
const PANEL := Color(0.018, 0.035, 0.046, 0.97)
const PANEL_ALT := Color(0.026, 0.052, 0.066, 0.96)
const BORDER := Color(0.23, 0.63, 0.78, 0.82)

class CashFlowChart:
	extends Control

	var days: Array[Dictionary] = []
	var earned := 0
	var spent := 0

	func _ready() -> void:
		custom_minimum_size = Vector2(430, 206)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_report(value: Array[Dictionary], total_earned: int, total_spent: int) -> void:
		days = value.duplicate(true)
		earned = total_earned
		spent = total_spent
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var graph := Rect2(54.0, 36.0, maxf(size.x - 70.0, 100.0), maxf(size.y - 66.0, 80.0))
		draw_rect(graph, Color(0.012, 0.026, 0.034, 0.96), true)
		var report_days := days.duplicate(true)
		if report_days.is_empty():
			report_days.append({"date": "TODAY", "earned": earned, "spent": spent})
		var max_value := 100
		for day in report_days:
			max_value = maxi(max_value, maxi(int(day.get("earned", 0)), int(day.get("spent", 0))))
		max_value = ceili(float(max_value) / 100.0) * 100
		for index in 5:
			var ratio := float(index) / 4.0
			var y := graph.end.y - graph.size.y * ratio
			draw_line(Vector2(graph.position.x, y), Vector2(graph.end.x, y), Color(0.14, 0.23, 0.28, 0.8), 1.0)
			var amount := roundi(float(max_value) * ratio)
			draw_string(font, Vector2(4, y + 4), _compact_money(amount), HORIZONTAL_ALIGNMENT_RIGHT, 44, 11, Color(0.38, 0.93, 0.49))
		for index in report_days.size():
			var ratio := 0.5 if report_days.size() == 1 else float(index) / float(report_days.size() - 1)
			var x := graph.position.x + graph.size.x * ratio
			draw_line(Vector2(x, graph.position.y), Vector2(x, graph.end.y), Color(0.14, 0.23, 0.28, 0.72), 1.0)
			var day_text := _compact_day_label(String(report_days[index].get("date", "DAY")))
			draw_string(font, Vector2(x - 27, graph.end.y + 19), day_text, HORIZONTAL_ALIGNMENT_CENTER, 54, 10, Color(0.55, 0.64, 0.7))
		draw_string(font, Vector2(10, 17), "DAILY PERFORMANCE", HORIZONTAL_ALIGNMENT_LEFT, 190, 13, Color(0.72, 0.82, 0.88))
		draw_string(font, Vector2(178, 17), "LAST 7 DAYS", HORIZONTAL_ALIGNMENT_LEFT, 90, 9, Color(0.42, 0.55, 0.63))
		draw_line(Vector2(size.x - 156, 13), Vector2(size.x - 142, 13), Color(0.25, 0.93, 0.39), 3.0)
		draw_string(font, Vector2(size.x - 136, 17), "INCOME", HORIZONTAL_ALIGNMENT_LEFT, 50, 10, Color(0.72, 0.82, 0.88))
		draw_line(Vector2(size.x - 76, 13), Vector2(size.x - 62, 13), Color(1.0, 0.28, 0.16), 3.0)
		draw_string(font, Vector2(size.x - 56, 17), "EXPENSES", HORIZONTAL_ALIGNMENT_LEFT, 55, 10, Color(0.72, 0.82, 0.88))
		var income_points := PackedVector2Array()
		var expense_points := PackedVector2Array()
		for index in report_days.size():
			var ratio := 0.5 if report_days.size() == 1 else float(index) / float(report_days.size() - 1)
			var x := graph.position.x + graph.size.x * ratio
			var day_earned := maxi(int(report_days[index].get("earned", 0)), 0)
			var day_spent := maxi(int(report_days[index].get("spent", 0)), 0)
			income_points.append(Vector2(x, graph.end.y - graph.size.y * float(day_earned) / float(max_value)))
			expense_points.append(Vector2(x, graph.end.y - graph.size.y * float(day_spent) / float(max_value)))
		if income_points.size() > 1:
			draw_polyline(income_points, Color(0.25, 0.93, 0.39), 3.0, true)
		if expense_points.size() > 1:
			draw_polyline(expense_points, Color(1.0, 0.28, 0.16), 3.0, true)
		for point in income_points:
			draw_circle(point, 4.0, Color(0.45, 1.0, 0.56))
		for point in expense_points:
			draw_circle(point, 4.0, Color(1.0, 0.45, 0.3))

	func _compact_money(amount: int) -> String:
		if amount >= 1000000:
			return "$%.1fM" % (float(amount) / 1000000.0)
		if amount >= 1000:
			return "$%.1fK" % (float(amount) / 1000.0)
		return "$%d" % amount

	func _compact_day_label(date_text: String) -> String:
		var parts := date_text.split(" ", false)
		if parts.size() >= 3:
			return "%s %s" % [parts[1], parts[2]]
		return date_text.left(8)

class LineIcon:
	extends Control

	var kind := "cash"
	var accent := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.39
		draw_circle(center, radius, Color(accent.r, accent.g, accent.b, 0.08))
		draw_arc(center, radius, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.86), 1.5, true)
		match kind:
			"income":
				var points := PackedVector2Array([
					center + Vector2(-radius * 0.58, radius * 0.35),
					center + Vector2(-radius * 0.12, -radius * 0.08),
					center + Vector2(radius * 0.18, radius * 0.08),
					center + Vector2(radius * 0.58, -radius * 0.48),
				])
				draw_polyline(points, accent, 2.0, true)
				draw_line(points[-1], points[-1] + Vector2(-radius * 0.38, 0), accent, 2.0)
				draw_line(points[-1], points[-1] + Vector2(0, radius * 0.38), accent, 2.0)
			"expense":
				var points := PackedVector2Array([
					center + Vector2(-radius * 0.58, -radius * 0.35),
					center + Vector2(-radius * 0.12, radius * 0.02),
					center + Vector2(radius * 0.18, -radius * 0.08),
					center + Vector2(radius * 0.58, radius * 0.48),
				])
				draw_polyline(points, accent, 2.0, true)
				draw_line(points[-1], points[-1] + Vector2(-radius * 0.38, 0), accent, 2.0)
				draw_line(points[-1], points[-1] + Vector2(0, -radius * 0.38), accent, 2.0)
			"list":
				for index in 3:
					var y := center.y - radius * 0.42 + float(index) * radius * 0.42
					draw_circle(Vector2(center.x - radius * 0.46, y), 1.8, accent)
					draw_line(Vector2(center.x - radius * 0.22, y), Vector2(center.x + radius * 0.5, y), accent, 1.8)
			"wallet":
				var rect := Rect2(center - Vector2(radius * 0.58, radius * 0.34), Vector2(radius * 1.16, radius * 0.68))
				draw_rect(rect, accent, false, 1.7)
				draw_circle(center + Vector2(radius * 0.28, 0), 2.0, accent)
			_:
				var font := ThemeDB.fallback_font
				draw_string(font, center + Vector2(-radius * 0.45, radius * 0.38), "$", HORIZONTAL_ALIGNMENT_CENTER, radius * 0.9, maxi(roundi(radius), 10), accent)

var _built := false
var _date_label: Label
var _revenue_value: Label
var _expense_value: Label
var _net_value: Label
var _cash_value: Label
var _income_rows: VBoxContainer
var _expense_rows: VBoxContainer
var _income_total_label: Label
var _expense_total_label: Label
var _best_value: Label
var _best_detail: Label
var _worst_value: Label
var _worst_detail: Label
var _transaction_count: Label
var _net_flow: Label
var _profit_value: Label
var _margin_value: Label
var _margin_bar: ProgressBar
var _chart: CashFlowChart
var _continue_button: Button


func _ready() -> void:
	if not _built:
		_build_interface()


func show_report(
	report_date: String,
	earned: int,
	spent: int,
	transactions: Array[Dictionary],
	cash_on_hand: int,
	daily_history: Array[Dictionary]
) -> void:
	if not _built:
		_build_interface()
	var entries := _with_balancing_entries(transactions, earned, spent)
	_date_label.text = "%s   |   00:00 - 23:59" % report_date
	_revenue_value.text = _money(earned)
	_expense_value.text = _money(spent)
	var net := earned - spent
	_net_value.text = _signed_money(net)
	_net_value.add_theme_color_override("font_color", GREEN if net >= 0 else RED)
	_cash_value.text = _money(cash_on_hand)
	_populate_ledger(_income_rows, entries, "income")
	_populate_ledger(_expense_rows, entries, "expense")
	_income_total_label.text = _money(earned)
	_expense_total_label.text = _money(spent)
	var best := _largest_entry(entries, "income")
	var worst := _largest_entry(entries, "expense")
	_best_value.text = _money(int(best.get("amount", 0)))
	_best_detail.text = _entry_summary(best, "No income recorded")
	_worst_value.text = _money(int(worst.get("amount", 0)))
	_worst_detail.text = _entry_summary(worst, "No expenses recorded")
	_transaction_count.text = str(entries.size())
	_net_flow.text = _signed_money(net)
	_net_flow.add_theme_color_override("font_color", GREEN if net >= 0 else RED)
	_profit_value.text = _signed_money(net)
	_profit_value.add_theme_color_override("font_color", GREEN if net >= 0 else RED)
	var margin := (float(net) / float(earned) * 100.0) if earned > 0 else 0.0
	_margin_value.text = "%.1f%%" % margin
	_margin_value.add_theme_color_override("font_color", GREEN if margin >= 0.0 else RED)
	_margin_bar.value = clampf(absf(margin), 0.0, 100.0)
	var fill := _margin_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill.bg_color = GREEN if margin >= 0.0 else RED
	_margin_bar.add_theme_stylebox_override("fill", fill)
	_chart.set_report(daily_history, earned, spent)
	visible = true
	_continue_button.grab_focus()


func _build_interface() -> void:
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.008, 0.015, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var frame := PanelContainer.new()
	frame.name = "FinancialReportFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 34
	frame.offset_top = 24
	frame.offset_right = -34
	frame.offset_bottom = -24
	frame.add_theme_stylebox_override("panel", _style(PANEL, BORDER, 2, 10, Color(0.0, 0.55, 0.78, 0.22), 18))
	add_child(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	frame.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	margin.add_child(root)
	root.add_child(_build_header())
	root.add_child(_build_top_section())
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	var income_panel := _build_ledger_panel("REVENUE", GREEN, "income")
	income_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(income_panel)
	var expense_panel := _build_ledger_panel("EXPENSES", RED, "expense")
	expense_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(expense_panel)
	var summary := _build_summary_panel()
	summary.custom_minimum_size.x = 260
	middle.add_child(summary)
	root.add_child(middle)
	root.add_child(_build_profit_bar())
	_continue_button = Button.new()
	_continue_button.name = "ReportContinueButton"
	_continue_button.custom_minimum_size.y = 43
	_continue_button.text = "CONTINUE"
	_continue_button.add_theme_font_size_override("font_size", 17)
	_continue_button.add_theme_color_override("font_color", Color(0.9, 0.95, 0.98))
	_continue_button.add_theme_stylebox_override("normal", _style(Color(0.025, 0.05, 0.062), BORDER, 1, 4))
	_continue_button.add_theme_stylebox_override("hover", _style(Color(0.05, 0.13, 0.16), BLUE, 1, 4, Color(0.1, 0.65, 0.9, 0.18), 5))
	_continue_button.add_theme_stylebox_override("pressed", _style(Color(0.025, 0.09, 0.11), GREEN, 1, 4))
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	root.add_child(_continue_button)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 58
	header.add_theme_constant_override("separation", 14)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(58, 58)
	icon_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.075, 0.095), BLUE, 1, 6))
	var icon := _label("$", 29, BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_panel.add_child(icon)
	header.add_child(icon_panel)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(_label("DAILY FINANCIAL REPORT", 27, Color(0.91, 0.96, 1.0)))
	_date_label = _label("MON JAN 1   |   00:00 - 23:59", 14, Color(0.64, 0.75, 0.84))
	titles.add_child(_date_label)
	header.add_child(titles)
	var status := _label("DAY CLOSED  /  LEDGER FINAL", 12, GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(status)
	return header


func _build_top_section() -> Control:
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 210
	top.add_theme_constant_override("separation", 10)
	var metrics := GridContainer.new()
	metrics.columns = 2
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("h_separation", 8)
	metrics.add_theme_constant_override("v_separation", 8)
	_revenue_value = _add_metric(metrics, "TOTAL REVENUE", "$0", GREEN, "income")
	_expense_value = _add_metric(metrics, "TOTAL EXPENSES", "$0", RED, "expense")
	_net_value = _add_metric(metrics, "NET PROFIT", "$0", GREEN, "cash")
	_cash_value = _add_metric(metrics, "CASH ON HAND", "$0", BLUE, "wallet")
	var chart_panel := PanelContainer.new()
	chart_panel.custom_minimum_size.x = 530
	chart_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_panel.add_theme_stylebox_override("panel", _style(Color(0.014, 0.03, 0.039), Color(0.18, 0.42, 0.52), 1, 5))
	var chart_margin := MarginContainer.new()
	chart_margin.add_theme_constant_override("margin_left", 8)
	chart_margin.add_theme_constant_override("margin_top", 6)
	chart_margin.add_theme_constant_override("margin_right", 8)
	chart_margin.add_theme_constant_override("margin_bottom", 4)
	chart_panel.add_child(chart_margin)
	_chart = CashFlowChart.new()
	_chart.name = "CashFlowChart"
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_margin.add_child(_chart)
	top.add_child(metrics)
	top.add_child(chart_panel)
	return top


func _add_metric(parent: GridContainer, title: String, value: String, color: Color, icon_text: String) -> Label:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(205, 99)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(PANEL_ALT, Color(color.r, color.g, color.b, 0.75), 1, 5, Color(color.r, color.g, color.b, 0.1), 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	margin.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_child(_label(title, 11, color))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	heading.add_child(_line_icon(icon_text, color, 24))
	box.add_child(heading)
	var value_label := _label(value, 25, color)
	box.add_child(value_label)
	box.add_child(_label("TODAY'S ACTIVITY", 9, MUTED))
	parent.add_child(card)
	return value_label


func _build_ledger_panel(title: String, color: Color, direction: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 290)
	panel.add_theme_stylebox_override("panel", _style(Color(0.014, 0.029, 0.038), Color(0.17, 0.36, 0.44), 1, 4))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var heading := _section_heading(title, color)
	box.add_child(heading)
	box.add_child(_ledger_header())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	scroll.add_child(rows)
	box.add_child(scroll)
	var total_row := HBoxContainer.new()
	total_row.custom_minimum_size.y = 44
	total_row.add_theme_stylebox_override("panel", _style(Color(0.02, 0.055, 0.062), Color.TRANSPARENT, 0, 0))
	var total_title := _label("TOTAL %s" % title, 16, color)
	total_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(total_title)
	var total := _label("$0", 19, color, HORIZONTAL_ALIGNMENT_RIGHT)
	total.custom_minimum_size.x = 100
	total_row.add_child(total)
	box.add_child(total_row)
	if direction == "income":
		_income_rows = rows
		_income_total_label = total
	else:
		_expense_rows = rows
		_expense_total_label = total
	return panel


func _ledger_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	row.add_theme_constant_override("separation", 5)
	var category := _label("CATEGORY", 13, Color(0.58, 0.68, 0.75))
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category.size_flags_stretch_ratio = 0.31
	row.add_child(category)
	var detail := _label("DETAIL", 13, Color(0.58, 0.68, 0.75))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = 0.47
	row.add_child(detail)
	var amount := _label("AMOUNT", 13, Color(0.58, 0.68, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.size_flags_stretch_ratio = 0.22
	row.add_child(amount)
	return row


func _populate_ledger(rows: VBoxContainer, entries: Array[Dictionary], direction: String) -> void:
	for child in rows.get_children():
		child.queue_free()
	var count := 0
	for entry in entries:
		if String(entry.get("direction", "")) != direction:
			continue
		rows.add_child(_ledger_row(entry, direction, count % 2 == 1))
		count += 1
	if count == 0:
		var empty := _label("NO TRANSACTIONS RECORDED", 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		empty.custom_minimum_size.y = 58
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rows.add_child(empty)


func _ledger_row(entry: Dictionary, direction: String, alternate: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 43
	row.add_theme_constant_override("separation", 5)
	if alternate:
		row.add_theme_stylebox_override("panel", _style(Color(0.025, 0.052, 0.061, 0.62), Color.TRANSPARENT, 0, 0))
	var category := _label(String(entry.get("category", "Other")), 15, TEXT)
	category.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category.size_flags_stretch_ratio = 0.31
	category.tooltip_text = category.text
	row.add_child(category)
	var minute := clampi(int(entry.get("minute", 0)), 0, 1439)
	var time_text := "%02d:%02d" % [minute / 60, minute % 60]
	var detail_text := "%s  ·  %s  ·  %s" % [String(entry.get("detail", "Transaction")), String(entry.get("cash_type", "Cash")), time_text]
	var detail := _label(detail_text, 14, Color(0.66, 0.74, 0.8))
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = 0.47
	detail.tooltip_text = detail_text
	row.add_child(detail)
	var color := GREEN if direction == "income" else RED
	var amount := _label(_money(int(entry.get("amount", 0))), 16, color, HORIZONTAL_ALIGNMENT_RIGHT)
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.size_flags_stretch_ratio = 0.22
	row.add_child(amount)
	return row


func _build_summary_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.014, 0.029, 0.038), Color(0.17, 0.36, 0.44), 1, 4))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	box.add_child(_section_heading("PERFORMANCE SUMMARY", BLUE))
	var best := _summary_card("BEST EARNER", "income", GREEN)
	_best_detail = best[0] as Label
	_best_value = best[1] as Label
	box.add_child(best[2] as Control)
	var worst := _summary_card("HIGHEST EXPENSE", "expense", RED)
	_worst_detail = worst[0] as Label
	_worst_value = worst[1] as Label
	box.add_child(worst[2] as Control)
	var count := _summary_card("TOTAL TRANSACTIONS", "list", BLUE)
	_transaction_count = count[1] as Label
	(count[0] as Label).text = "Ledger entries"
	box.add_child(count[2] as Control)
	var flow := _summary_card("NET CASH FLOW", "wallet", GREEN)
	_net_flow = flow[1] as Label
	(flow[0] as Label).text = "Revenue minus expenses"
	box.add_child(flow[2] as Control)
	return panel


func _summary_card(title: String, icon_text: String, color: Color) -> Array:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(Color(0.018, 0.042, 0.052), Color(0.17, 0.36, 0.44), 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var icon := _line_icon(icon_text, color, 40)
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_label(title, 13, color))
	var detail := _label("No activity", 14, Color(0.7, 0.78, 0.83))
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(detail)
	var value := _label("$0", 20, color)
	texts.add_child(value)
	row.add_child(texts)
	return [detail, value, card]


func _build_profit_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 55
	panel.add_theme_stylebox_override("panel", _style(Color(0.018, 0.06, 0.051), Color(0.23, 0.78, 0.38), 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	row.add_child(_label("NET PROFIT", 16, GREEN))
	_profit_value = _label("$0", 22, GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	_profit_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_profit_value)
	var divider := VSeparator.new()
	divider.custom_minimum_size.x = 1
	row.add_child(divider)
	var margin_title := _label("PROFIT MARGIN", 10, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	margin_title.custom_minimum_size.x = 110
	row.add_child(margin_title)
	_margin_value = _label("0.0%", 17, GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	_margin_value.custom_minimum_size.x = 72
	row.add_child(_margin_value)
	_margin_bar = ProgressBar.new()
	_margin_bar.custom_minimum_size = Vector2(88, 9)
	_margin_bar.max_value = 100
	_margin_bar.show_percentage = false
	_margin_bar.add_theme_stylebox_override("background", _style(Color(0.08, 0.14, 0.16), Color.TRANSPARENT, 0, 5))
	_margin_bar.add_theme_stylebox_override("fill", _style(GREEN, Color.TRANSPARENT, 0, 5))
	row.add_child(_margin_bar)
	return panel


func _section_heading(text: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 39
	panel.add_theme_stylebox_override("panel", _style(Color(color.r * 0.06, color.g * 0.06, color.b * 0.06, 0.8), Color.TRANSPARENT, 0, 0))
	var label := _label(text, 17, color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _label(text: String, size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _line_icon(kind: String, color: Color, pixels: int) -> LineIcon:
	var icon := LineIcon.new()
	icon.kind = kind
	icon.accent = color
	icon.custom_minimum_size = Vector2(pixels, pixels)
	return icon


func _style(background: Color, border: Color, border_width: int, radius: int, shadow := Color.TRANSPARENT, shadow_size := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = shadow
	style.shadow_size = shadow_size
	return style


func _with_balancing_entries(source: Array[Dictionary], earned: int, spent: int) -> Array[Dictionary]:
	var result := source.duplicate(true)
	var listed_income := 0
	var listed_expenses := 0
	for entry in result:
		if String(entry.get("direction", "")) == "income":
			listed_income += int(entry.get("amount", 0))
		else:
			listed_expenses += int(entry.get("amount", 0))
	if listed_income < earned:
		result.append({"minute": 1439, "amount": earned - listed_income, "direction": "income", "category": "Other Income", "detail": "Uncategorized earnings", "cash_type": "Cash"})
	if listed_expenses < spent:
		result.append({"minute": 1439, "amount": spent - listed_expenses, "direction": "expense", "category": "Other Expense", "detail": "Uncategorized spending", "cash_type": "Cash"})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("minute", 0)) < int(b.get("minute", 0)))
	return result


func _largest_entry(entries: Array[Dictionary], direction: String) -> Dictionary:
	var result: Dictionary = {}
	for entry in entries:
		if String(entry.get("direction", "")) != direction:
			continue
		if int(entry.get("amount", 0)) > int(result.get("amount", -1)):
			result = entry
	return result


func _entry_summary(entry: Dictionary, fallback: String) -> String:
	if entry.is_empty():
		return fallback
	return "%s (%s)" % [String(entry.get("category", "Other")), String(entry.get("detail", "Transaction"))]


func _money(amount: int) -> String:
	var value := str(absi(amount))
	var formatted := ""
	while value.length() > 3:
		formatted = ",%s%s" % [value.right(3), formatted]
		value = value.left(value.length() - 3)
	return "$%s%s" % [value, formatted]


func _signed_money(amount: int) -> String:
	if amount > 0:
		return "+%s" % _money(amount)
	if amount < 0:
		return "-%s" % _money(-amount)
	return "$0"
