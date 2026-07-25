class_name WorldEvent
extends RefCounted

enum Type {
	UNKNOWN,
	GUNSHOT,
	VISIBLE_CRIME,
	ACTOR_ATTACKED,
	OFFICER_DOWN,
	BODY_DISCOVERED,
	POLICE_PRESENCE,
	SIREN,
}

var event_id := 0
var event_type := Type.UNKNOWN
var world_position := Vector3.ZERO
var source_actor: Node
var source_actor_id := 0
var source_faction: StringName = &"unknown"
var created_at_seconds := 0.0
var audible_radius := 0.0
var severity := 1
var territory_id: StringName = &""
var lifetime_seconds := 30.0
var metadata := {}


func is_source_known() -> bool:
	return is_instance_valid(source_actor) or source_actor_id != 0


func get_source_actor() -> Node:
	return source_actor if is_instance_valid(source_actor) else null


func to_dictionary() -> Dictionary:
	return {
		"event_id": event_id,
		"event_type": event_type,
		"world_position": world_position,
		"source_actor_id": source_actor_id,
		"source_faction": String(source_faction),
		"created_at_seconds": created_at_seconds,
		"audible_radius": audible_radius,
		"severity": severity,
		"territory_id": String(territory_id),
		"lifetime_seconds": lifetime_seconds,
		"metadata": metadata.duplicate(true),
	}
