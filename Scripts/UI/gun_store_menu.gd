class_name GunStoreMenu
extends CanvasLayer

const ACCENT := Color(0.93, 0.68, 0.16, 1.0)
const GREEN := Color(0.39, 0.72, 0.26, 1.0)

@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var weapon_component_path := NodePath("../Components/WeaponComponent")
@export var store_service_path := NodePath("../Components/GunStoreService")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var weapon := get_node(weapon_component_path) as PlayerWeaponComponent
@onready var store := get_node(store_service_path) as GunStoreService
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController

var _root: Control
var _weapon_list: VBoxContainer
var _preview_pivot: Node3D
var _preview_instance: Node3D
var _name_label: Label
var _description_label: Label
var _stats_label: Label
var _balance_label: Label
var _feedback_label: Label
var _purchase_button: Button
var _ammo_button: Button
var _attachment_list: VBoxContainer
var _selected: WeaponDefinition
var _is_open := false
var _dragging := false
var _last_mouse_x := 0.0
var _preview_generation := 0


func _ready() -> void:
	_build_ui()
	_root.visible = false
	var catalog := weapon.get_catalog_weapons()
	if not catalog.is_empty():
		_selected = catalog[0]
	store.transaction_finished.connect(_on_transaction_finished)
	wallet.money_changed.connect(_on_money_changed)
	weapon.attachments_changed.connect(_on_weapon_changed)
	weapon.ammo_changed.connect(_on_ammo_changed)
	set_process(true)


func _process(delta: float) -> void:
	if _is_open and _preview_pivot != null and not _dragging:
		_preview_pivot.rotation.y += delta * 0.35


func _input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open_store() -> void:
	if not menu_controller.request_open(&"gun_store"):
		return
	_is_open = true
	_root.visible = true
	_feedback_label.text = ""
	_refresh()


func close() -> void:
	if not _is_open or not menu_controller.close(&"gun_store"):
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
	dimmer.color = Color(0.005, 0.006, 0.008, 0.92)
	_root.add_child(dimmer)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		outer.add_theme_constant_override(side, 22)
	_root.add_child(outer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.039, 0.045, 0.99), Color(0.18, 0.19, 0.2, 1.0), 3, 10))
	outer.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	panel.add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 74
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)
	var title := Label.new()
	title.text = "  WEAPON SHOP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.92, 0.91, 0.86))
	header.add_child(title)
	_balance_label = Label.new()
	_balance_label.add_theme_font_size_override("font_size", 24)
	_balance_label.add_theme_color_override("font_color", GREEN)
	_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_balance_label)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(70, 54)
	_style_button(close_button, Color(0.75, 0.23, 0.18))
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	page.add_child(content)

	var left := _section("WEAPONS")
	left.custom_minimum_size.x = 280
	content.add_child(left)
	_weapon_list = VBoxContainer.new()
	_weapon_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_weapon_list.add_theme_constant_override("separation", 10)
	(left.get_child(0) as VBoxContainer).add_child(_weapon_list)

	var middle := _section("3D PREVIEW")
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(middle)
	var middle_box := middle.get_child(0) as VBoxContainer
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(440, 410)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.027, 0.031), Color(0.16, 0.16, 0.17), 1, 4))
	viewport_container.gui_input.connect(_on_preview_input)
	middle_box.add_child(viewport_container)
	var preview := SubViewport.new()
	preview.size = Vector2i(700, 500)
	preview.transparent_bg = true
	preview.own_world_3d = true
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(preview)
	_preview_pivot = Node3D.new()
	preview.add_child(_preview_pivot)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.25, 2.25)
	camera.look_at_from_position(camera.position, Vector3(0, 0.05, 0))
	camera.fov = 38.0
	preview.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_energy = 2.0
	key.light_color = Color(1.0, 0.86, 0.66)
	preview.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 145, 0)
	fill.light_energy = 1.15
	fill.light_color = Color(0.45, 0.58, 0.9)
	preview.add_child(fill)
	var hint := Label.new()
	hint.text = "DRAG TO ROTATE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.52))
	middle_box.add_child(hint)

	var right := _section("DETAILS")
	right.custom_minimum_size.x = 390
	content.add_child(right)
	var right_box := right.get_child(0) as VBoxContainer
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.add_theme_color_override("font_color", ACCENT)
	right_box.add_child(_name_label)
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_color_override("font_color", Color(0.7, 0.71, 0.72))
	right_box.add_child(_description_label)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 17)
	_stats_label.add_theme_color_override("font_color", Color(0.86, 0.86, 0.83))
	right_box.add_child(_stats_label)
	var attach_title := Label.new()
	attach_title.text = "ATTACHMENTS"
	attach_title.add_theme_font_size_override("font_size", 18)
	attach_title.add_theme_color_override("font_color", ACCENT)
	right_box.add_child(attach_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 235
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(scroll)
	_attachment_list = VBoxContainer.new()
	_attachment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attachment_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_attachment_list)
	_purchase_button = Button.new()
	_purchase_button.custom_minimum_size.y = 52
	_style_button(_purchase_button, GREEN)
	_purchase_button.pressed.connect(_buy_selected_weapon)
	right_box.add_child(_purchase_button)
	_ammo_button = Button.new()
	_ammo_button.custom_minimum_size.y = 46
	_style_button(_ammo_button, ACCENT)
	_ammo_button.pressed.connect(_buy_selected_ammo)
	right_box.add_child(_ammo_button)

	_feedback_label = Label.new()
	_feedback_label.custom_minimum_size.y = 34
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 18)
	page.add_child(_feedback_label)


func _section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.058, 0.064, 0.98), Color(0.13, 0.14, 0.15), 1, 5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.72, 0.72, 0.7))
	box.add_child(title)
	return panel


func _refresh() -> void:
	if _selected == null:
		return
	_balance_label.text = "CLEAN BANK  $%d   " % wallet.clean_cash
	for child in _weapon_list.get_children():
		_weapon_list.remove_child(child)
		child.queue_free()
	for definition in weapon.get_catalog_weapons():
		var button := Button.new()
		button.custom_minimum_size.y = 82
		var status := "OWNED" if weapon.owns_weapon(definition.weapon_id) else "$%d" % definition.purchase_price
		button.text = "%s\n%s" % [definition.display_name, status]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(button, ACCENT if definition == _selected else Color(0.35, 0.36, 0.38))
		button.pressed.connect(_select_weapon.bind(definition))
		_weapon_list.add_child(button)
	_name_label.text = _selected.display_name
	_description_label.text = _selected.description
	_stats_label.text = "DAMAGE        %.0f\nFIRE RATE     %.1f / sec\nRANGE         %.0f m\nRELOAD        %.1f sec\nMAGAZINE      %d rounds\nRESERVE       %d rounds" % [
		_selected.damage,
		_selected.get_rounds_per_second(),
		_selected.max_range,
		_selected.reload_duration,
		_selected.magazine_capacity,
		weapon.get_reserve_ammo_for(_selected.weapon_id),
	]
	var owned := weapon.owns_weapon(_selected.weapon_id)
	_purchase_button.text = "OWNED" if owned else "BUY  $%d" % _selected.purchase_price
	_purchase_button.disabled = owned or not wallet.can_spend_clean(_selected.purchase_price)
	_ammo_button.text = "BUY AMMO  +%d   $%d" % [_selected.ammo_bundle_amount, _selected.ammo_bundle_price]
	_ammo_button.disabled = not owned or not wallet.can_spend_clean(_selected.ammo_bundle_price)
	_refresh_attachments(owned)
	_refresh_preview()


func _refresh_attachments(weapon_owned: bool) -> void:
	for child in _attachment_list.get_children():
		_attachment_list.remove_child(child)
		child.queue_free()
	for attachment_id in PlayerWeaponComponent.STORE_ATTACHMENT_IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = store.get_attachment_name(attachment_id)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(126, 36)
		var unlocked := weapon.owns_attachment(_selected.weapon_id, attachment_id)
		var equipped := weapon.is_attachment_equipped(_selected.weapon_id, attachment_id)
		if not weapon_owned:
			button.text = "LOCKED"
			button.disabled = true
		elif not unlocked:
			var price := store.get_attachment_price(attachment_id)
			button.text = "BUY $%d" % price
			button.disabled = not wallet.can_spend_clean(price)
			button.pressed.connect(_buy_attachment.bind(attachment_id))
		else:
			button.text = "REMOVE" if equipped else "EQUIP"
			button.pressed.connect(_toggle_attachment.bind(attachment_id, not equipped))
		_style_button(button, GREEN if unlocked else ACCENT)
		row.add_child(button)
		_attachment_list.add_child(row)


func _refresh_preview() -> void:
	_preview_generation += 1
	if is_instance_valid(_preview_instance):
		_preview_instance.free()
	_preview_instance = null
	_preview_pivot.rotation = Vector3.ZERO
	if _selected.visual_scene == null:
		return
	_preview_instance = _selected.visual_scene.instantiate() as Node3D
	if _preview_instance == null:
		return
	_preview_pivot.add_child(_preview_instance)
	_preview_instance.rotation_degrees = Vector3(0, -90, 0)
	_preview_instance.scale = Vector3.ONE * (2.1 if _selected.weapon_id == &"pistol" else 1.35)
	var flash := _preview_instance.get_node_or_null("MuzzleFlash") as Node3D
	if flash != null:
		flash.visible = false
	var generation := _preview_generation
	_apply_preview_attachment_state(_selected.weapon_id, generation)
	# WeaponPresentation initializes its children with every attachment hidden.
	# Reapply after the preview scene's ready pass so that initialization cannot
	# overwrite the store's selected loadout.
	call_deferred("_apply_preview_attachment_state", _selected.weapon_id, generation)


func _apply_preview_attachment_state(weapon_id: StringName, generation: int) -> void:
	if generation != _preview_generation or not is_instance_valid(_preview_instance):
		return
	if _selected == null or _selected.weapon_id != weapon_id:
		return
	if not _preview_instance.has_method("apply_attachment_visuals"):
		return
	_preview_instance.call(
		"apply_attachment_visuals",
		weapon.is_attachment_equipped(weapon_id, &"sights"),
		weapon.is_attachment_equipped(weapon_id, &"laser"),
		_get_preview_magazine_type(),
		weapon.is_attachment_equipped(weapon_id, &"switch")
	)


func _get_preview_magazine_type() -> int:
	if weapon.is_attachment_equipped(_selected.weapon_id, &"drum"):
		return PlayerWeaponComponent.MagazineType.DRUM
	if weapon.is_attachment_equipped(_selected.weapon_id, &"extended"):
		return PlayerWeaponComponent.MagazineType.EXTENDED
	return PlayerWeaponComponent.MagazineType.STANDARD


func _select_weapon(definition: WeaponDefinition) -> void:
	_selected = definition
	_feedback_label.text = ""
	_refresh()


func _buy_selected_weapon() -> void:
	store.buy_weapon(_selected)


func _buy_selected_ammo() -> void:
	store.buy_ammo(_selected)


func _buy_attachment(attachment_id: StringName) -> void:
	store.buy_attachment(_selected, attachment_id)


func _toggle_attachment(attachment_id: StringName, enabled: bool) -> void:
	store.set_attachment_equipped(_selected, attachment_id, enabled)


func _on_transaction_finished(message: String, success: bool) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override("font_color", GREEN if success else Color(0.95, 0.33, 0.25))
	_refresh()


func _on_money_changed(_dirty: int, _clean: int) -> void:
	if _is_open:
		_refresh()


func _on_weapon_changed(_first: Variant = null, _second: Variant = null) -> void:
	if _is_open:
		_refresh()


func _on_ammo_changed(_magazine: int, _reserve: int) -> void:
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
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.09, 0.09, 0.09), accent.darkened(0.42), 1, 5))
	button.add_theme_stylebox_override("hover", _panel_style(accent.darkened(0.42), accent, 1, 5))
	button.add_theme_stylebox_override("pressed", _panel_style(accent.darkened(0.58), accent.lightened(0.1), 1, 5))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.045, 0.046, 0.048), Color(0.13, 0.13, 0.13), 1, 5))
	button.add_theme_color_override("font_color", Color(0.95, 0.94, 0.89))
	button.add_theme_color_override("font_disabled_color", Color(0.38, 0.38, 0.38))
