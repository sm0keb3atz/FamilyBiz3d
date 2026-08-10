class_name GasStationMenu
extends CanvasLayer

const REPAIR_PRICE_PER_DAMAGE := 40
const PRIMARY_PAINT_PRICE := 800
const SECONDARY_PAINT_PRICE := 600
const WINDOW_TINT_PRICE := 400
const UPGRADE_PRICES := [0, 4000, 8000, 16000]
const UPGRADE_NAMES := ["STOCK", "STREET TUNE", "SPORT TUNE", "RACE TUNE"]
const TINT_NAMES := ["CLEAR", "LIGHT", "MEDIUM", "DARK", "LIMO"]
const TINT_VALUES := [0.0, 0.25, 0.5, 0.75, 0.9]
const ACCENT := Color(0.2, 0.62, 0.96)
const TEAL := Color(0.24, 0.82, 0.7)
const GREEN := Color(0.36, 0.78, 0.24)
const AMBER := Color(0.96, 0.68, 0.18)
const RED := Color(0.86, 0.22, 0.2)
const MUTED := Color(0.62, 0.68, 0.76)
const PANEL_BG := Color(0.02, 0.03, 0.042, 0.98)
const SECTION_BG := Color(0.032, 0.047, 0.064, 0.97)
const BORDER := Color(0.11, 0.19, 0.26, 0.96)
const BusinessPanelScript := preload("res://Scripts/UI/business_management_panel.gd")

@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var inventory_component_path := NodePath("../Components/InventoryComponent")
@export var consumable_component_path := NodePath("../Components/ConsumableComponent")
@export var garage_component_path := NodePath("../Components/VehicleGarageComponent")
@export var vehicle_component_path := NodePath("../Components/VehicleComponent")
@export var property_component_path := NodePath("../Components/PropertyComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var inventory := get_node(inventory_component_path) as PlayerInventoryComponent
@onready var consumables := get_node(consumable_component_path) as PlayerConsumableComponent
@onready var garage := get_node(garage_component_path) as PlayerVehicleGarageComponent
@onready var vehicle_component := get_node(vehicle_component_path) as PlayerVehicleComponent
@onready var properties := get_node(property_component_path) as PlayerPropertyComponent
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController

var _root: Control
var _title: Label
var _subtitle: Label
var _balance_label: Label
var _store_tabs: HBoxContainer
var _store_page: VBoxContainer
var _business_panel: VBoxContainer
var _auto_page: VBoxContainer
var _feedback: Label
var _repair_label: Label
var _repair_button: Button
var _primary_picker: OptionButton
var _secondary_picker: OptionButton
var _tint_picker: OptionButton
var _upgrade_label: Label
var _upgrade_button: Button
var _damage_bar: ProgressBar
var _damage_value: Label
var _vehicle_name_label: Label
var _ownership_label: Label
var _performance_bar: ProgressBar
var _preview_pivot: Node3D
var _preview_model: Node3D
var _preview_camera: Camera3D
var _auto_nav_buttons: Dictionary = {}
var _auto_panels: Dictionary = {}
var _appearance_buttons: Array[Button] = []
var _auto_service := &"repair"
var _vehicle: BaseVehicle
var _station: GasStationController
var _baseline: Dictionary
var _mode := &""


func _ready() -> void:
	_build_ui()
	_root.visible = false
	wallet.money_changed.connect(_on_money_changed)
	inventory.consumable_quantity_changed.connect(_on_supply_changed)


func _process(delta: float) -> void:
	if _root.visible and _mode == &"auto" and _preview_pivot != null:
		_preview_pivot.rotation.y += delta * 0.28


func _input(event: InputEvent) -> void:
	if (
		_root.visible
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_ESCAPE
	):
		close()
		get_viewport().set_input_as_handled()


func open_store() -> void:
	if not menu_controller.request_open(&"gas_station_store"):
		return
	_mode = &"store"
	_feedback.text = ""
	_vehicle = null
	_station = null
	_title.text = "86 GAS & CONVENIENCE"
	_subtitle.text = "SUPPLIES / BUSINESS"
	_store_tabs.visible = true
	_set_store_tab(false)
	_auto_page.visible = false
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_store()


func open_auto_shop(vehicle: BaseVehicle, station: GasStationController) -> void:
	if _root.visible or vehicle == null or station == null:
		return
	_mode = &"auto"
	_feedback.text = ""
	_vehicle = vehicle
	_station = station
	_baseline = vehicle.export_condition_state()
	vehicle.set_service_locked(true)
	_title.text = "86 AUTO SERVICE"
	_subtitle.text = "REPAIR / CUSTOMIZE / PERFORMANCE"
	_store_tabs.visible = false
	_store_page.visible = false
	_business_panel.visible = false
	_auto_page.visible = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_auto_service(&"repair")
	_refresh_auto()


func close() -> void:
	if not _root.visible:
		return
	if _mode == &"store":
		if not menu_controller.close(&"gas_station_store"):
			return
	elif _mode == &"auto" and is_instance_valid(_vehicle):
		_vehicle.import_condition_state(_baseline)
		_vehicle.set_service_locked(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_root.visible = false
	_vehicle = null
	_station = null
	_mode = &""


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.008, 0.013, 0.94)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-670, -390)
	panel.size = Vector2(1340, 780)
	panel.add_theme_stylebox_override(
		"panel", _panel_style(PANEL_BG, Color(0.1, 0.24, 0.36), 2, 12)
	)
	_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 64
	header.add_theme_constant_override("separation", 14)
	page.add_child(header)
	var title_accent := ColorRect.new()
	title_accent.custom_minimum_size = Vector2(5, 40)
	title_accent.color = ACCENT
	title_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_accent)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	title_stack.add_child(_title)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 12)
	_subtitle.add_theme_color_override("font_color", ACCENT)
	title_stack.add_child(_subtitle)
	_balance_label = Label.new()
	_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_balance_label.add_theme_font_size_override("font_size", 20)
	_balance_label.add_theme_color_override("font_color", GREEN)
	header.add_child(_balance_label)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(60, 50)
	_style_button(close_button, RED)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_store_tabs = HBoxContainer.new()
	_store_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_store_tabs)
	for entry in [["SHOP", false, "ShopTab"], ["BUSINESS", true, "BusinessTab"]]:
		var tab := Button.new()
		tab.text = entry[0]
		tab.name = entry[2]
		tab.custom_minimum_size = Vector2(180, 40)
		_style_button(tab, ACCENT)
		tab.pressed.connect(_set_store_tab.bind(entry[1]))
		_store_tabs.add_child(tab)
	_store_page = VBoxContainer.new()
	_store_page.name = "ShopPage"
	_store_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_store_page.add_theme_constant_override("separation", 8)
	page.add_child(_store_page)
	_business_panel = BusinessPanelScript.new()
	_business_panel.name = "BusinessManagementPanel"
	page.add_child(_business_panel)
	_business_panel.setup(PropertyCatalog.GAS_STATION_ID, properties, wallet)
	_auto_page = VBoxContainer.new()
	_auto_page.name = "AutoServicePage"
	_auto_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_auto_page.add_theme_constant_override("separation", 12)
	page.add_child(_auto_page)
	_build_auto_page()
	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 17)
	_feedback.add_theme_color_override("font_color", AMBER)
	page.add_child(_feedback)


func _build_auto_page() -> void:
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	_auto_page.add_child(columns)

	var navigation := _section("SERVICE MENU")
	navigation.custom_minimum_size.x = 230
	columns.add_child(navigation)
	var nav_box := navigation.get_child(0) as VBoxContainer
	_auto_nav_button(nav_box, "REPAIR", "RESTORE CONDITION", &"repair")
	_auto_nav_button(nav_box, "APPEARANCE", "PAINT & WINDOW TINT", &"appearance")
	_auto_nav_button(nav_box, "PERFORMANCE", "ENGINE UPGRADES", &"performance")
	var nav_spacer := Control.new()
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_box.add_child(nav_spacer)
	var cash_note := Label.new()
	cash_note.text = "ALL SERVICES USE\nCLEAN CASH"
	cash_note.add_theme_font_size_override("font_size", 12)
	cash_note.add_theme_color_override("font_color", MUTED)
	nav_box.add_child(cash_note)

	var preview := _section("3D PREVIEW")
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(preview)
	var preview_box := preview.get_child(0) as VBoxContainer
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(540, 500)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	preview_box.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 560)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	_preview_pivot = Node3D.new()
	viewport.add_child(_preview_pivot)
	_add_preview_stage(_preview_pivot)
	_preview_camera = Camera3D.new()
	viewport.add_child(_preview_camera)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, -42, 0)
	key_light.light_energy = 2.25
	key_light.light_color = Color(0.78, 0.89, 1.0)
	viewport.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(18, 135, 0)
	fill_light.light_energy = 1.25
	fill_light.light_color = Color(1.0, 0.7, 0.42)
	viewport.add_child(fill_light)
	var preview_hint := Label.new()
	preview_hint.text = "DRAG-FREE ROTATING PREVIEW  /  CHANGES PREVIEW BEFORE PURCHASE"
	preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_hint.add_theme_font_size_override("font_size", 11)
	preview_hint.add_theme_color_override("font_color", MUTED)
	preview_box.add_child(preview_hint)

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size.x = 350
	right_column.add_theme_constant_override("separation", 10)
	columns.add_child(right_column)
	var status := _section("VEHICLE STATUS")
	right_column.add_child(status)
	var status_box := status.get_child(0) as VBoxContainer
	_vehicle_name_label = Label.new()
	_vehicle_name_label.add_theme_font_size_override("font_size", 20)
	_vehicle_name_label.add_theme_color_override("font_color", ACCENT)
	status_box.add_child(_vehicle_name_label)
	_ownership_label = Label.new()
	_ownership_label.add_theme_font_size_override("font_size", 12)
	_ownership_label.add_theme_color_override("font_color", MUTED)
	status_box.add_child(_ownership_label)
	var damage_header := HBoxContainer.new()
	status_box.add_child(damage_header)
	var damage_caption := Label.new()
	damage_caption.text = "CURRENT DAMAGE"
	damage_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	damage_caption.add_theme_font_size_override("font_size", 12)
	damage_caption.add_theme_color_override("font_color", Color(0.8, 0.84, 0.88))
	damage_header.add_child(damage_caption)
	_damage_value = Label.new()
	_damage_value.add_theme_font_size_override("font_size", 12)
	_damage_value.add_theme_color_override("font_color", AMBER)
	damage_header.add_child(_damage_value)
	_damage_bar = ProgressBar.new()
	_damage_bar.custom_minimum_size.y = 10
	_damage_bar.show_percentage = false
	_damage_bar.add_theme_stylebox_override("background", _meter_background())
	_damage_bar.add_theme_stylebox_override("fill", _meter_fill(AMBER))
	status_box.add_child(_damage_bar)

	var repair_panel := _section("FULL REPAIR")
	repair_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(repair_panel)
	_auto_panels[&"repair"] = repair_panel
	var repair_box := repair_panel.get_child(0) as VBoxContainer
	_repair_label = Label.new()
	_repair_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_repair_label.add_theme_color_override("font_color", MUTED)
	repair_box.add_child(_repair_label)
	var repair_spacer := Control.new()
	repair_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	repair_box.add_child(repair_spacer)
	_repair_button = Button.new()
	_repair_button.custom_minimum_size.y = 50
	_style_button(_repair_button, GREEN)
	_repair_button.pressed.connect(_repair_vehicle)
	repair_box.add_child(_repair_button)

	var appearance_panel := _section("PAINT & WINDOW TINT")
	appearance_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(appearance_panel)
	_auto_panels[&"appearance"] = appearance_panel
	var appearance_box := appearance_panel.get_child(0) as VBoxContainer
	_primary_picker = _build_color_picker(
		"PRIMARY PAINT", _preview_primary, appearance_box
	)
	_secondary_picker = _build_color_picker(
		"SECONDARY PAINT", _preview_secondary, appearance_box
	)
	_tint_picker = OptionButton.new()
	for tint_name in TINT_NAMES:
		_tint_picker.add_item(tint_name)
	_tint_picker.item_selected.connect(_preview_tint)
	appearance_box.add_child(
		_service_row("WINDOW TINT", _tint_picker, "APPLY  $400", _buy_tint)
	)

	var performance_panel := _section("ENGINE PERFORMANCE")
	performance_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(performance_panel)
	_auto_panels[&"performance"] = performance_panel
	var performance_box := performance_panel.get_child(0) as VBoxContainer
	_upgrade_label = Label.new()
	_upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_label.add_theme_color_override("font_color", MUTED)
	performance_box.add_child(_upgrade_label)
	_performance_bar = ProgressBar.new()
	_performance_bar.max_value = 3.0
	_performance_bar.custom_minimum_size.y = 10
	_performance_bar.show_percentage = false
	_performance_bar.add_theme_stylebox_override("background", _meter_background())
	_performance_bar.add_theme_stylebox_override("fill", _meter_fill(ACCENT))
	performance_box.add_child(_performance_bar)
	var performance_spacer := Control.new()
	performance_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	performance_box.add_child(performance_spacer)
	_upgrade_button = Button.new()
	_upgrade_button.custom_minimum_size.y = 50
	_style_button(_upgrade_button, GREEN)
	_upgrade_button.pressed.connect(_buy_upgrade)
	performance_box.add_child(_upgrade_button)
	_set_auto_service(&"repair")


func _build_color_picker(
	label: String,
	preview: Callable,
	parent: VBoxContainer
) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 38
	for option in ClothingStoreMenu.COLOR_OPTIONS:
		picker.add_item(str(option.name).to_upper())
	picker.item_selected.connect(preview)
	var price := PRIMARY_PAINT_PRICE if label.begins_with("PRIMARY") else SECONDARY_PAINT_PRICE
	var action := _buy_primary if label.begins_with("PRIMARY") else _buy_secondary
	parent.add_child(_service_row(label, picker, "APPLY  $%d" % price, action))
	return picker


func _service_row(
	label_text: String,
	picker: Control,
	button_text: String,
	action: Callable
) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.8, 0.84, 0.88))
	stack.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(120, 38)
	_style_button(button, ACCENT)
	button.pressed.connect(action)
	row.add_child(button)
	_appearance_buttons.append(button)
	return stack


func _auto_nav_button(
	parent: VBoxContainer,
	title_text: String,
	description: String,
	service: StringName
) -> void:
	var button := Button.new()
	button.text = "%s\n%s" % [title_text, description]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 68
	_style_button(button, ACCENT)
	button.pressed.connect(_set_auto_service.bind(service))
	parent.add_child(button)
	_auto_nav_buttons[service] = button


func _set_auto_service(service: StringName) -> void:
	if not _auto_panels.has(service):
		return
	_auto_service = service
	for key in _auto_panels:
		var panel := _auto_panels[key] as Control
		panel.visible = key == service
	for key in _auto_nav_buttons:
		var button := _auto_nav_buttons[key] as Button
		_style_button(button, ACCENT if key == service else Color(0.25, 0.31, 0.38))
	if _root != null and _root.visible and _mode == &"auto":
		_feedback.text = ""
		if (
			service != &"repair"
			and is_instance_valid(_vehicle)
			and not garage.owns_vehicle(_vehicle)
		):
			_feedback.text = "CUSTOMIZATION REQUIRES AN OWNED VEHICLE"


func _refresh_auto_preview() -> void:
	if _preview_pivot == null or not is_instance_valid(_vehicle):
		return
	if is_instance_valid(_preview_model):
		_preview_pivot.remove_child(_preview_model)
		_preview_model.queue_free()
	_preview_model = null
	if _vehicle.definition == null or _vehicle.definition.visual_scene == null:
		return
	_preview_model = _vehicle.definition.visual_scene.instantiate() as Node3D
	if _preview_model == null:
		return
	_preview_model.rotation_degrees = _vehicle.definition.visual_rotation_degrees
	_preview_model.position = _vehicle.definition.visual_offset
	_preview_pivot.add_child(_preview_model)
	VehicleConditionComponent.apply_appearance_to_visual(
		_preview_model,
		_vehicle.definition,
		_vehicle.export_condition_state()
	)
	var target := Vector3(0.0, _vehicle.definition.collision_offset.y, 0.0)
	var distance := maxf(_vehicle.definition.collision_size.z * 1.45, 6.0)
	_preview_camera.look_at_from_position(
		Vector3(0.0, target.y + 1.05, distance),
		target
	)
	_preview_camera.fov = 38.0


func _add_preview_stage(pivot: Node3D) -> void:
	var stage := MeshInstance3D.new()
	var stage_mesh := CylinderMesh.new()
	stage_mesh.top_radius = 3.7
	stage_mesh.bottom_radius = 3.8
	stage_mesh.height = 0.12
	stage_mesh.radial_segments = 64
	stage.mesh = stage_mesh
	stage.position.y = -0.12
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.035, 0.045, 0.055)
	material.metallic = 0.72
	material.roughness = 0.3
	stage.material_override = material
	pivot.add_child(stage)


func _set_store_tab(show_business: bool) -> void:
	_store_page.visible = not show_business
	_business_panel.visible = show_business
	if show_business:
		_business_panel.refresh()
	else:
		_refresh_store()


func _refresh_store() -> void:
	if _store_page == null:
		return
	_balance_label.text = "CLEAN BANK  $%d" % wallet.clean_cash
	for child in _store_page.get_children():
		child.queue_free()
	_store_page.add_child(_heading("SUPPLIES - PURCHASES USE CLEAN CASH"))
	for item in ConsumableCatalog.get_all():
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 62
		var info := Label.new()
		info.text = "%s  |  %s\n%dG   OWNED: %d" % [
			item.display_name.to_upper(), item.description,
			item.weight_grams, inventory.get_consumable_quantity(item),
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var buy := Button.new()
		buy.text = "BUY  $%d" % item.price
		buy.custom_minimum_size = Vector2(145, 44)
		buy.disabled = not wallet.can_spend_clean(item.price)
		buy.pressed.connect(_buy_supply.bind(item))
		row.add_child(buy)
		_store_page.add_child(row)


func _buy_supply(item: ConsumableDefinition) -> void:
	if not inventory.add_consumable(item):
		_feedback.text = "NOT ENOUGH CARRY CAPACITY"
		return
	if not wallet.spend_clean(item.price, true, "Store Purchase", item.display_name):
		inventory.remove_consumable(item)
		_feedback.text = "NOT ENOUGH CLEAN CASH"
		return
	_feedback.text = "PURCHASED %s" % item.display_name.to_upper()
	_refresh_store()


func _refresh_auto() -> void:
	if not is_instance_valid(_vehicle):
		close()
		return
	_balance_label.text = "CLEAN BANK  $%d" % wallet.clean_cash
	var condition := _vehicle.condition_component
	var repair_cost := _price(ceili(condition.damage * REPAIR_PRICE_PER_DAMAGE))
	_vehicle_name_label.text = (
		_vehicle.definition.display_name.to_upper()
		if _vehicle.definition != null
		else "VEHICLE"
	)
	var owned := garage.owns_vehicle(_vehicle)
	_ownership_label.text = (
		"OWNED VEHICLE  /  FULL SERVICE ACCESS"
		if owned
		else "UNOWNED VEHICLE  /  REPAIR ONLY"
	)
	_ownership_label.add_theme_color_override("font_color", TEAL if owned else AMBER)
	_damage_value.text = "%d / 100" % roundi(condition.damage)
	_damage_value.add_theme_color_override(
		"font_color",
		GREEN if condition.damage <= 0.0 else RED if condition.damage >= 50.0 else AMBER
	)
	_damage_bar.value = condition.damage
	var damage_fill := _damage_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if damage_fill != null:
		damage_fill.bg_color = RED if condition.damage >= 50.0 else AMBER
	_repair_label.text = (
		"Restore the vehicle to 100%% condition.\n\n"
		+ "CURRENT DAMAGE   %d / 100\nSERVICE TOTAL   $%d CLEAN"
	) % [roundi(condition.damage), repair_cost]
	_repair_button.text = (
		"VEHICLE AT 100% CONDITION"
		if condition.damage <= 0.0
		else "FULL REPAIR  $%d CLEAN" % repair_cost
	)
	_repair_button.disabled = condition.damage <= 0.0 or not wallet.can_spend_clean(repair_cost)
	_primary_picker.disabled = not owned
	_secondary_picker.disabled = not owned
	_tint_picker.disabled = not owned
	var appearance_costs := [
		_price(PRIMARY_PAINT_PRICE),
		_price(SECONDARY_PAINT_PRICE),
		_price(WINDOW_TINT_PRICE),
	]
	for index in _appearance_buttons.size():
		var appearance_cost := int(appearance_costs[index])
		_appearance_buttons[index].text = "APPLY  $%d" % appearance_cost
		_appearance_buttons[index].disabled = (
			not owned or not wallet.can_spend_clean(appearance_cost)
		)
	var tier := condition.performance_tier
	_performance_bar.value = tier
	_upgrade_label.text = (
		"CURRENT SETUP\n%s  /  TIER %d OF 3\n\n"
		+ "Engine upgrades improve acceleration and top speed. "
		+ "Each tier includes the benefits of the previous tune."
	) % [UPGRADE_NAMES[tier], tier]
	if tier >= 3:
		_upgrade_button.text = "MAXIMUM TUNE INSTALLED"
		_upgrade_button.disabled = true
	else:
		var cost := _price(UPGRADE_PRICES[tier + 1])
		_upgrade_button.text = "INSTALL %s  $%d CLEAN" % [UPGRADE_NAMES[tier + 1], cost]
		_upgrade_button.disabled = not owned or not wallet.can_spend_clean(cost)
	if not owned and _auto_service != &"repair" and _feedback.text.is_empty():
		_feedback.text = "PAINT, TINT, AND TUNING REQUIRE AN OWNED VEHICLE"
	_refresh_auto_preview()


func _repair_vehicle() -> void:
	var cost := _price(ceili(_vehicle.condition_component.damage * REPAIR_PRICE_PER_DAMAGE))
	if cost > 0 and wallet.spend_clean(cost, true, "Vehicle Repair", "Full repair service"):
		_vehicle.import_condition_state(_baseline)
		_vehicle.condition_component.repair_full()
		_commit_baseline("VEHICLE FULLY REPAIRED")


func _preview_primary(index: int) -> void:
	if garage.owns_vehicle(_vehicle):
		_vehicle.import_condition_state(_baseline)
		_vehicle.condition_component.set_primary_color(ClothingStoreMenu.COLOR_OPTIONS[index].color)
		_refresh_auto_preview()


func _preview_secondary(index: int) -> void:
	if garage.owns_vehicle(_vehicle):
		_vehicle.import_condition_state(_baseline)
		_vehicle.condition_component.set_secondary_color(ClothingStoreMenu.COLOR_OPTIONS[index].color)
		_refresh_auto_preview()


func _preview_tint(index: int) -> void:
	if garage.owns_vehicle(_vehicle):
		_vehicle.import_condition_state(_baseline)
		_vehicle.condition_component.set_window_tint(TINT_VALUES[index])
		_refresh_auto_preview()


func _buy_primary() -> void:
	_buy_visual(_price(PRIMARY_PAINT_PRICE), "primary_color", "PRIMARY PAINT APPLIED")


func _buy_secondary() -> void:
	_buy_visual(_price(SECONDARY_PAINT_PRICE), "secondary_color", "SECONDARY PAINT APPLIED")


func _buy_tint() -> void:
	_buy_visual(_price(WINDOW_TINT_PRICE), "window_tint", "WINDOW TINT APPLIED")


func _buy_visual(cost: int, field: String, message: String) -> void:
	if not garage.owns_vehicle(_vehicle):
		return
	var preview := _vehicle.export_condition_state()
	if preview.get(field) == _baseline.get(field):
		_feedback.text = "SELECT A DIFFERENT OPTION FIRST"
		return
	if wallet.spend_clean(cost, true, "Vehicle Customization", message):
		_commit_baseline(message)


func _buy_upgrade() -> void:
	var tier := _vehicle.condition_component.performance_tier
	if tier >= 3 or not garage.owns_vehicle(_vehicle):
		return
	var cost := _price(UPGRADE_PRICES[tier + 1])
	if wallet.spend_clean(cost, true, "Vehicle Upgrade", UPGRADE_NAMES[tier + 1]):
		_vehicle.import_condition_state(_baseline)
		_vehicle.condition_component.set_performance_tier(tier + 1)
		_commit_baseline("%s INSTALLED" % UPGRADE_NAMES[tier + 1])


func _commit_baseline(message: String) -> void:
	_baseline = _vehicle.export_condition_state()
	_feedback.text = message
	_refresh_auto()


func _price(base_price: int) -> int:
	return _station.get_discounted_price(base_price) if _station != null else base_price


func _section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel", _panel_style(SECTION_BG, BORDER, 1, 8)
	)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.76, 0.84, 0.92))
	box.add_child(title)
	box.add_child(_divider())
	return panel


func _divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1
	divider.color = BORDER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _meter_background() -> StyleBoxFlat:
	return _panel_style(Color(0.055, 0.07, 0.085), BORDER, 1, 3, 0)


func _meter_fill(color: Color) -> StyleBoxFlat:
	return _panel_style(color, color, 0, 3, 0)


func _style_button(button: Button, color: Color) -> void:
	var normal := _panel_style(color.darkened(0.5), color, 1, 6)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.darkened(0.28)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.18)
	pressed.border_color = color.lightened(0.12)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.05, 0.06, 0.07, 0.92)
	disabled.border_color = Color(0.12, 0.14, 0.16, 0.85)
	button.add_theme_stylebox_override("disabled", disabled)


func _panel_style(
	background: Color,
	border: Color,
	width: int,
	radius: int,
	padding: int = 13
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_top = maxi(padding - 2, 0)
	style.content_margin_right = padding
	style.content_margin_bottom = maxi(padding - 2, 0)
	return style


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.28, 0.82, 0.68))
	return label


func _on_money_changed(_dirty: int, _clean: int) -> void:
	if _mode == &"store" and _store_page.visible:
		_refresh_store()
	elif _mode == &"auto":
		_refresh_auto()


func _on_supply_changed(_item: ConsumableDefinition, _quantity: int) -> void:
	if _mode == &"store" and _store_page.visible:
		_refresh_store()
