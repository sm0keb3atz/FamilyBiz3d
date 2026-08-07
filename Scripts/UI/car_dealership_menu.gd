class_name CarDealershipMenu
extends CanvasLayer

const ACCENT := Color(0.2, 0.58, 0.94)
const GREEN := Color(0.32, 0.75, 0.34)
const RED := Color(0.82, 0.25, 0.2)
const MUTED := Color(0.68, 0.7, 0.74)
const BusinessManagementPanelScript := preload(
	"res://Scripts/UI/business_management_panel.gd"
)

@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var garage_component_path := NodePath(
	"../Components/VehicleGarageComponent"
)
@export var service_path := NodePath(
	"../Components/CarDealershipService"
)
@export var menu_controller_path := NodePath(
	"../Components/MenuController"
)
@export var property_component_path := NodePath(
	"../Components/PropertyComponent"
)
@export var hud_path := NodePath("../PlayerHUD")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var garage := (
	get_node(garage_component_path) as PlayerVehicleGarageComponent
)
@onready var service := get_node(service_path) as CarDealershipService
@onready var menu_controller := (
	get_node(menu_controller_path) as PlayerMenuController
)
@onready var properties := (
	get_node(property_component_path) as PlayerPropertyComponent
)
@onready var hud := get_node_or_null(hud_path) as CanvasLayer

var _root: Control
var _balance_label: Label
var _buy_tab: Button
var _sell_tab: Button
var _business_tab: Button
var _buy_content: HBoxContainer
var _sell_content: VBoxContainer
var _business_panel: VBoxContainer
var _vehicle_list: VBoxContainer
var _sell_list: VBoxContainer
var _preview_pivot: Node3D
var _preview_model: Node3D
var _preview_camera: Camera3D
var _name_label: Label
var _description_label: Label
var _price_label: Label
var _stats_label: Label
var _owned_label: Label
var _delivery_label: Label
var _purchase_button: Button
var _feedback_label: Label
var _selected: VehicleDefinition
var _dealership: CarDealershipController
var _pending_sale_id: StringName
var _active_tab := &"buy"
var _is_open := false
var _hud_was_visible := true


func _ready() -> void:
	_build_ui()
	_root.visible = false
	var catalog := VehicleCatalog.get_all()
	if not catalog.is_empty():
		_selected = catalog[0]
	service.transaction_finished.connect(_on_transaction_finished)
	wallet.money_changed.connect(_on_money_changed)
	garage.ownership_changed.connect(_on_garage_changed)


func _process(delta: float) -> void:
	if _is_open and _active_tab == &"buy" and _preview_pivot != null:
		_preview_pivot.rotation.y += delta * 0.3


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


func open_store(dealership: CarDealershipController) -> void:
	if dealership == null or not menu_controller.request_open(&"car_dealership"):
		return
	_dealership = dealership
	_is_open = true
	_pending_sale_id = &""
	_feedback_label.text = ""
	_root.visible = true
	if hud != null:
		_hud_was_visible = hud.visible
		hud.visible = false
	_set_tab(&"buy")
	_refresh()
	_buy_tab.grab_focus()


func close() -> void:
	if not _is_open or not menu_controller.close(&"car_dealership"):
		return
	_is_open = false
	_dealership = null
	_pending_sale_id = &""
	_root.visible = false
	if hud != null:
		hud.visible = _hud_was_visible


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MenuRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.004, 0.008, 0.014, 0.93)
	_root.add_child(dimmer)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		outer.add_theme_constant_override(side, 22)
	_root.add_child(outer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.025, 0.035, 0.05), Color(0.12, 0.3, 0.5), 3, 10)
	)
	outer.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	panel.add_child(page)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 72
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)
	var title := Label.new()
	title.text = "  DOWNTOWN AUTO"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	header.add_child(title)
	_balance_label = Label.new()
	_balance_label.add_theme_font_size_override("font_size", 23)
	_balance_label.add_theme_color_override("font_color", GREEN)
	_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_balance_label)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(70, 52)
	_style_button(close_button, RED)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	page.add_child(tabs)
	_buy_tab = _tab_button(tabs, "BUY", &"buy")
	_sell_tab = _tab_button(tabs, "SELL", &"sell")
	_business_tab = _tab_button(tabs, "BUSINESS", &"business")
	_build_buy_content(page)
	_build_sell_content(page)
	_business_panel = BusinessManagementPanelScript.new()
	page.add_child(_business_panel)
	_business_panel.setup(
		PropertyCatalog.DOWNTOWN_CAR_DEALERSHIP_ID,
		properties,
		wallet
	)
	_feedback_label = Label.new()
	_feedback_label.custom_minimum_size.y = 32
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 17)
	page.add_child(_feedback_label)


func _build_buy_content(page: VBoxContainer) -> void:
	_buy_content = HBoxContainer.new()
	_buy_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_buy_content.add_theme_constant_override("separation", 14)
	page.add_child(_buy_content)
	var left := _section("VEHICLES")
	left.custom_minimum_size.x = 285
	_buy_content.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(left.get_child(0) as VBoxContainer).add_child(scroll)
	_vehicle_list = VBoxContainer.new()
	_vehicle_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vehicle_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_vehicle_list)
	var middle := _section("3D PREVIEW")
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_content.add_child(middle)
	var middle_box := middle.get_child(0) as VBoxContainer
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(430, 390)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	middle_box.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(700, 500)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	_preview_pivot = Node3D.new()
	viewport.add_child(_preview_pivot)
	_preview_camera = Camera3D.new()
	viewport.add_child(_preview_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 2.2
	key.light_color = Color(0.82, 0.9, 1.0)
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(15, 140, 0)
	fill.light_energy = 1.3
	fill.light_color = Color(1.0, 0.72, 0.46)
	viewport.add_child(fill)
	var hint := Label.new()
	hint.text = "VEHICLE DELIVERY REQUIRES AN EMPTY PARKING SPACE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", MUTED)
	middle_box.add_child(hint)
	var right := _section("DETAILS")
	right.custom_minimum_size.x = 365
	_buy_content.add_child(right)
	var box := right.get_child(0) as VBoxContainer
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 29)
	_name_label.add_theme_color_override("font_color", ACCENT)
	box.add_child(_name_label)
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_color_override("font_color", MUTED)
	box.add_child(_description_label)
	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", 25)
	_price_label.add_theme_color_override("font_color", GREEN)
	box.add_child(_price_label)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_stats_label)
	_owned_label = Label.new()
	_owned_label.add_theme_color_override("font_color", MUTED)
	box.add_child(_owned_label)
	_delivery_label = Label.new()
	_delivery_label.add_theme_color_override("font_color", ACCENT)
	box.add_child(_delivery_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_purchase_button = Button.new()
	_purchase_button.custom_minimum_size.y = 54
	_style_button(_purchase_button, GREEN)
	_purchase_button.pressed.connect(_purchase_selected)
	box.add_child(_purchase_button)


func _build_sell_content(page: VBoxContainer) -> void:
	_sell_content = VBoxContainer.new()
	_sell_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sell_content.add_theme_constant_override("separation", 12)
	page.add_child(_sell_content)
	var heading := Label.new()
	heading.text = "PARK AN OWNED VEHICLE IN ANY MARKED SPACE, EXIT IT, THEN CONFIRM THE OFFER."
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", MUTED)
	_sell_content.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sell_content.add_child(scroll)
	_sell_list = VBoxContainer.new()
	_sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_sell_list)


func _refresh() -> void:
	if not _is_open:
		return
	_balance_label.text = "CLEAN BANK  $%d   " % wallet.clean_cash
	if _active_tab == &"buy":
		_refresh_buy()
	elif _active_tab == &"sell":
		_refresh_sell()
	else:
		_business_panel.refresh()


func _refresh_buy() -> void:
	for child in _vehicle_list.get_children():
		child.queue_free()
	for definition in VehicleCatalog.get_all():
		var button := Button.new()
		button.custom_minimum_size.y = 64
		button.text = "%s\n$%d   |   OWNED %d" % [
			definition.display_name,
			definition.purchase_price,
			garage.get_owned_count(definition.vehicle_id),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(button, ACCENT if definition == _selected else Color(0.3, 0.34, 0.4))
		button.pressed.connect(_select_vehicle.bind(definition))
		_vehicle_list.add_child(button)
	if _selected == null:
		return
	_name_label.text = _selected.display_name
	_description_label.text = _selected.description
	_price_label.text = "$%d CLEAN CASH" % _selected.purchase_price
	_stats_label.text = (
		"TOP SPEED       %d MPH\nACCELERATION    %s\nHANDLING        %s\nBRAKING         %s"
		% [
			roundi(_selected.max_forward_speed * 2.23694),
			_rating_text(_selected.acceleration_rating),
			_rating_text(_selected.handling_rating),
			_rating_text(_selected.braking_rating),
		]
	)
	_owned_label.text = "OWNED: %d" % garage.get_owned_count(_selected.vehicle_id)
	var bay_available := _dealership != null and _dealership.has_free_delivery_bay()
	_delivery_label.text = "DELIVERY SPACE AVAILABLE" if bay_available else "PARKING LOT FULL"
	_purchase_button.text = "BUY  $%d" % _selected.purchase_price
	_purchase_button.disabled = (
		not bay_available
		or not wallet.can_spend_clean(_selected.purchase_price)
	)
	_refresh_preview()


func _refresh_sell() -> void:
	for child in _sell_list.get_children():
		child.queue_free()
	if _dealership == null:
		return
	var parked := _dealership.get_parked_owned_vehicles(garage)
	if parked.is_empty():
		var empty := Label.new()
		empty.text = "No owned vehicles are parked in a sale space."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 22)
		empty.add_theme_color_override("font_color", MUTED)
		_sell_list.add_child(empty)
		return
	for vehicle in parked:
		var definition := vehicle.definition
		if definition == null:
			continue
		var instance_id := garage.get_owned_instance_id(vehicle)
		var panel := _section(definition.display_name)
		_sell_list.add_child(panel)
		var box := panel.get_child(0) as VBoxContainer
		var summary := Label.new()
		summary.text = "OWNED VEHICLE  %s    |    OFFER  $%d CLEAN CASH" % [
			String(instance_id).to_upper(),
			VehicleCatalog.get_resale_value(definition.vehicle_id),
		]
		summary.add_theme_color_override("font_color", MUTED)
		box.add_child(summary)
		var action := Button.new()
		var confirming := _pending_sale_id == instance_id
		action.text = "SELL VEHICLE"
		if confirming:
			action.text = "CONFIRM SALE  $%d" % (
				VehicleCatalog.get_resale_value(definition.vehicle_id)
			)
		action.custom_minimum_size.y = 46
		_style_button(action, RED if confirming else ACCENT)
		action.pressed.connect(_request_sale.bind(vehicle))
		box.add_child(action)


func _refresh_preview() -> void:
	if is_instance_valid(_preview_model):
		_preview_pivot.remove_child(_preview_model)
		_preview_model.queue_free()
	_preview_model = null
	_preview_pivot.rotation = Vector3.ZERO
	if _selected == null or _selected.visual_scene == null:
		return
	_preview_model = _selected.visual_scene.instantiate() as Node3D
	if _preview_model == null:
		return
	_preview_model.rotation_degrees = _selected.visual_rotation_degrees
	_preview_model.position = _selected.visual_offset
	_preview_pivot.add_child(_preview_model)
	var distance := maxf(_selected.collision_size.z * 1.35, 5.5)
	var target := Vector3(0.0, _selected.collision_offset.y, 0.0)
	_preview_camera.look_at_from_position(
		Vector3(0.0, target.y + 1.1, distance),
		target
	)
	_preview_camera.fov = 38.0


func _set_tab(tab: StringName) -> void:
	_active_tab = tab
	_pending_sale_id = &""
	_buy_content.visible = tab == &"buy"
	_sell_content.visible = tab == &"sell"
	_business_panel.visible = tab == &"business"
	for button in [_buy_tab, _sell_tab, _business_tab]:
		_style_button(button, ACCENT)
	var active := _buy_tab if tab == &"buy" else _sell_tab if tab == &"sell" else _business_tab
	active.add_theme_stylebox_override(
		"normal",
		_panel_style(ACCENT.darkened(0.5), ACCENT, 2, 5)
	)
	_refresh()


func _select_vehicle(definition: VehicleDefinition) -> void:
	_selected = definition
	_feedback_label.text = ""
	_refresh_buy()


func _purchase_selected() -> void:
	if _selected == null or _dealership == null:
		return
	service.purchase_vehicle(_selected, _dealership)


func _request_sale(vehicle: BaseVehicle) -> void:
	var instance_id := garage.get_owned_instance_id(vehicle)
	if instance_id.is_empty():
		return
	if _pending_sale_id != instance_id:
		_pending_sale_id = instance_id
		_feedback_label.text = "Press confirm to permanently sell this vehicle."
		_refresh_sell()
		return
	_pending_sale_id = &""
	service.sell_vehicle(vehicle, _dealership)


func _on_transaction_finished(message: String, success: bool) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override("font_color", GREEN if success else RED)
	_refresh()


func _on_money_changed(_dirty: int, _clean: int) -> void:
	_refresh()


func _on_garage_changed() -> void:
	_refresh()


func _tab_button(parent: HBoxContainer, text: String, tab: StringName) -> Button:
	var button := Button.new()
	button.name = "%sTab" % text.capitalize()
	button.text = text
	button.custom_minimum_size = Vector2(190, 42)
	button.pressed.connect(_set_tab.bind(tab))
	parent.add_child(button)
	return button


func _section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.04, 0.055, 0.075), Color(0.12, 0.18, 0.25), 1, 6)
	)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	box.add_child(title)
	return panel


func _rating_text(value: int) -> String:
	var result := ""
	for index in 5:
		result += "[X]" if index < value else "[ ]"
	return result


func _style_button(button: Button, color: Color) -> void:
	var normal := _panel_style(color.darkened(0.48), color, 1, 5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.darkened(0.28)
	button.add_theme_stylebox_override("hover", hover)


func _panel_style(
	background: Color,
	border: Color,
	width: int,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style
