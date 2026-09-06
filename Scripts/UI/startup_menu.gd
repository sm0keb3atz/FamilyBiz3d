class_name StartupMenu
extends Control

const ACCENT := Color(0.73, 0.38, 0.96, 1.0)
const GOLD := Color(0.94, 0.72, 0.2, 1.0)
const PREVIEW_SCENE := preload("res://Scenes/PlayerVisualModular.tscn")
const PREVIEW_ANIMATIONS := preload(
	"res://Assets/Animations/MainAnimationLibary.res"
)

var _continue_button: Button
var _new_game_button: Button
var _confirmation: ConfirmationDialog
var _preview_pivot: Node3D
var _preview_visual: Node3D
var _preview_appearance: PlayerAppearanceComponent
var _startup_flow: Variant


func _ready() -> void:
	_startup_flow = get_node("/root/StartupFlow")
	_build_ui()
	_build_preview()
	_continue_button.disabled = not _startup_flow.has_valid_save()
	_new_game_button.call_deferred("grab_focus")


func _process(delta: float) -> void:
	if _preview_pivot != null:
		_preview_pivot.rotation.y += delta * 0.16


func is_continue_available() -> bool:
	return _continue_button != null and not _continue_button.disabled


func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.008, 0.005, 0.014, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var purple_glow := ColorRect.new()
	purple_glow.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	purple_glow.anchor_left = 0.55
	purple_glow.color = Color(0.13, 0.045, 0.18, 0.72)
	purple_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(purple_glow)

	var top_rule := ColorRect.new()
	top_rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_rule.offset_bottom = 5.0
	top_rule.color = ACCENT
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_rule)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 90)
	outer.add_theme_constant_override("margin_top", 65)
	outer.add_theme_constant_override("margin_right", 70)
	outer.add_theme_constant_override("margin_bottom", 65)
	add_child(outer)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 55)
	outer.add_child(layout)

	var menu_column := VBoxContainer.new()
	menu_column.custom_minimum_size.x = 570.0
	menu_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_column.add_theme_constant_override("separation", 16)
	layout.add_child(menu_column)

	var eyebrow := Label.new()
	eyebrow.text = "BUILD YOUR NAME.  PROTECT YOUR FAMILY."
	eyebrow.add_theme_font_size_override("font_size", 18)
	eyebrow.add_theme_color_override("font_color", GOLD)
	menu_column.add_child(eyebrow)

	var title := Label.new()
	title.text = "FAMILY\nBUSINESS"
	title.add_theme_font_size_override("font_size", 82)
	title.add_theme_color_override("font_color", Color(0.97, 0.94, 0.99))
	title.add_theme_constant_override("line_spacing", -12)
	menu_column.add_child(title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(430, 3)
	divider.color = ACCENT
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_column.add_child(divider)

	var subtitle := Label.new()
	subtitle.text = "EVERY EMPIRE STARTS WITH A CHOICE"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override(
		"font_color",
		Color(0.68, 0.63, 0.72)
	)
	menu_column.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	menu_column.add_child(spacer)

	_new_game_button = _menu_button("NewGameButton", "NEW GAME", ACCENT)
	_new_game_button.pressed.connect(_on_new_game)
	menu_column.add_child(_new_game_button)

	_continue_button = _menu_button(
		"ContinueButton",
		"CONTINUE",
		GOLD
	)
	_continue_button.pressed.connect(_startup_flow.begin_continue)
	menu_column.add_child(_continue_button)

	var quit_button := _menu_button(
		"QuitButton",
		"QUIT",
		Color(0.72, 0.22, 0.2)
	)
	quit_button.pressed.connect(get_tree().quit)
	menu_column.add_child(quit_button)

	var error_label := Label.new()
	error_label.name = "ErrorLabel"
	error_label.custom_minimum_size.y = 48
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_font_size_override("font_size", 16)
	error_label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.42, 0.38)
	)
	error_label.text = _startup_flow.consume_last_error()
	menu_column.add_child(error_label)

	var preview_panel := PanelContainer.new()
	preview_panel.name = "CharacterPreviewPanel"
	preview_panel.custom_minimum_size = Vector2(690, 800)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.035, 0.025, 0.046, 0.92),
			Color(0.35, 0.18, 0.45),
			2,
			14
		)
	)
	layout.add_child(preview_panel)

	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_box)

	var preview_title := Label.new()
	preview_title.text = "  YOUR STORY STARTS HERE"
	preview_title.add_theme_font_size_override("font_size", 20)
	preview_title.add_theme_color_override("font_color", ACCENT)
	preview_box.add_child(preview_title)

	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "PreviewViewportContainer"
	viewport_container.custom_minimum_size = Vector2(620, 700)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	preview_box.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.name = "PreviewViewport"
	viewport.size = Vector2i(760, 820)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	_preview_pivot = Node3D.new()
	_preview_pivot.name = "PreviewPivot"
	viewport.add_child(_preview_pivot)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.08, 2.55)
	camera.look_at_from_position(camera.position, Vector3(0, 1.02, 0))
	camera.fov = 31.0
	viewport.add_child(camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -38, 0)
	key.light_energy = 2.35
	key.light_color = Color(1.0, 0.82, 0.66)
	viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(15, 145, 0)
	fill.light_energy = 1.65
	fill.light_color = Color(0.57, 0.34, 1.0)
	viewport.add_child(fill)

	_confirmation = ConfirmationDialog.new()
	_confirmation.name = "OverwriteConfirmation"
	_confirmation.title = "START A NEW GAME?"
	_confirmation.dialog_text = (
		"A saved game already exists. It will only be replaced after "
		+ "you finish creating the new character."
	)
	_confirmation.ok_button_text = "OPEN CHARACTER CREATOR"
	_confirmation.cancel_button_text = "KEEP CURRENT SAVE"
	_confirmation.confirmed.connect(_startup_flow.show_character_creator)
	add_child(_confirmation)


func _build_preview() -> void:
	_preview_visual = PREVIEW_SCENE.instantiate() as Node3D
	if _preview_visual == null:
		return
	_preview_visual.scale = Vector3.ONE * 1.34
	_preview_visual.position.y = 0.38
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
	call_deferred("_finish_preview")


func _finish_preview() -> void:
	if not is_instance_valid(_preview_appearance):
		return
	_preview_appearance.set_body_variant(
		PlayerAppearanceComponent.BODY_VARIANT_MALE
	)
	_preview_appearance.set_skin_preset(
		PlayerAppearanceComponent.SKIN_PRESET_MEDIUM
	)
	for clothing_id in [&"base_hoodie", &"jeans", &"sneakers"]:
		_preview_appearance.apply_clothing_definition(
			ClothingCatalog.get_by_id(clothing_id),
			Color.WHITE
		)


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


func _on_new_game() -> void:
	if _startup_flow.has_valid_save():
		_confirmation.popup_centered(Vector2i(650, 230))
	else:
		_startup_flow.show_character_creator()


func _menu_button(node_name: String, text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(430, 64)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.3, 0.28, 0.32))
	button.add_theme_stylebox_override(
		"normal",
		_panel_style(color.darkened(0.82), color.darkened(0.25), 1, 6)
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(color.darkened(0.58), color, 2, 6)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_panel_style(color.darkened(0.42), color.lightened(0.15), 2, 6)
	)
	button.add_theme_stylebox_override(
		"focus",
		_panel_style(color.darkened(0.64), color, 3, 6)
	)
	return button


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
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
