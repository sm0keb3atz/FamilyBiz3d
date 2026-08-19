class_name PlayerMenuController
extends Node

signal active_menu_changed(menu_id: StringName)

const UI_CLICK_STREAM := preload(
	"res://Assets/Audio/UI/menu_button_click.ogg"
)
const MENU_TOGGLE_STREAM := preload(
	"res://Assets/Audio/UI/menu_close-open.ogg"
)

@export var movement_component_path := NodePath("../MovementComponent")
@export var camera_component_path := NodePath("../CameraComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var health_component_path := NodePath("../HealthComponent")
@export var interaction_component_path := NodePath("../InteractionComponent")
@export var solicitation_component_path := NodePath("../SolicitationComponent")
@export var target_lock_component_path := NodePath("../TargetLockComponent")
@export_range(-30.0, 6.0, 0.5) var ui_click_volume_db := -9.0
@export_range(-30.0, 6.0, 0.5) var menu_toggle_volume_db := -7.0

var active_menu: StringName = &""
var _gameplay_locked := false
var _ui_click_player: AudioStreamPlayer
var _menu_toggle_player: AudioStreamPlayer

@onready var movement_component := get_node(movement_component_path)
@onready var camera_component := get_node(camera_component_path)
@onready var weapon_component := get_node(weapon_component_path)
@onready var health_component := get_node(health_component_path)
@onready var interaction_component := get_node(interaction_component_path)
@onready var solicitation_component := get_node(solicitation_component_path)
@onready var target_lock_component := get_node_or_null(target_lock_component_path)


func _ready() -> void:
	_ui_click_player = AudioStreamPlayer.new()
	_ui_click_player.name = "UIClickPlayer"
	_ui_click_player.stream = UI_CLICK_STREAM
	_ui_click_player.volume_db = ui_click_volume_db
	add_child(_ui_click_player)
	_menu_toggle_player = AudioStreamPlayer.new()
	_menu_toggle_player.name = "MenuTogglePlayer"
	_menu_toggle_player.stream = MENU_TOGGLE_STREAM
	_menu_toggle_player.volume_db = menu_toggle_volume_db
	add_child(_menu_toggle_player)
	get_tree().node_added.connect(_on_scene_node_added)
	_connect_existing_buttons.call_deferred()


func request_open(menu_id: StringName) -> bool:
	if (
		_gameplay_locked
		or menu_id.is_empty()
		or not active_menu.is_empty()
	):
		return false

	active_menu = menu_id
	_apply_gameplay_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_menu_toggle_sound()
	active_menu_changed.emit(active_menu)
	return true


func close(menu_id: StringName) -> bool:
	if active_menu != menu_id:
		return false

	active_menu = &""
	_apply_gameplay_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_play_menu_toggle_sound()
	active_menu_changed.emit(active_menu)
	return true


func replace_open(
	current_menu_id: StringName,
	next_menu_id: StringName
) -> bool:
	if (
		_gameplay_locked
		or active_menu != current_menu_id
		or next_menu_id.is_empty()
	):
		return false
	active_menu = next_menu_id
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_menu_toggle_sound()
	active_menu_changed.emit(active_menu)
	return true


func is_open(menu_id: StringName) -> bool:
	return active_menu == menu_id


func set_gameplay_locked(locked: bool) -> void:
	_gameplay_locked = locked


func _apply_gameplay_enabled(enabled: bool) -> void:
	enabled = enabled and not _gameplay_locked
	if not enabled and movement_component.has_method("stop_immediately"):
		movement_component.stop_immediately()
	movement_component.set_physics_process(
		enabled and health_component.is_alive()
	)
	camera_component.set_process_unhandled_input(enabled)
	weapon_component.set_process_unhandled_input(enabled)
	weapon_component.set_process(enabled)
	if target_lock_component != null:
		target_lock_component.set_process(enabled)
		target_lock_component.set_process_unhandled_input(enabled)
	interaction_component.set_gameplay_enabled(enabled)
	solicitation_component.set_gameplay_enabled(enabled)


func _connect_existing_buttons() -> void:
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_connect_button(node as BaseButton)


func _on_scene_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)


func _connect_button(button: BaseButton) -> void:
	if button == null or button.pressed.is_connected(_play_ui_click_sound):
		return
	button.pressed.connect(_play_ui_click_sound)


func _play_ui_click_sound() -> void:
	if _ui_click_player != null:
		_ui_click_player.pitch_scale = randf_range(0.985, 1.015)
		_ui_click_player.play()


func _play_menu_toggle_sound() -> void:
	if _menu_toggle_player != null:
		_menu_toggle_player.pitch_scale = randf_range(0.98, 1.02)
		_menu_toggle_player.play()
