class_name PlayerInteractionComponent
extends Node

@export var player_path := NodePath("../..")
@export var hud_path := NodePath("../../PlayerHUD")
@export_range(0.5, 10.0, 0.1) var interaction_radius := 2.5
@export var interact_action: StringName = &"interact"

@onready var player := get_node(player_path) as CharacterBody3D
@onready var hud := get_node(hud_path) as PlayerHUD

var _current_target: Node3D
var _gameplay_enabled := true


func _process(_delta: float) -> void:
	if not _gameplay_enabled:
		return

	_current_target = _find_nearest_interactable()
	hud.set_interaction_prompt(
		String(_current_target.call("get_interaction_prompt", player))
		if _current_target != null
		else ""
	)


func _unhandled_input(event: InputEvent) -> void:
	if (
		_gameplay_enabled
		and event.is_action_pressed(interact_action)
		and _current_target != null
	):
		_current_target.call("interact", player)
		get_viewport().set_input_as_handled()


func set_gameplay_enabled(enabled: bool) -> void:
	_gameplay_enabled = enabled
	set_process(enabled)
	set_process_unhandled_input(enabled)
	if not enabled:
		_current_target = null
		hud.set_interaction_prompt("")


func _find_nearest_interactable() -> Node3D:
	var nearest: Node3D
	var nearest_distance := interaction_radius

	for node in get_tree().get_nodes_in_group("interactable"):
		var target := node as Node3D
		if (
			target == null
			or not target.has_method("can_interact")
			or not target.has_method("get_interaction_prompt")
			or not target.has_method("interact")
			or not bool(target.call("can_interact", player))
		):
			continue
		var distance := player.global_position.distance_to(
			target.global_position
		)
		if distance <= nearest_distance:
			nearest = target
			nearest_distance = distance

	return nearest
