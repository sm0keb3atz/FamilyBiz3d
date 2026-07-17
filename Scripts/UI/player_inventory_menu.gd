class_name PlayerInventoryMenu
extends CanvasLayer

class TerritoryRevenueChart extends Control:
	var values: Array[int] = []

	func set_values(new_values: Array[int]) -> void:
		values = new_values
		queue_redraw()

	func _draw() -> void:
		if values.is_empty():
			return
		var font := ThemeDB.fallback_font
		var plot := Rect2(48.0, 16.0, maxf(size.x - 62.0, 40.0), maxf(size.y - 43.0, 40.0))
		var maximum := 1
		for value in values:
			maximum = maxi(maximum, value)
		for line_index in 4:
			var ratio := float(line_index) / 3.0
			var y := plot.end.y - plot.size.y * ratio
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.12, 0.21, 0.23, 0.85), 1.0)
			var amount := roundi(float(maximum) * ratio)
			draw_string(font, Vector2(0.0, y + 4.0), _compact_money(amount), HORIZONTAL_ALIGNMENT_RIGHT, 42.0, 10, Color(0.5, 0.58, 0.62))
		var points := PackedVector2Array()
		var slot_width := plot.size.x / float(maxi(values.size() - 1, 1))
		for index in values.size():
			var x := plot.position.x + slot_width * float(index)
			var y := plot.end.y - plot.size.y * (float(values[index]) / float(maximum))
			points.append(Vector2(x, y))
			draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(0.08, 0.15, 0.17, 0.55), 1.0)
		if points.size() >= 2:
			var fill := PackedVector2Array(points)
			fill.append(Vector2(points[points.size() - 1].x, plot.end.y))
			fill.append(Vector2(points[0].x, plot.end.y))
			draw_colored_polygon(fill, Color(0.08, 0.76, 0.55, 0.12))
			draw_polyline(points, Color(0.12, 0.86, 0.61), 3.0, true)
		for index in points.size():
			var point := points[index]
			draw_circle(point, 5.0, Color(0.12, 0.86, 0.61))
			draw_circle(point, 2.0, Color(0.8, 1.0, 0.92))
			var label := "TODAY" if index == points.size() - 1 else "%dD" % (points.size() - 1 - index)
			draw_string(font, Vector2(point.x - 23.0, plot.end.y + 18.0), label, HORIZONTAL_ALIGNMENT_CENTER, 46.0, 10, Color(0.53, 0.61, 0.65))
		var today_value := values[values.size() - 1]
		draw_string(font, Vector2(plot.end.x - 82.0, plot.position.y + 12.0), "TODAY  %s" % _compact_money(today_value), HORIZONTAL_ALIGNMENT_RIGHT, 82.0, 11, Color(0.2, 0.9, 0.62))

	func _compact_money(amount: int) -> String:
		if amount >= 1000000:
			return "$%.1fM" % (float(amount) / 1000000.0)
		if amount >= 1000:
			return "$%.1fK" % (float(amount) / 1000.0)
		return "$%d" % amount

@export var inventory_component_path := NodePath(
	"../Components/InventoryComponent"
)
@export var weapon_component_path := NodePath("../Components/WeaponComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")
@export var girlfriend_component_path := NodePath("../Components/GirlfriendComponent")
@export var property_component_path := NodePath("../Components/PropertyComponent")
@export var wallet_component_path := NodePath("../Components/WalletComponent")

@onready var menu_root := %MenuRoot as Control
@onready var tab_container := %TabContainer as TabContainer
@onready var content := $MenuRoot/Panel/Margin/Content as VBoxContainer
@onready var title_label := $MenuRoot/Panel/Margin/Content/Title as Label
@onready var dashboard_panel := $MenuRoot/Panel as PanelContainer
@onready var drug_list := %DrugList as VBoxContainer
@onready var weapon_list := %WeaponList as VBoxContainer
@onready var girlfriend_list := %GirlfriendList as VBoxContainer
@onready var property_list := %PropertyList as VBoxContainer
@onready var territory_list := %TerritoryList as VBoxContainer
@onready var feedback_label := %FeedbackLabel as Label
@onready var inventory := (
	get_node(inventory_component_path) as PlayerInventoryComponent
)
@onready var weapon_component := (
	get_node_or_null(weapon_component_path) as PlayerWeaponComponent
)
@onready var menu_controller := (
	get_node(menu_controller_path) as PlayerMenuController
)
@onready var girlfriends := get_node_or_null(girlfriend_component_path) as PlayerGirlfriendComponent
@onready var properties := get_node_or_null(property_component_path) as PlayerPropertyComponent
@onready var wallet := get_node_or_null(wallet_component_path) as PlayerWalletComponent

var _is_open := false
var _territory_dealers: TerritoryDealerService
var _navigation_buttons: Dictionary[int, Button] = {}
var _body: HBoxContainer
var _resize_tween: Tween


func _ready() -> void:
	inventory.quantity_changed.connect(_on_quantity_changed)
	if weapon_component != null:
		weapon_component.weapon_changed.connect(_on_weapon_changed)
		weapon_component.ammo_changed.connect(_on_ammo_changed)
		weapon_component.attachments_changed.connect(_on_attachments_changed)
	if girlfriends != null:
		girlfriends.roster_changed.connect(_on_roster_changed)
	if properties != null:
		properties.ownership_changed.connect(_on_property_changed)
		properties.stash_changed.connect(_on_property_stash_changed)
	if wallet != null:
		wallet.money_changed.connect(_on_wallet_changed)
	call_deferred("_resolve_territory_dealers")
	_style_tabs()
	_build_inventory_shell()
	menu_root.visible = false
	_refresh()


func _build_inventory_shell() -> void:
	title_label.visible = false
	$MenuRoot/Panel/Margin/Content/Hint.visible = false
	tab_container.tabs_visible = false
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.remove_child(tab_container)
	_body = HBoxContainer.new()
	_body.name = "DashboardBody"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	content.add_child(_body)
	content.move_child(_body, 0)
	var sidebar := VBoxContainer.new()
	sidebar.name = "Navigation"
	sidebar.custom_minimum_size = Vector2(190, 0)
	sidebar.add_theme_constant_override("separation", 6)
	_body.add_child(sidebar)
	var brand := Label.new()
	brand.text = "FAMILY BUSINESS"
	brand.add_theme_font_size_override("font_size", 18)
	brand.add_theme_color_override("font_color", Color(0.28, 0.9, 0.96))
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.custom_minimum_size.y = 52
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sidebar.add_child(brand)
	var separator := HSeparator.new()
	separator.modulate = Color(0.2, 0.7, 0.75, 0.45)
	sidebar.add_child(separator)
	var page_order := [
		{"label": "DRUGS", "index": 0},
		{"label": "WEAPONS", "index": 1},
		{"label": "PROPERTY", "index": 3},
		{"label": "TERRITORY", "index": 4},
		{"label": "GIRLFRIENDS", "index": 2},
	]
	for page in page_order:
		var button := Button.new()
		button.text = "   " + String(page.label)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(_select_sidebar_tab.bind(int(page.index)))
		sidebar.add_child(button)
		_navigation_buttons[int(page.index)] = button
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)
	var hint := Label.new()
	hint.text = "I / ESC  CLOSE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.42, 0.48, 0.54))
	sidebar.add_child(hint)
	var rail := VSeparator.new()
	rail.modulate = Color(0.15, 0.55, 0.6, 0.45)
	_body.add_child(rail)
	_body.add_child(tab_container)
	tab_container.tab_changed.connect(_on_dashboard_tab_changed)
	_update_navigation_styles()


func _select_sidebar_tab(index: int) -> void:
	tab_container.current_tab = index
	_update_navigation_styles()


func _on_dashboard_tab_changed(_index: int) -> void:
	_update_navigation_styles()
	if _is_open:
		_animate_panel_for_tab(true)


func _animate_panel_for_tab(animated: bool, territory_override := -1) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var territory_mode := (
		tab_container.current_tab == 4
		if territory_override < 0
		else territory_override == 1
	)
	var edge_margin := 18.0 if territory_mode else 54.0
	var maximum := Vector2(1500.0, 900.0) if territory_mode else Vector2(1200.0, 720.0)
	var target_size := Vector2(
		minf(maximum.x, maxf(viewport_size.x - edge_margin * 2.0, 760.0)),
		minf(maximum.y, maxf(viewport_size.y - edge_margin * 2.0, 560.0))
	)
	var targets := {
		"offset_left": -target_size.x * 0.5,
		"offset_top": -target_size.y * 0.5,
		"offset_right": target_size.x * 0.5,
		"offset_bottom": target_size.y * 0.5,
	}
	if is_instance_valid(_resize_tween):
		_resize_tween.kill()
	if not animated:
		for property_name in targets:
			dashboard_panel.set(property_name, targets[property_name])
		return
	_resize_tween = create_tween().set_parallel(true)
	_resize_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for property_name in targets:
		_resize_tween.tween_property(
			dashboard_panel,
			property_name,
			targets[property_name],
			0.32
		)


func _update_navigation_styles() -> void:
	for index in _navigation_buttons:
		var button := _navigation_buttons[index]
		var selected := int(index) == tab_container.current_tab
		var accent := Color(0.18, 0.84, 0.9) if selected else Color(0.18, 0.22, 0.26)
		button.add_theme_stylebox_override("normal", _make_panel_style(
			Color(0.055, 0.085, 0.095, 0.98) if selected else Color(0.045, 0.052, 0.062, 0.94), accent))
		button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.07, 0.11, 0.12, 1.0), Color(0.2, 0.72, 0.78)))
		button.add_theme_color_override("font_color", Color(0.88, 0.95, 0.97) if selected else Color(0.62, 0.68, 0.73))


func _input(event: InputEvent) -> void:
	if not _is_open and not menu_controller.active_menu.is_empty():
		return
	if event.is_action_pressed(&"inventory"):
		set_menu_open(not _is_open)
		get_viewport().set_input_as_handled()
	elif (
		_is_open
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_ESCAPE
	):
		set_menu_open(false)
		get_viewport().set_input_as_handled()


func set_menu_open(open: bool) -> void:
	if open:
		if not menu_controller.request_open(&"inventory"):
			return
	elif not menu_controller.close(&"inventory"):
		return

	_is_open = open
	menu_root.visible = _is_open
	if _is_open:
		_refresh()
		if tab_container.current_tab == 4:
			_animate_panel_for_tab(false, 0)
			_animate_panel_for_tab(true, 1)
		else:
			_animate_panel_for_tab(false, 0)
	else:
		_animate_panel_for_tab(false, 0)


func _refresh() -> void:
	_refresh_drugs()
	_refresh_weapons()
	_refresh_girlfriends()
	_refresh_properties()
	_refresh_territory()


func _resolve_territory_dealers() -> void:
	_territory_dealers = get_tree().get_first_node_in_group(&"territory_dealer_service") as TerritoryDealerService
	if _territory_dealers != null and not _territory_dealers.state_changed.is_connected(_on_territory_dealer_state_changed):
		_territory_dealers.state_changed.connect(_on_territory_dealer_state_changed)


func _refresh_territory() -> void:
	for child in territory_list.get_children():
		child.queue_free()
	if _territory_dealers == null:
		_resolve_territory_dealers()
	if _territory_dealers == null:
		territory_list.add_child(_create_empty_dashboard("TERRITORY MANAGEMENT UNAVAILABLE", "The territory service could not be found."))
		return
	var player := get_parent() as CharacterBody3D
	var boundary := TerritoryBoundary.find_at_position(get_tree(), player.global_position) if player != null else null
	if boundary == null or boundary.stats == null or boundary.stats.owner_faction != TerritoryStatsComponent.OwnerFaction.PLAYER:
		territory_list.add_child(_create_empty_dashboard("NO OWNED TERRITORY", "Enter territory you control to manage its dealers and income."))
		return
	var territory_id := boundary.territory_id
	var supply := _territory_dealers.get_supply_summary(territory_id)
	var earnings := _territory_dealers.get_earnings_summary(territory_id)
	territory_list.add_child(_create_territory_header(boundary.display_name))
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	stats_row.add_child(_create_stat_card("REPUTATION", "%d / 100" % roundi(boundary.stats.reputation),
		"MAX REPUTATION" if boundary.stats.reputation >= 100.0 else "Territory standing",
		Color(0.18, 0.66, 1.0), clampf((boundary.stats.reputation + 100.0) / 200.0, 0.0, 1.0)))
	stats_row.add_child(_create_stat_card("DAILY NET", "$%s" % _money(int(earnings.today_net)),
		"Lifetime: $%s" % _money(int(earnings.lifetime_net)), Color(0.2, 0.82, 0.42), -1.0))
	stats_row.add_child(_create_stat_card("TOTAL DEALERS", "%d / %d" % [int(earnings.staffed), int(earnings.total_slots)],
		"HIRED", Color(0.72, 0.3, 0.88), float(earnings.staffed) / maxf(float(earnings.total_slots), 1.0)))
	stats_row.add_child(_create_stat_card("HEAT", "%d / 100" % roundi(boundary.stats.heat),
		"SAFE" if boundary.stats.heat < 25.0 else "ELEVATED", Color(0.95, 0.22, 0.3), boundary.stats.heat / 100.0))
	territory_list.add_child(stats_row)
	var workspace := HBoxContainer.new()
	workspace.add_theme_constant_override("separation", 10)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.95
	left.add_theme_constant_override("separation", 10)
	left.add_child(_create_revenue_panel(earnings))
	left.add_child(_create_territory_details_panel(supply, earnings))
	workspace.add_child(left)
	var dealer_panel := _create_section_panel("DEALER MANAGEMENT")
	dealer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dealer_panel.size_flags_stretch_ratio = 1.15
	var dealer_box := dealer_panel.get_meta("content") as VBoxContainer
	var roster := _territory_dealers.get_roster(territory_id)
	dealer_box.add_child(_create_dealer_table_header(earnings))
	var current_zone: StringName = &""
	for entry in roster:
		var zone_id := StringName(entry.zone_id)
		if zone_id != current_zone:
			current_zone = zone_id
			var heading := _detail_label(String(zone_id).replace("hood_east_", "").replace("_", " ").to_upper() + " ZONE")
			heading.add_theme_color_override("font_color", Color(0.24, 0.8, 0.86))
			dealer_box.add_child(heading)
		dealer_box.add_child(_create_dealer_management_row(territory_id, entry, int(supply.product_units)))
	workspace.add_child(dealer_panel)
	territory_list.add_child(workspace)


func _create_territory_header(display_name: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.y = 76
	var title := Label.new()
	title.text = display_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.94, 0.97, 0.98))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Manage your territory, dealers, supply, and income."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.66, 0.72))
	box.add_child(subtitle)
	return box


func _create_stat_card(card_title: String, value: String, subtitle: String, accent: Color, progress: float) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.035, 0.047, 0.055, 0.98), Color(0.14, 0.22, 0.25, 0.9)))
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = card_title
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.68, 0.74, 0.78))
	box.add_child(heading)
	var amount := Label.new()
	amount.text = value
	amount.add_theme_font_size_override("font_size", 22)
	amount.add_theme_color_override("font_color", accent)
	box.add_child(amount)
	box.add_child(_detail_label(subtitle))
	if progress >= 0.0:
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 6
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = clampf(progress, 0.0, 1.0)
		bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.055, 0.065, 0.07), Color(0.055, 0.065, 0.07)))
		bar.add_theme_stylebox_override("fill", _make_panel_style(accent, accent))
		box.add_child(bar)
	return panel


func _create_section_panel(section_title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.042, 0.05, 0.98), Color(0.12, 0.22, 0.25, 0.9)))
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = section_title
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(0.22, 0.86, 0.92))
	box.add_child(heading)
	panel.set_meta("content", box)
	return panel


func _create_revenue_panel(earnings: Dictionary) -> Control:
	var panel := _create_section_panel("INCOME OVER TIME  •  LAST 7 DAYS")
	var box := panel.get_meta("content") as VBoxContainer
	var chart := TerritoryRevenueChart.new()
	chart.name = "TerritoryRevenueChart"
	chart.custom_minimum_size.y = 185
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.set_values(_territory_dealers.get_recent_daily_net(
		_get_current_territory_id(), 7
	))
	box.add_child(chart)
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 6)
	values.add_child(_create_metric("GROSS", "$%s" % _money(int(earnings.today_gross)), Color(0.18, 0.68, 1.0)))
	values.add_child(_create_metric("COMMISSION (10%)", "-$%s" % _money(int(earnings.today_commission)), Color(0.96, 0.3, 0.34)))
	values.add_child(_create_metric("NET", "$%s" % _money(int(earnings.today_net)), Color(0.2, 0.82, 0.42)))
	box.add_child(values)
	box.add_child(_detail_label("Revenue is deposited directly into the stash that supplied each sale."))
	return panel


func _get_current_territory_id() -> StringName:
	var player := get_parent() as CharacterBody3D
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(), player.global_position
	) if player != null else null
	return boundary.territory_id if boundary != null else &""


func _create_metric(label_text: String, value: String, accent: Color) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.67))
	box.add_child(label)
	var amount := Label.new()
	amount.text = value
	amount.add_theme_font_size_override("font_size", 19)
	amount.add_theme_color_override("font_color", accent)
	box.add_child(amount)
	return box


func _create_territory_details_panel(supply: Dictionary, earnings: Dictionary) -> Control:
	var panel := _create_section_panel("TERRITORY DETAILS")
	var box := panel.get_meta("content") as VBoxContainer
	var products := supply.get("products", {}) as Dictionary
	box.add_child(_create_detail_row("DEALER SUPPLY", "%dg Weed  •  %dg Coke  •  %dg Fent" % [
		int(products.get(String(EconomyCatalog.WEED_1G.product_id), 0)),
		int(products.get(String(EconomyCatalog.COKE_1G.product_id), 0)),
		int(products.get(String(EconomyCatalog.FENT_1G.product_id), 0))]))
	box.add_child(_create_detail_row("STASH CASH", "$%s DIRTY" % _money(int(supply.dirty_cash))))
	box.add_child(_create_detail_row("STAFF", "%d / %d hired" % [int(earnings.staffed), int(earnings.total_slots)]))
	for stash in supply.get("stashes", []) as Array:
		box.add_child(_create_stash_supply_row(stash))
	box.add_child(_detail_label("Bricks are excluded from dealer supply. Break them down at a stash first."))
	return panel


func _create_detail_row(label_text: String, value: String) -> Control:
	var row := HBoxContainer.new()
	var label := _detail_label(label_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var amount := Label.new()
	amount.text = value
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_theme_color_override("font_color", Color(0.86, 0.91, 0.93))
	row.add_child(amount)
	return row


func _create_dealer_table_header(earnings: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _detail_label("DEALER")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_table_value("LEVEL", 56, Color(0.55, 0.62, 0.67)))
	row.add_child(_table_value("DAILY NET", 76, Color(0.55, 0.62, 0.67)))
	row.add_child(_table_value("STATUS", 68, Color(0.55, 0.62, 0.67)))
	row.add_child(_table_value("ACTION", 160, Color(0.55, 0.62, 0.67)))
	row.tooltip_text = "%d / %d dealers hired" % [int(earnings.staffed), int(earnings.total_slots)]
	return row


func _create_empty_dashboard(heading_text: String, body_text: String) -> Control:
	var panel := _create_section_panel(heading_text)
	panel.custom_minimum_size.y = 260
	var box := panel.get_meta("content") as VBoxContainer
	var body := _detail_label(body_text)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(body)
	return panel


func _create_stash_supply_row(stash: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.064, 0.078, 0.96), Color(0.88, 0.58, 0.22, 0.45)))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var products := stash.get("products", {}) as Dictionary
	var title := Label.new()
	title.text = "%s  •  $%s DIRTY" % [stash.display_name, _money(int(stash.dirty_cash))]
	box.add_child(title)
	box.add_child(_detail_label("Weed %dg  •  Coke %dg  •  Fent %dg" % [
		int(products.get(String(EconomyCatalog.WEED_1G.product_id), 0)),
		int(products.get(String(EconomyCatalog.COKE_1G.product_id), 0)),
		int(products.get(String(EconomyCatalog.FENT_1G.product_id), 0))]))
	return panel


func _create_dealer_management_row(territory_id: StringName, entry: Dictionary, available_units: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.045, 0.057, 0.064, 0.96), Color(0.1, 0.17, 0.19, 0.9)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var employed := bool(entry.employed)
	var dealer_name := Label.new()
	dealer_name.text = String(entry.member_id).replace("_", " ").capitalize()
	dealer_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dealer_name.tooltip_text = "Sells every %d minutes • Lifetime net $%s" % [int(entry.sale_interval), _money(int(entry.lifetime_net))]
	row.add_child(dealer_name)
	var level := _table_value("LV. %d" % int(entry.level), 56, Color(0.78, 0.82, 0.84))
	row.add_child(level)
	var daily := _table_value("$%s" % _money(int(entry.today_net)), 76, Color(0.36, 0.84, 0.42))
	row.add_child(daily)
	var status_text := "OUT" if employed and available_units <= 0 else ("ACTIVE" if employed else "VACANT")
	var status_color := Color(0.95, 0.42, 0.28) if status_text == "OUT" else (Color(0.25, 0.85, 0.42) if employed else Color(0.55, 0.6, 0.63))
	row.add_child(_table_value(status_text, 68, status_color))
	var button := Button.new()
	if not employed:
		button.text = "HIRE  $%s" % _money(int(entry.hire_fee))
		button.custom_minimum_size = Vector2(160, 34)
		button.disabled = not wallet.can_spend_dirty(int(entry.hire_fee))
		button.tooltip_text = "Hire this dealer at Level 1"
		button.pressed.connect(_hire_dealer.bind(territory_id, entry.zone_id, entry.member_id))
		_style_button(button, Color(0.2, 0.72, 0.48))
		row.add_child(button)
	else:
		var actions := HBoxContainer.new()
		actions.custom_minimum_size.x = 160
		actions.add_theme_constant_override("separation", 4)
		var max_level := bool(entry.max_level)
		button.text = "MAX LEVEL" if max_level else "UPGRADE $%s" % _money(int(entry.upgrade_cost))
		button.custom_minimum_size = Vector2(112, 34)
		button.disabled = max_level or not wallet.can_spend_dirty(int(entry.upgrade_cost))
		button.tooltip_text = "Level 4 reached" if max_level else "Upgrade to Level %d for faster sales" % (int(entry.level) + 1)
		if not max_level:
			button.pressed.connect(_upgrade_dealer.bind(territory_id, entry.zone_id, entry.member_id))
		_style_button(button, Color(0.2, 0.68, 0.84))
		actions.add_child(button)
		var fire_button := Button.new()
		fire_button.text = "FIRE"
		fire_button.custom_minimum_size = Vector2(44, 34)
		fire_button.tooltip_text = "Fire this dealer with no refund"
		fire_button.pressed.connect(_fire_dealer.bind(territory_id, entry.zone_id, entry.member_id))
		_style_button(fire_button, Color(0.78, 0.22, 0.26))
		actions.add_child(fire_button)
		row.add_child(actions)
	return panel


func _table_value(text: String, width: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label


func _detail_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	return label


func _hire_dealer(territory_id: StringName, zone_id: StringName, member_id: StringName) -> void:
	var success := _territory_dealers.hire_dealer(territory_id, zone_id, member_id)
	feedback_label.text = "Dealer hired at Level 1." if success else "Could not hire that dealer."
	_refresh_territory()


func _upgrade_dealer(territory_id: StringName, zone_id: StringName, member_id: StringName) -> void:
	var success := _territory_dealers.upgrade_dealer(territory_id, zone_id, member_id)
	feedback_label.text = "Dealer upgraded." if success else "Could not upgrade that dealer."
	_refresh_territory()


func _fire_dealer(territory_id: StringName, zone_id: StringName, member_id: StringName) -> void:
	var success := _territory_dealers.fire_dealer(territory_id, zone_id, member_id)
	feedback_label.text = "Dealer fired." if success else "Could not fire that dealer."
	_refresh_territory()


func _refresh_properties() -> void:
	for child in property_list.get_children():
		child.queue_free()
	if properties == null or properties.get_owned_definitions().is_empty():
		property_list.add_child(_create_center_label("No properties owned."))
		return
	for definition in properties.get_owned_definitions():
		property_list.add_child(_create_property_row(definition))


func _create_property_row(definition: PropertyDefinition) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.064, 0.078, 0.96), Color(0.88, 0.58, 0.22, 0.55)))
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var title := Label.new()
	title.text = "%s  •  OWNED" % definition.display_name
	title.add_theme_font_size_override("font_size", 21)
	box.add_child(title)
	var location := Label.new()
	location.text = "%s  •  Bed & Save  •  Wardrobe  •  Private Stash" % definition.neighborhood
	location.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	box.add_child(location)
	var summary := properties.get_stash_summary(definition.property_id)
	var storage := Label.new()
	storage.text = "Stored: $%s dirty  •  %d drug units  •  %d weapons" % [_money(int(summary["dirty_cash"])), int(summary["product_units"]), int(summary["weapon_count"])]
	storage.add_theme_color_override("font_color", Color(0.9, 0.66, 0.3))
	box.add_child(storage)
	return panel


func _money(amount: int) -> String:
	var text := str(amount)
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result


func _refresh_girlfriends() -> void:
	for child in girlfriend_list.get_children():
		child.queue_free()
	if girlfriends == null or girlfriends.get_roster().is_empty():
		girlfriend_list.add_child(_create_center_label("No girlfriends recruited."))
		return
	for entry in girlfriends.get_roster():
		var npc: Variant = entry.get("npc")
		if is_instance_valid(npc):
			girlfriend_list.add_child(_create_girlfriend_row(entry))


func _create_girlfriend_row(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.064, 0.078, 0.96), Color(0.95, 0.32, 0.62, 0.55)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = "%s  •  Level %d  •  %s" % [entry["name"], entry["level"], str(entry["status"]).capitalize()]
	name_label.add_theme_font_size_override("font_size", 18)
	details.add_child(name_label)
	var relationship := int(entry.get("relationship", 0))
	var relationship_bar := ProgressBar.new()
	relationship_bar.custom_minimum_size = Vector2(220, 24)
	relationship_bar.min_value = -100
	relationship_bar.max_value = 100
	relationship_bar.value = relationship
	relationship_bar.show_percentage = false
	relationship_bar.tooltip_text = "Relationship %d / 100" % relationship
	var fill_color := Color(0.86, 0.24, 0.28, 1.0) if relationship < 0 else (Color(0.25, 0.82, 0.42, 1.0) if relationship > 0 else Color(0.62, 0.64, 0.68, 1.0))
	relationship_bar.add_theme_stylebox_override("fill", _make_panel_style(fill_color, fill_color.lightened(0.15)))
	details.add_child(relationship_bar)
	var relationship_label := Label.new()
	relationship_label.text = "Relationship: %d / 100" % relationship
	relationship_label.add_theme_font_size_override("font_size", 13)
	details.add_child(relationship_label)
	var npc := entry["npc"] as CustomerNPC
	var toggle := Button.new()
	toggle.text = "CALL" if entry["status"] == PlayerGirlfriendComponent.STATUS_HOME else "SEND HOME"
	toggle.pressed.connect(girlfriends.call_girlfriend.bind(npc) if entry["status"] == PlayerGirlfriendComponent.STATUS_HOME else girlfriends.send_home.bind(npc))
	_style_button(toggle, Color(0.25, 0.65, 0.85, 1.0))
	row.add_child(toggle)
	var breakup := Button.new()
	breakup.text = "BREAK UP"
	breakup.pressed.connect(girlfriends.break_up.bind(npc))
	_style_button(breakup, Color(0.8, 0.2, 0.3, 1.0))
	row.add_child(breakup)
	return panel


func _refresh_drugs() -> void:
	for child in drug_list.get_children():
		child.queue_free()

	var shown_count := 0
	for product in EconomyCatalog.get_all_products():
		if inventory.get_quantity(product) <= 0:
			continue
		drug_list.add_child(_create_drug_row(product))
		shown_count += 1
	if shown_count == 0:
		drug_list.add_child(_create_center_label("No drugs carried."))


func _refresh_weapons() -> void:
	for child in weapon_list.get_children():
		child.queue_free()

	if weapon_component == null:
		weapon_list.add_child(_create_center_label("No weapon component found."))
		return

	var weapons := weapon_component.get_weapon_slots()
	if weapons.is_empty():
		weapon_list.add_child(_create_center_label("No weapons carried."))
		return

	var equipped := weapon_component.get_equipped_weapon()
	for weapon in weapons:
		weapon_list.add_child(_create_weapon_row(weapon, equipped))


func _create_drug_row(product: ProductDefinition) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.055, 0.064, 0.078, 0.96), Color(0.16, 0.77, 0.86, 0.45))
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = product.icon
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.text = _get_drug_label(product)
	name_label.add_theme_font_size_override("font_size", 20)
	text_box.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = _get_drug_amount_text(product)
	detail_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	text_box.add_child(detail_label)

	var breakdown_button := Button.new()
	breakdown_button.text = "BREAK DOWN"
	breakdown_button.custom_minimum_size = Vector2(118, 36)
	breakdown_button.visible = product.can_break_down()
	breakdown_button.disabled = not inventory.has_product(product, 1)
	_style_button(breakdown_button, Color(0.15, 0.62, 0.72, 1.0))
	breakdown_button.pressed.connect(_break_down.bind(product))
	row.add_child(breakdown_button)

	return panel


func _create_weapon_row(
	weapon: WeaponDefinition,
	equipped: WeaponDefinition
) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.055, 0.064, 0.078, 0.96), Color(0.55, 0.62, 0.7, 0.35))
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)

	var name_label := Label.new()
	var equipped_text := " (Equipped)" if weapon == equipped else ""
	name_label.text = "%s%s" % [weapon.display_name, equipped_text]
	name_label.add_theme_font_size_override("font_size", 20)
	row.add_child(name_label)

	var detail_label := Label.new()
	if weapon == equipped:
		detail_label.text = "Magazine: %d/%d | Reserve: %d" % [
			weapon_component.get_magazine_ammo(),
			weapon_component.get_magazine_capacity(),
			weapon_component.get_reserve_ammo(),
		]
	else:
		detail_label.text = "Stored weapon"
	detail_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	row.add_child(detail_label)

	return panel


func _create_center_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	return label


func _get_drug_label(product: ProductDefinition) -> String:
	var name := _get_drug_name(product.drug_type)
	if product.package_kind == ProductDefinition.PackageKind.BRICK:
		return "%s Brick" % name
	return name


func _get_drug_amount_text(product: ProductDefinition) -> String:
	var total_grams := inventory.get_quantity(product) * product.package_size_grams
	return "%dg" % total_grams


func _get_drug_name(drug_type: int) -> String:
	match drug_type:
		ProductDefinition.DrugType.WEED:
			return "Weed"
		ProductDefinition.DrugType.COKE:
			return "Coke"
		ProductDefinition.DrugType.FENT:
			return "Fent"
		_:
			return "Product"


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
		_make_panel_style(Color(0.08, 0.095, 0.11, 1.0), accent.darkened(0.15))
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(accent.darkened(0.2), accent.lightened(0.15))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_panel_style(accent.darkened(0.35), accent.lightened(0.25))
	)
	button.add_theme_stylebox_override(
		"disabled",
		_make_panel_style(Color(0.05, 0.055, 0.065, 0.7), Color(0.18, 0.19, 0.21, 0.7))
	)
	button.add_theme_color_override("font_color", Color(0.92, 0.96, 0.98, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.44, 0.48, 1.0))


func _style_tabs() -> void:
	tab_container.add_theme_stylebox_override(
		"tab_selected",
		_make_tab_style(Color(0.11, 0.13, 0.15, 1.0), Color(0.24, 0.86, 0.96, 0.9))
	)
	tab_container.add_theme_stylebox_override(
		"tab_unselected",
		_make_tab_style(Color(0.045, 0.052, 0.062, 1.0), Color(0.12, 0.14, 0.16, 1.0))
	)
	tab_container.add_theme_stylebox_override(
		"tab_hovered",
		_make_tab_style(Color(0.08, 0.1, 0.12, 1.0), Color(0.18, 0.7, 0.8, 0.75))
	)
	tab_container.add_theme_constant_override("side_margin", 4)
	tab_container.add_theme_constant_override("h_separation", 8)
	tab_container.add_theme_color_override("font_selected_color", Color(0.95, 0.98, 1.0, 1.0))
	tab_container.add_theme_color_override("font_unselected_color", Color(0.58, 0.62, 0.68, 1.0))


func _make_tab_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _make_panel_style(fill, border)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _break_down(product: ProductDefinition) -> void:
	if inventory.break_down_product(product):
		feedback_label.text = "Broke down 1 %s into %d %s." % [
			product.display_name,
			product.breakdown_amount,
			product.breakdown_product.display_name,
		]
	else:
		feedback_label.text = "Cannot break that down."
	_refresh()


func _on_quantity_changed(
	_product: ProductDefinition,
	_quantity: int
) -> void:
	if _is_open:
		_refresh()


func _on_weapon_changed(_definition: WeaponDefinition) -> void:
	if _is_open:
		_refresh_weapons()


func _on_ammo_changed(_magazine: int, _reserve: int) -> void:
	if _is_open:
		_refresh_weapons()


func _on_attachments_changed() -> void:
	if _is_open:
		_refresh_weapons()


func _on_roster_changed() -> void:
	if _is_open:
		_refresh_girlfriends()


func _on_property_changed(_property_id: StringName, _owned: bool) -> void:
	if _is_open:
		_refresh_properties()


func _on_property_stash_changed(_property_id: StringName) -> void:
	if _is_open:
		_refresh_properties()
		_refresh_territory()


func _on_territory_dealer_state_changed(_territory_id: StringName) -> void:
	if _is_open:
		_refresh_territory()


func _on_wallet_changed(_dirty_cash: int, _clean_cash: int) -> void:
	if _is_open:
		_refresh_territory()
