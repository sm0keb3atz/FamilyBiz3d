class_name PlayerInventoryMenu
extends CanvasLayer

const INVENTORY_ICON: Texture2D = preload(
	"res://Assets/UI/Inventory/Icons/inventory.svg"
)
const DRUGS_ICON: Texture2D = preload(
	"res://Assets/UI/Inventory/Icons/drugs.svg"
)
const WEAPONS_ICON: Texture2D = preload(
	"res://Assets/UI/Inventory/Icons/weapons.svg"
)
const PROPERTY_ICON: Texture2D = preload(
	"res://Assets/UI/Inventory/Icons/property.svg"
)
const TERRITORY_ICON: Texture2D = preload(
	"res://Assets/UI/Inventory/Icons/territory.svg"
)
const LEGAL_ICON: Texture2D = preload(
	"res://Assets/UI/Inventory/Icons/legal.svg"
)
const GIRLFRIENDS_ICON: Texture2D = preload(
	"res://Assets/UI/PlayerStats/Icons/heart.svg"
)

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
@export var legal_component_path := NodePath("../Components/LegalComponent")
@export var entourage_component_path := NodePath("../Components/EntourageComponent")
@export var stats_component_path := NodePath("../Components/StatsComponent")
@export var carry_weight_component_path := NodePath(
	"../Components/CarryWeightComponent"
)
@export var consumable_component_path := NodePath(
	"../Components/ConsumableComponent"
)

@onready var menu_root := %MenuRoot as Control
@onready var tab_container := %TabContainer as TabContainer
@onready var content := $MenuRoot/Panel/Margin/Content as VBoxContainer
@onready var title_label := $MenuRoot/Panel/Margin/Content/Title as Label
@onready var dashboard_panel := $MenuRoot/Panel as PanelContainer
@onready var backdrop := $MenuRoot/Backdrop as ColorRect
@onready var drug_list := %DrugList as VBoxContainer
@onready var weapon_list := %WeaponList as VBoxContainer
@onready var girlfriend_list := %GirlfriendList as VBoxContainer
@onready var property_list := %PropertyList as VBoxContainer
@onready var territory_scroll := (
	$MenuRoot/Panel/Margin/Content/TabContainer/Territory/TerritoryScroll
	as ScrollContainer
)
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
@onready var legal := get_node_or_null(legal_component_path) as PlayerLegalComponent
@onready var entourage := get_node_or_null(
	entourage_component_path
) as PlayerEntourageComponent
@onready var stats := get_node(stats_component_path) as PlayerStatsComponent
@onready var carry_weight := get_node(
	carry_weight_component_path
) as PlayerCarryWeightComponent
@onready var consumables := get_node(
	consumable_component_path
) as PlayerConsumableComponent

var _is_open := false
var _territory_dealers: TerritoryDealerService
var _navigation_buttons: Dictionary[int, Button] = {}
var _body: HBoxContainer
var _resize_tween: Tween
var _open_tween: Tween
var _selected_territory_id: StringName = &""
var _territory_management_tab: StringName = &"properties"
var _selected_property_id: StringName = &""
var _legal_list: VBoxContainer
var _expanded_legal_case_id := ""
var _known_pending_case_ids: Array[String] = []
var _page_icon: TextureRect
var _page_title: Label
var _page_subtitle: Label
var _page_summary: Label
var _page_summary_panel: PanelContainer
var _carry_weight_value: Label
var _carry_weight_bar: ProgressBar
var _supplies_list: VBoxContainer


func _ready() -> void:
	inventory.quantity_changed.connect(_on_quantity_changed)
	inventory.consumable_quantity_changed.connect(_on_consumable_quantity_changed)
	consumables.item_used.connect(_on_consumable_used)
	if weapon_component != null:
		weapon_component.weapon_changed.connect(_on_weapon_changed)
		weapon_component.loadout_changed.connect(_on_weapon_loadout_changed)
		weapon_component.ammo_changed.connect(_on_ammo_changed)
		weapon_component.attachments_changed.connect(_on_attachments_changed)
	if girlfriends != null:
		girlfriends.roster_changed.connect(_on_roster_changed)
	if entourage != null:
		entourage.capacity_changed.connect(_on_entourage_capacity_changed)
	carry_weight.weight_changed.connect(_on_carry_weight_changed)
	if properties != null:
		properties.ownership_changed.connect(_on_property_changed)
		properties.stash_changed.connect(_on_property_stash_changed)
		properties.brick_station_changed.connect(
			_on_property_brick_station_changed
		)
		properties.runner_changed.connect(_on_property_runner_changed)
	if wallet != null:
		wallet.money_changed.connect(_on_wallet_changed)
	if legal != null:
		legal.legal_state_changed.connect(_on_legal_state_changed)
	_create_legal_tab()
	_create_supplies_tab()
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
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	content.add_child(_body)
	content.move_child(_body, 0)

	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(224, 0)
	sidebar_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.029, 0.04, 0.052, 0.98),
			Color(0.13, 0.18, 0.22, 0.95),
			14
		)
	)
	_body.add_child(sidebar_panel)
	var sidebar_margin := MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_left", 12)
	sidebar_margin.add_theme_constant_override("margin_top", 14)
	sidebar_margin.add_theme_constant_override("margin_right", 12)
	sidebar_margin.add_theme_constant_override("margin_bottom", 12)
	sidebar_panel.add_child(sidebar_margin)
	var sidebar := VBoxContainer.new()
	sidebar.name = "Navigation"
	sidebar.add_theme_constant_override("separation", 7)
	sidebar_margin.add_child(sidebar)
	var brand_row := HBoxContainer.new()
	brand_row.custom_minimum_size.y = 64
	brand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_row.add_theme_constant_override("separation", 10)
	sidebar.add_child(brand_row)
	var brand_icon := TextureRect.new()
	brand_icon.custom_minimum_size = Vector2(48, 48)
	brand_icon.texture = INVENTORY_ICON
	brand_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand_row.add_child(brand_icon)
	var brand_text := VBoxContainer.new()
	brand_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_text.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_text.add_theme_constant_override("separation", 0)
	brand_row.add_child(brand_text)
	var brand := Label.new()
	brand.text = "FAMILY BUSINESS"
	brand.add_theme_font_size_override("font_size", 15)
	brand.add_theme_color_override("font_color", Color(0.89, 0.95, 0.98))
	brand_text.add_child(brand)
	var brand_caption := Label.new()
	brand_caption.text = "PLAYER INVENTORY"
	brand_caption.add_theme_font_size_override("font_size", 10)
	brand_caption.add_theme_color_override("font_color", Color(0.25, 0.78, 0.84))
	brand_text.add_child(brand_caption)
	var separator := ColorRect.new()
	separator.custom_minimum_size.y = 1
	separator.color = Color(0.16, 0.33, 0.37, 0.72)
	sidebar.add_child(separator)
	var page_order := [
		{"label": "PRODUCT", "index": 0},
		{"label": "WEAPONS", "index": 1},
		{"label": "PROPERTIES", "index": 3},
		{"label": "TERRITORIES", "index": 4},
		{"label": "GIRLFRIENDS", "index": 2},
		{"label": "LEGAL DESK", "index": 5},
		{"label": "SUPPLIES", "index": 6},
	]
	for page in page_order:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 50)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_select_sidebar_tab.bind(int(page.index)))
		var nav_center := CenterContainer.new()
		nav_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		nav_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(nav_center)
		var nav_content := HBoxContainer.new()
		nav_content.add_theme_constant_override("separation", 10)
		nav_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav_center.add_child(nav_content)
		var nav_icon := TextureRect.new()
		nav_icon.custom_minimum_size = Vector2(22, 22)
		nav_icon.texture = _get_tab_icon(int(page.index))
		nav_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		nav_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		nav_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav_content.add_child(nav_icon)
		var nav_label := Label.new()
		nav_label.text = String(page.label)
		nav_label.add_theme_font_size_override("font_size", 13)
		nav_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nav_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav_content.add_child(nav_label)
		button.set_meta("nav_icon", nav_icon)
		button.set_meta("nav_label", nav_label)
		sidebar.add_child(button)
		_navigation_buttons[int(page.index)] = button
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)
	_build_carry_weight_panel(sidebar)
	var close_caption := Label.new()
	close_caption.text = "CLOSE MENU"
	close_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_caption.add_theme_font_size_override("font_size", 10)
	close_caption.add_theme_color_override("font_color", Color(0.38, 0.44, 0.5))
	sidebar.add_child(close_caption)
	var close_hint := Label.new()
	close_hint.text = "I   /   ESC"
	close_hint.custom_minimum_size.y = 30
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close_hint.add_theme_font_size_override("font_size", 12)
	close_hint.add_theme_color_override("font_color", Color(0.72, 0.77, 0.82))
	close_hint.add_theme_stylebox_override(
		"normal",
		_make_panel_style(
			Color(0.055, 0.068, 0.082, 0.96),
			Color(0.19, 0.24, 0.29, 0.95),
			7
		)
	)
	sidebar.add_child(close_hint)

	var rail := ColorRect.new()
	rail.custom_minimum_size.x = 1
	rail.color = Color(0.12, 0.2, 0.24, 0.72)
	_body.add_child(rail)

	var workspace := VBoxContainer.new()
	workspace.name = "InventoryWorkspace"
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 10)
	_body.add_child(workspace)
	var page_header := HBoxContainer.new()
	page_header.custom_minimum_size.y = 70
	page_header.add_theme_constant_override("separation", 14)
	workspace.add_child(page_header)
	_page_icon = TextureRect.new()
	_page_icon.custom_minimum_size = Vector2(48, 48)
	_page_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_page_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	page_header.add_child(_page_icon)
	var page_copy := VBoxContainer.new()
	page_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	page_copy.add_theme_constant_override("separation", 1)
	page_header.add_child(page_copy)
	_page_title = Label.new()
	_page_title.add_theme_font_size_override("font_size", 27)
	_page_title.add_theme_color_override("font_color", Color(0.96, 0.98, 1))
	page_copy.add_child(_page_title)
	_page_subtitle = Label.new()
	_page_subtitle.add_theme_font_size_override("font_size", 13)
	_page_subtitle.add_theme_color_override("font_color", Color(0.54, 0.61, 0.68))
	page_copy.add_child(_page_subtitle)
	_page_summary_panel = PanelContainer.new()
	_page_summary_panel.custom_minimum_size = Vector2(150, 38)
	_page_summary_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.045, 0.057, 0.069, 0.96),
			Color(0.18, 0.25, 0.3, 0.9),
			9
		)
	)
	page_header.add_child(_page_summary_panel)
	_page_summary = Label.new()
	_page_summary.add_theme_font_size_override("font_size", 12)
	_page_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_summary_panel.add_child(_page_summary)
	var page_divider := ColorRect.new()
	page_divider.custom_minimum_size.y = 1
	page_divider.color = Color(0.13, 0.18, 0.22, 0.8)
	workspace.add_child(page_divider)
	workspace.add_child(tab_container)
	tab_container.tab_changed.connect(_on_dashboard_tab_changed)

	content.remove_child(feedback_label)
	var feedback_panel := PanelContainer.new()
	feedback_panel.name = "FeedbackBar"
	feedback_panel.custom_minimum_size.y = 34
	feedback_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.035, 0.048, 0.059, 0.95),
			Color(0.12, 0.2, 0.24, 0.9),
			8
		)
	)
	content.add_child(feedback_panel)
	feedback_panel.add_child(feedback_label)
	_update_navigation_styles()
	_update_carry_weight_display(
		carry_weight.get_current_weight_grams(),
		carry_weight.get_max_weight_grams()
	)


func _build_carry_weight_panel(sidebar: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "CarryWeightPanel"
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.035, 0.052, 0.063, 0.98),
			Color(0.16, 0.35, 0.39, 0.9),
			8
		)
	)
	sidebar.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := Label.new()
	title.text = "CARRY WEIGHT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.5, 0.62, 0.68))
	heading.add_child(title)
	_carry_weight_value = Label.new()
	_carry_weight_value.name = "CarryWeightValue"
	_carry_weight_value.text = "0g / 300g"
	_carry_weight_value.add_theme_font_size_override("font_size", 12)
	_carry_weight_value.add_theme_color_override(
		"font_color",
		Color(0.22, 0.8, 0.87)
	)
	heading.add_child(_carry_weight_value)
	_carry_weight_bar = ProgressBar.new()
	_carry_weight_bar.name = "CarryWeightBar"
	_carry_weight_bar.custom_minimum_size.y = 9
	_carry_weight_bar.show_percentage = false
	_carry_weight_bar.add_theme_stylebox_override(
		"background",
		_make_panel_style(
			Color(0.025, 0.035, 0.043, 1.0),
			Color(0.09, 0.13, 0.15, 1.0),
			4
		)
	)
	box.add_child(_carry_weight_bar)


func _update_carry_weight_display(current: int, maximum: int) -> void:
	if _carry_weight_value == null or _carry_weight_bar == null:
		return
	var safe_maximum := maxi(maximum, 1)
	var ratio := float(current) / float(safe_maximum)
	var color := Color(0.22, 0.8, 0.87)
	if ratio >= 0.85:
		color = Color(0.95, 0.3, 0.28)
	elif ratio >= 0.6:
		color = Color(0.95, 0.67, 0.22)
	_carry_weight_value.text = "%dg / %dg" % [current, maximum]
	_carry_weight_value.add_theme_color_override("font_color", color)
	_carry_weight_bar.max_value = maxf(
		maxf(float(maximum), float(current)),
		1.0
	)
	_carry_weight_bar.value = current
	_carry_weight_bar.add_theme_stylebox_override(
		"fill",
		_make_panel_style(color.darkened(0.18), color, 4)
	)
	_carry_weight_bar.tooltip_text = "%dg available" % (
		maxi(maximum - current, 0)
	)


func _select_sidebar_tab(index: int) -> void:
	if index == 4:
		_selected_territory_id = &""
	elif index == 3:
		_selected_property_id = &""
	tab_container.current_tab = index
	if _is_open:
		if index == 4:
			_refresh_territory()
		elif index == 3:
			_refresh_properties()
	_update_navigation_styles()


func _on_dashboard_tab_changed(_index: int) -> void:
	_update_navigation_styles()
	if _is_open:
		_animate_panel_for_tab(true)


func _animate_panel_for_tab(animated: bool, wide_override := -1) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var wide_mode := (
		tab_container.current_tab in [3, 4, 5]
		if wide_override < 0
		else wide_override == 1
	)
	var edge_margin := 18.0 if wide_mode else 54.0
	var maximum := Vector2(1500.0, 900.0) if wide_mode else Vector2(1200.0, 720.0)
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
		var accent := _get_tab_accent(int(index))
		var normal_style := _make_panel_style(
			Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.98)
			if selected else Color(0.035, 0.044, 0.054, 0.84),
			accent.darkened(0.08)
			if selected else Color(0.09, 0.12, 0.15, 0.55),
			10
		)
		normal_style.border_width_left = 3 if selected else 1
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override(
			"hover",
			_make_panel_style(
				Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 1.0),
				accent.darkened(0.05),
				10
			)
		)
		button.add_theme_stylebox_override(
			"pressed",
			_make_panel_style(
				Color(accent.r * 0.09, accent.g * 0.09, accent.b * 0.09, 1.0),
				accent,
				10
			)
		)
		button.add_theme_color_override(
			"font_color",
			Color(0.93, 0.97, 0.99) if selected else Color(0.57, 0.63, 0.69)
		)
		button.add_theme_color_override("font_hover_color", Color(0.95, 0.98, 1))
		button.add_theme_color_override(
			"icon_normal_color",
			Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.62)
		)
		button.add_theme_color_override("icon_hover_color", Color(1, 1, 1, 1))
		var nav_label := button.get_meta("nav_label") as Label
		var nav_icon := button.get_meta("nav_icon") as TextureRect
		if nav_label != null:
			nav_label.add_theme_color_override(
				"font_color",
				Color(0.93, 0.97, 0.99)
				if selected else Color(0.57, 0.63, 0.69)
			)
		if nav_icon != null:
			nav_icon.modulate = (
				Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.62)
			)
	_update_page_header()


func _update_page_header() -> void:
	if _page_title == null:
		return
	var index := tab_container.current_tab
	_page_icon.texture = _get_tab_icon(index)
	_page_title.text = _get_tab_title(index)
	_page_subtitle.text = _get_tab_subtitle(index)
	var accent := _get_tab_accent(index)
	_page_title.add_theme_color_override("font_color", Color(0.96, 0.98, 1))
	_page_summary.text = _get_tab_summary(index)
	_page_summary.add_theme_color_override("font_color", accent.lightened(0.2))
	_page_summary_panel.visible = index > 2


func _get_tab_icon(index: int) -> Texture2D:
	match index:
		0:
			return DRUGS_ICON
		1:
			return WEAPONS_ICON
		2:
			return GIRLFRIENDS_ICON
		3:
			return PROPERTY_ICON
		4:
			return TERRITORY_ICON
		5:
			return LEGAL_ICON
		6:
			return INVENTORY_ICON
		_:
			return INVENTORY_ICON


func _get_tab_accent(index: int) -> Color:
	match index:
		0:
			return Color(0.22, 0.8, 0.87)
		1:
			return Color(0.95, 0.34, 0.31)
		2:
			return Color(0.94, 0.31, 0.58)
		3:
			return Color(0.92, 0.65, 0.24)
		4:
			return Color(0.62, 0.43, 0.91)
		5:
			return Color(0.31, 0.78, 0.75)
		6:
			return Color(0.25, 0.86, 0.55)
		_:
			return Color(0.25, 0.78, 0.84)


func _get_tab_title(index: int) -> String:
	match index:
		0:
			return "PRODUCT INVENTORY"
		1:
			return "WEAPON LOADOUT"
		2:
			return "GIRLFRIEND ROSTER"
		3:
			return "PROPERTY PORTFOLIO"
		4:
			return "TERRITORY CONTROL"
		5:
			return "LEGAL DESK"
		6:
			return "SUPPLIES"
		_:
			return "INVENTORY"


func _get_tab_subtitle(index: int) -> String:
	match index:
		0:
			return "Review carried packages, street value, and breakdown options."
		1:
			return "Inspect your carried weapons, ammunition, and combat profile."
		2:
			return "Manage companions, availability, and relationship standing."
		3:
			return "Review owned properties, storage, automation, and operations."
		4:
			return "Control territory reputation, supply, dealers, and income."
		5:
			return "Manage active cases, retained counsel, and legal services."
		6:
			return "Use legal health, stamina, regeneration, and emergency fuel supplies."
		_:
			return "Manage everything your organization owns."


func _get_tab_summary(index: int) -> String:
	match index:
		0:
			var carried_types := 0
			for product in EconomyCatalog.get_all_products():
				if inventory.get_quantity(product) > 0:
					carried_types += 1
			return "%d CARRIED TYPES" % carried_types
		1:
			return "%d WEAPONS" % (
				weapon_component.get_weapon_slots().size()
				if weapon_component != null else 0
			)
		2:
			return "%d CONTACTS" % (
				girlfriends.get_roster().size() if girlfriends != null else 0
			)
		3:
			return "%d PROPERTIES" % (
				properties.get_owned_definitions().size()
				if properties != null else 0
			)
		4:
			return "%d TERRITORIES" % _get_owned_territories().size()
		5:
			return "%d ACTIVE CASES" % (
				legal.get_pending_cases().size() if legal != null else 0
			)
		6:
			var total := 0
			for item in ConsumableCatalog.get_all():
				total += inventory.get_consumable_quantity(item)
			return "%d ITEMS" % total
		_:
			return "PLAYER ASSETS"


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
	if _is_open:
		menu_root.visible = true
		if tab_container.current_tab == 4:
			_selected_territory_id = &""
		_refresh()
		_update_navigation_styles()
		if tab_container.current_tab == 4:
			_animate_panel_for_tab(false, 0)
			_animate_panel_for_tab(true, 1)
		else:
			_animate_panel_for_tab(false)
		_play_open_animation()
	else:
		if is_instance_valid(_open_tween):
			_open_tween.kill()
		menu_root.visible = false
		_animate_panel_for_tab(false, 0)


func _play_open_animation() -> void:
	if is_instance_valid(_open_tween):
		_open_tween.kill()
	dashboard_panel.modulate.a = 0.0
	backdrop.modulate.a = 0.0
	_open_tween = create_tween().set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(backdrop, "modulate:a", 1.0, 0.16)
	_open_tween.tween_property(dashboard_panel, "modulate:a", 1.0, 0.22)


func _refresh() -> void:
	_refresh_drugs()
	_refresh_weapons()
	_refresh_girlfriends()
	_refresh_properties()
	_refresh_territory()
	_refresh_legal()
	_refresh_supplies()
	_update_page_header()


func _create_legal_tab() -> void:
	var margin := MarginContainer.new()
	margin.name = "Legal"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	tab_container.add_child(margin)
	_legal_list = VBoxContainer.new()
	_legal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legal_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_legal_list.add_theme_constant_override("separation", 14)
	margin.add_child(_legal_list)


func _create_supplies_tab() -> void:
	var margin := MarginContainer.new()
	margin.name = "SuppliesPage"
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	tab_container.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_supplies_list = VBoxContainer.new()
	_supplies_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_supplies_list.add_theme_constant_override("separation", 9)
	scroll.add_child(_supplies_list)


func _refresh_supplies() -> void:
	if _supplies_list == null:
		return
	for child in _supplies_list.get_children():
		child.queue_free()
	var carried := 0
	for item in ConsumableCatalog.get_all():
		var quantity := inventory.get_consumable_quantity(item)
		if quantity <= 0:
			continue
		carried += quantity
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 74
		var info := Label.new()
		info.text = "%s  x%d\n%s   |   %dG EACH" % [
			item.display_name.to_upper(), quantity,
			item.description, item.weight_grams,
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var use_button := Button.new()
		use_button.text = "USE"
		use_button.custom_minimum_size = Vector2(120, 44)
		use_button.pressed.connect(_use_consumable.bind(item))
		_style_button(use_button, Color(0.25, 0.78, 0.55))
		row.add_child(use_button)
		_supplies_list.add_child(row)
	if carried == 0:
		_supplies_list.add_child(_create_empty_dashboard(
			"NO SUPPLIES CARRIED",
			"Purchase food, drinks, boosts, and fuel cans at the gas station."
		))


func _use_consumable(item: ConsumableDefinition) -> void:
	consumables.use(item)


func _on_consumable_used(
	_item: ConsumableDefinition,
	message: String,
	_success: bool
) -> void:
	feedback_label.text = message
	_refresh_supplies()
	_update_page_header()


func _on_consumable_quantity_changed(
	_item: ConsumableDefinition,
	_quantity: int
) -> void:
	if _is_open:
		_refresh_supplies()
		_update_page_header()


func _refresh_legal() -> void:
	if _legal_list == null or legal == null:
		return
	_render_legal_dashboard()


func _render_legal_dashboard() -> void:
	for child in _legal_list.get_children():
		child.queue_free()

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	_legal_list.add_child(title_row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	title_row.add_child(titles)
	var heading := _legal_note("CASE & COUNSEL OVERVIEW")
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(0.9, 0.96, 0.98))
	titles.add_child(heading)
	var subtitle := _legal_note(
		"Manage court cases, assigned counsel, and retained legal services."
	)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.56, 0.63, 0.68))
	titles.add_child(subtitle)
	var mark := _legal_note("SCALES OF JUSTICE")
	mark.custom_minimum_size.x = 118
	mark.autowrap_mode = TextServer.AUTOWRAP_OFF
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mark.add_theme_font_size_override("font_size", 11)
	mark.add_theme_color_override("font_color", Color(0.16, 0.72, 0.7, 0.55))
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(mark)

	var pending := legal.get_pending_cases()
	_update_expanded_legal_case(pending)
	var retained := _get_retained_lawyer_definitions()

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	_legal_list.add_child(columns)

	var case_list := VBoxContainer.new()
	case_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	case_list.add_theme_constant_override("separation", 8)
	var case_column := _create_legal_column(
		"UPCOMING COURT",
		"%d ACTIVE %s" % [
			pending.size(),
			"CASE" if pending.size() == 1 else "CASES",
		],
		case_list
	)
	case_column.size_flags_stretch_ratio = 0.92
	columns.add_child(case_column)
	if pending.is_empty():
		case_list.add_child(_create_legal_empty_state(
			"NO PENDING CASES",
			"New court matters will appear here after an arrest."
		))
	for legal_case in pending:
		case_list.add_child(_create_legal_case_card(
			legal_case,
			legal_case.case_id == _expanded_legal_case_id
		))

	var recent := legal.get_recent_cases()
	if not recent.is_empty():
		case_list.add_child(_legal_section_label("RECENT VERDICTS"))
		for legal_case in recent:
			var verdict: String = str(
				LegalCase.Status.keys()[legal_case.status]
			).capitalize()
			case_list.add_child(_create_legal_verdict_row(legal_case, verdict))

	var lawyer_list := VBoxContainer.new()
	lawyer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lawyer_list.add_theme_constant_override("separation", 8)
	var lawyer_column := _create_legal_column(
		"RETAINED LAWYERS & SERVICES",
		"%d HIRED" % retained.size(),
		lawyer_list
	)
	lawyer_column.size_flags_stretch_ratio = 1.08
	columns.add_child(lawyer_column)
	if retained.is_empty():
		lawyer_list.add_child(_create_legal_empty_state(
			"NO LAWYERS RETAINED",
			"Visit the courthouse to hire a lawyer and unlock their services."
		))
	for definition in retained:
		lawyer_list.add_child(_create_retained_lawyer_card(definition))

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.045, 0.06, 0.072, 0.94),
			Color(0.13, 0.27, 0.3, 0.8)
		)
	)
	var footer_margin := _legal_margin(12, 7)
	footer.add_child(footer_margin)
	var footer_label := _legal_note(
		"Assign retained counsel from an open case. Higher defense ranges improve the chance of beating the case."
	)
	footer_label.add_theme_color_override("font_color", Color(0.52, 0.61, 0.65))
	footer_label.add_theme_font_size_override("font_size", 12)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_margin.add_child(footer_label)
	_legal_list.add_child(footer)


func _update_expanded_legal_case(pending: Array[LegalCase]) -> void:
	var current_ids: Array[String] = []
	var newest_case_id := ""
	for legal_case in pending:
		current_ids.append(legal_case.case_id)
		if (
			not _known_pending_case_ids.has(legal_case.case_id)
			and newest_case_id.is_empty()
		):
			newest_case_id = legal_case.case_id
	if (
		not _expanded_legal_case_id.is_empty()
		and not current_ids.has(_expanded_legal_case_id)
	):
		_expanded_legal_case_id = ""
	if _expanded_legal_case_id.is_empty() and not newest_case_id.is_empty():
		_expanded_legal_case_id = newest_case_id
	_known_pending_case_ids = current_ids


func _create_legal_column(
	title: String,
	summary: String,
	list: Control
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.05, 0.062, 0.074, 0.98),
			Color(0.13, 0.24, 0.28, 0.95)
		)
	)
	var margin := _legal_margin(12, 10)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var label := _legal_section_label(title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(label)
	var count := _legal_note(summary)
	count.custom_minimum_size.x = 92
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 11)
	count.add_theme_color_override("font_color", Color(0.38, 0.7, 0.68))
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(count)
	var separator := HSeparator.new()
	separator.modulate = Color(0.18, 0.42, 0.43, 0.6)
	body.add_child(separator)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return panel


func _create_legal_case_card(
	legal_case: LegalCase,
	expanded: bool
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.035, 0.05, 0.06, 0.98),
			Color(0.16, 0.72, 0.7, 0.95)
			if expanded
			else Color(0.12, 0.25, 0.29, 0.9)
		)
	)
	var margin := _legal_margin(12, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	var assigned := legal.get_lawyer_definition(legal_case.assigned_lawyer_id)
	var assigned_name := (
		assigned.display_name if assigned != null else "Public Defender"
	)
	var title := Button.new()
	title.text = "%s    %d POINTS\nCOURT %s    |    %s    %s" % [
		legal_case.case_id,
		legal_case.get_total_points(),
		legal.get_hearing_datetime_text(legal_case),
		legal.get_hearing_countdown_text(legal_case),
		"[-]" if expanded else "[+]",
	]
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.25, 0.9, 0.82))
	title.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	title.add_theme_stylebox_override(
		"hover",
		_make_panel_style(
			Color(0.06, 0.1, 0.105, 0.8),
			Color(0.12, 0.35, 0.36, 0.8)
		)
	)
	title.pressed.connect(_toggle_legal_case.bind(legal_case.case_id))
	box.add_child(title)
	if not expanded:
		var collapsed_summary := _legal_note(
			"Assigned: %s    |    Win chance %.2f%%"
			% [assigned_name, legal.get_win_chance(legal_case) * 100.0]
		)
		collapsed_summary.add_theme_font_size_override("font_size", 12)
		collapsed_summary.add_theme_color_override(
			"font_color",
			Color(0.55, 0.62, 0.66)
		)
		box.add_child(collapsed_summary)
		return panel

	var overview := _legal_note(
		"ATTORNEY  %s    |    DEFENSE RANGE  %d-%d"
		% [
			assigned_name,
			legal.get_defense_range(legal_case).x,
			legal.get_defense_range(legal_case).y,
		]
	)
	overview.add_theme_font_size_override("font_size", 12)
	overview.add_theme_color_override("font_color", Color(0.65, 0.73, 0.77))
	box.add_child(overview)
	var charge_separator := HSeparator.new()
	charge_separator.modulate = Color(0.18, 0.34, 0.36, 0.7)
	box.add_child(charge_separator)
	var charges_title := _legal_note("CHARGES")
	charges_title.add_theme_font_size_override("font_size", 11)
	charges_title.add_theme_color_override("font_color", Color(0.35, 0.8, 0.72))
	box.add_child(charges_title)
	for charge in legal_case.charges:
		box.add_child(_create_legal_charge_row(charge))
	var total_row := HBoxContainer.new()
	box.add_child(total_row)
	var total_label := _legal_note("TOTAL CASE POINTS")
	total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_label.add_theme_color_override("font_color", Color(0.26, 0.9, 0.8))
	total_row.add_child(total_label)
	var total_value := _legal_note(str(legal_case.get_total_points()))
	total_value.custom_minimum_size.x = 42
	total_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	total_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_value.add_theme_font_size_override("font_size", 18)
	total_value.add_theme_color_override("font_color", Color(0.26, 0.9, 0.8))
	total_row.add_child(total_value)

	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 6)
	box.add_child(metrics)
	metrics.add_child(_create_legal_metric(
		"COURT DATE",
		legal.get_hearing_datetime_text(legal_case)
	))
	metrics.add_child(_create_legal_metric(
		"TIME LEFT",
		legal.get_hearing_countdown_text(legal_case)
	))
	metrics.add_child(_create_legal_metric(
		"WIN CHANCE",
		"%.2f%%" % (legal.get_win_chance(legal_case) * 100.0)
	))

	var assignment := HBoxContainer.new()
	assignment.add_theme_constant_override("separation", 8)
	box.add_child(assignment)
	var assignment_label := _legal_note("ASSIGN COUNSEL")
	assignment_label.custom_minimum_size.x = 115
	assignment_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	assignment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	assignment_label.add_theme_font_size_override("font_size", 11)
	assignment_label.add_theme_color_override(
		"font_color",
		Color(0.38, 0.78, 0.73)
	)
	assignment.add_child(assignment_label)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("Public Defender")
	picker.set_item_metadata(0, "")
	var selected_index := 0
	for definition in _get_retained_lawyer_definitions():
		picker.add_item("%s  |  Level %d  |  Defense %d-%d" % [
			definition.display_name,
			definition.level,
			definition.defense_min,
			definition.defense_max,
		])
		var item_index := picker.item_count - 1
		picker.set_item_metadata(item_index, String(definition.lawyer_id))
		if definition.lawyer_id == legal_case.assigned_lawyer_id:
			selected_index = item_index
	picker.select(selected_index)
	_style_legal_option_button(picker)
	picker.item_selected.connect(
		_on_case_lawyer_selected.bind(legal_case.case_id, picker)
	)
	assignment.add_child(picker)
	return panel


func _create_legal_charge_row(charge: LegalCharge) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name := _legal_note(
		"%s    %d x %d pts"
		% [charge.display_name, charge.count, charge.unit_points]
	)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 12)
	name.add_theme_color_override("font_color", Color(0.7, 0.76, 0.79))
	row.add_child(name)
	var points := _legal_note(str(charge.get_total_points()))
	points.custom_minimum_size.x = 34
	points.autowrap_mode = TextServer.AUTOWRAP_OFF
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points.add_theme_font_size_override("font_size", 12)
	points.add_theme_color_override("font_color", Color(0.85, 0.88, 0.9))
	row.add_child(points)
	return row


func _create_retained_lawyer_card(
	definition: LawyerDefinition
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.035, 0.048, 0.058, 0.98),
			Color(0.13, 0.31, 0.33, 0.9)
		)
	)
	var margin := _legal_margin(12, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	var retained_label := _legal_note("RETAINED")
	retained_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	retained_label.add_theme_font_size_override("font_size", 10)
	retained_label.add_theme_color_override("font_color", Color(0.23, 0.87, 0.76))
	identity.add_child(retained_label)
	var name := _legal_note(
		"%s    |    LEVEL %d" % [definition.display_name, definition.level]
	)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.add_theme_font_size_override("font_size", 17)
	name.add_theme_color_override("font_color", Color(0.9, 0.95, 0.97))
	identity.add_child(name)
	var daily_fee := _legal_note("$%s / DAY" % _money(definition.daily_fee_clean))
	daily_fee.custom_minimum_size.x = 96
	daily_fee.autowrap_mode = TextServer.AUTOWRAP_OFF
	daily_fee.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	daily_fee.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	daily_fee.add_theme_font_size_override("font_size", 11)
	daily_fee.add_theme_color_override("font_color", Color(0.82, 0.66, 0.31))
	header.add_child(daily_fee)
	var fire_button := Button.new()
	fire_button.text = "FIRE"
	fire_button.custom_minimum_size = Vector2(64, 32)
	_style_button(fire_button, Color(0.76, 0.2, 0.24))
	fire_button.pressed.connect(_fire_lawyer.bind(definition.lawyer_id))
	header.add_child(fire_button)
	var capabilities := _legal_note(
		"Defense %d-%d    |    Launder $%s/day (%d%% fee)    |    Lower heat %d/day"
		% [
			definition.defense_min,
			definition.defense_max,
			_money(definition.laundering_daily_limit),
			roundi(definition.laundering_cut * 100.0),
			definition.heat_daily_limit,
		]
	)
	capabilities.add_theme_font_size_override("font_size", 12)
	capabilities.add_theme_color_override("font_color", Color(0.58, 0.66, 0.7))
	box.add_child(capabilities)
	var separator := HSeparator.new()
	separator.modulate = Color(0.15, 0.33, 0.34, 0.75)
	box.add_child(separator)

	var contract := legal.get_contract(definition.lawyer_id)
	var laundered_today := int(contract.get("laundered_today", 0))
	var heat_used_today := int(contract.get("heat_used_today", 0))
	var launder_remaining := maxi(
		definition.laundering_daily_limit - laundered_today,
		0
	)
	var heat_remaining := maxi(definition.heat_daily_limit - heat_used_today, 0)
	var laundering_title := _legal_note(
		"MONEY LAUNDERING    |    $%s REMAINING TODAY"
		% _money(launder_remaining)
	)
	laundering_title.add_theme_font_size_override("font_size", 10)
	laundering_title.add_theme_color_override(
		"font_color",
		Color(0.34, 0.8, 0.72)
	)
	box.add_child(laundering_title)
	var laundering_row := HBoxContainer.new()
	laundering_row.add_theme_constant_override("separation", 6)
	box.add_child(laundering_row)
	var launder_amount := SpinBox.new()
	launder_amount.min_value = 100
	launder_amount.max_value = maxi(launder_remaining, 100)
	launder_amount.step = 100
	launder_amount.value = mini(10000, maxi(launder_remaining, 100))
	launder_amount.prefix = "$"
	launder_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launder_amount.editable = launder_remaining > 0
	laundering_row.add_child(launder_amount)
	var launder_button := Button.new()
	launder_button.text = "LAUNDER"
	launder_button.custom_minimum_size.x = 104
	launder_button.disabled = launder_remaining <= 0
	_style_button(launder_button, Color(0.12, 0.68, 0.61))
	launder_button.pressed.connect(
		_launder_with_lawyer.bind(definition.lawyer_id, launder_amount)
	)
	laundering_row.add_child(launder_button)

	var heat_title := _legal_note(
		"TERRITORY HEAT REDUCTION    |    REMOVES UP TO %d HEAT"
		% heat_remaining
	)
	heat_title.add_theme_font_size_override("font_size", 10)
	heat_title.add_theme_color_override("font_color", Color(0.34, 0.8, 0.72))
	box.add_child(heat_title)
	var heat_row := HBoxContainer.new()
	heat_row.add_theme_constant_override("separation", 6)
	box.add_child(heat_row)
	var territory_picker := OptionButton.new()
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null:
			territory_picker.add_item(boundary.display_name)
			territory_picker.set_item_metadata(
				territory_picker.item_count - 1,
				String(boundary.territory_id)
			)
	territory_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	territory_picker.disabled = (
		territory_picker.item_count == 0 or heat_remaining <= 0
	)
	_style_legal_option_button(territory_picker)
	heat_row.add_child(territory_picker)
	var heat_button := Button.new()
	heat_button.text = "LOWER HEAT (-%d)" % heat_remaining
	heat_button.custom_minimum_size.x = 148
	heat_button.disabled = (
		territory_picker.item_count == 0 or heat_remaining <= 0
	)
	_style_button(heat_button, Color(0.12, 0.68, 0.61))
	heat_button.pressed.connect(
		_lower_heat_with_lawyer.bind(
			definition.lawyer_id,
			territory_picker
		)
	)
	heat_row.add_child(heat_button)
	return panel


func _legal_margin(horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_bottom", vertical)
	return margin


func _create_legal_metric(
	label_text: String,
	value_text: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 58
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.045, 0.064, 0.072, 0.9),
			Color(0.12, 0.25, 0.27, 0.8)
		)
	)
	var margin := _legal_margin(8, 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	margin.add_child(box)
	var label := _legal_note(label_text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.4, 0.61, 0.62))
	box.add_child(label)
	var value := _legal_note(value_text)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", Color(0.76, 0.85, 0.86))
	box.add_child(value)
	return panel


func _create_legal_empty_state(
	title: String,
	description: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 110
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.035, 0.046, 0.056, 0.9),
			Color(0.11, 0.2, 0.23, 0.9)
		)
	)
	var margin := _legal_margin(18, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	var title_label := _legal_note(title)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.47, 0.69, 0.68))
	box.add_child(title_label)
	var description_label := _legal_note(description)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override(
		"font_color",
		Color(0.46, 0.52, 0.56)
	)
	box.add_child(description_label)
	return panel


func _create_legal_verdict_row(
	legal_case: LegalCase,
	verdict: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.038, 0.05, 0.06, 0.9),
			Color(0.11, 0.2, 0.23, 0.8)
		)
	)
	var margin := _legal_margin(9, 7)
	panel.add_child(margin)
	var label := _legal_note(
		"%s    |    %s    |    %d points    |    %d year sentence"
		% [
			legal_case.case_id,
			verdict,
			legal_case.get_total_points(),
			legal_case.sentence_years,
		]
	)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.53, 0.6, 0.64))
	margin.add_child(label)
	return panel


func _get_retained_lawyer_definitions() -> Array[LawyerDefinition]:
	var retained: Array[LawyerDefinition] = []
	for definition in legal.get_lawyer_definitions():
		if legal.is_lawyer_retained(definition.lawyer_id):
			retained.append(definition)
	return retained


func _toggle_legal_case(case_id: String) -> void:
	_expanded_legal_case_id = (
		"" if _expanded_legal_case_id == case_id else case_id
	)
	_refresh_legal()


func _on_case_lawyer_selected(
	item_index: int,
	case_id: String,
	picker: OptionButton
) -> void:
	var lawyer_id := StringName(str(picker.get_item_metadata(item_index)))
	_assign_case_lawyer(case_id, lawyer_id)


func _legal_section_label(text: String) -> Label:
	var label := _legal_note(text)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.22, 0.86, 0.76))
	return label


func _legal_note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _style_legal_option_button(button: OptionButton) -> void:
	button.custom_minimum_size.y = 38
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.82, 0.9, 0.91))
	button.add_theme_color_override("font_hover_color", Color(0.93, 1.0, 0.98))
	button.add_theme_color_override("font_pressed_color", Color(0.93, 1.0, 0.98))
	button.add_theme_stylebox_override(
		"normal",
		_make_panel_style(
			Color(0.035, 0.052, 0.06, 1.0),
			Color(0.12, 0.38, 0.39, 0.95)
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(
			Color(0.055, 0.105, 0.105, 1.0),
			Color(0.18, 0.76, 0.69, 1.0)
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_panel_style(
			Color(0.065, 0.16, 0.15, 1.0),
			Color(0.22, 0.88, 0.78, 1.0)
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_make_panel_style(
			Color(0.045, 0.08, 0.085, 1.0),
			Color(0.2, 0.86, 0.78, 1.0)
		)
	)
	var popup := button.get_popup()
	popup.add_theme_font_size_override("font_size", 13)
	popup.add_theme_color_override("font_color", Color(0.78, 0.86, 0.88))
	popup.add_theme_color_override("font_hover_color", Color(0.94, 1.0, 0.98))
	popup.add_theme_color_override("font_disabled_color", Color(0.36, 0.43, 0.45))
	popup.add_theme_constant_override("item_start_padding", 12)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.025, 0.038, 0.045, 1.0),
			Color(0.15, 0.67, 0.63, 1.0)
		)
	)
	popup.add_theme_stylebox_override(
		"hover",
		_make_panel_style(
			Color(0.06, 0.2, 0.185, 1.0),
			Color(0.2, 0.82, 0.73, 1.0)
		)
	)


func _assign_case_lawyer(case_id: String, lawyer_id: StringName) -> void:
	var assigned := legal.assign_lawyer(case_id, lawyer_id)
	var definition := legal.get_lawyer_definition(lawyer_id)
	var lawyer_name := (
		definition.display_name if definition != null else "Public Defender"
	)
	feedback_label.text = (
		"%s assigned to %s." % [lawyer_name, case_id]
		if assigned
		else "Assignment failed."
	)
	_refresh_legal()


func _fire_lawyer(lawyer_id: StringName) -> void:
	var definition := legal.get_lawyer_definition(lawyer_id)
	var lawyer_name := definition.display_name if definition != null else "Lawyer"
	var fired := legal.terminate_lawyer(lawyer_id)
	feedback_label.text = (
		"%s has been fired. Their cases now use the Public Defender."
		% lawyer_name
		if fired
		else "Could not fire that lawyer."
	)
	_refresh_legal()


func _launder_with_lawyer(lawyer_id: StringName, amount_input: SpinBox) -> void:
	var result := legal.launder_money(lawyer_id, roundi(amount_input.value))
	feedback_label.text = (
		"Laundered $%s into $%s clean."
		% [_money(int(result.get("dirty_spent", 0))), _money(int(result.get("clean_received", 0)))]
		if not result.is_empty() else "Laundering request failed."
	)
	_refresh_legal()


func _lower_heat_with_lawyer(
	lawyer_id: StringName,
	territory_picker: OptionButton
) -> void:
	if territory_picker.item_count == 0:
		feedback_label.text = "No loaded territory available."
		return
	var definition := legal.get_lawyer_definition(lawyer_id)
	if definition == null:
		feedback_label.text = "Heat service failed."
		return
	var contract := legal.get_contract(lawyer_id)
	var remaining := maxi(
		definition.heat_daily_limit - int(contract.get("heat_used_today", 0)),
		0
	)
	if remaining <= 0:
		feedback_label.text = "This lawyer has no heat reduction remaining today."
		return
	var territory_id := StringName(str(territory_picker.get_selected_metadata()))
	var result := legal.reduce_territory_heat(lawyer_id, territory_id, remaining)
	feedback_label.text = (
		"Heat lowered by %d for $%s dirty."
		% [int(result.get("points", 0)), _money(int(result.get("dirty_spent", 0)))]
		if not result.is_empty() else "Heat service failed."
	)
	_refresh_legal()


func _on_legal_state_changed() -> void:
	if _is_open:
		_refresh_legal()
		_update_page_header()


func _resolve_territory_dealers() -> void:
	_territory_dealers = get_tree().get_first_node_in_group(&"territory_dealer_service") as TerritoryDealerService
	if _territory_dealers != null and not _territory_dealers.state_changed.is_connected(_on_territory_dealer_state_changed):
		_territory_dealers.state_changed.connect(_on_territory_dealer_state_changed)


func _refresh_territory() -> void:
	for child in territory_list.get_children():
		child.queue_free()
	territory_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	territory_scroll.scroll_vertical = 0
	if _territory_dealers == null:
		_resolve_territory_dealers()
	if _territory_dealers == null:
		territory_list.add_child(_create_empty_dashboard("TERRITORY MANAGEMENT UNAVAILABLE", "The territory service could not be found."))
		return
	var owned_territories := _get_owned_territories()
	if owned_territories.is_empty():
		_selected_territory_id = &""
		territory_list.add_child(_create_empty_dashboard(
			"NO OWNED TERRITORIES",
			"Claim a territory to manage its dealers, supply, and income here."
		))
		return
	var selected := _find_owned_territory(
		owned_territories,
		_selected_territory_id
	)
	if selected == null:
		_selected_territory_id = &""
		_render_owned_territory_list(owned_territories)
		return
	_render_territory_dashboard(selected)


func _get_owned_territories() -> Array[TerritoryBoundary]:
	var result: Array[TerritoryBoundary] = []
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if (
			boundary != null
			and boundary.stats != null
			and boundary.stats.owner_faction
			== TerritoryStatsComponent.OwnerFaction.PLAYER
		):
			result.append(boundary)
	result.sort_custom(
		func(a: TerritoryBoundary, b: TerritoryBoundary) -> bool:
			return String(a.display_name) < String(b.display_name)
	)
	return result


func _find_owned_territory(
	owned_territories: Array[TerritoryBoundary],
	territory_id: StringName
) -> TerritoryBoundary:
	if territory_id.is_empty():
		return null
	for boundary in owned_territories:
		if boundary.territory_id == territory_id:
			return boundary
	return null


func _render_owned_territory_list(
	owned_territories: Array[TerritoryBoundary]
) -> void:
	territory_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var header := VBoxContainer.new()
	header.custom_minimum_size.y = 92
	var title := Label.new()
	title.text = "OWNED TERRITORIES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.94, 0.97, 0.98))
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = (
		"Choose a territory to manage its dealers from anywhere in the city."
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override(
		"font_color",
		Color(0.58, 0.66, 0.72)
	)
	header.add_child(subtitle)
	territory_list.add_child(header)
	var player := get_parent() as CharacterBody3D
	var current_boundary := (
		TerritoryBoundary.find_at_position(get_tree(), player.global_position)
		if player != null else null
	)
	for boundary in owned_territories:
		territory_list.add_child(_create_owned_territory_card(
			boundary,
			current_boundary != null
			and current_boundary.territory_id == boundary.territory_id
		))


func _create_owned_territory_card(
	boundary: TerritoryBoundary,
	is_current_location: bool
) -> Control:
	var earnings := _territory_dealers.get_earnings_summary(
		boundary.territory_id
	)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 112
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.035, 0.05, 0.06, 0.98),
			Color(0.18, 0.58, 0.64, 0.8)
			if is_current_location
			else Color(0.12, 0.22, 0.25, 0.9)
		)
	)
	var margin := MarginContainer.new()
	for side in [
		"margin_left", "margin_top", "margin_right", "margin_bottom"
	]:
		margin.add_theme_constant_override(side, 14)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 5)
	row.add_child(details)
	var title := Label.new()
	title.text = boundary.display_name.to_upper()
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.9, 0.96, 0.98))
	details.add_child(title)
	var location := _detail_label(
		"CURRENT LOCATION" if is_current_location else "OWNED TERRITORY"
	)
	location.add_theme_color_override(
		"font_color",
		Color(0.22, 0.86, 0.92)
		if is_current_location else Color(0.58, 0.66, 0.72)
	)
	details.add_child(location)
	details.add_child(_detail_label(
		"Reputation %d / 100  •  Heat %d / 100  •  Dealers %d / %d"
		% [
			roundi(boundary.stats.reputation),
			roundi(boundary.stats.heat),
			int(earnings.staffed),
			int(earnings.total_slots),
		]
	))
	details.add_child(_detail_label(
		"Today $%s net  •  Lifetime $%s"
		% [
			_money(int(earnings.today_net)),
			_money(int(earnings.lifetime_net)),
		]
	))
	var open_button := Button.new()
	open_button.text = "MANAGE  >"
	open_button.custom_minimum_size = Vector2(150, 48)
	open_button.pressed.connect(
		_select_owned_territory.bind(boundary.territory_id)
	)
	_style_button(open_button, Color(0.22, 0.72, 0.78))
	row.add_child(open_button)
	return panel


func _select_owned_territory(territory_id: StringName) -> void:
	_selected_territory_id = territory_id
	_territory_management_tab = &"properties"
	_refresh_territory()


func _show_owned_territory_list() -> void:
	_selected_territory_id = &""
	_refresh_territory()


func _render_territory_dashboard(boundary: TerritoryBoundary) -> void:
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
	left.add_child(_create_revenue_panel(territory_id, earnings))
	left.add_child(_create_territory_details_panel(supply, earnings))
	workspace.add_child(left)
	var logistics := _create_territory_management_panel(
		territory_id
	)
	logistics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logistics.size_flags_stretch_ratio = 1.15
	workspace.add_child(logistics)
	territory_list.add_child(workspace)


func _create_territory_management_panel(
	territory_id: StringName
) -> PanelContainer:
	var panel := _create_section_panel("TERRITORY MANAGEMENT")
	var box := panel.get_meta("content") as VBoxContainer
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for tab_id in [&"properties", &"dealers"]:
		var button := Button.new()
		button.text = String(tab_id).to_upper()
		button.custom_minimum_size = Vector2(150, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.set_pressed_no_signal(tab_id == _territory_management_tab)
		button.pressed.connect(_set_territory_management_tab.bind(tab_id))
		_style_button(
			button,
			Color(0.22, 0.72, 0.78)
			if tab_id == _territory_management_tab
			else Color(0.36, 0.42, 0.46)
		)
		tabs.add_child(button)
	if _territory_management_tab == &"dealers":
		box.add_child(_create_territory_dealer_duty_panel(territory_id))
	else:
		box.add_child(_create_territory_property_logistics_panel(territory_id))
	return panel


func _set_territory_management_tab(tab_id: StringName) -> void:
	if tab_id != &"properties" and tab_id != &"dealers":
		return
	_territory_management_tab = tab_id
	_refresh_territory()


func _create_territory_dealer_duty_panel(
	territory_id: StringName
) -> PanelContainer:
	var panel := _create_section_panel("DEALERS ON CALL")
	var box := panel.get_meta("content") as VBoxContainer
	box.add_child(_detail_label(
		"Call a hired dealer to follow you in combat. Their property income pauses until they are sent home."
	))
	var hired: Array[Dictionary] = []
	for entry in _territory_dealers.get_roster(territory_id):
		if bool(entry.get("employed", false)):
			hired.append(entry)
	if hired.is_empty():
		var empty := _detail_label(
			"No hired dealers are available in this territory. Assign dealers from a property's Operations tab."
		)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size.y = 80
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(empty)
		return panel
	for entry in hired:
		box.add_child(_create_dealer_duty_row(territory_id, entry))
	return panel


func _create_dealer_duty_row(
	territory_id: StringName,
	entry: Dictionary
) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.045, 0.057, 0.064, 0.96),
			Color(0.1, 0.24, 0.27, 0.9)
		)
	)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 9)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = String(entry.get("member_id", "dealer")).replace("_", " ").capitalize()
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.94, 0.96))
	details.add_child(name_label)
	var property_id := StringName(entry.get("property_id", ""))
	var property_definition := PropertyCatalog.get_by_id(property_id)
	var assignment := (
		property_definition.display_name
		if property_definition != null
		else "Unassigned"
	)
	details.add_child(_detail_label(
		"Level %d  •  %s  •  Today $%s net" % [
			int(entry.get("level", 1)),
			assignment,
			_money(int(entry.get("today_net", 0))),
		]
	))
	var following := bool(entry.get("following", false))
	var status := _table_value(
		"FOLLOWING" if following else "AVAILABLE",
		92,
		Color(0.22, 0.68, 0.95) if following else Color(0.25, 0.85, 0.42)
	)
	row.add_child(status)
	var duty_button := Button.new()
	duty_button.text = "SEND HOME" if following else "CALL"
	duty_button.custom_minimum_size = Vector2(112, 36)
	duty_button.disabled = not following and not _has_follower_capacity()
	duty_button.tooltip_text = (
		"Return this dealer to their assigned property and resume income"
		if following
		else (
			"Call this dealer to follow you as a bodyguard"
			if _has_follower_capacity()
			else PlayerEntourageComponent.LIMIT_FEEDBACK
		)
	)
	duty_button.pressed.connect(
		_send_dealer_back.bind(
			territory_id,
			StringName(entry.get("zone_id", "")),
			StringName(entry.get("member_id", ""))
		)
		if following
		else _call_dealer.bind(
			territory_id,
			StringName(entry.get("zone_id", "")),
			StringName(entry.get("member_id", ""))
		)
	)
	_style_button(duty_button, Color(0.25, 0.65, 0.85))
	row.add_child(duty_button)
	return panel


func _create_territory_header(display_name: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.y = 82
	box.add_theme_constant_override("separation", 3)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	box.add_child(title_row)
	var back_button := Button.new()
	back_button.text = "<  ALL TERRITORIES"
	back_button.custom_minimum_size = Vector2(190, 34)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(_show_owned_territory_list)
	_style_button(back_button, Color(0.22, 0.68, 0.74))
	title_row.add_child(back_button)
	var title := Label.new()
	title.text = display_name.to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.94, 0.97, 0.98))
	title_row.add_child(title)
	var balance := Control.new()
	balance.custom_minimum_size.x = 190
	title_row.add_child(balance)
	var subtitle := Label.new()
	subtitle.text = "Manage your territory, dealers, supply, and income."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.66, 0.72))
	box.add_child(subtitle)
	return box


func _create_stat_card(card_title: String, value: String, subtitle: String, accent: Color, progress: float) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 102
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := _make_panel_style(
		Color(0.037, 0.048, 0.059, 0.98),
		Color(accent.r, accent.g, accent.b, 0.42),
		11,
		0.16
	)
	card_style.border_width_top = 2
	panel.add_theme_stylebox_override("panel", card_style)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 13)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = card_title
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", Color(0.53, 0.6, 0.66))
	box.add_child(heading)
	var amount := Label.new()
	amount.text = value
	amount.add_theme_font_size_override("font_size", 23)
	amount.add_theme_color_override("font_color", accent)
	box.add_child(amount)
	box.add_child(_detail_label(subtitle))
	if progress >= 0.0:
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 7
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = clampf(progress, 0.0, 1.0)
		bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.055, 0.065, 0.07), Color(0.055, 0.065, 0.07)))
		bar.add_theme_stylebox_override("fill", _make_panel_style(accent, accent))
		box.add_child(bar)
	return panel


func _create_section_panel(section_title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.031, 0.042, 0.052, 0.98),
			Color(0.13, 0.21, 0.25, 0.92),
			12,
			0.14
		)
	)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = section_title
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color(0.22, 0.86, 0.92))
	box.add_child(heading)
	panel.set_meta("content", box)
	return panel


func _create_revenue_panel(
	territory_id: StringName,
	earnings: Dictionary
) -> Control:
	var panel := _create_section_panel("INCOME OVER TIME  •  LAST 7 DAYS")
	var box := panel.get_meta("content") as VBoxContainer
	var chart := TerritoryRevenueChart.new()
	chart.name = "TerritoryRevenueChart"
	chart.custom_minimum_size.y = 185
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.set_values(_territory_dealers.get_recent_daily_net(
		territory_id, 7
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
	box.add_child(_detail_label(
		"Dealers only use the stash assigned to them. Brick stations "
		+ "automate retail-unit production per property."
	))
	return panel


func _create_territory_property_logistics_panel(
	territory_id: StringName
) -> PanelContainer:
	var panel := _create_section_panel("PROPERTY LOGISTICS")
	var box := panel.get_meta("content") as VBoxContainer
	var definitions := properties.get_owned_stash_definitions(
		territory_id
	)
	if definitions.is_empty():
		box.add_child(_detail_label(
			"Own a stash house in this territory to create dealer capacity."
		))
		return panel
	for definition in definitions:
		var supply := _territory_dealers.get_property_supply_summary(
			definition.property_id
		)
		var earnings := _territory_dealers.get_property_earnings_summary(
			definition.property_id
		)
		var station := properties.get_brick_station_state(
			definition.property_id
		)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override(
			"panel",
			_make_panel_style(
				Color(0.05, 0.064, 0.075, 0.98),
				Color(0.18, 0.43, 0.46, 0.8)
			)
		)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var name_label := Label.new()
		name_label.text = definition.display_name.to_upper()
		name_label.add_theme_font_size_override("font_size", 16)
		details.add_child(name_label)
		details.add_child(_detail_label(
			"Dealers %d / %d  •  Supply %d units  •  Today $%s"
			% [
				int(earnings.staffed),
				int(earnings.total_slots),
				int(supply.product_units),
				_money(int(earnings.today_net)),
			]
		))
		details.add_child(_detail_label(
			"Stash $%s dirty  •  Brick station: %s"
			% [
				_money(int(supply.dirty_cash)),
				_station_short_status(station),
			]
		))
		var manage := Button.new()
		manage.text = "MANAGE  >"
		manage.custom_minimum_size = Vector2(120, 38)
		manage.pressed.connect(
			_manage_property_from_territory.bind(
				definition.property_id
			)
		)
		_style_button(manage, Color(0.22, 0.72, 0.78))
		row.add_child(manage)
		box.add_child(card)
	return panel


func _manage_property_from_territory(
	property_id: StringName
) -> void:
	_selected_property_id = property_id
	tab_container.current_tab = 3
	_update_navigation_styles()
	_refresh_properties()


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
	row.add_child(_table_value("STATUS", 76, Color(0.55, 0.62, 0.67)))
	row.add_child(_table_value("ACTION", 238, Color(0.55, 0.62, 0.67)))
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


func _create_dealer_management_row(
	territory_id: StringName,
	entry: Dictionary,
	available_units: int,
	property_context: StringName = &""
) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.045, 0.057, 0.064, 0.96), Color(0.1, 0.17, 0.19, 0.9)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var employed := bool(entry.employed)
	var following := bool(entry.get("following", false))
	var dealer_name := Label.new()
	dealer_name.text = String(entry.member_id).replace("_", " ").capitalize()
	dealer_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dealer_name.tooltip_text = "Sells every %d minutes • Lifetime net $%s" % [int(entry.sale_interval), _money(int(entry.lifetime_net))]
	row.add_child(dealer_name)
	var level := _table_value("LV. %d" % int(entry.level), 56, Color(0.78, 0.82, 0.84))
	row.add_child(level)
	var daily := _table_value("$%s" % _money(int(entry.today_net)), 76, Color(0.36, 0.84, 0.42))
	row.add_child(daily)
	var status_text := (
		"FOLLOWING"
		if following
		else "OUT"
		if employed and available_units <= 0
		else "ACTIVE"
		if employed
		else "VACANT"
	)
	var status_color := (
		Color(0.22, 0.68, 0.95)
		if following
		else Color(0.95, 0.42, 0.28)
		if status_text == "OUT"
		else Color(0.25, 0.85, 0.42)
		if employed
		else Color(0.55, 0.6, 0.63)
	)
	row.add_child(_table_value(status_text, 76, status_color))
	var button := Button.new()
	if not employed:
		button.text = "HIRE  $%s" % _money(int(entry.hire_fee))
		button.custom_minimum_size = Vector2(238, 34)
		button.disabled = not wallet.can_spend_dirty(int(entry.hire_fee))
		button.tooltip_text = "Hire this dealer at Level 1"
		button.pressed.connect(_hire_dealer.bind(territory_id, entry.zone_id, entry.member_id))
		_style_button(button, Color(0.2, 0.72, 0.48))
		row.add_child(button)
	else:
		var actions := HBoxContainer.new()
		actions.custom_minimum_size.x = 360 if not property_context.is_empty() else 238
		actions.add_theme_constant_override("separation", 4)
		var max_level := bool(entry.max_level)
		button.text = "MAX LEVEL" if max_level else "UPGRADE $%s" % _money(int(entry.upgrade_cost))
		button.custom_minimum_size = Vector2(104, 34)
		button.disabled = max_level or not wallet.can_spend_dirty(int(entry.upgrade_cost))
		button.tooltip_text = "Level 4 reached" if max_level else "Upgrade to Level %d for faster sales" % (int(entry.level) + 1)
		if not max_level:
			button.pressed.connect(_upgrade_dealer.bind(territory_id, entry.zone_id, entry.member_id))
		_style_button(button, Color(0.2, 0.68, 0.84))
		actions.add_child(button)
		var duty_button := Button.new()
		duty_button.text = "SEND BACK" if following else "CALL"
		duty_button.custom_minimum_size = Vector2(82, 34)
		duty_button.disabled = not following and not _has_follower_capacity()
		duty_button.tooltip_text = (
			"Return this dealer to work and resume their paused sale timer"
			if following
			else (
				"Call this dealer as a bodyguard; income pauses while following"
				if _has_follower_capacity()
				else PlayerEntourageComponent.LIMIT_FEEDBACK
			)
		)
		duty_button.pressed.connect(
			_send_dealer_back.bind(
				territory_id, entry.zone_id, entry.member_id
			)
			if following
			else _call_dealer.bind(
				territory_id, entry.zone_id, entry.member_id
			)
		)
		_style_button(duty_button, Color(0.25, 0.65, 0.85))
		actions.add_child(duty_button)
		var fire_button := Button.new()
		fire_button.text = "FIRE"
		fire_button.custom_minimum_size = Vector2(44, 34)
		fire_button.tooltip_text = "Fire this dealer with no refund"
		fire_button.pressed.connect(_fire_dealer.bind(territory_id, entry.zone_id, entry.member_id))
		_style_button(fire_button, Color(0.78, 0.22, 0.26))
		actions.add_child(fire_button)
		if not property_context.is_empty():
			var move_picker := OptionButton.new()
			move_picker.name = "DealerPropertyReassignment"
			move_picker.custom_minimum_size.x = 112
			var current_definition := PropertyCatalog.get_by_id(
				property_context
			)
			move_picker.add_item(
				current_definition.display_name
				if current_definition != null else "ASSIGNED"
			)
			move_picker.set_item_metadata(0, String(property_context))
			for definition in properties.get_owned_stash_definitions(
				territory_id
			):
				if definition.property_id == property_context:
					continue
				if (
					_territory_dealers.get_property_roster(
						definition.property_id
					).size()
					>= definition.dealer_capacity
				):
					continue
				move_picker.add_item("MOVE: %s" % definition.display_name)
				move_picker.set_item_metadata(
					move_picker.item_count - 1,
					String(definition.property_id)
				)
			move_picker.disabled = move_picker.item_count <= 1
			move_picker.item_selected.connect(
				_on_dealer_property_selected.bind(
					territory_id,
					StringName(entry.zone_id),
					StringName(entry.member_id),
					move_picker
				)
			)
			actions.add_child(move_picker)
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


func _on_dealer_property_selected(
	index: int,
	territory_id: StringName,
	zone_id: StringName,
	member_id: StringName,
	picker: OptionButton
) -> void:
	if index <= 0:
		return
	var property_id := StringName(picker.get_item_metadata(index))
	var success := _territory_dealers.reassign_dealer(
		territory_id,
		zone_id,
		member_id,
		property_id
	)
	feedback_label.text = (
		"Dealer reassigned to %s."
		% picker.get_item_text(index).trim_prefix("MOVE: ")
		if success else "Could not reassign that dealer."
	)
	_refresh_properties()
	_refresh_territory()


func _upgrade_dealer(territory_id: StringName, zone_id: StringName, member_id: StringName) -> void:
	var success := _territory_dealers.upgrade_dealer(territory_id, zone_id, member_id)
	feedback_label.text = "Dealer upgraded." if success else "Could not upgrade that dealer."
	_refresh_territory()


func _fire_dealer(territory_id: StringName, zone_id: StringName, member_id: StringName) -> void:
	var success := _territory_dealers.fire_dealer(territory_id, zone_id, member_id)
	feedback_label.text = "Dealer fired." if success else "Could not fire that dealer."
	_refresh_territory()


func _call_dealer(
	territory_id: StringName,
	zone_id: StringName,
	member_id: StringName
) -> void:
	var success := _territory_dealers.call_dealer(
		territory_id,
		zone_id,
		member_id
	)
	feedback_label.text = (
		"Dealer is following you. Their income is paused."
		if success
		else (
			PlayerEntourageComponent.LIMIT_FEEDBACK
			if not _has_follower_capacity()
			else "Could not call that dealer."
		)
	)
	_refresh_territory()


func _send_dealer_back(
	territory_id: StringName,
	zone_id: StringName,
	member_id: StringName
) -> void:
	var success := _territory_dealers.send_dealer_back(
		territory_id,
		zone_id,
		member_id
	)
	feedback_label.text = (
		"Dealer returned to work."
		if success
		else "Could not send that dealer back."
	)
	_refresh_territory()


func _refresh_properties() -> void:
	for child in property_list.get_children():
		child.queue_free()
	if properties == null or properties.get_owned_definitions().is_empty():
		_selected_property_id = &""
		property_list.add_child(_create_center_label("No properties owned."))
		return
	_selected_property_id = &""
	var heading := Label.new()
	heading.text = "OWNED PROPERTIES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	property_list.add_child(heading)
	var subtitle := _detail_label(
		"Stash houses control dealer staffing, supply, and brick automation."
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	property_list.add_child(subtitle)
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
	location.text = (
		"%s  •  Bed & Save  •  Wardrobe  •  Private Stash"
		% definition.neighborhood
		if definition.is_stash_house()
		else "%s  •  Passive Front Business" % definition.neighborhood
	)
	location.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	box.add_child(location)
	if definition.is_front_business():
		var business := properties.get_business_state(definition.property_id)
		var business_summary := Label.new()
		business_summary.text = (
			"Stock %d / %d  •  Pending $%s Clean  •  Lifetime $%s"
			% [
				int(business.get("stock", 0)),
				definition.business_stock_capacity,
				_money(int(business.get("accumulated_earnings", 0))),
				_money(int(business.get("total_earned", 0))),
			]
		)
		business_summary.add_theme_color_override(
			"font_color",
			Color(0.9, 0.66, 0.3)
		)
		box.add_child(business_summary)
		return panel
	var summary := properties.get_stash_summary(definition.property_id)
	var earnings := (
		_territory_dealers.get_property_earnings_summary(
			definition.property_id
		)
		if _territory_dealers != null else {
			"staffed": 0,
			"total_slots": definition.dealer_capacity,
			"today_net": 0,
		}
	)
	var station := properties.get_brick_station_state(
		definition.property_id
	)
	var vehicle_garage := get_parent().get_node_or_null(
		"Components/VehicleGarageComponent"
	) as PlayerVehicleGarageComponent
	var storage := Label.new()
	storage.text = (
		"Stored: $%s dirty  •  %d drug units  •  %d weapons\n"
		+ "Vehicles: %d / %d  •  Dealers: %d / %d  •  Today: $%s  •  Brick station: %s"
	) % [
		_money(int(summary["dirty_cash"])),
		int(summary["product_units"]),
		int(summary["weapon_count"]),
		vehicle_garage.get_stored_count(definition.property_id) if vehicle_garage != null else 0,
		definition.vehicle_storage_capacity,
		int(earnings.staffed),
		int(earnings.total_slots),
		_money(int(earnings.today_net)),
		_station_short_status(station),
	]
	storage.add_theme_color_override("font_color", Color(0.9, 0.66, 0.3))
	box.add_child(storage)
	var manage := Button.new()
	manage.text = "MANAGE PROPERTY  >"
	manage.custom_minimum_size = Vector2(190, 38)
	manage.size_flags_horizontal = Control.SIZE_SHRINK_END
	manage.pressed.connect(_select_property.bind(definition.property_id))
	_style_button(manage, Color(0.22, 0.72, 0.78))
	box.add_child(manage)
	return panel


func _select_property(property_id: StringName) -> void:
	var property_hub := get_parent().get_node_or_null("PropertyStashMenu")
	if property_hub == null:
		feedback_label.text = "Property management is unavailable."
		return
	if not menu_controller.replace_open(&"inventory", &"property_hub"):
		feedback_label.text = "Could not open property management."
		return
	_is_open = false
	menu_root.visible = false
	_animate_panel_for_tab(false, 0)
	property_hub.call(
		"open_remote",
		property_id,
		&"operations",
		true
	)


func _show_property_list() -> void:
	_selected_property_id = &""
	_refresh_properties()


func _render_property_dashboard(definition: PropertyDefinition) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.text = "<  ALL PROPERTIES"
	back.custom_minimum_size = Vector2(180, 36)
	back.pressed.connect(_show_property_list)
	_style_button(back, Color(0.22, 0.68, 0.74))
	header.add_child(back)
	var title := Label.new()
	title.text = definition.display_name.to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	header.add_child(title)
	var balance := Control.new()
	balance.custom_minimum_size.x = 180
	header.add_child(balance)
	property_list.add_child(header)
	var supply := (
		_territory_dealers.get_property_supply_summary(
			definition.property_id
		)
		if _territory_dealers != null
		else properties.get_property_supply_summary(
			definition.property_id,
			EconomyCatalog.get_gram_products()
		)
	)
	var earnings := (
		_territory_dealers.get_property_earnings_summary(
			definition.property_id
		)
		if _territory_dealers != null
		else {
			"staffed": 0,
			"total_slots": definition.dealer_capacity,
			"today_net": 0,
			"lifetime_net": 0,
		}
	)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	stats_row.add_child(_create_stat_card(
		"DEALERS",
		"%d / %d" % [int(earnings.staffed), int(earnings.total_slots)],
		"Assigned to this stash",
		Color(0.72, 0.3, 0.88),
		float(earnings.staffed) / maxf(float(earnings.total_slots), 1.0)
	))
	stats_row.add_child(_create_stat_card(
		"SELLABLE SUPPLY",
		"%d UNITS" % int(supply.product_units),
		"This stash only",
		Color(0.18, 0.68, 1.0),
		-1.0
	))
	stats_row.add_child(_create_stat_card(
		"DAILY NET",
		"$%s" % _money(int(earnings.today_net)),
		"Lifetime $%s" % _money(int(earnings.lifetime_net)),
		Color(0.2, 0.82, 0.42),
		-1.0
	))
	stats_row.add_child(_create_stat_card(
		"STASH CASH",
		"$%s" % _money(int(supply.dirty_cash)),
		"Dirty Cash",
		Color(0.93, 0.68, 0.16),
		-1.0
	))
	property_list.add_child(stats_row)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	var runner_panel := _create_runner_panel(definition)
	runner_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(runner_panel)
	var station_panel := _create_brick_station_panel(definition)
	station_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(station_panel)
	var dealer_panel := _create_property_dealer_panel(
		definition,
		supply,
		earnings
	)
	dealer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(dealer_panel)
	property_list.add_child(columns)


func _create_runner_panel(
	definition: PropertyDefinition
) -> PanelContainer:
	var panel := _create_section_panel("WHOLESALE RUNNER")
	var box := panel.get_meta("content") as VBoxContainer
	var installed := properties.has_runner(definition.property_id)
	box.add_child(_detail_label(
		"Receives complete wholesaler brick orders directly into this stash."
	))
	var status := Label.new()
	status.name = "PropertyRunnerStatus"
	status.text = "RUNNER ACTIVE" if installed else "NOT INSTALLED"
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override(
		"font_color",
		Color(0.2, 0.82, 0.42)
		if installed else Color(0.93, 0.68, 0.16)
	)
	box.add_child(status)
	if installed:
		box.add_child(_detail_label(
			"Available as a destination at every wholesaler."
		))
		return panel
	box.add_child(_detail_label(
		"Cost: $%s Clean  |  Available: $%s Clean" % [
			_money(PropertyCatalog.RUNNER_UPGRADE_COST),
			_money(wallet.clean_cash),
		]
	))
	var purchase := Button.new()
	purchase.name = "PropertyRunnerPurchase"
	purchase.text = "HIRE RUNNER  $%s CLEAN" % _money(
		PropertyCatalog.RUNNER_UPGRADE_COST
	)
	purchase.disabled = not wallet.can_spend_clean(
		PropertyCatalog.RUNNER_UPGRADE_COST
	)
	purchase.pressed.connect(
		_purchase_property_runner.bind(definition.property_id)
	)
	_style_button(purchase, Color(0.2, 0.74, 0.7))
	box.add_child(purchase)
	return panel


func _create_brick_station_panel(
	definition: PropertyDefinition
) -> PanelContainer:
	var panel := _create_section_panel("BRICK BREAKDOWN STATION")
	var box := panel.get_meta("content") as VBoxContainer
	var state := properties.get_brick_station_state(definition.property_id)
	var installed := bool(state.get("installed", false))
	box.add_child(_detail_label(
		"Converts one selected brick every 3 in-game hours. "
		+ "Output stays in this stash."
	))
	var status := Label.new()
	status.name = "PropertyBrickStationStatus"
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override(
		"font_color",
		Color(0.2, 0.82, 0.42)
		if installed else Color(0.93, 0.68, 0.16)
	)
	status.text = _station_detailed_status(state)
	box.add_child(status)
	if not installed:
		box.add_child(_detail_label(
			"Cost: $%s Clean  •  Available: $%s Clean"
			% [
				_money(definition.brick_station_cost),
				_money(wallet.clean_cash),
			]
		))
		var purchase := Button.new()
		purchase.name = "PropertyBrickStationPurchase"
		purchase.text = "INSTALL  $%s CLEAN" % _money(
			definition.brick_station_cost
		)
		purchase.disabled = not wallet.can_spend_clean(
			definition.brick_station_cost
		)
		purchase.pressed.connect(
			_purchase_property_brick_station.bind(
				definition.property_id
			)
		)
		_style_button(purchase, Color(0.9, 0.58, 0.18))
		box.add_child(purchase)
		return panel
	var selector := OptionButton.new()
	selector.name = "PropertyBrickStationProduct"
	selector.add_item("OFF")
	selector.set_item_metadata(0, "")
	var selected_id := StringName(
		state.get("selected_product_id", "")
	)
	var selected_index := 0
	for product in EconomyCatalog.get_brick_products():
		selector.add_item(product.display_name.to_upper())
		var index := selector.item_count - 1
		selector.set_item_metadata(index, String(product.product_id))
		if product.product_id == selected_id:
			selected_index = index
	selector.select(selected_index)
	selector.item_selected.connect(
		_on_property_station_product_selected.bind(
			definition.property_id,
			selector
		)
	)
	box.add_child(selector)
	var selected_product := EconomyCatalog.get_product(selected_id)
	if selected_product != null:
		box.add_child(_detail_label(
			"Stored: %d %s  •  Output per cycle: %d %s"
			% [
				properties.get_stashed_product_quantity(
					definition.property_id,
					selected_product
				),
				selected_product.display_name,
				selected_product.breakdown_amount,
				selected_product.breakdown_product.display_name,
			]
		))
	return panel


func _create_property_dealer_panel(
	definition: PropertyDefinition,
	supply: Dictionary,
	earnings: Dictionary
) -> PanelContainer:
	var panel := _create_section_panel("DEALERS  •  PROPERTY ASSIGNMENTS")
	var box := panel.get_meta("content") as VBoxContainer
	if _territory_dealers == null:
		box.add_child(_detail_label("Dealer service unavailable."))
		return panel
	if not _territory_dealers.can_manage_property_dealers(
		definition.property_id
	):
		box.add_child(_detail_label(
			"Take control of %s before hiring dealers for this property."
			% definition.neighborhood
		))
		return panel
	box.add_child(_create_dealer_table_header(earnings))
	var roster := _territory_dealers.get_property_roster(
		definition.property_id
	)
	for entry in roster:
		box.add_child(_create_dealer_management_row(
			definition.territory_id,
			entry,
			int(supply.product_units),
			definition.property_id
		))
	var open_slots := maxi(
		definition.dealer_capacity - roster.size(),
		0
	)
	for slot_index in open_slots:
		box.add_child(_create_property_hire_row(
			definition,
			slot_index + roster.size() + 1
		))
	return panel


func _create_property_hire_row(
	definition: PropertyDefinition,
	slot_number: int
) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.045, 0.057, 0.064, 0.96),
			Color(0.1, 0.17, 0.19, 0.9)
		)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var label := _detail_label("SLOT %d  •  VACANT" % slot_number)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker := OptionButton.new()
	picker.name = "DealerCandidatePicker"
	picker.custom_minimum_size.x = 205
	var candidates := _territory_dealers.get_available_candidates(
		definition.territory_id
	)
	for entry in candidates:
		picker.add_item(
			String(entry.member_id).replace("_", " ").capitalize()
		)
		picker.set_item_metadata(
			picker.item_count - 1,
			{
				"zone_id": String(entry.zone_id),
				"member_id": String(entry.member_id),
			}
		)
	picker.disabled = candidates.is_empty()
	row.add_child(picker)
	var hire := Button.new()
	hire.name = "PropertyDealerHire"
	hire.text = "HIRE  $%s" % _money(
		TerritoryDealerService.HIRE_FEE
	)
	hire.disabled = (
		candidates.is_empty()
		or not wallet.can_spend_dirty(
			TerritoryDealerService.HIRE_FEE
		)
	)
	hire.pressed.connect(
		_hire_property_dealer.bind(
			definition.property_id,
			definition.territory_id,
			picker
		)
	)
	_style_button(hire, Color(0.2, 0.72, 0.48))
	row.add_child(hire)
	return panel


func _station_short_status(state: Dictionary) -> String:
	if not bool(state.get("installed", false)):
		return "Not installed"
	var selected_id := StringName(
		state.get("selected_product_id", "")
	)
	if selected_id.is_empty():
		return "Off"
	var product := EconomyCatalog.get_product(selected_id)
	return (
		"%s / Blocked" % product.get_short_display_name()
		if not String(state.get("last_block_reason", "")).is_empty()
		else "%s / Active" % product.get_short_display_name()
	)


func _station_detailed_status(state: Dictionary) -> String:
	if not bool(state.get("installed", false)):
		return "NOT INSTALLED"
	var selected_id := StringName(
		state.get("selected_product_id", "")
	)
	if selected_id.is_empty():
		return "INSTALLED  •  OFF"
	var product := EconomyCatalog.get_product(selected_id)
	var block_reason := String(state.get("last_block_reason", ""))
	var next_minute := int(state.get("next_process_minute", -1))
	var remaining := maxi(next_minute - _get_absolute_minute(), 0)
	return "%s  •  %s  •  %dh %02dm" % [
		product.display_name.to_upper(),
		"BLOCKED: %s" % block_reason
		if not block_reason.is_empty() else "ACTIVE",
		remaining / 60,
		remaining % 60,
	]


func _purchase_property_brick_station(
	property_id: StringName
) -> void:
	var success := properties.purchase_brick_station(
		property_id,
		_get_absolute_minute()
	)
	feedback_label.text = (
		"Brick Breakdown Station installed for $5,000 Clean Cash."
		if success else "Could not install the brick station."
	)
	_refresh_properties()


func _purchase_property_runner(property_id: StringName) -> void:
	var success := properties.purchase_runner(property_id)
	feedback_label.text = (
		"Runner hired. Wholesalers can now deliver to this stash."
		if success else properties.last_transfer_error
	)
	_refresh_properties()


func _on_property_station_product_selected(
	index: int,
	property_id: StringName,
	selector: OptionButton
) -> void:
	if index < 0:
		return
	var product_id := StringName(selector.get_item_metadata(index))
	var success := properties.set_brick_station_product(
		property_id,
		product_id,
		_get_absolute_minute()
	)
	feedback_label.text = (
		"Brick automation turned off."
		if success and product_id.is_empty()
		else "Brick station set to %s."
		% selector.get_item_text(index)
		if success
		else "Could not change the brick station."
	)
	_refresh_properties()


func _hire_property_dealer(
	property_id: StringName,
	territory_id: StringName,
	picker: OptionButton
) -> void:
	if picker.item_count <= 0:
		feedback_label.text = "No dealer candidate is available."
		return
	var metadata := picker.get_selected_metadata() as Dictionary
	var success := _territory_dealers.hire_dealer(
		territory_id,
		StringName(metadata.get("zone_id", "")),
		StringName(metadata.get("member_id", "")),
		property_id
	)
	feedback_label.text = (
		"Dealer hired and assigned to this stash."
		if success else "Could not hire that dealer."
	)
	_refresh_properties()
	_refresh_territory()


func _money(amount: int) -> String:
	var text := str(amount)
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result


func _get_absolute_minute() -> int:
	var world_time := get_tree().get_first_node_in_group(
		&"world_time"
	) as WorldTimeComponent
	return world_time.get_absolute_minute() if world_time != null else 0


func _refresh_girlfriends() -> void:
	for child in girlfriend_list.get_children():
		child.queue_free()
	if girlfriends == null or girlfriends.get_roster().is_empty():
		girlfriend_list.add_child(_create_empty_dashboard(
			"NO GIRLFRIENDS RECRUITED",
			"Build relationships in the city to add companions to your roster."
		))
		return
	var roster := girlfriends.get_roster()
	girlfriend_list.add_child(_create_list_section_heading(
		"ROSTER", "CALL OR SEND HOME", Color(0.94, 0.31, 0.58)
	))
	for entry in roster:
		var npc: Variant = entry.get("npc")
		if is_instance_valid(npc):
			girlfriend_list.add_child(_create_girlfriend_row(entry))


func _create_girlfriend_row(entry: Dictionary) -> Control:
	var accent := Color(0.94, 0.31, 0.58)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 104
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.042, 0.052, 0.064, 0.97),
			Color(accent.r, accent.g, accent.b, 0.48),
			11,
			0.18
		)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var npc := entry["npc"] as CustomerNPC
	row.add_child(_create_girlfriend_model_preview(npc, accent))
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = "%s  •  Level %d  •  %s" % [entry["name"], entry["level"], str(entry["status"]).capitalize()]
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99))
	details.add_child(name_label)
	var relationship := int(entry.get("relationship", 0))
	var relationship_bar := ProgressBar.new()
	relationship_bar.custom_minimum_size = Vector2(220, 12)
	relationship_bar.min_value = -100
	relationship_bar.max_value = 100
	relationship_bar.value = relationship
	relationship_bar.show_percentage = false
	relationship_bar.tooltip_text = "Relationship %d / 100" % relationship
	var fill_color := Color(0.86, 0.24, 0.28, 1.0) if relationship < 0 else (Color(0.25, 0.82, 0.42, 1.0) if relationship > 0 else Color(0.62, 0.64, 0.68, 1.0))
	relationship_bar.add_theme_stylebox_override(
		"background",
		_make_panel_style(Color(0.018, 0.024, 0.032), Color(0.12, 0.15, 0.18), 6)
	)
	relationship_bar.add_theme_stylebox_override(
		"fill", _make_panel_style(fill_color, fill_color.lightened(0.15), 6)
	)
	details.add_child(relationship_bar)
	var relationship_label := Label.new()
	relationship_label.text = "Relationship: %d / 100" % relationship
	relationship_label.add_theme_font_size_override("font_size", 13)
	details.add_child(relationship_label)
	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(112, 40)
	toggle.text = "CALL" if entry["status"] == PlayerGirlfriendComponent.STATUS_HOME else "SEND HOME"
	var girlfriend_home: bool = entry["status"] == PlayerGirlfriendComponent.STATUS_HOME
	toggle.disabled = girlfriend_home and not _has_follower_capacity()
	toggle.tooltip_text = (
		PlayerEntourageComponent.LIMIT_FEEDBACK
		if toggle.disabled
		else "Call this girlfriend to join your active crew"
		if girlfriend_home
		else "Send this girlfriend home and free a Motion follower slot"
	)
	toggle.pressed.connect(girlfriends.call_girlfriend.bind(npc) if entry["status"] == PlayerGirlfriendComponent.STATUS_HOME else girlfriends.send_home.bind(npc))
	_style_button(toggle, Color(0.25, 0.65, 0.85, 1.0))
	row.add_child(toggle)
	var breakup := Button.new()
	breakup.custom_minimum_size = Vector2(104, 40)
	breakup.text = "BREAK UP"
	breakup.pressed.connect(girlfriends.break_up.bind(npc))
	_style_button(breakup, Color(0.8, 0.2, 0.3, 1.0))
	row.add_child(breakup)
	return panel


func _refresh_drugs() -> void:
	for child in drug_list.get_children():
		child.queue_free()
	var carried: Array[ProductDefinition] = []
	for product in EconomyCatalog.get_all_products():
		var quantity := inventory.get_quantity(product)
		if quantity <= 0:
			continue
		carried.append(product)
	if carried.is_empty():
		drug_list.add_child(_create_empty_dashboard(
			"NO PRODUCT CARRIED",
			"Purchased and collected product will appear here."
		))
		return
	drug_list.add_child(_create_list_section_heading(
		"CARRIED PACKAGES", "VALUE AND RISK PROFILE", Color(0.22, 0.8, 0.87)
	))
	for product in carried:
		drug_list.add_child(_create_drug_row(product))


func _refresh_weapons() -> void:
	for child in weapon_list.get_children():
		child.queue_free()

	if weapon_component == null:
		weapon_list.add_child(_create_empty_dashboard(
			"WEAPON LOADOUT UNAVAILABLE", "The player weapon system could not be found."
		))
		return

	var weapons := weapon_component.get_weapon_slots()
	if weapons.is_empty():
		weapon_list.add_child(_create_empty_dashboard(
			"NO WEAPONS CARRIED", "Purchased weapons will appear in this loadout."
		))
		return

	var equipped := weapon_component.get_equipped_weapon()
	weapon_list.add_child(_create_list_section_heading(
		"WEAPON SLOTS", "COMBAT PROFILE", Color(0.95, 0.34, 0.31)
	))
	for weapon in weapons:
		weapon_list.add_child(_create_weapon_row(weapon, equipped))


func _create_drug_row(product: ProductDefinition) -> Control:
	var accent := _get_drug_accent(product)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 104
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.042, 0.052, 0.064, 0.98),
			Color(accent.r, accent.g, accent.b, 0.52),
			11,
			0.18
		)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(72, 72)
	icon_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(accent.r * 0.13, accent.g * 0.13, accent.b * 0.13, 0.9),
			Color(accent.r, accent.g, accent.b, 0.58),
			12
		)
	)
	row.add_child(icon_panel)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(50, 50)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = product.icon if product.icon != null else DRUGS_ICON
	icon_panel.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 5)
	row.add_child(text_box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	text_box.add_child(title_row)
	var name_label := Label.new()
	name_label.text = _get_drug_label(product)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1))
	title_row.add_child(name_label)
	var package_label := Label.new()
	package_label.text = (
		"BRICK" if product.is_brick() else "%dG PACKAGE" % product.package_size_grams
	)
	package_label.add_theme_font_size_override("font_size", 10)
	package_label.add_theme_color_override("font_color", accent.lightened(0.2))
	package_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(package_label)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 18)
	text_box.add_child(metrics)
	metrics.add_child(_create_inline_metric(
		"CARRIED", _get_drug_amount_text(product), accent
	))
	metrics.add_child(_create_inline_metric(
		"PACKAGES", str(inventory.get_quantity(product)), Color(0.72, 0.76, 0.82)
	))
	metrics.add_child(_create_inline_metric(
		"STREET EACH", "$%s" % _money(product.sale_price), Color(0.34, 0.86, 0.5)
	))
	metrics.add_child(_create_inline_metric(
		"HEAT", "+%d" % roundi(product.heat_reward), Color(0.96, 0.36, 0.34)
	))

	var breakdown_button := Button.new()
	breakdown_button.text = "BREAK DOWN"
	breakdown_button.custom_minimum_size = Vector2(126, 42)
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
	var is_equipped := weapon == equipped
	var accent := Color(0.95, 0.34, 0.31) if is_equipped else Color(0.46, 0.54, 0.62)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 104
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.042, 0.052, 0.064, 0.98),
			Color(accent.r, accent.g, accent.b, 0.55),
			11,
			0.18
		)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	row.add_child(_create_weapon_model_preview(weapon, accent))
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 5)
	row.add_child(details)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	details.add_child(heading)
	var name_label := Label.new()
	name_label.text = weapon.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1))
	heading.add_child(name_label)
	var status := Label.new()
	status.text = "EQUIPPED" if is_equipped else "STORED"
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", accent.lightened(0.2))
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(status)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 20)
	details.add_child(metrics)
	metrics.add_child(_create_inline_metric(
		"DAMAGE", "%d" % roundi(weapon.damage), Color(0.96, 0.42, 0.38)
	))
	metrics.add_child(_create_inline_metric(
		"FIRE RATE", "%.1f / SEC" % weapon.get_rounds_per_second(),
		Color(0.95, 0.67, 0.3)
	))
	metrics.add_child(_create_inline_metric(
		"RANGE", "%d M" % roundi(weapon.max_range), Color(0.4, 0.75, 0.95)
	))
	metrics.add_child(_create_inline_metric(
		"MODE", "AUTO" if weapon.supports_full_auto else "SEMI",
		Color(0.7, 0.73, 0.78)
	))
	metrics.add_child(_create_inline_metric(
		"WEIGHT",
		"%dG" % weapon.get_carry_weight_grams(
			weapon_component.get_attachment_state(weapon.weapon_id)
		),
		Color(0.34, 0.82, 0.84)
	))

	var detail_label := Label.new()
	if is_equipped:
		detail_label.text = "MAGAZINE  %d / %d     RESERVE  %d" % [
			weapon_component.get_magazine_ammo(),
			weapon_component.get_magazine_capacity(),
			weapon_component.get_reserve_ammo(),
		]
	else:
		detail_label.text = "READY IN WEAPON SLOT"
	detail_label.add_theme_font_size_override("font_size", 11)
	detail_label.add_theme_color_override("font_color", Color(0.55, 0.61, 0.67, 1.0))
	details.add_child(detail_label)

	return panel


func _create_weapon_model_preview(
	weapon: WeaponDefinition,
	accent: Color
) -> Control:
	if weapon.visual_scene == null:
		return _create_preview_fallback(
			Vector2(124, 76), WEAPONS_ICON, accent, 12
		)
	var model := weapon.visual_scene.instantiate() as Node3D
	if model == null:
		return _create_preview_fallback(
			Vector2(124, 76), WEAPONS_ICON, accent, 12
		)

	var preview := _create_model_preview_shell(Vector2(124, 76), accent, 12)
	var viewport := preview.get_meta("viewport") as SubViewport
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	pivot.add_child(model)
	model.process_mode = Node.PROCESS_MODE_DISABLED
	model.rotation_degrees = Vector3(0, -90, 0)
	model.scale = Vector3.ONE * (2.1 if weapon.weapon_id == &"pistol" else 1.35)
	_hide_preview_extras(model)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.18, 2.15)
	camera.look_at_from_position(camera.position, Vector3(0, 0.04, 0))
	camera.fov = 34.0
	viewport.add_child(camera)
	_add_preview_lighting(viewport, accent)
	return preview


func _create_girlfriend_model_preview(
	npc: CustomerNPC,
	accent: Color
) -> Control:
	var source: Node3D = null
	if is_instance_valid(npc):
		source = npc.get_node_or_null("Visual/PlayerTest2") as Node3D
	if source == null:
		return _create_preview_fallback(
			Vector2(90, 82), GIRLFRIENDS_ICON, accent, 12
		)
	# Duplicate the live hierarchy instead of reinstantiating its source scene so
	# the preview keeps this NPC's current body, outfit, colors, and pose.
	var model := source.duplicate(Node.DUPLICATE_GROUPS) as Node3D
	if model == null:
		return _create_preview_fallback(
			Vector2(90, 82), GIRLFRIENDS_ICON, accent, 12
		)

	var preview := _create_model_preview_shell(Vector2(90, 82), accent, 12)
	var viewport := preview.get_meta("viewport") as SubViewport
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	pivot.add_child(model)
	model.process_mode = Node.PROCESS_MODE_DISABLED
	_hide_preview_extras(model)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.28, 3.15)
	camera.look_at_from_position(camera.position, Vector3(0, 1.2, 0))
	camera.fov = 27.0
	viewport.add_child(camera)
	_add_preview_lighting(viewport, accent)
	return preview


func _create_model_preview_shell(
	preview_size: Vector2,
	accent: Color,
	radius: int
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = preview_size
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(accent.r * 0.1, accent.g * 0.1, accent.b * 0.1, 0.92),
			Color(accent.r, accent.g, accent.b, 0.58),
			radius
		)
	)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(
		maxi(roundi(preview_size.x * 2.0), 1),
		maxi(roundi(preview_size.y * 2.0), 1)
	)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	panel.set_meta("viewport", viewport)
	return panel


func _create_preview_fallback(
	preview_size: Vector2,
	icon_texture: Texture2D,
	accent: Color,
	radius: int
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = preview_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.9),
			Color(accent.r, accent.g, accent.b, 0.58),
			radius
		)
	)
	var icon := TextureRect.new()
	icon.custom_minimum_size = preview_size * 0.5
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	return panel


func _add_preview_lighting(viewport: SubViewport, accent: Color) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_energy = 2.25
	key.light_color = Color(1.0, 0.9, 0.76)
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18, 145, 0)
	fill.light_energy = 1.35
	fill.light_color = accent.lightened(0.35)
	viewport.add_child(fill)


func _hide_preview_extras(root: Node3D) -> void:
	for node in root.find_children("*", "Node3D", true, false):
		var node_3d := node as Node3D
		var clean_name := String(node_3d.name).to_lower()
		if (
			clean_name.contains("muzzleflash")
			or clean_name.contains("laserbeam")
			or clean_name == "equippedweapon"
		):
			node_3d.visible = false


func _create_list_section_heading(
	title: String,
	caption: String,
	accent: Color
) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 34
	row.add_theme_constant_override("separation", 10)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(4, 20)
	marker.color = accent
	row.add_child(marker)
	var heading := Label.new()
	heading.text = title
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9))
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(heading)
	var note := Label.new()
	note.text = caption
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.41, 0.47, 0.53))
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(note)
	return row


func _create_inline_metric(
	caption: String,
	value: String,
	accent: Color
) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 90
	box.add_theme_constant_override("separation", 0)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_size_override("font_size", 9)
	caption_label.add_theme_color_override("font_color", Color(0.42, 0.48, 0.54))
	box.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", accent)
	box.add_child(value_label)
	return box


func _get_drug_accent(product: ProductDefinition) -> Color:
	match product.drug_type:
		ProductDefinition.DrugType.WEED:
			return Color(0.3, 0.82, 0.48)
		ProductDefinition.DrugType.COKE:
			return Color(0.29, 0.75, 0.94)
		ProductDefinition.DrugType.FENT:
			return Color(0.68, 0.46, 0.91)
		_:
			return Color(0.22, 0.8, 0.87)


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


func _make_panel_style(
	fill: Color,
	border: Color,
	radius := 10,
	shadow_strength := 0.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.anti_aliasing = true
	if shadow_strength > 0.0:
		style.shadow_color = Color(0, 0, 0, shadow_strength)
		style.shadow_size = 8
	return style


func _style_button(button: Button, accent: Color) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override(
		"normal",
		_make_panel_style(
			Color(accent.r * 0.13, accent.g * 0.13, accent.b * 0.13, 0.96),
			accent.darkened(0.2),
			8
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(accent.darkened(0.25), accent.lightened(0.12), 8, 0.22)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_panel_style(accent.darkened(0.42), accent.lightened(0.2), 8)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_make_panel_style(
			Color(0.045, 0.052, 0.062, 0.76),
			Color(0.14, 0.16, 0.19, 0.72),
			8
		)
	)
	var focus_style := _make_panel_style(
		Color(0, 0, 0, 0), accent.lightened(0.22), 8
	)
	focus_style.border_width_left = 2
	focus_style.border_width_top = 2
	focus_style.border_width_right = 2
	focus_style.border_width_bottom = 2
	focus_style.expand_margin_left = 2
	focus_style.expand_margin_top = 2
	focus_style.expand_margin_right = 2
	focus_style.expand_margin_bottom = 2
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_color_override("font_color", Color(0.92, 0.96, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", accent.lightened(0.36))
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
		_update_page_header()


func _on_weapon_loadout_changed() -> void:
	if _is_open:
		_refresh_weapons()
		_update_page_header()


func _on_ammo_changed(_magazine: int, _reserve: int) -> void:
	if _is_open:
		_refresh_weapons()


func _on_attachments_changed() -> void:
	if _is_open:
		_refresh_weapons()


func _on_carry_weight_changed(current: int, maximum: int) -> void:
	_update_carry_weight_display(current, maximum)
	if _is_open:
		_refresh_weapons()


func _on_roster_changed() -> void:
	if _is_open:
		_refresh_girlfriends()
		_update_page_header()


func _on_entourage_capacity_changed(_active: int, _maximum: int) -> void:
	if _is_open:
		_refresh_girlfriends()
		_refresh_territory()


func _has_follower_capacity() -> bool:
	return entourage == null or entourage.has_capacity()


func _on_property_changed(_property_id: StringName, _owned: bool) -> void:
	if _is_open:
		_refresh_properties()
		_refresh_territory()
		_update_page_header()


func _on_property_stash_changed(_property_id: StringName) -> void:
	if _is_open:
		_refresh_properties()
		_refresh_territory()


func _on_property_brick_station_changed(_property_id: StringName) -> void:
	if _is_open:
		_refresh_properties()
		_refresh_territory()


func _on_property_runner_changed(_property_id: StringName) -> void:
	if _is_open:
		_refresh_properties()


func _on_territory_dealer_state_changed(_territory_id: StringName) -> void:
	if _is_open:
		_refresh_properties()
		_refresh_territory()


func _on_wallet_changed(_dirty_cash: int, _clean_cash: int) -> void:
	if _is_open:
		_refresh_properties()
		_refresh_territory()
