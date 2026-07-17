@tool
class_name ActivitySpot3D
extends Marker3D

const ACTIVITY_SPOT_GROUP := &"npc_activity_spot"

@export var activity_type: StringName = &"stand_wait":
	set(value):
		activity_type = value
		update_configuration_warnings()
@export var animation_name: StringName = &"Idle":
	set(value):
		animation_name = value
		update_configuration_warnings()
@export_range(0.1, 120.0, 0.1) var minimum_duration := 5.0:
	set(value):
		minimum_duration = value
		update_configuration_warnings()
@export_range(0.1, 120.0, 0.1) var maximum_duration := 12.0:
	set(value):
		maximum_duration = value
		update_configuration_warnings()
@export_range(1, 16, 1) var capacity := 1:
	set(value):
		capacity = maxi(value, 1)
		update_configuration_warnings()
@export var allowed_roles := PackedStringArray(["civilian"])
@export_range(0.01, 20.0, 0.01) var selection_weight := 1.0
@export_range(0.1, 5.0, 0.05) var arrival_radius := 0.65
@export_range(0.1, 5.0, 0.05) var slot_spacing := 1.1
@export var allow_random_selection := true
@export var face_slot_center := false
@export var auto_free_when_empty := false

var _occupants: Dictionary[int, WeakRef] = {}
var _slots: Dictionary[int, int] = {}
var _has_held_reservation := false


func _enter_tree() -> void:
	add_to_group(ACTIVITY_SPOT_GROUP)


func try_reserve(npc: Node) -> int:
	_prune_invalid_reservations()
	if npc == null or not is_role_allowed(npc):
		return -1
	var instance_id := int(npc.get_instance_id())
	if _slots.has(instance_id):
		return int(_slots[instance_id])
	var slot_index := _find_available_slot()
	if slot_index < 0:
		return -1
	_occupants[instance_id] = weakref(npc)
	_slots[instance_id] = slot_index
	_has_held_reservation = true
	var callback := _on_occupant_tree_exiting.bind(instance_id)
	if not npc.tree_exiting.is_connected(callback):
		npc.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
	return slot_index


func release(npc: Node) -> void:
	if npc == null:
		return
	_release_instance_id(int(npc.get_instance_id()))


func has_reservation(npc: Node) -> bool:
	_prune_invalid_reservations()
	return npc != null and _slots.has(int(npc.get_instance_id()))


func get_reserved_count() -> int:
	_prune_invalid_reservations()
	return _slots.size()


func get_available_count() -> int:
	return maxi(capacity - get_reserved_count(), 0)


func get_reserved_slot(npc: Node) -> int:
	if not has_reservation(npc):
		return -1
	return int(_slots[int(npc.get_instance_id())])


func get_reserved_npcs() -> Array[Node]:
	_prune_invalid_reservations()
	var result: Array[Node] = []
	for reference in _occupants.values():
		var weak_reference := reference as WeakRef
		if weak_reference == null:
			continue
		var npc := weak_reference.get_ref() as Node
		if is_instance_valid(npc):
			result.append(npc)
	return result


func get_slot_position(slot_index: int) -> Vector3:
	var centered_index := float(slot_index) - float(capacity - 1) * 0.5
	return global_transform * Vector3(centered_index * slot_spacing, 0.0, 0.0)


func get_slot_facing_y(slot_index: int) -> float:
	if face_slot_center and capacity > 1:
		var centered_index := float(slot_index) - float(capacity - 1) * 0.5
		return global_rotation.y + (PI * 0.5 if centered_index < 0.0 else -PI * 0.5)
	return global_rotation.y


func get_random_duration(random: RandomNumberGenerator) -> float:
	var low := minf(minimum_duration, maximum_duration)
	var high := maxf(minimum_duration, maximum_duration)
	if random == null:
		return randf_range(low, high)
	return random.randf_range(low, high)


func is_role_allowed(npc: Node) -> bool:
	if allowed_roles.is_empty():
		return true
	if npc == null or not npc.has_method("get_activity_role"):
		return false
	return String(npc.call("get_activity_role")) in allowed_roles


func _find_available_slot() -> int:
	var occupied_slots := _slots.values()
	for slot_index in range(capacity):
		if slot_index not in occupied_slots:
			return slot_index
	return -1


func _prune_invalid_reservations() -> void:
	for instance_id in _occupants.keys():
		var reference := _occupants[instance_id] as WeakRef
		if reference == null or not is_instance_valid(reference.get_ref()):
			_release_instance_id(int(instance_id))


func _release_instance_id(instance_id: int) -> void:
	_occupants.erase(instance_id)
	_slots.erase(instance_id)
	if (
		auto_free_when_empty
		and _has_held_reservation
		and _slots.is_empty()
		and is_inside_tree()
		and not is_queued_for_deletion()
	):
		queue_free()


func _on_occupant_tree_exiting(instance_id: int) -> void:
	_release_instance_id(instance_id)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if activity_type.is_empty():
		warnings.append("Activity type is empty.")
	if animation_name.is_empty():
		warnings.append("Animation name is empty; Idle fallback will be used.")
	if minimum_duration > maximum_duration:
		warnings.append("Minimum duration is greater than maximum duration.")
	if capacity < 1:
		warnings.append("Capacity must be at least one.")
	return warnings
