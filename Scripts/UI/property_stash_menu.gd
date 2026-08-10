class_name PropertyStashMenu
extends CanvasLayer

enum AccessMode {
	LOCAL,
	REMOTE,
}

const ACCENT := Color("f06a22")
const CYAN := Color("39c2d7")
const GREEN := Color("50d06f")
const RED := Color("ed5b62")
const TEXT := Color("edf0f4")
const MUTED := Color("8c96a5")
const CASH_PRESETS := [100, 1000, 10000, 2147483647]
const PRODUCT_PRESETS := [1, 10, 100, 2147483647]

@export var property_component_path := NodePath("../Components/PropertyComponent")
@export var inventory_component_path := NodePath("../Components/InventoryComponent")
@export var weapon_component_path := NodePath("../Components/WeaponComponent")
@export var stats_component_path := NodePath("../Components/StatsComponent")
@export var garage_component_path := NodePath("../Components/VehicleGarageComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var properties := get_node(property_component_path) as PlayerPropertyComponent
@onready var inventory := get_node(inventory_component_path) as PlayerInventoryComponent
@onready var weapons := get_node(weapon_component_path) as PlayerWeaponComponent
@onready var stats := get_node(stats_component_path) as PlayerStatsComponent
@onready var garage := get_node(garage_component_path) as PlayerVehicleGarageComponent
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController

var _root: Control
var _title: Label
var _subtitle: Label
var _tab_bar: HBoxContainer
var _content: MarginContainer
var _feedback: Label
var _tab_buttons: Dictionary[StringName, Button] = {}
var _preview_pivots: Array[Node3D] = []

var _property_id: StringName = &""
var _active_tab: StringName = &"stash"
var _access_mode := AccessMode.LOCAL
var _building: PropertyBuilding
var _garage_controller: PropertyGarageController
var _is_open := false
var _category := &"all"
var _selected_key := ""
var _selected_from_inventory := true
var _selected_amount_index := 0
var _territory_dealers: TerritoryDealerService


func _ready() -> void:
	_build_shell()
	_root.visible = false
	properties.stash_changed.connect(_on_property_data_changed)
	properties.brick_station_changed.connect(_on_property_data_changed)
	properties.runner_changed.connect(_on_property_data_changed)
	properties.ownership_changed.connect(_on_ownership_changed)
	properties.wallet.money_changed.connect(_on_money_changed)
	inventory.quantity_changed.connect(_on_inventory_changed)
	weapons.weapon_changed.connect(_on_weapon_changed)
	garage.storage_changed.connect(_on_vehicle_storage_changed)
	garage.ownership_changed.connect(_on_garage_changed)
	call_deferred("_resolve_territory_dealers")


func _process(delta: float) -> void:
	if not _is_open or _active_tab != &"garage":
		return
	for pivot in _preview_pivots:
		if is_instance_valid(pivot):
			pivot.rotate_y(delta * 0.45)


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


func open_stash(property_id: StringName) -> void:
	var building := _find_property_building(property_id)
	if building != null:
		open_local(building, &"stash")
	else:
		open_remote(property_id, &"stash")


func open_local(
	building: PropertyBuilding,
	initial_tab: StringName = &"stash"
) -> void:
	if building == null or not building.is_owned():
		return
	_building = building
	_property_id = building.property_id
	_garage_controller = building.get_node_or_null(
		"Garage"
	) as PropertyGarageController
	_access_mode = AccessMode.LOCAL
	_open(initial_tab, false)


func open_remote(
	property_id: StringName,
	initial_tab: StringName = &"operations",
	menu_already_claimed := false
) -> void:
	if not properties.owns(property_id):
		return
	_property_id = property_id
	_building = _find_property_building(property_id)
	_garage_controller = (
		_building.get_node_or_null("Garage") as PropertyGarageController
		if _building != null else null
	)
	_access_mode = AccessMode.REMOTE
	_open(initial_tab, menu_already_claimed)


func close() -> void:
	if not _is_open or not menu_controller.close(&"property_hub"):
		return
	_is_open = false
	_root.visible = false
	_preview_pivots.clear()


func _open(initial_tab: StringName, menu_already_claimed: bool) -> void:
	if (
		not menu_already_claimed
		and not menu_controller.request_open(&"property_hub")
	):
		return
	if menu_already_claimed and menu_controller.active_menu != &"property_hub":
		return
	_is_open = true
	_active_tab = initial_tab
	_category = &"all"
	_selected_key = ""
	_selected_from_inventory = true
	_selected_amount_index = 0
	_root.visible = true
	_set_feedback(
		"Remote access: storage is view-only until you visit this property."
		if _access_mode == AccessMode.REMOTE
		else "Select an item on either side to move it, or open Garage and Operations.",
		false
	)
	_refresh()


func _build_shell() -> void:
	_root = Control.new()
	_root.name = "MenuRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.008, 0.011, 0.017, 0.985)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dimmer)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		safe.add_theme_constant_override(side, 32)
	safe.add_theme_constant_override("margin_top", 24)
	safe.add_theme_constant_override("margin_bottom", 22)
	_root.add_child(safe)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	safe.add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 72
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title = _label("PROPERTY HUB", 31, TEXT)
	titles.add_child(_title)
	_subtitle = _label("PROPERTY MANAGEMENT", 13, ACCENT)
	titles.add_child(_subtitle)
	var close_button := Button.new()
	close_button.text = "CLOSE  X"
	close_button.custom_minimum_size = Vector2(118, 48)
	_style_button(close_button, MUTED)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 8)
	page.add_child(_tab_bar)
	for tab in [&"stash", &"garage", &"operations"]:
		var button := Button.new()
		button.name = "%sTab" % String(tab).capitalize()
		button.text = String(tab).to_upper()
		button.custom_minimum_size = Vector2(178, 44)
		button.pressed.connect(_set_tab.bind(tab))
		_tab_bar.add_child(button)
		_tab_buttons[tab] = button

	var content_panel := PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("0b1018"), Color("27303d"), 1, 10)
	)
	page.add_child(content_panel)
	_content = MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_content.add_theme_constant_override(side, 16)
	content_panel.add_child(_content)

	_feedback = _label("", 13, MUTED)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.custom_minimum_size.y = 24
	page.add_child(_feedback)


func _refresh() -> void:
	if not _is_open:
		return
	var definition := PropertyCatalog.get_by_id(_property_id)
	if definition == null:
		close()
		return
	_title.text = definition.display_name.to_upper()
	_subtitle.text = "%s  /  %s ACCESS  /  OWNED" % [
		definition.neighborhood.to_upper(),
		"LOCAL" if _access_mode == AccessMode.LOCAL else "REMOTE",
	]
	for tab in _tab_buttons:
		var button := _tab_buttons[tab]
		_style_button(button, ACCENT if tab == _active_tab else MUTED)
		button.set_pressed_no_signal(tab == _active_tab)
	_clear(_content)
	_preview_pivots.clear()
	match _active_tab:
		&"garage":
			_build_garage_tab(definition)
		&"operations":
			_build_operations_tab(definition)
		_:
			_build_stash_tab(definition)


func _set_tab(tab: StringName) -> void:
	_active_tab = tab
	_selected_key = ""
	_selected_amount_index = 0
	_refresh()


func _build_stash_tab(definition: PropertyDefinition) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_content.add_child(page)

	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 10)
	page.add_child(summary)
	summary.add_child(_stat_card(
		"STASH CAPACITY",
		"%d / %d" % [
			properties.get_stash_used_capacity(_property_id),
			definition.stash_capacity,
		],
		"Drugs and weapons",
		ACCENT
	))
	summary.add_child(_stat_card(
		"DIRTY CASH STORED",
		"$%s" % _money(properties.get_stashed_dirty_cash(_property_id)),
		"Cash uses no capacity",
		GREEN
	))
	summary.add_child(_stat_card(
		"CARRIED DIRTY CASH",
		"$%s" % _money(properties.wallet.dirty_cash),
		"Available to store",
		CYAN
	))

	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", 8)
	page.add_child(categories)
	for category in [&"all", &"drugs", &"money", &"weapons"]:
		var button := Button.new()
		button.text = String(category).to_upper()
		button.custom_minimum_size = Vector2(132, 36)
		button.pressed.connect(_set_category.bind(category))
		_style_button(button, ACCENT if category == _category else MUTED)
		categories.add_child(button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)
	body.add_child(_build_item_pane("YOUR INVENTORY", true))
	body.add_child(_build_transfer_dock())
	body.add_child(_build_item_pane("PROPERTY STASH", false))


func _build_item_pane(title_text: String, from_inventory: bool) -> Control:
	var panel := _section_panel(title_text)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	var box := panel.get_meta("content") as VBoxContainer
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "InventoryGrid" if from_inventory else "StashGrid"
	grid.columns = 3
	grid.custom_minimum_size.x = 650.0
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var entries := _get_item_entries(from_inventory)
	if entries.is_empty():
		var empty := _label(
			"No matching carried items." if from_inventory else "Nothing stored in this category.",
			15,
			MUTED
		)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(620, 64)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(empty)
	for entry in entries:
		grid.add_child(_item_card(entry, from_inventory))
	return panel


func _get_item_entries(from_inventory: bool) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var cash := (
		properties.wallet.dirty_cash
		if from_inventory
		else properties.get_stashed_dirty_cash(_property_id)
	)
	if cash > 0 and _category in [&"all", &"money"]:
		entries.append({
			"key": "cash", "kind": "cash", "title": "DIRTY CASH",
			"amount": cash,
		})
	if _category in [&"all", &"drugs"]:
		for product in EconomyCatalog.get_all_products():
			var amount := (
				inventory.get_quantity(product)
				if from_inventory
				else properties.get_stashed_product_quantity(_property_id, product)
			)
			if amount > 0:
				entries.append({
					"key": "product:%s" % product.product_id,
					"kind": "product",
					"title": product.display_name.to_upper(),
					"amount": amount,
					"definition": product,
				})
	if _category in [&"all", &"weapons"]:
		var stored_ids := properties.get_stashed_weapon_ids(_property_id)
		for definition in weapons.get_catalog_weapons():
			var available := (
				weapons.owns_weapon(definition.weapon_id)
				if from_inventory
				else definition.weapon_id in stored_ids
			)
			if available:
				entries.append({
					"key": "weapon:%s" % definition.weapon_id,
					"kind": "weapon",
					"title": definition.display_name.to_upper(),
					"amount": 1,
					"definition": definition,
				})
	return entries


func _item_card(entry: Dictionary, from_inventory: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(138, 142)
	button.toggle_mode = true
	button.button_pressed = (
		_selected_key == String(entry.get("key", ""))
		and _selected_from_inventory == from_inventory
	)
	button.add_theme_stylebox_override(
		"normal", _panel_style(Color("111721"), Color("28313d"), 1, 7)
	)
	button.add_theme_stylebox_override(
		"hover", _panel_style(Color("171923"), ACCENT, 1, 7)
	)
	button.add_theme_stylebox_override(
		"pressed", _panel_style(Color("25170f"), ACCENT, 2, 7)
	)
	button.pressed.connect(
		_select_item.bind(String(entry.get("key", "")), from_inventory)
	)
	button.gui_input.connect(_on_item_gui_input.bind(entry, from_inventory))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 9
	box.offset_top = 8
	box.offset_right = -9
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var title := _label(String(entry.get("title", "ITEM")), 13, TEXT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(center)
	if String(entry.get("kind", "")) == "product":
		var icon := TextureRect.new()
		icon.texture = (entry.get("definition") as ProductDefinition).icon
		icon.custom_minimum_size = Vector2(70, 70)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
	else:
		var symbol := _label(
			"$" if String(entry.get("kind", "")) == "cash" else "WEAPON",
			36 if String(entry.get("kind", "")) == "cash" else 14,
			GREEN if String(entry.get("kind", "")) == "cash" else ACCENT
		)
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(symbol)
	var amount := int(entry.get("amount", 0))
	var count := _label(
		"$%s" % _money(amount)
		if String(entry.get("kind", "")) == "cash"
		else "x%s" % _money(amount),
		19,
		TEXT
	)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(count)
	return button


func _build_transfer_dock() -> Control:
	var panel := _section_panel("TRANSFER")
	panel.custom_minimum_size.x = 250
	var box := panel.get_meta("content") as VBoxContainer
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var entry := _get_selected_entry()
	var local_access := _access_mode == AccessMode.LOCAL
	if entry.is_empty():
		var instruction := _label(
			"Select a card from either side.\nDouble-click for a quick maximum transfer.",
			14,
			MUTED
		)
		instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(instruction)
		return panel
	var direction := _label(
		"INVENTORY  ->  STASH"
		if _selected_from_inventory else "STASH  ->  INVENTORY",
		13,
		CYAN
	)
	direction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(direction)
	var selected_title := _label(String(entry.get("title", "ITEM")), 20, TEXT)
	selected_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(selected_title)
	var kind := String(entry.get("kind", ""))
	if kind != "weapon":
		var amounts := GridContainer.new()
		amounts.columns = 2
		amounts.add_theme_constant_override("h_separation", 6)
		amounts.add_theme_constant_override("v_separation", 6)
		box.add_child(amounts)
		var presets := CASH_PRESETS if kind == "cash" else PRODUCT_PRESETS
		for index in presets.size():
			var amount_button := Button.new()
			amount_button.text = (
				"MAX" if index == 3
				else "$%s" % _money(presets[index]) if kind == "cash"
				else str(presets[index])
			)
			amount_button.custom_minimum_size = Vector2(98, 34)
			amount_button.pressed.connect(_select_transfer_amount.bind(index))
			_style_button(
				amount_button,
				ACCENT if index == _selected_amount_index else MUTED
			)
			amounts.add_child(amount_button)
	var action := Button.new()
	action.name = "TransferButton"
	action.text = (
		"STORE WEAPON" if kind == "weapon" and _selected_from_inventory
		else "TAKE WEAPON" if kind == "weapon"
		else "STORE ->" if _selected_from_inventory
		else "<- TAKE"
	)
	action.custom_minimum_size = Vector2(210, 50)
	action.disabled = not local_access
	action.tooltip_text = "Visit this property to move stored items." if not local_access else ""
	action.pressed.connect(_transfer_selected.bind(false))
	_style_button(action, ACCENT)
	box.add_child(action)
	if not local_access:
		var remote := _label("VIEW ONLY - VISIT PROPERTY", 11, RED)
		remote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(remote)
	return panel


func _set_category(category: StringName) -> void:
	_category = category
	_selected_key = ""
	_refresh()


func _select_item(key: String, from_inventory: bool) -> void:
	_selected_key = key
	_selected_from_inventory = from_inventory
	_selected_amount_index = 0
	_refresh()


func _on_item_gui_input(
	event: InputEvent,
	entry: Dictionary,
	from_inventory: bool
) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.double_click
	):
		_selected_key = String(entry.get("key", ""))
		_selected_from_inventory = from_inventory
		_selected_amount_index = 3
		_transfer_selected(true)


func _select_transfer_amount(index: int) -> void:
	_selected_amount_index = clampi(index, 0, 3)
	_refresh()


func _get_selected_entry() -> Dictionary:
	for entry in _get_item_entries(_selected_from_inventory):
		if String(entry.get("key", "")) == _selected_key:
			return entry
	return {}


func _transfer_selected(force_max: bool) -> void:
	if _access_mode != AccessMode.LOCAL:
		_set_feedback("Visit this property to move stored items.", true)
		return
	var entry := _get_selected_entry()
	if entry.is_empty():
		return
	var kind := String(entry.get("kind", ""))
	var index := 3 if force_max else _selected_amount_index
	var moved := 0
	var success := false
	match kind:
		"cash":
			moved = properties.transfer_dirty_cash(
				_property_id,
				CASH_PRESETS[index],
				_selected_from_inventory
			)
			success = moved > 0
		"product":
			moved = properties.transfer_product(
				_property_id,
				entry.get("definition") as ProductDefinition,
				PRODUCT_PRESETS[index],
				_selected_from_inventory
			)
			success = moved > 0
		"weapon":
			var weapon_id := (
				entry.get("definition") as WeaponDefinition
			).weapon_id
			success = (
				properties.store_weapon(_property_id, weapon_id)
				if _selected_from_inventory
				else properties.take_weapon(_property_id, weapon_id)
			)
			moved = 1 if success else 0
	if success:
		_set_feedback(
			"%s %s %s." % [
				"Stored" if _selected_from_inventory else "Took",
				"$%s" % _money(moved) if kind == "cash" else str(moved),
				String(entry.get("title", "item")).to_lower(),
			],
			false
		)
	else:
		_set_feedback(
			properties.last_transfer_error
			if not properties.last_transfer_error.is_empty()
			else "The stash is full or nothing is available to transfer.",
			true
		)
	_refresh()


func _build_garage_tab(definition: PropertyDefinition) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_content.add_child(page)
	var stored := garage.get_stored_vehicle_records(_property_id)
	var capacity := definition.vehicle_storage_capacity
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 10)
	page.add_child(summary)
	summary.add_child(_stat_card(
		"VEHICLE STORAGE", "%d / %d" % [stored.size(), capacity],
		"Retrieval frees a slot", ACCENT
	))
	var block_reason := (
		_garage_controller.get_spawn_block_reason()
		if _access_mode == AccessMode.LOCAL and _garage_controller != null
		else "Visit the property to retrieve a vehicle."
	)
	summary.add_child(_stat_card(
		"RETRIEVAL BAY",
		"CLEAR" if block_reason.is_empty() else "BLOCKED",
		"Ready for retrieval" if block_reason.is_empty() else block_reason,
		GREEN if block_reason.is_empty() else RED
	))
	var parked: Array[BaseVehicle] = []
	if _access_mode == AccessMode.LOCAL and _garage_controller != null:
		parked = _garage_controller.get_parked_owned_vehicles(garage)
	summary.add_child(_stat_card(
		"PARKED TO STORE", str(parked.size()),
		"Exit an owned car inside Garage Area", CYAN
	))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "GarageGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for record in stored:
		grid.add_child(_stored_vehicle_card(record, block_reason))
	for vehicle in parked:
		grid.add_child(_parked_vehicle_card(vehicle, stored.size() < capacity))
	for slot_index in maxi(capacity - stored.size(), 0):
		grid.add_child(_empty_garage_slot(slot_index + stored.size() + 1))
	if capacity <= 0:
		var unavailable := _label(
			"This property has no configured vehicle storage.", 17, MUTED
		)
		grid.add_child(unavailable)


func _stored_vehicle_card(record: Dictionary, block_reason: String) -> Control:
	var vehicle_id := StringName(record.get("vehicle_id", ""))
	var definition := VehicleCatalog.get_by_id(vehicle_id)
	var panel := _section_panel(
		definition.display_name.to_upper() if definition != null else "VEHICLE"
	)
	panel.custom_minimum_size = Vector2(360, 330)
	var box := panel.get_meta("content") as VBoxContainer
	if definition != null:
		box.add_child(_vehicle_preview(
			definition,
			record.get("condition", {}) as Dictionary
		))
		var ratings := _label(
			"ACCEL %d/5   HANDLING %d/5   BRAKING %d/5" % [
				definition.acceleration_rating,
				definition.handling_rating,
				definition.braking_rating,
			],
			12,
			MUTED
		)
		ratings.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(ratings)
	var button := Button.new()
	button.text = "RETRIEVE VEHICLE"
	button.custom_minimum_size.y = 46
	button.disabled = (
		_access_mode != AccessMode.LOCAL
		or _garage_controller == null
		or not block_reason.is_empty()
	)
	button.tooltip_text = (
		"Visit this property to retrieve this vehicle."
		if _access_mode != AccessMode.LOCAL
		else block_reason
	)
	button.pressed.connect(
		_retrieve_vehicle.bind(StringName(record.get("instance_id", "")))
	)
	_style_button(button, GREEN)
	box.add_child(button)
	return panel


func _parked_vehicle_card(vehicle: BaseVehicle, has_space: bool) -> Control:
	var definition := vehicle.definition
	var panel := _section_panel(
		"PARKED  /  %s" % definition.display_name.to_upper()
	)
	panel.custom_minimum_size = Vector2(360, 330)
	var box := panel.get_meta("content") as VBoxContainer
	box.add_child(_vehicle_preview(
		definition,
		vehicle.export_condition_state()
	))
	var note := _label(
		"Eligible owned vehicle detected in Garage Area.", 12, CYAN
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var button := Button.new()
	button.text = "STORE VEHICLE"
	button.custom_minimum_size.y = 46
	button.disabled = not has_space
	button.tooltip_text = "This garage is full." if not has_space else ""
	button.pressed.connect(_store_vehicle.bind(vehicle))
	_style_button(button, ACCENT)
	box.add_child(button)
	return panel


func _empty_garage_slot(slot_number: int) -> Control:
	var panel := _section_panel("EMPTY SLOT %d" % slot_number)
	panel.custom_minimum_size = Vector2(360, 250)
	var box := panel.get_meta("content") as VBoxContainer
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := _label("+", 54, Color("495362"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(icon)
	var note := _label("Park and exit an owned car inside Garage Area.", 13, MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	return panel


func _vehicle_preview(
	definition: VehicleDefinition,
	condition: Dictionary = {}
) -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(320, 205)
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 360)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	_preview_pivots.append(pivot)
	if definition.visual_scene != null:
		var model := definition.visual_scene.instantiate() as Node3D
		if model != null:
			model.rotation_degrees = definition.visual_rotation_degrees
			model.position = definition.visual_offset
			pivot.add_child(model)
			VehicleConditionComponent.apply_appearance_to_visual(
				model,
				definition,
				condition
			)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var distance := maxf(definition.collision_size.z * 1.35, 5.5)
	var target := Vector3(0.0, definition.collision_offset.y, 0.0)
	camera.look_at_from_position(Vector3(0.0, target.y + 1.1, distance), target)
	camera.fov = 38.0
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
	return container


func _store_vehicle(vehicle: BaseVehicle) -> void:
	var result := garage.store_vehicle(_property_id, vehicle)
	_set_feedback(String(result.get("message", "Vehicle could not be stored.")), not bool(result.get("success", false)))
	if bool(result.get("success", false)):
		await get_tree().physics_frame
		await get_tree().physics_frame
	_refresh()


func _retrieve_vehicle(instance_id: StringName) -> void:
	if _access_mode != AccessMode.LOCAL or _garage_controller == null:
		_set_feedback("Visit this property to retrieve a vehicle.", true)
		return
	var block_reason := _garage_controller.get_spawn_block_reason()
	if not block_reason.is_empty():
		_set_feedback(block_reason, true)
		_refresh()
		return
	var player := get_parent() as CharacterBody3D
	var result := garage.retrieve_vehicle(
		_property_id,
		instance_id,
		_garage_controller.get_spawn_transform(),
		player.get_parent() as Node3D
	)
	_set_feedback(String(result.get("message", "Vehicle could not be retrieved.")), not bool(result.get("success", false)))
	if bool(result.get("success", false)):
		close()
	else:
		_refresh()


func _build_operations_tab(definition: PropertyDefinition) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_content.add_child(page)
	var supply := properties.get_property_supply_summary(
		_property_id,
		EconomyCatalog.get_gram_products()
	)
	var earnings := {
		"staffed": 0, "total_slots": definition.dealer_capacity,
		"today_net": 0, "lifetime_net": 0,
	}
	if _territory_dealers != null:
		supply = _territory_dealers.get_property_supply_summary(_property_id)
		earnings = _territory_dealers.get_property_earnings_summary(_property_id)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 10)
	page.add_child(stats_row)
	stats_row.add_child(_stat_card(
		"DEALERS", "%d / %d" % [int(earnings.get("staffed", 0)), int(earnings.get("total_slots", 0))],
		"Assigned to this property", CYAN
	))
	stats_row.add_child(_stat_card(
		"SELLABLE SUPPLY", "%d UNITS" % int(supply.get("product_units", 0)),
		"This stash only", ACCENT
	))
	stats_row.add_child(_stat_card(
		"TODAY NET", "$%s" % _money(int(earnings.get("today_net", 0))),
		"Lifetime $%s" % _money(int(earnings.get("lifetime_net", 0))), GREEN
	))
	stats_row.add_child(_stat_card(
		"STASH CASH", "$%s" % _money(int(supply.get("dirty_cash", 0))),
		"Dirty cash", ACCENT
	))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	page.add_child(columns)
	columns.add_child(_build_runner_panel())
	columns.add_child(_build_brick_station_panel(definition))
	columns.add_child(_build_dealer_panel(definition))


func _build_runner_panel() -> Control:
	var panel := _section_panel("WHOLESALE RUNNER")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := panel.get_meta("content") as VBoxContainer
	var installed := properties.has_runner(_property_id)
	box.add_child(_label(
		"Receives complete wholesaler brick orders directly into this stash.",
		13,
		MUTED
	))
	var status := _label(
		"RUNNER ACTIVE" if installed else "NOT INSTALLED",
		18,
		GREEN if installed else ACCENT
	)
	status.name = "RunnerStatus"
	box.add_child(status)
	if installed:
		box.add_child(_label(
			"Select this property from any wholesaler delivery menu.",
			13,
			MUTED
		))
		return panel
	var purchase := Button.new()
	purchase.name = "RunnerPurchase"
	purchase.text = "HIRE RUNNER  $%s CLEAN" % _money(
		PropertyCatalog.RUNNER_UPGRADE_COST
	)
	purchase.custom_minimum_size.y = 46
	purchase.disabled = not properties.wallet.can_spend_clean(
		PropertyCatalog.RUNNER_UPGRADE_COST
	)
	purchase.pressed.connect(_purchase_runner)
	_style_button(purchase, CYAN)
	box.add_child(purchase)
	return panel


func _build_brick_station_panel(definition: PropertyDefinition) -> Control:
	var panel := _section_panel("BRICK BREAKDOWN STATION")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := panel.get_meta("content") as VBoxContainer
	var state := properties.get_brick_station_state(_property_id)
	var installed := bool(state.get("installed", false))
	box.add_child(_label(
		"Converts one selected brick every three in-game hours. Output remains in this stash.",
		13,
		MUTED
	))
	var status := _label(_station_status_text(state), 18, GREEN if installed else ACCENT)
	status.name = "BrickStationStatus"
	box.add_child(status)
	if not installed:
		var purchase := Button.new()
		purchase.name = "BrickStationPurchase"
		purchase.text = "INSTALL  $%s CLEAN" % _money(definition.brick_station_cost)
		purchase.custom_minimum_size.y = 46
		purchase.disabled = not properties.wallet.can_spend_clean(definition.brick_station_cost)
		purchase.pressed.connect(_purchase_brick_station)
		_style_button(purchase, ACCENT)
		box.add_child(purchase)
		return panel
	var selector := OptionButton.new()
	selector.name = "BrickStationProduct"
	selector.add_item("OFF")
	selector.set_item_metadata(0, "")
	var selected_id := StringName(state.get("selected_product_id", ""))
	var selected_index := 0
	for product in EconomyCatalog.get_brick_products():
		selector.add_item(product.display_name.to_upper())
		var index := selector.item_count - 1
		selector.set_item_metadata(index, String(product.product_id))
		if product.product_id == selected_id:
			selected_index = index
	selector.select(selected_index)
	selector.item_selected.connect(_select_brick_product.bind(selector))
	box.add_child(selector)
	return panel


func _build_dealer_panel(definition: PropertyDefinition) -> Control:
	var panel := _section_panel("DEALER STAFFING")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := panel.get_meta("content") as VBoxContainer
	if _territory_dealers == null:
		box.add_child(_label("Dealer service unavailable.", 14, MUTED))
		return panel
	if not _territory_dealers.can_manage_property_dealers(_property_id):
		box.add_child(_label(
			"Take control of this territory before staffing the property.", 14, MUTED
		))
		return panel
	var roster := _territory_dealers.get_property_roster(_property_id)
	for entry in roster:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name := String(entry.get("member_id", "dealer")).replace("_", " ").capitalize()
		var info := _label(
			"%s  /  LEVEL %d  /  TODAY $%s" % [
				name,
				int(entry.get("level", 1)),
				_money(int(entry.get("today_net", 0))),
			],
			13,
			TEXT
		)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var level := int(entry.get("level", 1))
		var upgrade := Button.new()
		upgrade.text = "UPGRADE"
		upgrade.disabled = level >= 4 or not properties.wallet.can_spend_dirty(
			_territory_dealers.get_upgrade_cost(level)
		)
		upgrade.pressed.connect(_upgrade_dealer.bind(
			definition.territory_id,
			StringName(entry.get("zone_id", "")),
			StringName(entry.get("member_id", ""))
		))
		_style_button(upgrade, CYAN)
		row.add_child(upgrade)
		var fire := Button.new()
		fire.text = "FIRE"
		fire.pressed.connect(_fire_dealer.bind(
			definition.territory_id,
			StringName(entry.get("zone_id", "")),
			StringName(entry.get("member_id", ""))
		))
		_style_button(fire, RED)
		row.add_child(fire)
		box.add_child(row)
	var open_slots := maxi(definition.dealer_capacity - roster.size(), 0)
	if open_slots <= 0:
		box.add_child(_label("All dealer slots are staffed.", 13, MUTED))
		return panel
	var candidates := _territory_dealers.get_available_candidates(definition.territory_id)
	var hire_row := HBoxContainer.new()
	hire_row.add_theme_constant_override("separation", 8)
	var picker := OptionButton.new()
	picker.name = "DealerCandidatePicker"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in candidates:
		picker.add_item(String(entry.get("member_id", "dealer")).replace("_", " ").capitalize())
		picker.set_item_metadata(picker.item_count - 1, {
			"zone_id": String(entry.get("zone_id", "")),
			"member_id": String(entry.get("member_id", "")),
		})
	picker.disabled = candidates.is_empty()
	hire_row.add_child(picker)
	var hire := Button.new()
	hire.name = "DealerHire"
	hire.text = "HIRE  $%s DIRTY" % _money(TerritoryDealerService.HIRE_FEE)
	hire.disabled = candidates.is_empty() or not properties.wallet.can_spend_dirty(TerritoryDealerService.HIRE_FEE)
	hire.pressed.connect(_hire_dealer.bind(definition, picker))
	_style_button(hire, GREEN)
	hire_row.add_child(hire)
	box.add_child(hire_row)
	return panel


func _purchase_brick_station() -> void:
	var success := properties.purchase_brick_station(_property_id, _get_absolute_minute())
	_set_feedback("Brick station installed." if success else "Could not install the brick station.", not success)
	_refresh()


func _purchase_runner() -> void:
	var success := properties.purchase_runner(_property_id)
	_set_feedback(
		"Runner hired. Wholesalers can now deliver to this stash."
		if success else properties.last_transfer_error,
		not success
	)
	_refresh()


func _select_brick_product(index: int, selector: OptionButton) -> void:
	if index < 0:
		return
	var product_id := StringName(selector.get_item_metadata(index))
	var success := properties.set_brick_station_product(
		_property_id, product_id, _get_absolute_minute()
	)
	_set_feedback("Brick station updated." if success else "Could not update the brick station.", not success)
	_refresh()


func _hire_dealer(definition: PropertyDefinition, picker: OptionButton) -> void:
	if _territory_dealers == null or picker.item_count <= 0:
		return
	var metadata := picker.get_selected_metadata() as Dictionary
	var success := _territory_dealers.hire_dealer(
		definition.territory_id,
		StringName(metadata.get("zone_id", "")),
		StringName(metadata.get("member_id", "")),
		_property_id
	)
	_set_feedback("Dealer hired." if success else "Could not hire that dealer.", not success)
	_refresh()


func _upgrade_dealer(
	territory_id: StringName,
	zone_id: StringName,
	member_id: StringName
) -> void:
	var success := _territory_dealers.upgrade_dealer(territory_id, zone_id, member_id)
	_set_feedback("Dealer upgraded." if success else "Could not upgrade that dealer.", not success)
	_refresh()


func _fire_dealer(
	territory_id: StringName,
	zone_id: StringName,
	member_id: StringName
) -> void:
	var success := _territory_dealers.fire_dealer(territory_id, zone_id, member_id)
	_set_feedback("Dealer fired." if success else "Could not fire that dealer.", not success)
	_refresh()


func _station_status_text(state: Dictionary) -> String:
	if not bool(state.get("installed", false)):
		return "NOT INSTALLED"
	var selected_id := StringName(state.get("selected_product_id", ""))
	if selected_id.is_empty():
		return "INSTALLED  /  OFF"
	var product := EconomyCatalog.get_product(selected_id)
	var block_reason := String(state.get("last_block_reason", ""))
	return (
		"BLOCKED  /  %s" % block_reason
		if not block_reason.is_empty()
		else "ACTIVE  /  %s" % product.display_name.to_upper()
	)


func _stat_card(
	heading: String,
	value: String,
	note: String,
	color: Color
) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("101620"), color.darkened(0.45), 1, 7)
	)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 11)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.add_child(_label(heading, 11, MUTED))
	box.add_child(_label(value, 21, color))
	box.add_child(_label(note, 11, MUTED))
	return panel


func _section_panel(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("0e141d"), Color("28323f"), 1, 8)
	)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	box.add_child(_label(title_text, 16, TEXT))
	panel.set_meta("content", box)
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_button(button: Button, color: Color) -> void:
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override(
		"normal", _panel_style(Color("111721"), color.darkened(0.5), 1, 6)
	)
	button.add_theme_stylebox_override(
		"hover", _panel_style(Color("1a202a"), color, 1, 6)
	)
	button.add_theme_stylebox_override(
		"pressed", _panel_style(color.darkened(0.62), color, 2, 6)
	)
	button.add_theme_stylebox_override(
		"disabled", _panel_style(Color("0b0f15"), Color("252b34"), 1, 6)
	)


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
	return style


func _set_feedback(message: String, error: bool) -> void:
	_feedback.text = message
	_feedback.add_theme_color_override("font_color", RED if error else MUTED)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _money(amount: int) -> String:
	var text := str(maxi(amount, 0))
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result


func _get_absolute_minute() -> int:
	var world_time := get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	return world_time.get_absolute_minute() if world_time != null else 0


func _find_property_building(property_id: StringName) -> PropertyBuilding:
	for node in get_tree().get_nodes_in_group(&"property_buildings"):
		var building := node as PropertyBuilding
		if building != null and building.property_id == property_id:
			return building
	return null


func _resolve_territory_dealers() -> void:
	_territory_dealers = get_tree().get_first_node_in_group(
		&"territory_dealer_service"
	) as TerritoryDealerService
	if (
		_territory_dealers != null
		and not _territory_dealers.state_changed.is_connected(
			_on_territory_dealer_state_changed
		)
	):
		_territory_dealers.state_changed.connect(_on_territory_dealer_state_changed)
	if _is_open and _active_tab == &"operations":
		_refresh()


func _on_property_data_changed(property_id: StringName) -> void:
	if _is_open and property_id == _property_id:
		_refresh()


func _on_ownership_changed(property_id: StringName, owned: bool) -> void:
	if not _is_open or property_id != _property_id:
		return
	if not owned:
		close()
	else:
		_refresh()


func _on_vehicle_storage_changed(property_id: StringName) -> void:
	if _is_open and property_id == _property_id:
		_refresh()


func _on_garage_changed() -> void:
	if _is_open and _active_tab == &"garage":
		_refresh()


func _on_money_changed(_dirty: int, _clean: int) -> void:
	if _is_open:
		_refresh()


func _on_inventory_changed(_product: ProductDefinition, _quantity: int) -> void:
	if _is_open and _active_tab == &"stash":
		_refresh()


func _on_weapon_changed(_definition: WeaponDefinition) -> void:
	if _is_open and _active_tab == &"stash":
		_refresh()


func _on_territory_dealer_state_changed(territory_id: StringName) -> void:
	var definition := PropertyCatalog.get_by_id(_property_id)
	if (
		_is_open
		and _active_tab == &"operations"
		and definition != null
		and definition.territory_id == territory_id
	):
		_refresh()
