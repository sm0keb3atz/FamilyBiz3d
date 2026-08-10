class_name RobberyEventDealer
extends DealerNPC

signal player_reached

enum Phase {
	APPROACH,
	FLEE,
}

@export_range(0.5, 5.0, 0.1) var contact_distance := 1.4
@export_range(1.0, 10.0, 0.1) var approach_speed := 5.0
@export_range(1.0, 10.0, 0.1) var flee_speed := 5.5
@export_range(5.0, 60.0, 1.0) var flee_target_distance := 30.0

var robbery_phase := Phase.APPROACH
var _robbery_player: CharacterBody3D
var _contact_emitted := false
var _flee_repath_remaining := 0.0


func configure_robbery_actor(
	player: CharacterBody3D,
	territory_id: StringName,
	phase := Phase.APPROACH
) -> void:
	_robbery_player = player
	is_temporary_war_attacker = true
	var role := get_role_component()
	if role != null:
		role.territory_id = territory_id
	configure_dealer(1, false)
	if role != null:
		role.deactivate()
	remove_from_group(&"interactable_npc")
	remove_from_group(&"interactable")
	add_to_group(&"territory_robber")
	set_navigation_avoidance_enabled(true)
	set_local_obstacle_steering_enabled(true)
	set_robbery_phase(phase)


func set_robbery_phase(phase: int) -> void:
	robbery_phase = clampi(phase, Phase.APPROACH, Phase.FLEE)
	_contact_emitted = robbery_phase == Phase.FLEE
	_flee_repath_remaining = 0.0
	clear_hostility()
	clear_navigation_target()
	var combat := get_combat_component()
	if combat != null:
		combat.clear_aim()
		combat.set_equipped(false)


func tick_dealer_ai_mode(_mode: int, delta: float) -> void:
	if is_defeated() or not is_instance_valid(_robbery_player):
		stop_moving(delta)
		return
	var combat := get_combat_component()
	if combat != null:
		combat.clear_aim()
		combat.set_equipped(false)
	if robbery_phase == Phase.APPROACH:
		_tick_approach(delta)
	else:
		_tick_flee(delta)


func _grant_kill_experience(_source: Node) -> void:
	# The robbery's reward is handled by the encounter controller (+5 local Rep
	# and exact property recovery), so it does not also grant dealer-kill XP.
	pass


func _tick_approach(delta: float) -> void:
	move_speed = approach_speed
	var target := _robbery_player.global_position
	if global_position.distance_squared_to(target) <= contact_distance * contact_distance:
		stop_moving(delta)
		if not _contact_emitted:
			_contact_emitted = true
			player_reached.emit()
		return
	animation_component.use_sex_appropriate_walk()
	move_toward_navigation_target(target, delta)


func _tick_flee(delta: float) -> void:
	move_speed = flee_speed
	_flee_repath_remaining = maxf(_flee_repath_remaining - delta, 0.0)
	if _flee_repath_remaining <= 0.0:
		var away := global_position - _robbery_player.global_position
		away.y = 0.0
		if away.length_squared() <= 0.001:
			away = -global_basis.z
		set_navigation_target(global_position + away.normalized() * flee_target_distance)
		_flee_repath_remaining = 0.35
	animation_component.use_sex_appropriate_walk()
	advance_navigation(delta)
