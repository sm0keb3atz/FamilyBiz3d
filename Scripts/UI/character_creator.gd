class_name CharacterCreator
extends Control

const ACCENT := Color(0.73, 0.38, 0.96, 1.0)
const GOLD := Color(0.94, 0.72, 0.2, 1.0)
const GREEN := Color(0.39, 0.72, 0.26, 1.0)
const PREVIEW_SCENE := preload("res://Scenes/PlayerVisualModular.tscn")
const PREVIEW_ANIMATIONS := preload(
	"res://Assets/Animations/MainAnimationLibary.res"
)
const DIFFICULTY_NAMES := ["EASY", "MEDIUM", "HARD"]
const PRESET_NAMES := ["WHITE", "ASIAN", "BLACK"]

var _name_edit: LineEdit
var _difficulty_slider: HSlider
var _difficulty_label: Label
var _preset_label: Label
var _feedback_label: Label
var _category_buttons: Dictionary = {}
var _item_list: VBoxContainer
var _item_name_label: Label
var _item_variant_label: Label
var _color_controls: VBoxContainer
var _color_swatch: ColorRect
var _color_name_label: Label
var _preview_pivot: Node3D
var _preview_visual: Node3D
var _preview_appearance: PlayerAppearanceComponent
var _preview_generation := 0
var _selected_category := ClothingCatalog.CATEGORY_TOP
var _selected_by_category: Dictionary = {
	ClothingCatalog.CATEGORY_TOP: &"base_hoodie",
	ClothingCatalog.CATEGORY_BOTTOM: &"jeans",
	ClothingCatalog.CATEGORY_SHOES: &"sneakers",
}
var _colors: Dictionary = {
	&"base_hoodie": Color("f4f1e8"),
	&"tshirt_white": Color("f4f1e8"),
}
var _color_indices: Dictionary = {
	&"base_hoodie": 0,
	&"tshirt_white": 0,
}
var _dragging := false
var _last_mouse_x := 0.0
var _startup_flow: Variant


func _ready() -> void:
	_startup_flow = get_node("/root/StartupFlow")
	_build_ui()
	_rebuild_item_list()
	_refresh_selection()
	_refresh_preview()
	_name_edit.call_deferred("grab_focus")


func _process(delta: float) -> void:
	if _preview_pivot != null and not _dragging:
		_preview_pivot.rotation.y += delta * 0.2


func get_available_clothing_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in ClothingCatalog.get_all():
		if definition.starting_owned:
			result.append(definition.clothing_id)
	return result


func build_profile() -> Dictionary:
	var display_name := _name_edit.text.strip_edges() if _name_edit != null else ""
	if not PlayerIdentityComponent.is_valid_display_name(display_name):
		return {}
	var owned: Array[String] = []
	for clothing_id in ClothingCatalog.get_starting_ids():
		owned.append(String(clothing_id))
	var equipped := {}
	for category in _selected_by_category:
		equipped[String(category)] = String(_selected_by_category[category])
	var saved_colors := {}
	for clothing_id in _colors:
		var color := _colors[clothing_id] as Color
		saved_colors[String(clothing_id)] = [
			color.r,
			color.g,
			color.b,
			color.a,
		]
	return {
		"identity": {"display_name": display_name},
		"appearance": {
			"body_variant": "male",
			"skin_preset": String(_skin_preset_for_index(
				int(_difficulty_slider.value)
			)),
		},
		"wardrobe": {
			"owned": owned,
			"equipped": equipped,
			"colors": saved_colors,
		},
	}


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.008, 0.005, 0.012, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var top_rule := ColorRect.new()
	top_rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_rule.offset_bottom = 5.0
	top_rule.color = ACCENT
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_rule)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		outer.add_theme_constant_override(side, 24)
	add_child(outer)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	outer.add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 74
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "<  BACK"
	back_button.custom_minimum_size = Vector2(150, 52)
	_style_button(back_button, Color(0.4, 0.37, 0.44))
	back_button.pressed.connect(_startup_flow.show_main_menu)
	header.add_child(back_button)

	var title := Label.new()
	title.text = "CREATE YOUR CHARACTER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.97, 0.93, 0.99))
	header.add_child(title)

	var step := Label.new()
	step.text = "NEW GAME  /  STEP 1"
	step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step.add_theme_font_size_override("font_size", 17)
	step.add_theme_color_override("font_color", GOLD)
	header.add_child(step)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	page.add_child(content)

	_build_identity_section(content)
	_build_preview_section(content)
	_build_outfit_section(content)

	_feedback_label = Label.new()
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.custom_minimum_size.y = 34
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 17)
	_feedback_label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.42, 0.38)
	)
	page.add_child(_feedback_label)


func _build_identity_section(parent: HBoxContainer) -> void:
	var section := _section("IDENTITY")
	section.custom_minimum_size.x = 360
	parent.add_child(section)
	var box := section.get_child(0) as VBoxContainer

	var name_heading := _small_heading("DISPLAY NAME")
	box.add_child(name_heading)
	_name_edit = LineEdit.new()
	_name_edit.name = "DisplayNameEdit"
	_name_edit.placeholder_text = "ENTER YOUR NAME"
	_name_edit.max_length = PlayerIdentityComponent.MAX_NAME_LENGTH
	_name_edit.custom_minimum_size.y = 52
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _create_character())
	box.add_child(_name_edit)

	var name_hint := Label.new()
	name_hint.text = "2–24 CHARACTERS"
	name_hint.add_theme_font_size_override("font_size", 13)
	name_hint.add_theme_color_override("font_color", Color(0.55, 0.51, 0.58))
	box.add_child(name_hint)

	var gap := Control.new()
	gap.custom_minimum_size.y = 22
	box.add_child(gap)

	box.add_child(_small_heading("DIFFICULTY / SKIN PRESET"))
	_difficulty_label = Label.new()
	_difficulty_label.name = "DifficultyLabel"
	_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_difficulty_label.add_theme_font_size_override("font_size", 31)
	_difficulty_label.add_theme_color_override("font_color", GOLD)
	box.add_child(_difficulty_label)

	_difficulty_slider = HSlider.new()
	_difficulty_slider.name = "DifficultySlider"
	_difficulty_slider.min_value = 0
	_difficulty_slider.max_value = 2
	_difficulty_slider.step = 1
	_difficulty_slider.value = 1
	_difficulty_slider.custom_minimum_size.y = 52
	_difficulty_slider.value_changed.connect(_on_difficulty_changed)
	box.add_child(_difficulty_slider)

	var stops := HBoxContainer.new()
	box.add_child(stops)
	for label_text in DIFFICULTY_NAMES:
		var stop := Label.new()
		stop.text = label_text
		stop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stop.add_theme_font_size_override("font_size", 13)
		stops.add_child(stop)

	_preset_label = Label.new()
	_preset_label.name = "PresetLabel"
	_preset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preset_label.add_theme_font_size_override("font_size", 18)
	_preset_label.add_theme_color_override("font_color", ACCENT)
	box.add_child(_preset_label)

	var cosmetic := Label.new()
	cosmetic.text = "COSMETIC ONLY\nNO GAMEPLAY EFFECT — FOR NOW"
	cosmetic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cosmetic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cosmetic.add_theme_font_size_override("font_size", 14)
	cosmetic.add_theme_color_override(
		"font_color",
		Color(0.68, 0.64, 0.71)
	)
	box.add_child(cosmetic)
	_on_difficulty_changed(_difficulty_slider.value)


func _build_preview_section(parent: HBoxContainer) -> void:
	var section := _section("YOUR CHARACTER")
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var box := section.get_child(0) as VBoxContainer

	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "PreviewViewportContainer"
	viewport_container.custom_minimum_size = Vector2(500, 650)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.gui_input.connect(_on_preview_input)
	box.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(700, 760)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	_preview_pivot = Node3D.new()
	viewport.add_child(_preview_pivot)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.05, 2.45)
	camera.look_at_from_position(camera.position, Vector3(0, 1.0, 0))
	camera.fov = 31.0
	viewport.add_child(camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_energy = 2.25
	key.light_color = Color(1.0, 0.86, 0.7)
	viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 145, 0)
	fill.light_energy = 1.45
	fill.light_color = Color(0.55, 0.38, 1.0)
	viewport.add_child(fill)

	var hint := Label.new()
	hint.text = "DRAG TO ROTATE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.55, 0.5, 0.58))
	box.add_child(hint)


func _build_outfit_section(parent: HBoxContainer) -> void:
	var section := _section("STARTING OUTFIT")
	section.custom_minimum_size.x = 430
	parent.add_child(section)
	var box := section.get_child(0) as VBoxContainer

	var category_row := HBoxContainer.new()
	category_row.add_theme_constant_override("separation", 6)
	box.add_child(category_row)
	for entry in [
		[ClothingCatalog.CATEGORY_TOP, "TOPS"],
		[ClothingCatalog.CATEGORY_BOTTOM, "BOTTOMS"],
		[ClothingCatalog.CATEGORY_SHOES, "SHOES"],
	]:
		var button := Button.new()
		button.text = entry[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		button.pressed.connect(_select_category.bind(entry[0]))
		category_row.add_child(button)
		_category_buttons[entry[0]] = button

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 205
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_item_list = VBoxContainer.new()
	_item_list.name = "StarterItemList"
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_item_list)

	_item_name_label = Label.new()
	_item_name_label.add_theme_font_size_override("font_size", 25)
	_item_name_label.add_theme_color_override("font_color", ACCENT)
	box.add_child(_item_name_label)

	_item_variant_label = Label.new()
	_item_variant_label.add_theme_font_size_override("font_size", 15)
	_item_variant_label.add_theme_color_override(
		"font_color",
		Color(0.75, 0.7, 0.78)
	)
	box.add_child(_item_variant_label)

	_color_controls = VBoxContainer.new()
	_color_controls.name = "ColorControls"
	_color_controls.add_theme_constant_override("separation", 6)
	box.add_child(_color_controls)
	_color_controls.add_child(_small_heading("STARTING COLOR"))
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 7)
	_color_controls.add_child(color_row)
	var previous := Button.new()
	previous.text = "<"
	previous.custom_minimum_size = Vector2(46, 55)
	_style_button(previous, ACCENT)
	previous.pressed.connect(_cycle_color.bind(-1))
	color_row.add_child(previous)
	var color_center := VBoxContainer.new()
	color_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_row.add_child(color_center)
	_color_swatch = ColorRect.new()
	_color_swatch.custom_minimum_size.y = 32
	_color_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_center.add_child(_color_swatch)
	_color_name_label = Label.new()
	_color_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_color_name_label.add_theme_font_size_override("font_size", 13)
	color_center.add_child(_color_name_label)
	var next := Button.new()
	next.text = ">"
	next.custom_minimum_size = Vector2(46, 55)
	_style_button(next, ACCENT)
	next.pressed.connect(_cycle_color.bind(1))
	color_row.add_child(next)

	var create_button := Button.new()
	create_button.name = "CreateCharacterButton"
	create_button.text = "CREATE CHARACTER"
	create_button.custom_minimum_size.y = 62
	create_button.add_theme_font_size_override("font_size", 21)
	_style_button(create_button, GREEN)
	create_button.pressed.connect(_create_character)
	box.add_child(create_button)


func _rebuild_item_list() -> void:
	for child in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()
	for definition in _get_starter_items(_selected_category):
		var button := Button.new()
		button.custom_minimum_size.y = 56
		button.text = "%s\n%s" % [
			definition.display_name.to_upper(),
			definition.variant_name.to_upper(),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(
			button,
			ACCENT
			if _selected_by_category[_selected_category] == definition.clothing_id
			else Color(0.38, 0.35, 0.4)
		)
		button.pressed.connect(_select_item.bind(definition.clothing_id))
		_item_list.add_child(button)
	for category in _category_buttons:
		_style_button(
			_category_buttons[category],
			ACCENT if category == _selected_category else Color(0.35, 0.32, 0.38)
		)


func _refresh_selection() -> void:
	var selected_id := StringName(_selected_by_category[_selected_category])
	var definition := ClothingCatalog.get_by_id(selected_id)
	if definition == null:
		return
	_item_name_label.text = definition.display_name.to_upper()
	_item_variant_label.text = "STARTER ITEM  /  %s" % definition.variant_name.to_upper()
	_color_controls.visible = definition.tintable
	if definition.tintable:
		var index := int(_color_indices.get(selected_id, 0))
		var option: Dictionary = ClothingColorPalette.OPTIONS[index]
		_color_swatch.color = option.color
		_color_name_label.text = str(option.name).to_upper()


func _refresh_preview() -> void:
	_preview_generation += 1
	if is_instance_valid(_preview_visual):
		_preview_visual.free()
	_preview_visual = PREVIEW_SCENE.instantiate() as Node3D
	_preview_appearance = null
	if _preview_visual == null:
		return
	_preview_visual.scale = Vector3.ONE * 1.3
	_preview_visual.position.y = 0.4
	_preview_pivot.add_child(_preview_visual)
	_play_idle_preview(_preview_visual)
	var weapon_socket := _preview_visual.get_node_or_null(
		"Armature/GeneralSkeleton/WeaponSocket"
	) as Node3D
	if weapon_socket != null:
		weapon_socket.visible = false
	_preview_appearance = PlayerAppearanceComponent.new()
	_preview_appearance.skeleton_path = NodePath(
		"../Armature/GeneralSkeleton"
	)
	_preview_visual.add_child(_preview_appearance)
	call_deferred("_finish_preview", _preview_generation)


func _finish_preview(generation: int) -> void:
	if generation != _preview_generation or not is_instance_valid(_preview_appearance):
		return
	_preview_appearance.set_body_variant(
		PlayerAppearanceComponent.BODY_VARIANT_MALE
	)
	_preview_appearance.set_skin_difficulty(int(_difficulty_slider.value))
	for category in _selected_by_category:
		var clothing_id := StringName(_selected_by_category[category])
		var definition := ClothingCatalog.get_by_id(clothing_id)
		var color := _colors.get(clothing_id, Color.WHITE) as Color
		_preview_appearance.apply_clothing_definition(definition, color)


func _play_idle_preview(visual: Node3D) -> void:
	var animation_player := AnimationPlayer.new()
	animation_player.name = "PreviewAnimationPlayer"
	visual.add_child(animation_player)
	var preview_library := AnimationLibrary.new()
	var idle := PREVIEW_ANIMATIONS.get_animation(&"Idle").duplicate(true) as Animation
	for track_index in range(idle.get_track_count() - 1, -1, -1):
		if idle.track_get_type(track_index) == Animation.TYPE_SCALE_3D:
			idle.remove_track(track_index)
	preview_library.add_animation(&"Idle", idle)
	animation_player.add_animation_library(&"", preview_library)
	if animation_player.has_animation(&"Idle"):
		animation_player.play(&"Idle")


func _get_starter_items(category: StringName) -> Array[ClothingDefinition]:
	var result: Array[ClothingDefinition] = []
	for definition in ClothingCatalog.get_for_category(category):
		if definition.starting_owned:
			result.append(definition)
	return result


func _select_category(category: StringName) -> void:
	_selected_category = category
	_rebuild_item_list()
	_refresh_selection()


func _select_item(clothing_id: StringName) -> void:
	var definition := ClothingCatalog.get_by_id(clothing_id)
	if definition == null or not definition.starting_owned:
		return
	_selected_by_category[definition.category] = clothing_id
	_rebuild_item_list()
	_refresh_selection()
	_refresh_preview()


func _cycle_color(direction: int) -> void:
	var clothing_id := StringName(_selected_by_category[_selected_category])
	var definition := ClothingCatalog.get_by_id(clothing_id)
	if definition == null or not definition.tintable:
		return
	var next_index := wrapi(
		int(_color_indices.get(clothing_id, 0)) + direction,
		0,
		ClothingColorPalette.OPTIONS.size()
	)
	_color_indices[clothing_id] = next_index
	_colors[clothing_id] = ClothingColorPalette.OPTIONS[next_index].color
	_refresh_selection()
	_refresh_preview()


func _on_difficulty_changed(value: float) -> void:
	var index := clampi(int(value), 0, 2)
	_difficulty_label.text = DIFFICULTY_NAMES[index]
	_preset_label.text = "%s PRESET" % PRESET_NAMES[index]
	if is_instance_valid(_preview_appearance):
		_preview_appearance.set_skin_difficulty(index)


func _skin_preset_for_index(index: int) -> StringName:
	match index:
		0:
			return PlayerAppearanceComponent.SKIN_PRESET_EASY
		1:
			return PlayerAppearanceComponent.SKIN_PRESET_MEDIUM
		_:
			return PlayerAppearanceComponent.SKIN_PRESET_HARD


func _create_character() -> void:
	var profile := build_profile()
	if profile.is_empty():
		_feedback_label.text = "ENTER A NAME BETWEEN 2 AND 24 CHARACTERS."
		_name_edit.grab_focus()
		return
	_feedback_label.text = ""
	_startup_flow.begin_new_game(profile)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_last_mouse_x = event.position.x
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_preview_pivot.rotation.y += (motion.position.x - _last_mouse_x) * 0.01
		_last_mouse_x = motion.position.x


func _section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.04, 0.032, 0.052, 0.96),
			Color(0.22, 0.14, 0.28),
			1,
			8
		)
	)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.78, 0.72, 0.82))
	box.add_child(title)
	return panel


func _small_heading(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.58, 0.54, 0.62))
	return label


func _style_button(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.35, 0.33, 0.37))
	button.add_theme_stylebox_override(
		"normal",
		_panel_style(color.darkened(0.72), color.darkened(0.18), 1, 5)
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(color.darkened(0.52), color, 2, 5)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_panel_style(color.darkened(0.4), color.lightened(0.12), 2, 5)
	)
	button.add_theme_stylebox_override(
		"focus",
		_panel_style(color.darkened(0.58), color, 2, 5)
	)


func _panel_style(
	background: Color,
	border: Color,
	border_width: int,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style
