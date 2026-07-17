class_name TerritoryEncounterController
extends Node

signal gang_war_started(territory_id: StringName, duration: float)
signal gang_war_time_changed(remaining: float)
signal gang_war_ended(territory_id: StringName, won: bool)
signal war_wins_changed(territory_id: StringName, wins: int)
signal territory_claimed(territory_id: StringName, route: StringName)

const TARGET_TERRITORY := &"hood_east"
const WAR_DURATION := 60.0
const WAVE_TIMES := [0.0, 20.0, 40.0]
const COOLDOWN_MINUTES := 360
const PURCHASE_PRICE := 100000
const XP_REWARDS := [25.0, 40.0, 60.0, 90.0]

@export var player_path := NodePath("../Gameplay/Player")
@export var world_time_path := NodePath("../WorldTimeComponent")
@export var dealer_scene: PackedScene

@onready var player := get_node(player_path) as CharacterBody3D
@onready var world_time := get_node(world_time_path) as WorldTimeComponent

var _random := RandomNumberGenerator.new()
var _war_wins: Dictionary[StringName, int] = {}
var _cooldown_until: Dictionary[StringName, int] = {}
var _active_territory: StringName
var _war_remaining := 0.0
var _waves_spawned := 0
var _attackers: Array[DealerNPC] = []
var _active_tier := 0


func _ready() -> void:
	add_to_group(&"territory_encounter")
	_random.randomize()
	world_time.minute_advanced.connect(_on_minute_advanced)
	var health := player.get_node("Components/HealthComponent") as PlayerHealthComponent
	health.downed.connect(_on_player_downed)
	set_process(false)


func _process(delta: float) -> void:
	if _active_territory.is_empty():
		set_process(false)
		return
	_war_remaining = maxf(_war_remaining - delta, 0.0)
	while _waves_spawned < WAVE_TIMES.size() and WAR_DURATION - _war_remaining >= float(WAVE_TIMES[_waves_spawned]):
		_spawn_wave()
	gang_war_time_changed.emit(_war_remaining)
	if is_zero_approx(_war_remaining):
		_finish_war(true)


func get_risk_tier(reputation: float) -> int:
	if reputation >= 0.0:
		return 0
	if reputation <= -75.0:
		return 4
	if reputation <= -50.0:
		return 3
	if reputation <= -25.0:
		return 2
	return 1


func get_hourly_chance(reputation: float) -> float:
	var chances: Array[float] = [0.0, 0.05, 0.15, 0.30, 0.50]
	return chances[get_risk_tier(reputation)]


func is_war_active(territory_id := TARGET_TERRITORY) -> bool:
	return _active_territory == territory_id


func get_war_remaining() -> float:
	return _war_remaining


func get_active_tier() -> int:
	return _active_tier if not _active_territory.is_empty() else 0


func get_war_wins(territory_id := TARGET_TERRITORY) -> int:
	return int(_war_wins.get(territory_id, 0))


func get_cooldown_minutes(territory_id := TARGET_TERRITORY) -> int:
	return maxi(int(_cooldown_until.get(territory_id, 0)) - world_time.get_absolute_minute(), 0)


func can_purchase_territory(territory_id: StringName) -> bool:
	var stats := _get_stats(territory_id)
	return stats != null and stats.can_purchase_territory() and territory_id == TARGET_TERRITORY


func purchase_territory(territory_id: StringName, buyer: CharacterBody3D) -> String:
	if not can_purchase_territory(territory_id):
		return "Requires +100 Reputation in this territory."
	var wallet := buyer.get_node_or_null("Components/WalletComponent") as PlayerWalletComponent
	if wallet == null or not wallet.spend_dirty(PURCHASE_PRICE):
		return "Requires $%d Dirty Cash." % PURCHASE_PRICE
	claim_territory(territory_id, &"purchase")
	return "Territory purchased for $%d Dirty Cash." % PURCHASE_PRICE


func claim_territory(territory_id: StringName, route: StringName) -> bool:
	var stats := _get_stats(territory_id)
	if stats == null or stats.owner_faction == TerritoryStatsComponent.OwnerFaction.PLAYER:
		return false
	stats.set_owner_faction(TerritoryStatsComponent.OwnerFaction.PLAYER)
	stats.set_reputation(100.0)
	for zone in _get_zones(territory_id):
		zone.set_faction(TerritoryStatsComponent.OwnerFaction.PLAYER)
	_cleanup_attackers()
	_active_territory = &""
	_war_remaining = 0.0
	_set_wanted_suppression(false)
	set_process(false)
	territory_claimed.emit(territory_id, route)
	var hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
	if hud != null:
		hud.show_feedback("TERRITORY CLAIMED: %s" % String(territory_id).replace("_", " ").to_upper(), 5.0)
	return true


func on_permanent_dealer_defeated(zone: DealerActivityZone3D, _dealer: DealerNPC) -> void:
	if zone == null or zone.territory_id != TARGET_TERRITORY:
		return
	var stats := _get_stats(zone.territory_id)
	if stats == null or not stats.can_wipe_dealers_for_takeover():
		return
	for candidate in _get_zones(zone.territory_id):
		if (
			candidate.faction != TerritoryStatsComponent.OwnerFaction.PLAYER
			and not candidate.has_completed_takeover_wipe()
		):
			return
	claim_territory(zone.territory_id, &"dealer_wipe")


func start_gang_war(territory_id := TARGET_TERRITORY) -> bool:
	if not _can_start_war(territory_id):
		return false
	var stats := _get_stats(territory_id)
	return _begin_gang_war(territory_id, get_risk_tier(stats.reputation))


func debug_start_gang_war(tier := 0) -> bool:
	if not _active_territory.is_empty():
		return false
	var stats := _get_stats(TARGET_TERRITORY)
	if stats == null:
		return false
	var selected_tier := clampi(tier, 0, 4)
	if selected_tier == 0:
		selected_tier = maxi(get_risk_tier(stats.reputation), 1)
	return _begin_gang_war(TARGET_TERRITORY, selected_tier)


func debug_finish_gang_war(won: bool) -> bool:
	if _active_territory.is_empty():
		return false
	_finish_war(won)
	return true


func debug_clear_gang_war_cooldown(
	territory_id := TARGET_TERRITORY
) -> void:
	_cooldown_until.erase(territory_id)


func _begin_gang_war(territory_id: StringName, tier: int) -> bool:
	_active_territory = territory_id
	_active_tier = clampi(tier, 1, 4)
	_war_remaining = WAR_DURATION
	_waves_spawned = 0
	_cleanup_attackers()
	_set_wanted_suppression(true)
	set_process(true)
	gang_war_started.emit(territory_id, WAR_DURATION)
	_show_feedback("GANG WAR: survive for 60 seconds.", 4.0)
	_spawn_wave()
	return true


func _on_minute_advanced(absolute_minute: int) -> void:
	if absolute_minute % 60 != 0 or not _can_start_war(TARGET_TERRITORY):
		return
	var stats := _get_stats(TARGET_TERRITORY)
	if _random.randf() < get_hourly_chance(stats.reputation):
		start_gang_war(TARGET_TERRITORY)


func _can_start_war(territory_id: StringName) -> bool:
	if not _active_territory.is_empty() or get_cooldown_minutes(territory_id) > 0:
		return false
	var stats := _get_stats(territory_id)
	var health := player.get_node("Components/HealthComponent") as PlayerHealthComponent
	var boundary := TerritoryBoundary.find_at_position(get_tree(), player.global_position)
	return (
		territory_id == TARGET_TERRITORY
		and stats != null
		and stats.reputation < 0.0
		and stats.owner_faction != TerritoryStatsComponent.OwnerFaction.PLAYER
		and health.is_alive()
		and boundary != null
		and boundary.territory_id == territory_id
	)


func _spawn_wave() -> void:
	if dealer_scene == null or _active_tier <= 0:
		return
	var positions: Array[Vector3] = []
	for zone in _get_zones(_active_territory):
		positions.append_array(zone.get_reinforcement_world_positions())
	if positions.is_empty():
		positions.append(player.global_position + Vector3(12.0, 0.0, 0.0))
	var wave_sizes: Array[int] = [0, 3, 4, 5, 6]
	var count: int = wave_sizes[_active_tier]
	for index in range(count):
		var dealer := dealer_scene.instantiate() as DealerNPC
		if dealer == null:
			continue
		var container := get_parent().get_node_or_null("Gameplay")
		if container == null:
			return
		container.add_child(dealer)
		dealer.global_position = positions[index % positions.size()] + Vector3(float(index / positions.size()) * 1.25, 0.0, 0.0)
		dealer.configure_war_attacker(_roll_attacker_level(), _active_territory)
		_attackers.append(dealer)
	_waves_spawned += 1


func _roll_attacker_level() -> int:
	match _active_tier:
		1: return 1
		2: return _random.randi_range(1, 2)
		3: return _random.randi_range(2, 3)
		_: return _random.randi_range(2, 4)


func _on_player_downed() -> void:
	if not _active_territory.is_empty():
		_finish_war(false)


func _finish_war(won: bool) -> void:
	var territory_id := _active_territory
	if territory_id.is_empty():
		return
	var stats := _get_stats(territory_id)
	if won:
		var wins := get_war_wins(territory_id) + 1
		_war_wins[territory_id] = wins
		if stats != null:
			stats.add_reputation(15.0)
		war_wins_changed.emit(territory_id, wins)
	else:
		if stats != null:
			stats.add_reputation(-10.0)
	_cooldown_until[territory_id] = world_time.get_absolute_minute() + COOLDOWN_MINUTES
	_cleanup_attackers()
	_active_territory = &""
	_war_remaining = 0.0
	_set_wanted_suppression(false)
	set_process(false)
	gang_war_ended.emit(territory_id, won)
	_show_feedback(
		"GANG WAR WON: +15 Rep (%d/3 wins)." % get_war_wins(territory_id)
		if won
		else "GANG WAR LOST: -10 Rep.",
		4.0
	)
	if won and get_war_wins(territory_id) >= 3:
		claim_territory(territory_id, &"gang_wars")


func _cleanup_attackers() -> void:
	for attacker in _attackers:
		if is_instance_valid(attacker):
			attacker.queue_free()
	_attackers.clear()


func export_save_data() -> Dictionary:
	var attacker_data: Array[Dictionary] = []
	var saved_wins := {}
	for territory_id in _war_wins.keys():
		saved_wins[String(territory_id)] = _war_wins[territory_id]
	var saved_cooldowns := {}
	for territory_id in _cooldown_until.keys():
		saved_cooldowns[String(territory_id)] = _cooldown_until[territory_id]
	for attacker in _attackers:
		if is_instance_valid(attacker) and not attacker.is_defeated():
			attacker_data.append({
				"level": attacker.get_role_component().dealer_level,
				"position": [attacker.global_position.x, attacker.global_position.y, attacker.global_position.z],
			})
	return {
		"war_wins": saved_wins,
		"cooldown_until": saved_cooldowns,
		"active_territory": String(_active_territory),
		"war_remaining": _war_remaining,
		"waves_spawned": _waves_spawned,
		"active_tier": _active_tier,
		"attackers": attacker_data,
	}


func import_save_data(data: Dictionary) -> void:
	_cleanup_attackers()
	_war_wins.clear()
	for key in (data.get("war_wins", {}) as Dictionary).keys():
		_war_wins[StringName(String(key))] = int((data["war_wins"] as Dictionary)[key])
	_cooldown_until.clear()
	for key in (data.get("cooldown_until", {}) as Dictionary).keys():
		_cooldown_until[StringName(String(key))] = int((data["cooldown_until"] as Dictionary)[key])
	_active_territory = StringName(String(data.get("active_territory", "")))
	_war_remaining = maxf(float(data.get("war_remaining", 0.0)), 0.0)
	_waves_spawned = clampi(int(data.get("waves_spawned", 0)), 0, WAVE_TIMES.size())
	_active_tier = clampi(int(data.get("active_tier", 0)), 0, 4)
	if not _active_territory.is_empty() and _war_remaining > 0.0:
		_set_wanted_suppression(true)
		for entry in data.get("attackers", []) as Array:
			_spawn_saved_attacker(entry as Dictionary)
		set_process(true)
	else:
		_active_territory = &""
		_set_wanted_suppression(false)
		set_process(false)


func _set_wanted_suppression(active: bool) -> void:
	var wanted := player.get_node_or_null(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	if wanted != null:
		wanted.set_gang_war_suppressed(active)


func _spawn_saved_attacker(data: Dictionary) -> void:
	if dealer_scene == null:
		return
	var dealer := dealer_scene.instantiate() as DealerNPC
	get_parent().get_node("Gameplay").add_child(dealer)
	var position := data.get("position", []) as Array
	if position.size() == 3:
		dealer.global_position = Vector3(float(position[0]), float(position[1]), float(position[2]))
	dealer.configure_war_attacker(clampi(int(data.get("level", 1)), 1, 4), _active_territory)
	_attackers.append(dealer)


func _get_stats(territory_id: StringName) -> TerritoryStatsComponent:
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.territory_id == territory_id:
			return boundary.stats
	return null


func _get_zones(territory_id: StringName) -> Array[DealerActivityZone3D]:
	var result: Array[DealerActivityZone3D] = []
	for node in get_tree().get_nodes_in_group(&"dealer_activity_zone"):
		var zone := node as DealerActivityZone3D
		if zone != null and zone.territory_id == territory_id:
			result.append(zone)
	return result


func _show_feedback(message: String, duration := 2.5) -> void:
	var hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
	if hud != null:
		hud.show_feedback(message, duration)
