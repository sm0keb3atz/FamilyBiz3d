class_name CustomerNPC
extends BaseNPC

enum State {
	IDLE,
	APPROACHING,
	WAITING,
	RETURNING,
	COOLDOWN,
}

@export var product_wanted: ProductDefinition
@export var territory_stats_path := NodePath("../TerritoryStats")
@export_range(0.5, 5.0, 0.1) var player_stop_distance := 1.6
@export_range(0.5, 10.0, 0.1) var home_stop_distance := 0.6
@export_range(0.0, 60.0, 0.5) var cooldown_duration := 5.0

var _state := State.IDLE
var _home_position := Vector3.ZERO
var _target_player: CharacterBody3D
var _cooldown_remaining := 0.0


func _ready() -> void:
	super()
	_home_position = global_position
	add_to_group("customer_npc")
	add_to_group("interactable_npc")
	navigation_agent.path_desired_distance = 0.3
	navigation_agent.target_desired_distance = player_stop_distance


func _physics_process(delta: float) -> void:
	match _state:
		State.APPROACHING:
			if not is_instance_valid(_target_player):
				_begin_returning()
			elif global_position.distance_to(
				_target_player.global_position
			) <= player_stop_distance:
				_state = State.WAITING
				stop_moving(delta)
			else:
				move_toward_navigation_target(
					_target_player.global_position,
					delta
				)
		State.WAITING:
			stop_moving(delta)
			if is_instance_valid(_target_player):
				_face_target(_target_player.global_position, delta)
		State.RETURNING:
			if global_position.distance_to(_home_position) <= home_stop_distance:
				_state = State.COOLDOWN
				_cooldown_remaining = cooldown_duration
				stop_moving(delta)
			else:
				move_toward_navigation_target(_home_position, delta)
		State.COOLDOWN:
			stop_moving(delta)
			_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
			if is_zero_approx(_cooldown_remaining):
				_state = State.IDLE
				_target_player = null
		_:
			stop_moving(delta)


func can_respond_to_solicitation() -> bool:
	return (
		not is_defeated()
		and _state == State.IDLE
		and product_wanted != null
	)


func respond_to_solicitation(player: CharacterBody3D) -> bool:
	if not can_respond_to_solicitation():
		return false

	_target_player = player
	_state = State.APPROACHING
	navigation_agent.target_desired_distance = player_stop_distance
	return true


func can_interact(player: CharacterBody3D) -> bool:
	return (
		not is_defeated()
		and _state == State.WAITING
		and player == _target_player
		and product_wanted != null
	)


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return "E — Sell %s" % product_wanted.display_name


func interact(player: CharacterBody3D) -> void:
	if not can_interact(player):
		return

	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var stats := player.get_node(
		"Components/StatsComponent"
	) as PlayerStatsComponent
	var hud := player.get_node("PlayerHUD") as PlayerHUD
	var territory := get_node_or_null(
		territory_stats_path
	) as TerritoryStatsComponent

	if not inventory.has_product(product_wanted, 1):
		hud.show_feedback("You have no %s to sell." % product_wanted.display_name)
		_begin_returning()
		return

	if not inventory.remove_product(product_wanted, 1):
		hud.show_feedback("Sale failed.")
		return

	wallet.add_dirty(product_wanted.sale_price)
	stats.add_experience(product_wanted.experience_reward)
	if territory != null:
		territory.add_reputation(product_wanted.reputation_reward)

	hud.show_feedback(
		"Sold 1 %s for $%d  •  +%d EXP  •  +%.0f Rep"
		% [
			product_wanted.display_name,
			product_wanted.sale_price,
			roundi(product_wanted.experience_reward),
			product_wanted.reputation_reward,
		]
	)
	_begin_returning()


func get_state_name() -> String:
	return State.keys()[_state]


func _begin_returning() -> void:
	_state = State.RETURNING
	navigation_agent.target_desired_distance = home_stop_distance


func _face_target(target: Vector3, delta: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	visual.rotation.y = lerp_angle(
		visual.rotation.y,
		atan2(direction.x, direction.z),
		minf(turn_speed * delta, 1.0)
	)
