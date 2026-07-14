class_name PlayerInventoryMenu
extends CanvasLayer

@export var inventory_component_path := NodePath(
	"../Components/InventoryComponent"
)
@export var weapon_component_path := NodePath("../Components/WeaponComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")
@export var girlfriend_component_path := NodePath("../Components/GirlfriendComponent")
@export var property_component_path := NodePath("../Components/PropertyComponent")

@onready var menu_root := %MenuRoot as Control
@onready var tab_container := %TabContainer as TabContainer
@onready var drug_list := %DrugList as VBoxContainer
@onready var weapon_list := %WeaponList as VBoxContainer
@onready var girlfriend_list := %GirlfriendList as VBoxContainer
@onready var property_list := %PropertyList as VBoxContainer
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

var _is_open := false


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
	_style_tabs()
	menu_root.visible = false
	_refresh()


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


func _refresh() -> void:
	_refresh_drugs()
	_refresh_weapons()
	_refresh_girlfriends()
	_refresh_properties()


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
