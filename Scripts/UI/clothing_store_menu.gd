class_name ClothingStoreMenu
extends CanvasLayer

const ACCENT := Color(0.73, 0.38, 0.96, 1.0)
const GREEN := Color(0.39, 0.72, 0.26, 1.0)
const PREVIEW_SCENE := preload("res://Scenes/PlayerVisualModular.tscn")
const BusinessManagementPanelScript := preload("res://Scripts/UI/business_management_panel.gd")
const COLOR_OPTIONS := [
	{"name": "White", "color": Color("f4f1e8")},
	{"name": "Cream", "color": Color("e8dcc4")},
	{"name": "Black", "color": Color("151419")},
	{"name": "Charcoal", "color": Color("34343c")},
	{"name": "Slate Grey", "color": Color("626776")},
	{"name": "Silver", "color": Color("aeb4c0")},
	{"name": "Scarlet", "color": Color("db2b39")},
	{"name": "Burgundy", "color": Color("702c3e")},
	{"name": "Burnt Orange", "color": Color("c65d28")},
	{"name": "Gold", "color": Color("d6a72e")},
	{"name": "Sun Yellow", "color": Color("e8cf45")},
	{"name": "Forest Green", "color": Color("315a45")},
	{"name": "Emerald", "color": Color("25855e")},
	{"name": "Mint", "color": Color("8fd9bd")},
	{"name": "Teal", "color": Color("257b7c")},
	{"name": "Sky Blue", "color": Color("6fb8e8")},
	{"name": "Royal Blue", "color": Color("3158c9")},
	{"name": "Navy", "color": Color("202f59")},
	{"name": "Purple", "color": Color("713ea8")},
	{"name": "Lavender", "color": Color("b8a1dc")},
	{"name": "Hot Pink", "color": Color("d9478d")},
	{"name": "Rose", "color": Color("b8546f")},
	{"name": "Pastel Peach", "color": Color("f1b89f")},
	{"name": "Pastel Yellow", "color": Color("f2dda0")},
	{"name": "Pastel Green", "color": Color("b8dfb1")},
	{"name": "Pastel Blue", "color": Color("aecff0")},
	{"name": "Pastel Purple", "color": Color("cbb7e8")},
	{"name": "Pastel Pink", "color": Color("efbdd5")},
]

@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var wardrobe_component_path := NodePath("../Components/WardrobeComponent")
@export var appearance_component_path := NodePath("../Components/AppearanceComponent")
@export var store_service_path := NodePath("../Components/ClothingStoreService")
@export var menu_controller_path := NodePath("../Components/MenuController")
@export var property_component_path := NodePath("../Components/PropertyComponent")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var wardrobe := get_node(wardrobe_component_path) as PlayerWardrobeComponent
@onready var appearance := get_node(appearance_component_path) as PlayerAppearanceComponent
@onready var store := get_node(store_service_path) as ClothingStoreService
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController
@onready var properties := get_node(property_component_path) as PlayerPropertyComponent

var _root: Control
var _title_label: Label
var _item_list: VBoxContainer
var _filter_box: VBoxContainer
var _type_row: HBoxContainer
var _brand_row: GridContainer
var _browse_label: Label
var _category_buttons: Dictionary[StringName, Button] = {}
var _store_tabs: HBoxContainer
var _categories: HBoxContainer
var _shop_content: HBoxContainer
var _business_panel: VBoxContainer
var _shop_tab: Button
var _business_tab: Button
var _preview_pivot: Node3D
var _preview_visual: Node3D
var _preview_appearance: PlayerAppearanceComponent
var _name_label: Label
var _variant_label: Label
var _price_label: Label
var _aura_label: Label
var _total_aura_label: Label
var _feedback_label: Label
var _action_button: Button
var _color_row: VBoxContainer
var _color_swatch: ColorRect
var _color_name_label: Label
var _color_apply_button: Button
var _category := ClothingCatalog.CATEGORY_TOP
var _selected_type := ClothingCatalog.TYPE_HOODIE
var _selected_brand := "Base"
var _selected: ClothingDefinition
var _trial_color := Color.WHITE
var _color_index := 0
var _is_open := false
var _wardrobe_mode := false
var _active_menu_id: StringName = &"clothing_store"
var _dragging := false
var _last_mouse_x := 0.0
var _preview_generation := 0


func _ready() -> void:
	_build_ui()
	_root.visible = false
	_select_first_for_category()
	store.transaction_finished.connect(_on_transaction_finished)
	wallet.money_changed.connect(_on_money_changed)
	wardrobe.ownership_changed.connect(_on_wardrobe_changed)
	wardrobe.equipped_changed.connect(_on_wardrobe_changed)
	wardrobe.clothing_color_changed.connect(_on_wardrobe_changed)
	appearance.aura_changed.connect(_on_aura_changed)


func _process(delta: float) -> void:
	if _is_open and _preview_pivot != null and not _dragging:
		_preview_pivot.rotation.y += delta * 0.25


func _input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open_store() -> void:
	if not menu_controller.request_open(&"clothing_store"):
		return
	_wardrobe_mode = false
	_active_menu_id = &"clothing_store"
	_title_label.text = "  CLOTHING SHOP"
	_store_tabs.visible = true
	_set_store_tab(false)
	_select_first_for_category()
	_is_open = true
	_root.visible = true
	_feedback_label.text = ""
	_refresh()


func open_wardrobe() -> void:
	if not menu_controller.request_open(&"wardrobe"):
		return
	_wardrobe_mode = true
	_active_menu_id = &"wardrobe"
	_title_label.text = "  HOME WARDROBE"
	_store_tabs.visible = false
	_set_store_tab(false)
	_select_first_for_category()
	_is_open = true
	_root.visible = true
	_feedback_label.text = "Choose from clothing you own."
	_refresh()


func close() -> void:
	if not _is_open or not menu_controller.close(_active_menu_id):
		return
	_is_open = false
	_dragging = false
	_root.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.008, 0.005, 0.012, 0.93)
	_root.add_child(dimmer)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		outer.add_theme_constant_override(side, 22)
	_root.add_child(outer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.03, 0.043), Color(0.25, 0.17, 0.3), 3, 10))
	outer.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	panel.add_child(page)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 74
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)
	_title_label = Label.new()
	_title_label.text = "  CLOTHING SHOP"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.98))
	header.add_child(_title_label)
	_total_aura_label = Label.new()
	_total_aura_label.add_theme_font_size_override("font_size", 24)
	_total_aura_label.add_theme_color_override(
		"font_color",
		Color(0.94, 0.72, 0.2)
	)
	_total_aura_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_total_aura_label)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(70, 54)
	_style_button(close_button, Color(0.75, 0.23, 0.18))
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_store_tabs = HBoxContainer.new()
	_store_tabs.name = "StoreTabs"
	_store_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_store_tabs.add_theme_constant_override("separation", 10)
	page.add_child(_store_tabs)
	_shop_tab = Button.new()
	_shop_tab.name = "ShopTab"
	_shop_tab.text = "SHOP"
	_shop_tab.custom_minimum_size = Vector2(190, 42)
	_shop_tab.pressed.connect(_set_store_tab.bind(false))
	_store_tabs.add_child(_shop_tab)
	_business_tab = Button.new()
	_business_tab.name = "BusinessTab"
	_business_tab.text = "BUSINESS"
	_business_tab.custom_minimum_size = Vector2(190, 42)
	_business_tab.pressed.connect(_set_store_tab.bind(true))
	_store_tabs.add_child(_business_tab)
	_categories = HBoxContainer.new()
	_categories.name = "ShopCategories"
	_categories.alignment = BoxContainer.ALIGNMENT_CENTER
	_categories.add_theme_constant_override("separation", 10)
	page.add_child(_categories)
	for entry in [[ClothingCatalog.CATEGORY_TOP, "TOPS"], [ClothingCatalog.CATEGORY_BOTTOM, "BOTTOMS"], [ClothingCatalog.CATEGORY_SHOES, "SHOES"]]:
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size = Vector2(180, 42)
		_style_button(button, ACCENT)
		button.pressed.connect(_select_category.bind(entry[0]))
		_categories.add_child(button)
		_category_buttons[entry[0]] = button
	_shop_content = HBoxContainer.new()
	_shop_content.name = "ShopContent"
	_shop_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_content.add_theme_constant_override("separation", 14)
	page.add_child(_shop_content)
	var left := _section("CATALOG")
	left.custom_minimum_size.x = 290
	_shop_content.add_child(left)
	var left_box := left.get_child(0) as VBoxContainer
	_filter_box = VBoxContainer.new()
	_filter_box.add_theme_constant_override("separation", 8)
	left_box.add_child(_filter_box)
	var type_heading := Label.new()
	type_heading.text = "TYPE"
	type_heading.add_theme_font_size_override("font_size", 13)
	type_heading.add_theme_color_override("font_color", Color(0.58, 0.54, 0.62))
	_filter_box.add_child(type_heading)
	_type_row = HBoxContainer.new()
	_type_row.add_theme_constant_override("separation", 6)
	_filter_box.add_child(_type_row)
	var brand_heading := Label.new()
	brand_heading.text = "BRAND"
	brand_heading.add_theme_font_size_override("font_size", 13)
	brand_heading.add_theme_color_override("font_color", Color(0.58, 0.54, 0.62))
	_filter_box.add_child(brand_heading)
	_brand_row = GridContainer.new()
	_brand_row.columns = 2
	_brand_row.add_theme_constant_override("h_separation", 6)
	_brand_row.add_theme_constant_override("v_separation", 6)
	_filter_box.add_child(_brand_row)
	_browse_label = Label.new()
	_browse_label.add_theme_font_size_override("font_size", 15)
	_browse_label.add_theme_color_override("font_color", Color(0.82, 0.74, 0.88))
	left_box.add_child(_browse_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(scroll)
	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_item_list)
	var middle := _section("YOUR CHARACTER")
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_content.add_child(middle)
	var middle_box := middle.get_child(0) as VBoxContainer
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(440, 450)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.gui_input.connect(_on_preview_input)
	middle_box.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(700, 560)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	_preview_pivot = Node3D.new()
	viewport.add_child(_preview_pivot)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.02, 2.3)
	camera.look_at_from_position(camera.position, Vector3(0, 1.0, 0))
	camera.fov = 32.0
	viewport.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_energy = 2.1
	key.light_color = Color(1.0, 0.87, 0.72)
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 145, 0)
	fill.light_energy = 1.2
	fill.light_color = Color(0.55, 0.42, 0.95)
	viewport.add_child(fill)
	var hint := Label.new()
	hint.text = "DRAG TO ROTATE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.55, 0.5, 0.58))
	middle_box.add_child(hint)
	var right := _section("ITEM DETAILS")
	right.custom_minimum_size.x = 325
	_shop_content.add_child(right)
	var right_box := right.get_child(0) as VBoxContainer
	_name_label = Label.new()
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", ACCENT)
	right_box.add_child(_name_label)
	_variant_label = Label.new()
	_variant_label.add_theme_font_size_override("font_size", 17)
	_variant_label.add_theme_color_override("font_color", Color(0.76, 0.72, 0.79))
	right_box.add_child(_variant_label)
	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", 23)
	right_box.add_child(_price_label)
	_aura_label = Label.new()
	_aura_label.add_theme_font_size_override("font_size", 21)
	_aura_label.add_theme_color_override("font_color", Color(0.94, 0.72, 0.2))
	right_box.add_child(_aura_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(spacer)
	_color_row = VBoxContainer.new()
	var color_label := Label.new()
	color_label.text = "CUSTOM COLOR"
	color_label.add_theme_font_size_override("font_size", 17)
	_color_row.add_child(color_label)
	var color_selector := HBoxContainer.new()
	color_selector.add_theme_constant_override("separation", 8)
	_color_row.add_child(color_selector)
	var previous_color := Button.new()
	previous_color.text = "<"
	previous_color.custom_minimum_size = Vector2(48, 58)
	_style_button(previous_color, ACCENT)
	previous_color.pressed.connect(_cycle_color.bind(-1))
	color_selector.add_child(previous_color)
	var color_center := VBoxContainer.new()
	color_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_center.add_theme_constant_override("separation", 4)
	color_selector.add_child(color_center)
	_color_swatch = ColorRect.new()
	_color_swatch.custom_minimum_size.y = 36
	_color_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_center.add_child(_color_swatch)
	_color_name_label = Label.new()
	_color_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_color_name_label.add_theme_font_size_override("font_size", 14)
	color_center.add_child(_color_name_label)
	var next_color := Button.new()
	next_color.text = ">"
	next_color.custom_minimum_size = Vector2(48, 58)
	_style_button(next_color, ACCENT)
	next_color.pressed.connect(_cycle_color.bind(1))
	color_selector.add_child(next_color)
	var color_cost := Label.new()
	color_cost.text = "COLOR SERVICE  $%d CLEAN" % ClothingStoreService.COLOR_CHANGE_PRICE
	color_cost.add_theme_color_override("font_color", Color(0.62, 0.75, 0.58))
	_color_row.add_child(color_cost)
	_color_apply_button = Button.new()
	_color_apply_button.text = "APPLY COLOR  $%d" % ClothingStoreService.COLOR_CHANGE_PRICE
	_color_apply_button.custom_minimum_size.y = 44
	_style_button(_color_apply_button, ACCENT)
	_color_apply_button.pressed.connect(_buy_color_change)
	_color_row.add_child(_color_apply_button)
	right_box.add_child(_color_row)
	_action_button = Button.new()
	_action_button.custom_minimum_size.y = 56
	_style_button(_action_button, GREEN)
	_action_button.pressed.connect(_perform_action)
	right_box.add_child(_action_button)
	_business_panel = BusinessManagementPanelScript.new()
	page.add_child(_business_panel)
	_business_panel.setup(PropertyCatalog.CLOTHING_STORE_ID, properties, wallet)
	_feedback_label = Label.new()
	_feedback_label.custom_minimum_size.y = 34
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 18)
	page.add_child(_feedback_label)
	_set_store_tab(false)


func _set_store_tab(show_business: bool) -> void:
	if _shop_content == null or _business_panel == null:
		return
	if _wardrobe_mode:
		show_business = false
	_categories.visible = not show_business
	_shop_content.visible = not show_business
	_business_panel.visible = show_business
	_shop_tab.disabled = false
	_business_tab.disabled = false
	_style_button(_shop_tab, ACCENT)
	_style_button(_business_tab, ACCENT)
	var active_tab := _business_tab if show_business else _shop_tab
	active_tab.add_theme_stylebox_override(
		"normal",
		_panel_style(ACCENT.darkened(0.55), ACCENT, 1, 5)
	)
	if show_business:
		_feedback_label.text = ""
		_business_panel.refresh()


func _section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.052, 0.07), Color(0.18, 0.13, 0.22), 1, 5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.75, 0.7, 0.78))
	box.add_child(title)
	return panel


func _refresh() -> void:
	if _selected == null:
		return
	_total_aura_label.text = "TOTAL AURA  %d   " % appearance.get_current_aura()
	for category in _category_buttons:
		_style_button(
			_category_buttons[category],
			ACCENT if category == _category else Color(0.32, 0.3, 0.35)
		)
	_rebuild_filters()
	for child in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()
	for definition in _get_visible_items():
		var button := Button.new()
		button.custom_minimum_size.y = 58
		var status := "OWNED" if wardrobe.owns(definition.clothing_id) else "$%d" % definition.price
		button.text = "%s\n%s" % [definition.variant_name, status]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(button, ACCENT if definition == _selected else Color(0.38, 0.35, 0.4))
		button.pressed.connect(_select_item.bind(definition))
		_item_list.add_child(button)
	_name_label.text = "%s\n%s" % [_selected.brand, _selected.display_name]
	_variant_label.text = "VARIANT  %s" % _selected.variant_name.to_upper()
	_price_label.text = "OWNED" if wardrobe.owns(_selected.clothing_id) else "PRICE  $%d" % _selected.price
	_aura_label.text = "AURA  +%d" % _selected.aura
	_color_row.visible = _selected.tintable and not _wardrobe_mode
	_refresh_color_selector()
	_color_apply_button.disabled = (
		not wardrobe.owns(_selected.clothing_id)
		or wardrobe.get_item_color(_selected.clothing_id).is_equal_approx(_trial_color)
		or not wallet.can_spend_clean(ClothingStoreService.COLOR_CHANGE_PRICE)
	)
	var owned := wardrobe.owns(_selected.clothing_id)
	var equipped := wardrobe.get_equipped_id(_selected.category) == _selected.clothing_id
	if equipped:
		_action_button.text = "EQUIPPED"
		_action_button.disabled = true
	elif owned:
		_action_button.text = "EQUIP"
		_action_button.disabled = false
	elif not _wardrobe_mode:
		_action_button.text = "BUY  $%d" % _selected.price
		_action_button.disabled = not wallet.can_spend_clean(_selected.price)
	else:
		_action_button.text = "UNAVAILABLE"
		_action_button.disabled = true
	_refresh_preview()


func _refresh_preview() -> void:
	_preview_generation += 1
	if is_instance_valid(_preview_visual):
		_preview_visual.free()
	_preview_visual = PREVIEW_SCENE.instantiate() as Node3D
	_preview_appearance = null
	_preview_pivot.rotation = Vector3.ZERO
	if _preview_visual == null:
		return
	_preview_visual.scale = Vector3.ONE * 1.25
	_preview_visual.position.y = 0.42
	_preview_pivot.add_child(_preview_visual)
	var weapon_socket := _preview_visual.get_node_or_null(
		"Armature/GeneralSkeleton/WeaponSocket"
	) as Node3D
	if weapon_socket != null:
		weapon_socket.visible = false
	_preview_appearance = PlayerAppearanceComponent.new()
	_preview_appearance.skeleton_path = NodePath("../Armature/GeneralSkeleton")
	_preview_visual.add_child(_preview_appearance)
	call_deferred("_finish_preview", _preview_generation)


func _finish_preview(generation: int) -> void:
	if generation != _preview_generation or not is_instance_valid(_preview_appearance):
		return
	wardrobe.apply_outfit_to(_preview_appearance, _selected.clothing_id)
	if _selected.tintable and not _wardrobe_mode:
		_preview_appearance.apply_clothing_definition(_selected, _trial_color)
	appearance.copy_skeleton_pose_to(_preview_appearance)


func _get_visible_items() -> Array[ClothingDefinition]:
	if _wardrobe_mode:
		var owned: Array[ClothingDefinition] = []
		for definition in ClothingCatalog.get_for_category(_category):
			if wardrobe.owns(definition.clothing_id):
				owned.append(definition)
		return owned
	if _category == ClothingCatalog.CATEGORY_TOP:
		return ClothingCatalog.get_filtered(
			_category,
			_selected_type,
			_selected_brand
		)
	return ClothingCatalog.get_for_category(_category)


func _rebuild_filters() -> void:
	_filter_box.visible = _category == ClothingCatalog.CATEGORY_TOP and not _wardrobe_mode
	if not _filter_box.visible:
		_browse_label.text = "%s YOU OWN" % String(_category).to_upper() if _wardrobe_mode else String(_category).to_upper()
		return
	for child in _type_row.get_children():
		_type_row.remove_child(child)
		child.queue_free()
	for entry in [
		[ClothingCatalog.TYPE_HOODIE, "HOODIES"],
		[ClothingCatalog.TYPE_TSHIRT, "T-SHIRTS"],
	]:
		var button := Button.new()
		button.text = entry[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(button, ACCENT if entry[0] == _selected_type else Color(0.38, 0.35, 0.4))
		button.pressed.connect(_select_type.bind(entry[0]))
		_type_row.add_child(button)
	for child in _brand_row.get_children():
		_brand_row.remove_child(child)
		child.queue_free()
	for brand in ClothingCatalog.get_brands(_category, _selected_type):
		var button := Button.new()
		button.text = brand.to_upper()
		button.custom_minimum_size.y = 36
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(button, ACCENT if brand == _selected_brand else Color(0.38, 0.35, 0.4))
		button.pressed.connect(_select_brand.bind(brand))
		_brand_row.add_child(button)
	_browse_label.text = "%s  /  %s  /  VARIANTS" % [
		"HOODIES" if _selected_type == ClothingCatalog.TYPE_HOODIE else "T-SHIRTS",
		_selected_brand.to_upper(),
	]


func _select_type(clothing_type: StringName) -> void:
	_selected_type = clothing_type
	var brands := ClothingCatalog.get_brands(_category, clothing_type)
	_selected_brand = brands[0] if not brands.is_empty() else ""
	_select_first_for_category()
	_feedback_label.text = ""
	_refresh()


func _select_brand(brand: String) -> void:
	_selected_brand = brand
	_select_first_for_category()
	_feedback_label.text = ""
	_refresh()


func _select_category(category: StringName) -> void:
	_category = category
	if category == ClothingCatalog.CATEGORY_TOP:
		_selected_type = ClothingCatalog.TYPE_HOODIE
		_selected_brand = "Base"
	else:
		_selected_type = &""
		_selected_brand = ""
	_select_first_for_category()
	_feedback_label.text = ""
	_refresh()


func _select_first_for_category() -> void:
	var entries := _get_visible_items()
	_selected = entries[0] if not entries.is_empty() else null
	if _selected != null:
		_select_nearest_color(wardrobe.get_item_color(_selected.clothing_id))


func _select_item(definition: ClothingDefinition) -> void:
	_selected = definition
	_select_nearest_color(wardrobe.get_item_color(definition.clothing_id))
	_feedback_label.text = ""
	_refresh()


func _perform_action() -> void:
	if _selected == null:
		return
	if wardrobe.owns(_selected.clothing_id):
		store.equip(_selected.clothing_id)
	elif not _wardrobe_mode:
		store.buy(_selected.clothing_id)


func _cycle_color(direction: int) -> void:
	_set_color_index(wrapi(_color_index + direction, 0, COLOR_OPTIONS.size()))


func _set_color_index(index: int) -> void:
	_color_index = clampi(index, 0, COLOR_OPTIONS.size() - 1)
	_trial_color = COLOR_OPTIONS[_color_index]["color"] as Color
	_refresh_color_selector()
	if _selected != null:
		_color_apply_button.disabled = (
			wardrobe.get_item_color(_selected.clothing_id).is_equal_approx(
				_trial_color
			)
			or not wallet.can_spend_clean(
				ClothingStoreService.COLOR_CHANGE_PRICE
			)
		)
	if is_instance_valid(_preview_appearance) and _selected != null:
		_preview_appearance.apply_clothing_definition(
			_selected,
			_trial_color
		)


func _refresh_color_selector() -> void:
	if _color_swatch == null or COLOR_OPTIONS.is_empty():
		return
	var option: Dictionary = COLOR_OPTIONS[_color_index]
	_color_swatch.color = option["color"] as Color
	_color_name_label.text = str(option["name"]).to_upper()


func _select_nearest_color(color: Color) -> void:
	var best_index := 0
	var best_distance := INF
	for index in COLOR_OPTIONS.size():
		var candidate := COLOR_OPTIONS[index]["color"] as Color
		var distance := (
			pow(candidate.r - color.r, 2)
			+ pow(candidate.g - color.g, 2)
			+ pow(candidate.b - color.b, 2)
		)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	_set_color_index(best_index)


func _buy_color_change() -> void:
	if _selected != null and _selected.tintable:
		store.buy_color_change(_selected.clothing_id, _trial_color)


func _on_transaction_finished(message: String, success: bool) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override("font_color", GREEN if success else Color(0.95, 0.33, 0.25))
	_refresh()


func _on_money_changed(_dirty: int, _clean: int) -> void:
	if _is_open:
		_refresh()


func _on_aura_changed(current: int) -> void:
	if _total_aura_label != null:
		_total_aura_label.text = "TOTAL AURA  %d   " % current


func _on_wardrobe_changed(_first: Variant = null, _second: Variant = null) -> void:
	if _is_open:
		_refresh()


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_last_mouse_x = event.position.x
	elif event is InputEventMouseMotion and _dragging:
		_preview_pivot.rotation.y += (event.position.x - _last_mouse_x) * 0.012
		_last_mouse_x = event.position.x


func _panel_style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_top = 14
	style.content_margin_right = 16
	style.content_margin_bottom = 14
	return style


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.09, 0.08, 0.1), accent.darkened(0.42), 1, 5))
	button.add_theme_stylebox_override("hover", _panel_style(accent.darkened(0.42), accent, 1, 5))
	button.add_theme_stylebox_override("pressed", _panel_style(accent.darkened(0.58), accent.lightened(0.1), 1, 5))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.045, 0.042, 0.05), Color(0.13, 0.12, 0.14), 1, 5))
	button.add_theme_color_override("font_color", Color(0.96, 0.94, 0.98))
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.37, 0.42))
