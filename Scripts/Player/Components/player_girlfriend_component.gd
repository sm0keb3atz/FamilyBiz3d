class_name PlayerGirlfriendComponent
extends Node

signal roster_changed
signal status_changed(npc: CustomerNPC, status: StringName)
signal relationship_changed(npc: CustomerNPC, relationship: int)
signal automatic_breakup(npc: CustomerNPC)

const STATUS_FOLLOWING := &"following"
const STATUS_HOME := &"home"
const NAMES := ["Aaliyah", "Brianna", "Camila", "Destiny", "Jade", "Kayla", "Maya", "Nia", "Raven", "Sasha", "Tiana", "Zoe"]
const AURA_REQUIREMENTS := {1: 50, 2: 75, 3: 100, 4: 150}

@export var appearance_component_path := NodePath("../AppearanceComponent")
@export var hud_path := NodePath("../../PlayerHUD")
@export var wallet_component_path := NodePath("../WalletComponent")
@export var player_path := NodePath("../..")
@export_range(0.1, 120.0, 0.1) var following_seconds_per_point := 10.0
@export_range(0.1, 120.0, 0.1) var home_seconds_per_point := 30.0
@export_range(0.0, 10.0, 0.05) var heat_decay_per_level := 0.25

var _entries: Array[Dictionary] = []
var _next_name_index := 0


func _process(delta: float) -> void:
	_update_relationships(delta)
	_apply_following_heat_decay(delta)


func get_aura_requirement(level: int) -> int:
	return int(AURA_REQUIREMENTS.get(clampi(level, 1, 4), 150))


func can_recruit(npc: CustomerNPC) -> bool:
	return npc != null and not has_girlfriend(npc) and get_current_aura() >= get_aura_requirement(npc.get_customer_level())


func recruit(npc: CustomerNPC) -> bool:
	if not can_recruit(npc):
		return false
	var entry := {"npc": npc, "name": _next_name(), "level": npc.get_customer_level(), "status": STATUS_FOLLOWING, "relationship": 0, "relationship_elapsed": 0.0}
	_entries.append(entry)
	npc.begin_girlfriend_following(get_parent().get_parent(), self, _entries.size() - 1)
	roster_changed.emit()
	_show_feedback("%s: I'd love to!" % entry["name"])
	return true


func send_home(npc: CustomerNPC) -> bool:
	var index := _find_index(npc)
	if index < 0:
		return false
	_entries[index]["status"] = STATUS_HOME
	npc.send_girlfriend_home()
	status_changed.emit(npc, STATUS_HOME)
	roster_changed.emit()
	_show_feedback("%s went home." % _entries[index]["name"])
	return true


func call_girlfriend(npc: CustomerNPC) -> bool:
	var index := _find_index(npc)
	if index < 0:
		return false
	_entries[index]["status"] = STATUS_FOLLOWING
	npc.call_girlfriend(get_parent().get_parent(), index)
	status_changed.emit(npc, STATUS_FOLLOWING)
	roster_changed.emit()
	_show_feedback("%s is on her way." % _entries[index]["name"])
	return true


func break_up(npc: CustomerNPC) -> bool:
	var index := _find_index(npc)
	if index < 0:
		return false
	var display_name := str(_entries[index]["name"])
	_entries.remove_at(index)
	npc.end_girlfriend_relationship()
	_reassign_follow_slots()
	roster_changed.emit()
	_show_feedback("You broke up with %s." % display_name)
	return true


func remove_girlfriend_due_to_death(npc: CustomerNPC) -> void:
	var index := _find_index(npc)
	if index < 0:
		return
	var display_name := str(_entries[index]["name"])
	_entries.remove_at(index)
	_reassign_follow_slots()
	roster_changed.emit()
	_show_feedback("%s died and was removed from your girlfriends." % display_name)


func get_roster() -> Array[Dictionary]:
	_prune_invalid_entries()
	return _entries.duplicate(true)


func has_girlfriend(npc: CustomerNPC) -> bool:
	return _find_index(npc) >= 0


func get_current_aura() -> int:
	var appearance := get_node_or_null(appearance_component_path) as PlayerAppearanceComponent
	return appearance.get_current_aura() if appearance != null else 0


func get_relationship(npc: CustomerNPC) -> int:
	var index := _find_index(npc)
	return int(_entries[index]["relationship"]) if index >= 0 else 0


func adjust_relationship(npc: CustomerNPC, amount: int) -> bool:
	var index := _find_index(npc)
	if index < 0 or amount == 0:
		return false
	var previous := int(_entries[index]["relationship"])
	var next_value := clampi(previous + amount, -100, 100)
	if next_value == previous:
		return false
	_entries[index]["relationship"] = next_value
	relationship_changed.emit(npc, next_value)
	roster_changed.emit()
	if next_value <= -100:
		_automatic_break_up(npc)
	return true


func purchase_gift(npc: CustomerNPC, cost: int, relationship_gain: int) -> bool:
	var index := _find_index(npc)
	if index < 0 or _entries[index]["status"] != STATUS_FOLLOWING:
		return false
	var wallet := get_node_or_null(wallet_component_path) as PlayerWalletComponent
	if wallet == null or not wallet.spend_dirty(cost):
		_show_feedback("You do not have enough dirty cash.")
		return false
	adjust_relationship(npc, relationship_gain)
	_show_feedback("%s appreciated the $%d gift. Relationship +%d." % [_entries[index]["name"], cost, relationship_gain])
	return true


func get_following_heat_decay_bonus() -> float:
	var total := 0.0
	for entry in _entries:
		var npc: Variant = entry.get("npc")
		if not is_instance_valid(npc) or entry["status"] != STATUS_FOLLOWING:
			continue
		var bonus := float(entry["level"]) * heat_decay_per_level
		if int(entry["relationship"]) >= 100:
			bonus *= 2.0
		total += bonus
	return total


func _find_index(npc: CustomerNPC) -> int:
	for index in _entries.size():
		if _entries[index]["npc"] == npc:
			return index
	return -1


func _next_name() -> String:
	var result: String = NAMES[_next_name_index % NAMES.size()]
	_next_name_index += 1
	return result


func _reassign_follow_slots() -> void:
	for index in _entries.size():
		var npc := _entries[index]["npc"] as CustomerNPC
		if is_instance_valid(npc):
			npc.set_girlfriend_follow_slot(index)


func _prune_invalid_entries() -> void:
	var removed := false
	for index in range(_entries.size() - 1, -1, -1):
		var npc: Variant = _entries[index].get("npc")
		if not is_instance_valid(npc):
			_entries.remove_at(index)
			removed = true
	if removed:
		_reassign_follow_slots()


func _show_feedback(message: String) -> void:
	var hud := get_node_or_null(hud_path) as PlayerHUD
	if hud != null:
		hud.show_feedback(message)


func _update_relationships(delta: float) -> void:
	var pending_breakups: Array[CustomerNPC] = []
	for entry in _entries:
		var npc := entry["npc"] as CustomerNPC
		if not is_instance_valid(npc):
			continue
		entry["relationship_elapsed"] = float(entry["relationship_elapsed"]) + delta
		var following: bool = entry["status"] == STATUS_FOLLOWING
		var interval: float = following_seconds_per_point if following else home_seconds_per_point
		while float(entry["relationship_elapsed"]) >= interval:
			entry["relationship_elapsed"] = float(entry["relationship_elapsed"]) - interval
			var next_value := clampi(int(entry["relationship"]) + (1 if following else -1), -100, 100)
			if next_value == int(entry["relationship"]):
				break
			entry["relationship"] = next_value
			relationship_changed.emit(npc, next_value)
			roster_changed.emit()
			if next_value <= -100:
				pending_breakups.append(npc)
				break
	for npc in pending_breakups:
		_automatic_break_up(npc)


func _automatic_break_up(npc: CustomerNPC) -> void:
	var index := _find_index(npc)
	if index < 0:
		return
	var display_name := str(_entries[index]["name"])
	_entries.remove_at(index)
	npc.end_girlfriend_relationship()
	_reassign_follow_slots()
	automatic_breakup.emit(npc)
	roster_changed.emit()
	_show_feedback("%s ended the relationship." % display_name)


func _apply_following_heat_decay(delta: float) -> void:
	var bonus := get_following_heat_decay_bonus()
	if bonus <= 0.0:
		return
	var player := get_node_or_null(player_path) as CharacterBody3D
	if player == null:
		return
	var boundary := TerritoryBoundary.find_at_position(get_tree(), player.global_position)
	if boundary != null and boundary.stats != null and boundary.stats.heat > 0.0:
		boundary.stats.set_heat(boundary.stats.heat - bonus * delta)
