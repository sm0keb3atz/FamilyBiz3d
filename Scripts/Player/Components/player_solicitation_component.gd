class_name PlayerSolicitationComponent
extends Node

@export var player_path := NodePath("../..")
@export var hud_path := NodePath("../../PlayerHUD")
@export var pulse_mesh_path := NodePath("../../SolicitationPulse")
@export_range(1.0, 30.0, 0.5) var solicitation_radius := 8.0
@export_range(0.1, 10.0, 0.1) var pulse_duration := 0.65
@export var solicit_action: StringName = &"solicit"

@onready var player := get_node(player_path) as CharacterBody3D
@onready var hud := get_node(hud_path) as PlayerHUD
@onready var pulse_mesh := get_node(pulse_mesh_path) as MeshInstance3D

var _gameplay_enabled := true
var _pulse_tween: Tween


func _ready() -> void:
	pulse_mesh.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _gameplay_enabled and event.is_action_pressed(solicit_action):
		solicit()
		get_viewport().set_input_as_handled()


func set_gameplay_enabled(enabled: bool) -> void:
	_gameplay_enabled = enabled
	set_process_unhandled_input(enabled)


func solicit() -> void:
	_play_pulse()
	var customer := _select_customer()
	if customer == null:
		hud.show_feedback("No available customers nearby.")
		return

	customer.respond_to_solicitation(player)
	hud.show_feedback("A customer is coming over.")


func _select_customer() -> CustomerNPC:
	var nearest: CustomerNPC
	var nearest_distance := solicitation_radius

	for node in get_tree().get_nodes_in_group("customer_npc"):
		var customer := node as CustomerNPC
		if customer == null or not customer.can_respond_to_solicitation():
			continue
		var distance := player.global_position.distance_to(customer.global_position)
		if distance <= nearest_distance:
			nearest = customer
			nearest_distance = distance

	return nearest


func _play_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	pulse_mesh.visible = true
	pulse_mesh.scale = Vector3(0.1, 1.0, 0.1)
	var material := pulse_mesh.get_active_material(0) as StandardMaterial3D
	if material != null:
		material.albedo_color.a = 0.5

	_pulse_tween = create_tween()
	_pulse_tween.set_parallel(true)
	_pulse_tween.tween_property(
		pulse_mesh,
		"scale",
		Vector3(solicitation_radius, 1.0, solicitation_radius),
		pulse_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if material != null:
		_pulse_tween.tween_property(
			material,
			"albedo_color:a",
			0.0,
			pulse_duration
		)
	_pulse_tween.chain().tween_callback(
		func() -> void: pulse_mesh.visible = false
	)
