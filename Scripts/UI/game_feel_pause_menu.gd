class_name GameFeelPauseMenu
extends CanvasLayer

const MENU_ID := &"game_feel_pause"

@export var menu_controller_path := NodePath("../Components/MenuController")
@export var settings_component_path := NodePath(
	"../Components/GameFeelSettingsComponent"
)

@onready var menu_controller := get_node(
	menu_controller_path
) as PlayerMenuController
@onready var settings := get_node(
	settings_component_path
) as GameFeelSettingsComponent

var _panel: Control
var _previous_tree_paused := false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_menu()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if menu_controller.is_open(MENU_ID):
		close_menu()
	elif menu_controller.active_menu.is_empty():
		open_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func open_menu() -> void:
	if not menu_controller.request_open(MENU_ID):
		return
	_previous_tree_paused = get_tree().paused
	_panel.visible = true
	get_tree().paused = true


func close_menu() -> void:
	if not menu_controller.is_open(MENU_ID):
		return
	get_tree().paused = _previous_tree_paused
	_panel.visible = false
	settings.save_settings()
	menu_controller.close(MENU_ID)


func _build_menu() -> void:
	_panel = ColorRect.new()
	_panel.name = "GameFeelPauseOverlay"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.color = Color(0.008, 0.012, 0.018, 0.78)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-245.0, -210.0)
	card.size = Vector2(490.0, 420.0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.025, 0.035, 0.05, 0.98)
	card_style.border_color = Color(0.88, 0.22, 0.12, 0.88)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", card_style)
	_panel.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.66))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "GAME FEEL"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.64, 0.7, 0.76))
	content.add_child(subtitle)

	_add_slider(
		content,
		"MOVEMENT BOB",
		settings.movement_bob_intensity,
		settings.set_movement_bob_intensity
	)
	_add_slider(
		content,
		"CAMERA SHAKE",
		settings.camera_shake_intensity,
		settings.set_camera_shake_intensity
	)
	_add_slider(
		content,
		"DAMAGE FLASH",
		settings.damage_flash_intensity,
		settings.set_damage_flash_intensity
	)

	var resume := Button.new()
	resume.text = "RESUME"
	resume.custom_minimum_size.y = 48.0
	resume.pressed.connect(close_menu)
	content.add_child(resume)


func _add_slider(
	parent: VBoxContainer,
	caption: String,
	initial_value: float,
	setter: Callable
) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var header := HBoxContainer.new()
	row.add_child(header)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var value_label := Label.new()
	value_label.text = "%d%%" % roundi(initial_value * 100.0)
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_value * 100.0
	slider.custom_minimum_size.y = 28.0
	slider.value_changed.connect(
		func(value: float) -> void:
			value_label.text = "%d%%" % roundi(value)
			setter.call(value / 100.0)
	)
	row.add_child(slider)
