class_name PlayerAppearanceMenu
extends CanvasLayer

const MENU_ID := &"appearance"

@export var appearance_component_path := NodePath(
	"../Components/AppearanceComponent"
)
@export var menu_controller_path := NodePath(
	"../Components/MenuController"
)

var _appearance: PlayerAppearanceComponent
var _menu_controller: PlayerMenuController
var _menu_root: Control
var _labels: Dictionary = {}
var _material_labels: Dictionary = {}
var _is_open := false


func _ready() -> void:
	_appearance = get_node(
		appearance_component_path
	) as PlayerAppearanceComponent
	_menu_controller = get_node(
		menu_controller_path
	) as PlayerMenuController
	_build_menu()
	_appearance.appearance_changed.connect(_on_appearance_changed)
	_appearance.material_changed.connect(_on_material_changed)
	_refresh_labels()
	_menu_root.visible = false


func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
	):
		if event.physical_keycode == KEY_C:
			set_menu_open(not _is_open)
			get_viewport().set_input_as_handled()
		elif _is_open and event.physical_keycode == KEY_ESCAPE:
			set_menu_open(false)
			get_viewport().set_input_as_handled()


func set_menu_open(open: bool) -> void:
	if open:
		if not _menu_controller.request_open(MENU_ID):
			return
	elif not _menu_controller.close(MENU_ID):
		return
	_is_open = open
	_menu_root.visible = open
	if open:
		_refresh_labels()


func _build_menu() -> void:
	_menu_root = Control.new()
	_menu_root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	add_child(_menu_root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-390.0, -325.0)
	panel.custom_minimum_size = Vector2(360.0, 650.0)
	_menu_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var title := Label.new()
	title.text = "Character Customization"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)

	var help := Label.new()
	help.text = "Press C or Escape to close"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(help)

	_add_material_row(
		content,
		"Body Material",
		PlayerAppearanceComponent.SLOT_BODY
	)
	_add_option_row(
		content,
		"Top",
		PlayerAppearanceComponent.SLOT_TOP
	)
	_add_material_row(
		content,
		"Top Material",
		PlayerAppearanceComponent.SLOT_TOP
	)
	_add_option_row(
		content,
		"Bottom",
		PlayerAppearanceComponent.SLOT_BOTTOM
	)
	_add_material_row(
		content,
		"Bottom Material",
		PlayerAppearanceComponent.SLOT_BOTTOM
	)
	_add_option_row(
		content,
		"Shoes",
		PlayerAppearanceComponent.SLOT_SHOES
	)
	_add_material_row(
		content,
		"Shoes Material",
		PlayerAppearanceComponent.SLOT_SHOES
	)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)

	var randomize_button := Button.new()
	randomize_button.text = "Randomize"
	randomize_button.pressed.connect(
		_appearance.randomize_appearance
	)
	actions.add_child(randomize_button)

	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(_appearance.reset_appearance)
	actions.add_child(reset_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(set_menu_open.bind(false))
	content.add_child(close_button)


func _add_option_row(
	parent: VBoxContainer,
	display_name: String,
	slot: StringName
) -> void:
	var heading := Label.new()
	heading.text = display_name
	heading.add_theme_font_size_override("font_size", 18)
	parent.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var previous_button := Button.new()
	previous_button.text = "<"
	previous_button.custom_minimum_size.x = 48.0
	previous_button.pressed.connect(
		_appearance.cycle_option.bind(slot, -1)
	)
	row.add_child(previous_button)

	var value_label := Label.new()
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	_labels[slot] = value_label

	var next_button := Button.new()
	next_button.text = ">"
	next_button.custom_minimum_size.x = 48.0
	next_button.pressed.connect(
		_appearance.cycle_option.bind(slot, 1)
	)
	row.add_child(next_button)


func _add_material_row(
	parent: VBoxContainer,
	display_name: String,
	slot: StringName
) -> void:
	var heading := Label.new()
	heading.text = display_name
	heading.add_theme_font_size_override("font_size", 16)
	parent.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var previous_button := Button.new()
	previous_button.text = "<"
	previous_button.custom_minimum_size.x = 48.0
	previous_button.pressed.connect(
		_appearance.cycle_material.bind(slot, -1)
	)
	row.add_child(previous_button)

	var value_label := Label.new()
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	_material_labels[slot] = value_label

	var next_button := Button.new()
	next_button.text = ">"
	next_button.custom_minimum_size.x = 48.0
	next_button.pressed.connect(
		_appearance.cycle_material.bind(slot, 1)
	)
	row.add_child(next_button)


func _refresh_labels() -> void:
	for slot in _labels:
		var label := _labels[slot] as Label
		label.text = _appearance.get_option_name(slot)
	for slot in _material_labels:
		var label := _material_labels[slot] as Label
		label.text = _appearance.get_material_name(slot)


func _on_appearance_changed(
	slot: StringName,
	_option_index: int,
	option_name: String
) -> void:
	if _labels.has(slot):
		var label := _labels[slot] as Label
		label.text = option_name
	if _material_labels.has(slot):
		var material_label := _material_labels[slot] as Label
		material_label.text = _appearance.get_material_name(slot)


func _on_material_changed(
	slot: StringName,
	_material_index: int,
	material_name: String
) -> void:
	if _material_labels.has(slot):
		var label := _material_labels[slot] as Label
		label.text = material_name
