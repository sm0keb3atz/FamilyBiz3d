class_name PlayerRespawnComponent
extends Node

@export var health_component_path := NodePath("../HealthComponent")
@export var body_path := NodePath("../..")

@onready var health_component := (
	get_node(health_component_path) as PlayerHealthComponent
)
@onready var body := get_node(body_path) as CharacterBody3D

var _spawn_transform := Transform3D.IDENTITY


func _ready() -> void:
	_spawn_transform = body.global_transform


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_R
	):
		if respawn():
			get_viewport().set_input_as_handled()


func respawn() -> bool:
	if not health_component.begin_respawn():
		return false

	body.global_transform = _spawn_transform
	body.velocity = Vector3.ZERO
	health_component.complete_respawn()
	return true
