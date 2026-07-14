class_name PropertyStashMenu
extends CanvasLayer

const ACCENT := Color(1.0, 0.42, 0.08)
const MUTED := Color(0.56, 0.59, 0.64)
const CASH_PRESETS := [100, 1000, 10000, 2147483647]
const PRODUCT_PRESETS := [1, 10, 100, 2147483647]

@export var property_component_path := NodePath("../Components/PropertyComponent")
@export var inventory_component_path := NodePath("../Components/InventoryComponent")
@export var weapon_component_path := NodePath("../Components/WeaponComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var properties := get_node(property_component_path) as PlayerPropertyComponent
@onready var inventory := get_node(inventory_component_path) as PlayerInventoryComponent
@onready var weapons := get_node(weapon_component_path) as PlayerWeaponComponent
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController

@onready var _root := %MenuRoot as Control
@onready var _title := %Title as Label
@onready var _neighborhood := %Neighborhood as Label
@onready var _cash_value := %CashValue as Label
@onready var _capacity_value := %CapacityValue as Label
@onready var _capacity_bar := %CapacityBar as ProgressBar
@onready var _status_value := %StatusValue as Label
@onready var _stored_cash := %StoredCash as Label
@onready var _category_title := %CategoryTitle as Label
@onready var _item_count := %ItemCount as Label
@onready var _transfer_mode_button := %TransferModeButton as Button
@onready var _item_grid := %ItemGrid as GridContainer
@onready var _empty_state := %EmptyState as Label
@onready var _detail_title := %DetailTitle as Label
@onready var _detail_category := %DetailCategory as Label
@onready var _detail_icon := %DetailIcon as TextureRect
@onready var _cash_preview := %CashPreview as Label
@onready var _weapon_preview := %WeaponPreview as SubViewportContainer
@onready var _preview_root := %PreviewRoot as Node3D
@onready var _detail_description := %DetailDescription as Label
@onready var _carried_value := %CarriedValue as Label
@onready var _stashed_value := %StashedValue as Label
@onready var _estimated_value := %EstimatedValue as Label
@onready var _amount_label := %AmountLabel as Label
@onready var _amounts := %Amounts as HBoxContainer
@onready var _store_button := %StoreButton as Button
@onready var _take_button := %TakeButton as Button
@onready var _feedback := %FeedbackLabel as Label

var _property_id: StringName
var _is_open := false
var _category := "all"
var _selected_key := "cash"
var _selected_amount_index := 0
var _inventory_mode := false
var _entries: Array[Dictionary] = []
var _category_buttons: Dictionary[String, Button] = {}
var _amount_buttons: Array[Button] = []
var _refresh_pending := false


func _ready() -> void:
	_root.visible = false
	_category_buttons = {
		"all": %AllCategory,
		"drugs": %DrugsCategory,
		"money": %MoneyCategory,
		"weapons": %WeaponsCategory,
	}
	_amount_buttons = [%Amount1, %Amount2, %Amount3, %AmountMax]
	for key in _category_buttons:
		_category_buttons[key].pressed.connect(_set_category.bind(key))
	for index in _amount_buttons.size():
		_amount_buttons[index].pressed.connect(_select_amount.bind(index))
	%CloseButton.pressed.connect(close)
	_transfer_mode_button.pressed.connect(_toggle_inventory_mode)
	_store_button.pressed.connect(_transfer_selected.bind(true))
	_take_button.pressed.connect(_transfer_selected.bind(false))
	properties.stash_changed.connect(_on_stash_changed)
	inventory.quantity_changed.connect(_on_inventory_changed)
	weapons.weapon_changed.connect(_on_weapon_changed)


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
	if not properties.owns(property_id) or PropertyCatalog.get_by_id(property_id) == null:
		return
	if not menu_controller.request_open(&"property_stash"):
		return
	_property_id = property_id
	_is_open = true
	_category = "all"
	_selected_key = "cash"
	_selected_amount_index = 0
	_inventory_mode = false
	_root.visible = true
	_set_feedback("TIP: Stored drugs and weapons use capacity. Dirty cash does not.", false)
	_refresh()


func close() -> void:
	if not _is_open or not menu_controller.close(&"property_stash"):
		return
	_is_open = false
	_root.visible = false
	_clear_weapon_preview()


func _refresh() -> void:
	if not _is_open:
		return
	var definition := PropertyCatalog.get_by_id(_property_id)
	if definition == null:
		return
	_entries = _build_entries()
	_refresh_summary(definition)
	_refresh_categories()
	var visible_entries := _get_filtered_entries()
	if not _contains_key(visible_entries, _selected_key):
		_selected_key = str(visible_entries[0]["key"]) if not visible_entries.is_empty() else ""
	_refresh_grid(visible_entries)
	_refresh_detail()


func _refresh_summary(definition: PropertyDefinition) -> void:
	var used := properties.get_stash_used_capacity(_property_id)
	var capacity := properties.get_stash_capacity(_property_id)
	_title.text = "%s  •  STASH" % definition.display_name.to_upper()
	_neighborhood.text = "%s  /  PROPERTY STORAGE" % definition.neighborhood.to_upper()
	_cash_value.text = "$%s" % _money(properties.wallet.dirty_cash)
	_capacity_value.text = "%s / %s" % [_money(used), _money(capacity)]
	_capacity_bar.max_value = maxf(float(capacity), 1.0)
	_capacity_bar.value = mini(used, capacity)
	_status_value.text = "●  OWNED" if properties.owns(_property_id) else "●  LOCKED"
	_stored_cash.text = "STORED CASH\n$%s" % _money(
		properties.get_stashed_dirty_cash(_property_id)
	)


func _refresh_categories() -> void:
	var cash_stack := 0
	var product_units := 0
	var weapon_count := 0
	if _inventory_mode:
		cash_stack = 1 if properties.wallet.dirty_cash > 0 else 0
		for product in EconomyCatalog.get_all_products():
			product_units += inventory.get_quantity(product)
		for definition in weapons.get_catalog_weapons():
			if weapons.owns_weapon(definition.weapon_id):
				weapon_count += 1
	else:
		var summary := properties.get_stash_summary(_property_id)
		cash_stack = 1 if int(summary["dirty_cash"]) > 0 else 0
		product_units = int(summary["product_units"])
		weapon_count = int(summary["weapon_count"])
	_category_buttons["all"].text = "▦   ALL ITEMS     %d" % (product_units + weapon_count + cash_stack)
	_category_buttons["drugs"].text = "◆   DRUGS         %d" % product_units
	_category_buttons["money"].text = "$   MONEY         %d" % cash_stack
	_category_buttons["weapons"].text = "▲   WEAPONS       %d" % weapon_count
	for key in _category_buttons:
		_category_buttons[key].set_pressed_no_signal(key == _category)
	var category_name: String = str({
		"all": "ALL ITEMS",
		"drugs": "DRUGS",
		"money": "MONEY",
		"weapons": "WEAPONS",
	}.get(_category, "ALL ITEMS"))
	_category_title.text = (
		"INVENTORY  •  %s" % category_name if _inventory_mode else category_name
	)
	_transfer_mode_button.text = (
		"←  VIEW STASH" if _inventory_mode else "+  ADD FROM INVENTORY"
	)


func _build_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cash_amount: int = (
		properties.wallet.dirty_cash
		if _inventory_mode
		else properties.get_stashed_dirty_cash(_property_id)
	)
	if cash_amount > 0:
		result.append({
			"key": "cash",
			"kind": "cash",
			"category": "money",
			"title": "DIRTY CASH",
		})
	for product in EconomyCatalog.get_all_products():
		var product_amount: int = (
			inventory.get_quantity(product)
			if _inventory_mode
			else properties.get_stashed_product_quantity(_property_id, product)
		)
		if product_amount > 0:
			result.append({
				"key": "product:%s" % product.product_id,
				"kind": "product",
				"category": "drugs",
				"title": product.display_name.to_upper(),
				"definition": product,
			})
	var stored_ids := properties.get_stashed_weapon_ids(_property_id)
	for definition in weapons.get_catalog_weapons():
		var available: bool = (
			weapons.owns_weapon(definition.weapon_id)
			if _inventory_mode
			else definition.weapon_id in stored_ids
		)
		if available:
			result.append({
				"key": "weapon:%s" % definition.weapon_id,
				"kind": "weapon",
				"category": "weapons",
				"title": definition.display_name.to_upper(),
				"definition": definition,
			})
	return result


func _get_filtered_entries() -> Array[Dictionary]:
	if _category == "all":
		return _entries.duplicate()
	var result: Array[Dictionary] = []
	for entry in _entries:
		if entry["category"] == _category:
			result.append(entry)
	return result


func _refresh_grid(visible_entries: Array[Dictionary]) -> void:
	_clear(_item_grid)
	_empty_state.visible = visible_entries.is_empty()
	%ItemScroll.visible = not visible_entries.is_empty()
	_empty_state.text = (
		"Nothing available to store from this category."
		if _inventory_mode
		else "Your stash is empty. Use ADD FROM INVENTORY to store something."
	)
	_item_count.text = "%d ENTRIES" % visible_entries.size()
	for entry in visible_entries:
		_item_grid.add_child(_create_item_card(entry))


func _create_item_card(entry: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 178)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.button_pressed = entry["key"] == _selected_key
	button.add_theme_stylebox_override("normal", _card_style(false, false))
	button.add_theme_stylebox_override("hover", _card_style(true, false))
	button.add_theme_stylebox_override("pressed", _card_style(false, true))
	button.pressed.connect(_select_entry.bind(str(entry["key"])))

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 11
	content.offset_top = 9
	content.offset_right = -11
	content.offset_bottom = -9
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	button.add_child(content)

	var name_label := Label.new()
	name_label.text = entry["title"]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.89))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	var preview := CenterContainer.new()
	preview.custom_minimum_size.y = 72
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview)
	if entry["kind"] == "product":
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(78, 78)
		icon.texture = (entry["definition"] as ProductDefinition).icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(icon)
	else:
		var symbol := Label.new()
		symbol.text = "$" if entry["kind"] == "cash" else "WEAPON"
		symbol.add_theme_font_size_override("font_size", 42 if entry["kind"] == "cash" else 18)
		symbol.add_theme_color_override(
			"font_color",
			Color(0.38, 0.84, 0.42) if entry["kind"] == "cash" else ACCENT
		)
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(symbol)

	var counts := _get_entry_counts(entry)
	var primary_amount: int = counts[0] if _inventory_mode else counts[1]
	var amount_label := Label.new()
	amount_label.text = (
		"$%s" % _money(primary_amount)
		if entry["kind"] == "cash"
		else "×%s" % _money(primary_amount)
	)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.add_theme_font_size_override("font_size", 25)
	amount_label.add_theme_color_override(
		"font_color",
		Color(0.38, 0.84, 0.42) if entry["kind"] == "cash" else Color(0.96, 0.96, 0.94)
	)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(amount_label)

	var location_label := Label.new()
	location_label.text = "IN INVENTORY" if _inventory_mode else "IN STASH"
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	location_label.add_theme_font_size_override("font_size", 11)
	location_label.add_theme_color_override("font_color", MUTED)
	location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(location_label)
	return button


func _refresh_detail() -> void:
	var entry := _get_selected_entry()
	if entry.is_empty():
		_detail_title.text = "SELECT AN ITEM"
		_detail_category.text = "STASH ITEM"
		_detail_description.text = "Choose an item to see its details."
		_detail_icon.texture = null
		_detail_icon.visible = false
		_cash_preview.visible = false
		_weapon_preview.visible = false
		_amounts.visible = false
		_amount_label.visible = false
		_store_button.visible = _inventory_mode
		_take_button.visible = not _inventory_mode
		_store_button.disabled = true
		_take_button.disabled = true
		_clear_weapon_preview()
		return

	var counts := _get_entry_counts(entry)
	var carried := counts[0]
	var stored := counts[1]
	_detail_title.text = entry["title"]
	_detail_category.text = str(entry["category"]).to_upper()
	_carried_value.text = "CARRIED  %s" % _display_count(entry, carried)
	_stashed_value.text = "STORED  %s" % _display_count(entry, stored)
	_detail_icon.visible = false
	_cash_preview.visible = false
	_weapon_preview.visible = false
	_clear_weapon_preview()

	match entry["kind"]:
		"cash":
			_cash_preview.visible = true
			_detail_description.text = "Dirty cash stored safely at this property. Cash does not use stash capacity."
			_estimated_value.text = "STORED VALUE  $%s" % _money(stored)
		"product":
			var product := entry["definition"] as ProductDefinition
			_detail_icon.texture = product.icon
			_detail_icon.visible = true
			_detail_description.text = "%d gram %s package. Estimated street value is based on the current unit sale price." % [
				product.package_size_grams,
				"brick" if product.is_brick() else "retail",
			]
			_estimated_value.text = "EST. STORED VALUE  $%s" % _money(product.sale_price * stored)
		"weapon":
			var definition := entry["definition"] as WeaponDefinition
			_weapon_preview.visible = true
			_show_weapon_preview(definition)
			_detail_description.text = definition.description
			_estimated_value.text = "EST. VALUE  $%s" % _money(definition.purchase_price)

	var uses_amount: bool = str(entry["kind"]) != "weapon"
	_amounts.visible = uses_amount
	_amount_label.visible = uses_amount
	if uses_amount:
		_refresh_amount_buttons(entry["kind"] == "cash")
	var remaining := properties.get_stash_remaining_capacity(_property_id)
	_store_button.visible = _inventory_mode
	_take_button.visible = not _inventory_mode
	_store_button.disabled = carried <= 0 or (
		entry["kind"] != "cash" and remaining <= 0
	)
	_take_button.disabled = stored <= 0
	_store_button.text = "STORE WEAPON" if entry["kind"] == "weapon" else "STORE"
	_take_button.text = "TAKE WEAPON" if entry["kind"] == "weapon" else "TAKE"


func _refresh_amount_buttons(cash: bool) -> void:
	var values := CASH_PRESETS if cash else PRODUCT_PRESETS
	for index in _amount_buttons.size():
		_amount_buttons[index].text = (
			"MAX" if index == 3 else "$%s" % _money(values[index]) if cash else str(values[index])
		)
		_amount_buttons[index].set_pressed_no_signal(index == _selected_amount_index)


func _transfer_selected(to_stash: bool) -> void:
	var entry := _get_selected_entry()
	if entry.is_empty():
		return
	var moved := 0
	var success := false
	match entry["kind"]:
		"cash":
			moved = properties.transfer_dirty_cash(
				_property_id, CASH_PRESETS[_selected_amount_index], to_stash
			)
			success = moved > 0
		"product":
			moved = properties.transfer_product(
				_property_id,
				entry["definition"] as ProductDefinition,
				PRODUCT_PRESETS[_selected_amount_index],
				to_stash
			)
			success = moved > 0
		"weapon":
			var weapon_id := (entry["definition"] as WeaponDefinition).weapon_id
			success = (
				properties.store_weapon(_property_id, weapon_id)
				if to_stash
				else properties.take_weapon(_property_id, weapon_id)
			)
			moved = 1 if success else 0

	_refresh()
	if success:
		_set_feedback(
			"%s %s %s." % [
				"Stored" if to_stash else "Took",
				_display_count(entry, moved),
				str(entry["title"]).to_lower(),
			],
			false
		)
	elif to_stash and entry["kind"] != "cash" and properties.get_stash_remaining_capacity(_property_id) <= 0:
		_set_feedback("STASH FULL — take something out before storing more items.", true)
	else:
		_set_feedback("Nothing available to transfer.", true)


func _get_entry_counts(entry: Dictionary) -> Array[int]:
	match entry["kind"]:
		"cash":
			return [properties.wallet.dirty_cash, properties.get_stashed_dirty_cash(_property_id)]
		"product":
			var product := entry["definition"] as ProductDefinition
			return [inventory.get_quantity(product), properties.get_stashed_product_quantity(_property_id, product)]
		"weapon":
			var weapon_id := (entry["definition"] as WeaponDefinition).weapon_id
			return [1 if weapons.owns_weapon(weapon_id) else 0, 1 if weapon_id in properties.get_stashed_weapon_ids(_property_id) else 0]
	return [0, 0]


func _display_count(entry: Dictionary, amount: int) -> String:
	return "$%s" % _money(amount) if entry["kind"] == "cash" else str(amount)


func _set_category(category: String) -> void:
	_category = category
	var visible_entries := _get_filtered_entries()
	_selected_key = str(visible_entries[0]["key"]) if not visible_entries.is_empty() else ""
	_refresh()


func _toggle_inventory_mode() -> void:
	_inventory_mode = not _inventory_mode
	_category = "all"
	_selected_key = ""
	_selected_amount_index = 0
	_set_feedback(
		"Select something you carry, choose an amount, then press STORE."
		if _inventory_mode
		else "Showing only items currently stored at this property.",
		false
	)
	_refresh()


func _select_entry(key: String) -> void:
	_selected_key = key
	_refresh_grid(_get_filtered_entries())
	_refresh_detail()


func _select_amount(index: int) -> void:
	_selected_amount_index = index
	var entry := _get_selected_entry()
	_refresh_amount_buttons(not entry.is_empty() and entry["kind"] == "cash")


func _get_selected_entry() -> Dictionary:
	for entry in _entries:
		if entry["key"] == _selected_key:
			return entry
	return {}


func _contains_key(entries: Array[Dictionary], key: String) -> bool:
	for entry in entries:
		if entry["key"] == key:
			return true
	return false


func _show_weapon_preview(definition: WeaponDefinition) -> void:
	if definition == null or definition.visual_scene == null:
		return
	var model := definition.visual_scene.instantiate() as Node3D
	if model == null:
		return
	model.process_mode = Node.PROCESS_MODE_DISABLED
	model.scale = Vector3.ONE * 3.2
	model.rotation_degrees = Vector3(-8, -42, 0)
	_preview_root.add_child(model)
	_hide_preview_effects(model)


func _hide_preview_effects(node: Node) -> void:
	if node is Node3D and (node.name == "MuzzleFlash" or node.name == "LaserOrigin"):
		(node as Node3D).visible = false
	for child in node.get_children():
		_hide_preview_effects(child)


func _clear_weapon_preview() -> void:
	if not is_instance_valid(_preview_root):
		return
	for child in _preview_root.get_children():
		_preview_root.remove_child(child)
		child.queue_free()


func _card_style(hovered: bool, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.075, 0.05, 0.98) if selected else Color(0.075, 0.082, 0.094, 0.96)
	style.border_color = ACCENT if selected or hovered else Color(0.2, 0.22, 0.25)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(6)
	return style


func _set_feedback(message: String, error: bool) -> void:
	_feedback.text = message
	_feedback.add_theme_color_override(
		"font_color", Color(1.0, 0.42, 0.18) if error else Color(0.68, 0.72, 0.75)
	)


func _queue_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_run_queued_refresh")


func _run_queued_refresh() -> void:
	_refresh_pending = false
	_refresh()


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


func _on_stash_changed(property_id: StringName) -> void:
	if _is_open and property_id == _property_id:
		_queue_refresh()


func _on_inventory_changed(_product: ProductDefinition, _quantity: int) -> void:
	if _is_open:
		_queue_refresh()


func _on_weapon_changed(_definition: WeaponDefinition) -> void:
	if _is_open:
		_queue_refresh()
