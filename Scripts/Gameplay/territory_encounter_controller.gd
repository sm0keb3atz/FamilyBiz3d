class_name TerritoryEncounterController
extends Node

signal encounter_started(encounter_type: int, territory_id: StringName, duration: float)
signal encounter_time_changed(encounter_type: int, remaining: float)
signal encounter_ended(encounter_type: int, territory_id: StringName, result: int)
signal gang_war_started(territory_id: StringName, duration: float)
signal gang_war_time_changed(remaining: float)
signal gang_war_ended(territory_id: StringName, won: bool)
signal war_wins_changed(territory_id: StringName, wins: int)
signal territory_claimed(territory_id: StringName, route: StringName)

enum EncounterType {
	NONE,
	GANG_WAR,
	ROBBERY,
}

enum EncounterResult {
	CANCELLED,
	WON,
	LOST,
}

enum RobberyPhase {
	NONE,
	APPROACH,
	FLEE,
}

const TARGET_TERRITORY := &"hood_east"
const WAR_DURATION := 60.0
const WAVE_TIMES := [0.0, 20.0, 40.0]
const COOLDOWN_MINUTES := 360
const PURCHASE_PRICE := 100000
const XP_REWARDS := [25.0, 40.0, 60.0, 90.0]
const ROBBERY_REPUTATION_LIMIT := 70.0
const ROBBERY_APPROACH_DURATION := 30.0
const ROBBERY_ESCAPE_DURATION := 75.0
const ROBBERY_ESCAPE_DISTANCE := 60.0
const ROBBERY_TRANSFER_PERCENT := 0.5
const ROBBERY_WIN_REPUTATION := 5.0
const ROBBERY_LOSS_REPUTATION := -20.0
const ROBBERY_SPAWN_MIN_DISTANCE := 15.0
const ROBBERY_SPAWN_MAX_DISTANCE := 35.0

@export var player_path := NodePath("../Gameplay/Player")
@export var world_time_path := NodePath("../WorldTimeComponent")
@export var dealer_scene: PackedScene
@export var robbery_dealer_scene: PackedScene

@onready var player := get_node(player_path) as CharacterBody3D
@onready var world_time := get_node(world_time_path) as WorldTimeComponent

var _random := RandomNumberGenerator.new()
var _war_wins: Dictionary[StringName, int] = {}
var _cooldown_until: Dictionary[StringName, int] = {}
var _active_encounter := EncounterType.NONE
var _active_territory: StringName
var _war_remaining := 0.0
var _waves_spawned := 0
var _attackers: Array[DealerNPC] = []
var _active_tier := 0
var _robbery_phase := RobberyPhase.NONE
var _robbery_remaining := 0.0
var _robber: RobberyEventDealer
var _stolen_dirty_cash := 0
var _stolen_products := {}


func _ready() -> void:
	add_to_group(&"territory_encounter")
	_random.randomize()
	world_time.minute_advanced.connect(_on_minute_advanced)
	var health := player.get_node("Components/HealthComponent") as PlayerHealthComponent
	health.downed.connect(_on_player_downed)
	set_process(false)


func _process(delta: float) -> void:
	match _active_encounter:
		EncounterType.GANG_WAR:
			_process_gang_war(delta)
		EncounterType.ROBBERY:
			_process_robbery(delta)
		_:
			set_process(false)


func _process_gang_war(delta: float) -> void:
	_war_remaining = maxf(_war_remaining - delta, 0.0)
	while (
		_waves_spawned < WAVE_TIMES.size()
		and WAR_DURATION - _war_remaining >= float(WAVE_TIMES[_waves_spawned])
	):
		_spawn_wave()
	gang_war_time_changed.emit(_war_remaining)
	encounter_time_changed.emit(EncounterType.GANG_WAR, _war_remaining)
	if is_zero_approx(_war_remaining):
		_finish_war(true)


func _process_robbery(delta: float) -> void:
	if not is_instance_valid(_robber):
		_finish_robbery(
			EncounterResult.LOST
			if _robbery_phase == RobberyPhase.FLEE
			else EncounterResult.CANCELLED
		)
		return
	_robbery_remaining = maxf(_robbery_remaining - delta, 0.0)
	encounter_time_changed.emit(EncounterType.ROBBERY, _robbery_remaining)
	if _robbery_phase == RobberyPhase.APPROACH:
		if is_zero_approx(_robbery_remaining):
			_finish_robbery(EncounterResult.CANCELLED)
		return
	if (
		is_zero_approx(_robbery_remaining)
		or _robber.global_position.distance_to(player.global_position)
		>= ROBBERY_ESCAPE_DISTANCE
	):
		_finish_robbery(EncounterResult.LOST)


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


func get_robbery_hourly_chance(reputation: float) -> float:
	if reputation >= ROBBERY_REPUTATION_LIMIT:
		return 0.0
	if reputation >= 50.0:
		return 0.05
	if reputation >= 25.0:
		return 0.10
	if reputation >= 0.0:
		return 0.20
	return 0.30


func is_encounter_active(encounter_type := EncounterType.NONE) -> bool:
	return (
		_active_encounter != EncounterType.NONE
		and (
			encounter_type == EncounterType.NONE
			or _active_encounter == encounter_type
		)
	)


func get_active_encounter_type() -> int:
	return _active_encounter


func get_active_territory_id() -> StringName:
	return _active_territory


func get_active_phase() -> int:
	return _robbery_phase if _active_encounter == EncounterType.ROBBERY else 0


func get_encounter_remaining() -> float:
	match _active_encounter:
		EncounterType.GANG_WAR:
			return _war_remaining
		EncounterType.ROBBERY:
			return _robbery_remaining
	return 0.0


func is_war_active(territory_id := TARGET_TERRITORY) -> bool:
	return (
		_active_encounter == EncounterType.GANG_WAR
		and _active_territory == territory_id
	)


func get_war_remaining() -> float:
	return _war_remaining


func get_active_tier() -> int:
	return _active_tier if _active_encounter == EncounterType.GANG_WAR else 0


func get_war_wins(territory_id := TARGET_TERRITORY) -> int:
	return int(_war_wins.get(territory_id, 0))


func get_cooldown_minutes(territory_id := TARGET_TERRITORY) -> int:
	return maxi(
		int(_cooldown_until.get(territory_id, 0))
		- world_time.get_absolute_minute(),
		0
	)


func can_purchase_territory(territory_id: StringName) -> bool:
	var stats := _get_stats(territory_id)
	return (
		not is_encounter_active()
		and stats != null
		and stats.can_purchase_territory()
		and territory_id == TARGET_TERRITORY
	)


func purchase_territory(territory_id: StringName, buyer: CharacterBody3D) -> String:
	if not can_purchase_territory(territory_id):
		return "Requires +100 Reputation in this territory."
	var wallet := buyer.get_node_or_null("Components/WalletComponent") as PlayerWalletComponent
	if wallet == null or not wallet.spend_dirty(
		PURCHASE_PRICE, true, "Territory Deal", "Territory encounter purchase"
	):
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
	_cleanup_robber()
	_reset_active_encounter()
	_set_wanted_suppression(false)
	territory_claimed.emit(territory_id, route)
	var hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
	if hud != null:
		hud.show_feedback(
			"TERRITORY CLAIMED: %s"
			% String(territory_id).replace("_", " ").to_upper(),
			5.0
		)
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


func start_robbery(territory_id: StringName) -> bool:
	if not _can_start_robbery(territory_id):
		return false
	return _begin_robbery(territory_id)


func debug_start_gang_war(tier := 0) -> bool:
	if is_encounter_active():
		return false
	var stats := _get_stats(TARGET_TERRITORY)
	if stats == null:
		return false
	var selected_tier := clampi(tier, 0, 4)
	if selected_tier == 0:
		selected_tier = maxi(get_risk_tier(stats.reputation), 1)
	return _begin_gang_war(TARGET_TERRITORY, selected_tier)


func debug_finish_gang_war(won: bool) -> bool:
	if _active_encounter != EncounterType.GANG_WAR:
		return false
	_finish_war(won)
	return true


func debug_start_robbery(territory_id := &"") -> bool:
	if is_encounter_active():
		return false
	var selected_territory: StringName = territory_id
	if selected_territory.is_empty():
		var boundary := TerritoryBoundary.find_at_position(
			get_tree(), player.global_position
		)
		if boundary == null:
			return false
		selected_territory = boundary.territory_id
	if not _can_start_robbery(selected_territory, true):
		return false
	return _begin_robbery(selected_territory)


func debug_finish_robbery(won: bool) -> bool:
	if _active_encounter != EncounterType.ROBBERY:
		return false
	_finish_robbery(
		EncounterResult.WON if won else EncounterResult.LOST
	)
	return true


func debug_trigger_robbery_contact() -> bool:
	if (
		_active_encounter != EncounterType.ROBBERY
		or _robbery_phase != RobberyPhase.APPROACH
	):
		return false
	_on_robber_reached_player()
	return _robbery_phase == RobberyPhase.FLEE


func debug_clear_event_cooldown(territory_id := TARGET_TERRITORY) -> void:
	_cooldown_until.erase(territory_id)


func debug_clear_gang_war_cooldown(territory_id := TARGET_TERRITORY) -> void:
	debug_clear_event_cooldown(territory_id)


func _begin_gang_war(territory_id: StringName, tier: int) -> bool:
	_active_encounter = EncounterType.GANG_WAR
	_active_territory = territory_id
	_active_tier = clampi(tier, 1, 4)
	_war_remaining = WAR_DURATION
	_waves_spawned = 0
	_cleanup_attackers()
	_set_wanted_suppression(true)
	set_process(true)
	encounter_started.emit(EncounterType.GANG_WAR, territory_id, WAR_DURATION)
	gang_war_started.emit(territory_id, WAR_DURATION)
	_show_feedback("GANG WAR: survive for 60 seconds.", 4.0)
	_spawn_wave()
	return true


func _begin_robbery(territory_id: StringName) -> bool:
	_active_encounter = EncounterType.ROBBERY
	_active_territory = territory_id
	_robbery_phase = RobberyPhase.APPROACH
	_robbery_remaining = ROBBERY_APPROACH_DURATION
	_stolen_dirty_cash = 0
	_stolen_products.clear()
	if not _spawn_robber(_get_robbery_spawn_position(), _robbery_phase):
		_reset_active_encounter()
		return false
	_set_wanted_suppression(true)
	set_process(true)
	encounter_started.emit(
		EncounterType.ROBBERY,
		territory_id,
		ROBBERY_APPROACH_DURATION
	)
	_show_feedback("ROBBERY: a thief is rushing you!", 4.0)
	return true


func _on_minute_advanced(absolute_minute: int) -> void:
	if absolute_minute % 60 != 0 or is_encounter_active():
		return
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(), player.global_position
	)
	if boundary == null or boundary.stats == null:
		return
	var territory_id := boundary.territory_id
	if get_cooldown_minutes(territory_id) > 0:
		return
	if territory_id == TARGET_TERRITORY and _can_start_war(territory_id):
		if _random.randf() < get_hourly_chance(boundary.stats.reputation):
			start_gang_war(territory_id)
			return
	if _can_start_robbery(territory_id):
		if _random.randf() < get_robbery_hourly_chance(
			boundary.stats.reputation
		):
			start_robbery(territory_id)


func _can_start_war(territory_id: StringName) -> bool:
	if is_encounter_active() or get_cooldown_minutes(territory_id) > 0:
		return false
	var stats := _get_stats(territory_id)
	var health := player.get_node("Components/HealthComponent") as PlayerHealthComponent
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(), player.global_position
	)
	return (
		territory_id == TARGET_TERRITORY
		and stats != null
		and stats.reputation < 0.0
		and stats.owner_faction != TerritoryStatsComponent.OwnerFaction.PLAYER
		and health.is_alive()
		and boundary != null
		and boundary.territory_id == territory_id
	)


func _can_start_robbery(
	territory_id: StringName,
	ignore_cooldown := false
) -> bool:
	if robbery_dealer_scene == null or is_encounter_active():
		return false
	if not ignore_cooldown and get_cooldown_minutes(territory_id) > 0:
		return false
	var stats := _get_stats(territory_id)
	var health := player.get_node("Components/HealthComponent") as PlayerHealthComponent
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(), player.global_position
	)
	return (
		stats != null
		and stats.reputation < ROBBERY_REPUTATION_LIMIT
		and stats.owner_faction != TerritoryStatsComponent.OwnerFaction.PLAYER
		and health.is_alive()
		and boundary != null
		and boundary.territory_id == territory_id
		and _has_stealable_loot()
	)


func _has_stealable_loot() -> bool:
	var wallet := player.get_node_or_null(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node_or_null(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	if wallet != null and floori(
		float(wallet.dirty_cash) * ROBBERY_TRANSFER_PERCENT
	) > 0:
		return true
	return (
		inventory != null
		and not inventory.get_fractional_product_transfer(
			ROBBERY_TRANSFER_PERCENT
		).is_empty()
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
		dealer.global_position = (
			positions[index % positions.size()]
			+ Vector3(float(index / positions.size()) * 1.25, 0.0, 0.0)
		)
		dealer.configure_war_attacker(_roll_attacker_level(), _active_territory)
		_attackers.append(dealer)
	_waves_spawned += 1


func _roll_attacker_level() -> int:
	match _active_tier:
		1: return 1
		2: return _random.randi_range(1, 2)
		3: return _random.randi_range(2, 3)
		_: return _random.randi_range(2, 4)


func _get_robbery_spawn_position() -> Vector3:
	var candidates: Array[Vector3] = []
	for zone in _get_zones(_active_territory):
		for position in zone.get_reinforcement_world_positions():
			var distance := position.distance_to(player.global_position)
			if (
				distance >= ROBBERY_SPAWN_MIN_DISTANCE
				and distance <= ROBBERY_SPAWN_MAX_DISTANCE
			):
				candidates.append(position)
	if not candidates.is_empty():
		return candidates[_random.randi_range(0, candidates.size() - 1)]
	var angle := _random.randf_range(-PI, PI)
	var distance := _random.randf_range(
		ROBBERY_SPAWN_MIN_DISTANCE,
		ROBBERY_SPAWN_MAX_DISTANCE
	)
	return player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance


func _spawn_robber(position: Vector3, phase: int) -> bool:
	if robbery_dealer_scene == null:
		return false
	var spawned := robbery_dealer_scene.instantiate() as RobberyEventDealer
	var container := get_parent().get_node_or_null("Gameplay")
	if spawned == null or container == null:
		return false
	container.add_child(spawned)
	var navigation_map := spawned.navigation_agent.get_navigation_map()
	spawned.global_position = (
		NavigationServer3D.map_get_closest_point(navigation_map, position)
		if navigation_map.is_valid()
		else position
	)
	spawned.configure_robbery_actor(
		player,
		_active_territory,
		RobberyEventDealer.Phase.FLEE
		if phase == RobberyPhase.FLEE
		else RobberyEventDealer.Phase.APPROACH
	)
	spawned.player_reached.connect(_on_robber_reached_player)
	spawned.damageable.depleted.connect(_on_robber_defeated)
	_robber = spawned
	return true


func _on_robber_reached_player() -> void:
	if (
		_active_encounter != EncounterType.ROBBERY
		or _robbery_phase != RobberyPhase.APPROACH
		or not is_instance_valid(_robber)
	):
		return
	var wallet := player.get_node_or_null(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node_or_null(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	if wallet == null or inventory == null:
		_finish_robbery(EncounterResult.CANCELLED)
		return
	var cash := floori(float(wallet.dirty_cash) * ROBBERY_TRANSFER_PERCENT)
	var products := inventory.get_fractional_product_transfer(
		ROBBERY_TRANSFER_PERCENT
	)
	if cash <= 0 and products.is_empty():
		_finish_robbery(EncounterResult.CANCELLED)
		_show_feedback("The thief found nothing to take.", 3.0)
		return
	if not inventory.remove_product_transfer(products):
		_finish_robbery(EncounterResult.CANCELLED)
		return
	if cash > 0 and not wallet.spend_dirty(
		cash, true, "Robbery Loss", "Territory robber stole Dirty Cash"
	):
		inventory.restore_product_transfer(products)
		_finish_robbery(EncounterResult.CANCELLED)
		return
	_stolen_dirty_cash = cash
	_stolen_products = products.duplicate(true)
	_robbery_phase = RobberyPhase.FLEE
	_robbery_remaining = ROBBERY_ESCAPE_DURATION
	_robber.set_robbery_phase(RobberyEventDealer.Phase.FLEE)
	var product_units := 0
	for amount in _stolen_products.values():
		product_units += int(amount)
	_show_feedback(
		"ROBBED: $%d Dirty Cash and %d drug units. Catch the thief!"
		% [_stolen_dirty_cash, product_units],
		5.0
	)


func _on_robber_defeated(
	_source: Node,
	_hit_position: Vector3,
	_hit_direction: Vector3
) -> void:
	if _active_encounter == EncounterType.ROBBERY and is_instance_valid(_robber):
		_finish_robbery(EncounterResult.WON, true)


func _on_player_downed() -> void:
	match _active_encounter:
		EncounterType.GANG_WAR:
			_finish_war(false)
		EncounterType.ROBBERY:
			_finish_robbery(
				EncounterResult.LOST
				if _robbery_phase == RobberyPhase.FLEE
				else EncounterResult.CANCELLED
			)


func _finish_war(won: bool) -> void:
	if _active_encounter != EncounterType.GANG_WAR:
		return
	var territory_id := _active_territory
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
	_set_shared_cooldown(territory_id)
	_cleanup_attackers()
	_reset_active_encounter()
	_set_wanted_suppression(false)
	gang_war_ended.emit(territory_id, won)
	encounter_ended.emit(
		EncounterType.GANG_WAR,
		territory_id,
		EncounterResult.WON if won else EncounterResult.LOST
	)
	_show_feedback(
		"GANG WAR WON: +15 Rep (%d/3 wins)." % get_war_wins(territory_id)
		if won
		else "GANG WAR LOST: -10 Rep.",
		4.0
	)
	if won and get_war_wins(territory_id) >= 3:
		claim_territory(territory_id, &"gang_wars")


func _finish_robbery(result: int, preserve_dead_actor := false) -> void:
	if _active_encounter != EncounterType.ROBBERY:
		return
	var territory_id := _active_territory
	var stats := _get_stats(territory_id)
	if result == EncounterResult.WON:
		_restore_stolen_loot()
		if stats != null:
			stats.add_reputation(ROBBERY_WIN_REPUTATION)
	elif result == EncounterResult.LOST and stats != null:
		stats.add_reputation(ROBBERY_LOSS_REPUTATION)
	_set_shared_cooldown(territory_id)
	if preserve_dead_actor:
		_robber = null
	else:
		_cleanup_robber()
	_reset_active_encounter()
	_set_wanted_suppression(false)
	encounter_ended.emit(EncounterType.ROBBERY, territory_id, result)
	match result:
		EncounterResult.WON:
			_show_feedback("THIEF STOPPED: property recovered, +5 Rep.", 5.0)
		EncounterResult.LOST:
			_show_feedback("THIEF ESCAPED: property lost, -20 Rep.", 5.0)
		_:
			_show_feedback("ROBBERY ENDED: the thief got nothing.", 3.0)


func _restore_stolen_loot() -> void:
	var wallet := player.get_node_or_null(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node_or_null(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	if wallet != null and _stolen_dirty_cash > 0:
		wallet.add_dirty(
			_stolen_dirty_cash,
			true,
			"Robbery Recovery",
			"Recovered stolen Dirty Cash"
		)
	if inventory != null:
		inventory.restore_product_transfer(_stolen_products)
	_stolen_dirty_cash = 0
	_stolen_products.clear()


func _set_shared_cooldown(territory_id: StringName) -> void:
	if territory_id.is_empty():
		return
	_cooldown_until[territory_id] = (
		world_time.get_absolute_minute() + COOLDOWN_MINUTES
	)


func _cleanup_attackers() -> void:
	for attacker in _attackers:
		if is_instance_valid(attacker):
			attacker.queue_free()
	_attackers.clear()


func _cleanup_robber() -> void:
	if is_instance_valid(_robber):
		_robber.queue_free()
	_robber = null


func _reset_active_encounter() -> void:
	_active_encounter = EncounterType.NONE
	_active_territory = &""
	_war_remaining = 0.0
	_waves_spawned = 0
	_active_tier = 0
	_robbery_phase = RobberyPhase.NONE
	_robbery_remaining = 0.0
	_stolen_dirty_cash = 0
	_stolen_products.clear()
	set_process(false)


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
				"position": _vector_to_array(attacker.global_position),
			})
	var robber_data := {}
	if is_instance_valid(_robber) and not _robber.is_defeated():
		robber_data = {
			"position": _vector_to_array(_robber.global_position),
			"health": _robber.damageable.health,
		}
	return {
		"encounter_type": _active_encounter,
		"war_wins": saved_wins,
		"cooldown_until": saved_cooldowns,
		"active_territory": String(_active_territory),
		"war_remaining": _war_remaining,
		"waves_spawned": _waves_spawned,
		"active_tier": _active_tier,
		"attackers": attacker_data,
		"robbery_phase": _robbery_phase,
		"robbery_remaining": _robbery_remaining,
		"robber": robber_data,
		"stolen_dirty_cash": _stolen_dirty_cash,
		"stolen_products": _stolen_products.duplicate(true),
	}


func import_save_data(data: Dictionary) -> void:
	_cleanup_attackers()
	_cleanup_robber()
	_war_wins.clear()
	for key in (data.get("war_wins", {}) as Dictionary).keys():
		_war_wins[StringName(String(key))] = int(
			(data["war_wins"] as Dictionary)[key]
		)
	_cooldown_until.clear()
	for key in (data.get("cooldown_until", {}) as Dictionary).keys():
		_cooldown_until[StringName(String(key))] = int(
			(data["cooldown_until"] as Dictionary)[key]
		)
	_active_territory = StringName(String(data.get("active_territory", "")))
	var saved_type := int(data.get("encounter_type", EncounterType.NONE))
	if (
		saved_type == EncounterType.NONE
		and not _active_territory.is_empty()
		and float(data.get("war_remaining", 0.0)) > 0.0
	):
		saved_type = EncounterType.GANG_WAR
	_active_encounter = clampi(
		saved_type,
		EncounterType.NONE,
		EncounterType.ROBBERY
	)
	match _active_encounter:
		EncounterType.GANG_WAR:
			_import_active_gang_war(data)
		EncounterType.ROBBERY:
			_import_active_robbery(data)
		_:
			_reset_active_encounter()
			_set_wanted_suppression(false)


func _import_active_gang_war(data: Dictionary) -> void:
	_war_remaining = maxf(float(data.get("war_remaining", 0.0)), 0.0)
	_waves_spawned = clampi(
		int(data.get("waves_spawned", 0)), 0, WAVE_TIMES.size()
	)
	_active_tier = clampi(int(data.get("active_tier", 0)), 0, 4)
	if _active_territory.is_empty() or _war_remaining <= 0.0:
		_reset_active_encounter()
		_set_wanted_suppression(false)
		return
	_set_wanted_suppression(true)
	for entry in data.get("attackers", []) as Array:
		_spawn_saved_attacker(entry as Dictionary)
	set_process(true)


func _import_active_robbery(data: Dictionary) -> void:
	_robbery_phase = clampi(
		int(data.get("robbery_phase", RobberyPhase.NONE)),
		RobberyPhase.NONE,
		RobberyPhase.FLEE
	)
	_robbery_remaining = maxf(
		float(data.get("robbery_remaining", 0.0)), 0.0
	)
	_stolen_dirty_cash = maxi(int(data.get("stolen_dirty_cash", 0)), 0)
	_stolen_products = (
		data.get("stolen_products", {}) as Dictionary
	).duplicate(true)
	var robber_data := data.get("robber", {}) as Dictionary
	var position := _array_to_vector(
		robber_data.get("position", []) as Array,
		_get_robbery_spawn_position()
	)
	if (
		_active_territory.is_empty()
		or _robbery_phase == RobberyPhase.NONE
		or _robbery_remaining <= 0.0
		or not _spawn_robber(position, _robbery_phase)
	):
		_restore_stolen_loot()
		_reset_active_encounter()
		_set_wanted_suppression(false)
		return
	var saved_health := clampf(
		float(robber_data.get("health", _robber.damageable.maximum_health)),
		1.0,
		_robber.damageable.maximum_health
	)
	if saved_health < _robber.damageable.maximum_health:
		_robber.damageable.apply_damage(
			_robber.damageable.maximum_health - saved_health
		)
	_set_wanted_suppression(true)
	set_process(true)


func _set_wanted_suppression(active: bool) -> void:
	var wanted := player.get_node_or_null(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	if wanted != null:
		wanted.set_territory_event_suppressed(active)


func _spawn_saved_attacker(data: Dictionary) -> void:
	if dealer_scene == null:
		return
	var dealer := dealer_scene.instantiate() as DealerNPC
	if dealer == null:
		return
	get_parent().get_node("Gameplay").add_child(dealer)
	dealer.global_position = _array_to_vector(
		data.get("position", []) as Array,
		player.global_position + Vector3(12.0, 0.0, 0.0)
	)
	dealer.configure_war_attacker(
		clampi(int(data.get("level", 1)), 1, 4),
		_active_territory
	)
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


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _array_to_vector(value: Array, fallback: Vector3) -> Vector3:
	if value.size() != 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _show_feedback(message: String, duration := 2.5) -> void:
	var hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
	if hud != null:
		hud.show_feedback(message, duration)
