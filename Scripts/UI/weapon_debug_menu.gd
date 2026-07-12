class_name WeaponDebugMenu
extends CanvasLayer

@export var weapon_component_path := NodePath("../Components/WeaponComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var menu_root := %MenuRoot as Control
@onready var sights_toggle := %SightsToggle as CheckButton
@onready var laser_toggle := %LaserToggle as CheckButton
@onready var switch_toggle := %SwitchToggle as CheckButton
@onready var standard_magazine_button := %StandardMagazineButton as Button
@onready var extended_magazine_button := %ExtendedMagazineButton as Button
@onready var drum_magazine_button := %DrumMagazineButton as Button
@onready var add_ammo_button := %AddAmmoButton as Button
@onready var ammo_value := %AmmoValue as Label
@onready var weapon := get_node(weapon_component_path) as PlayerWeaponComponent
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController

var _is_open := false
var _refreshing := false


func _ready() -> void:
	sights_toggle.toggled.connect(_on_sights_toggled)
	laser_toggle.toggled.connect(_on_laser_toggled)
	switch_toggle.toggled.connect(_on_switch_toggled)
	standard_magazine_button.pressed.connect(
		func() -> void: weapon.set_magazine_type(PlayerWeaponComponent.MagazineType.STANDARD)
	)
	extended_magazine_button.pressed.connect(
		func() -> void: weapon.set_magazine_type(PlayerWeaponComponent.MagazineType.EXTENDED)
	)
	drum_magazine_button.pressed.connect(
		func() -> void: weapon.set_magazine_type(PlayerWeaponComponent.MagazineType.DRUM)
	)
	add_ammo_button.pressed.connect(_add_ammo)
	weapon.ammo_changed.connect(_on_weapon_state_changed)
	weapon.attachments_changed.connect(_on_weapon_state_changed)
	menu_root.visible = false
	_refresh()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_G:
		return
	set_menu_open(not _is_open)
	get_viewport().set_input_as_handled()


func set_menu_open(open: bool) -> void:
	if open:
		if not menu_controller.request_open(&"weapon_debug"):
			return
	elif not menu_controller.close(&"weapon_debug"):
		return
	_is_open = open
	menu_root.visible = _is_open
	if _is_open:
		_refresh()


func _add_ammo() -> void:
	weapon.add_reserve_ammo(30)


func _on_sights_toggled(enabled: bool) -> void:
	if not _refreshing:
		weapon.set_sights_enabled(enabled)


func _on_laser_toggled(enabled: bool) -> void:
	if not _refreshing:
		weapon.set_laser_enabled(enabled)


func _on_switch_toggled(enabled: bool) -> void:
	if not _refreshing:
		weapon.set_switch_enabled(enabled)


func _on_weapon_state_changed(_first: Variant = null, _second: Variant = null) -> void:
	_refresh()


func _refresh() -> void:
	_refreshing = true
	sights_toggle.button_pressed = weapon.is_sights_enabled()
	laser_toggle.button_pressed = weapon.is_laser_enabled()
	switch_toggle.button_pressed = weapon.is_switch_enabled()
	var equipped_weapon := weapon.get_equipped_weapon()
	var standard_capacity := 0
	var extended_capacity := 0
	var drum_capacity := 0
	if equipped_weapon != null:
		standard_capacity = equipped_weapon.magazine_capacity
		extended_capacity = equipped_weapon.extended_magazine_capacity
		drum_capacity = equipped_weapon.drum_magazine_capacity
	standard_magazine_button.text = "Standard\n%d" % standard_capacity
	extended_magazine_button.text = "Extended\n%d" % extended_capacity
	drum_magazine_button.text = "Drum\n%d" % drum_capacity
	var magazine_type := weapon.get_magazine_type()
	standard_magazine_button.disabled = magazine_type == PlayerWeaponComponent.MagazineType.STANDARD
	extended_magazine_button.disabled = magazine_type == PlayerWeaponComponent.MagazineType.EXTENDED
	drum_magazine_button.disabled = magazine_type == PlayerWeaponComponent.MagazineType.DRUM
	ammo_value.text = "%d / %d loaded  |  %d reserve" % [
		weapon.get_magazine_ammo(),
		weapon.get_magazine_capacity(),
		weapon.get_reserve_ammo(),
	]
	_refreshing = false
