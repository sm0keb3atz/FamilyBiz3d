@tool
class_name TerritoryMobility3D
extends Node3D

const MOBILITY_GROUP := &"territory_mobility"

@export var territory_id: StringName = &""
@export var traffic_routes_path := NodePath("TrafficRoutes")
@export var pedestrian_network_path := NodePath("PedestrianNetwork")


func _enter_tree() -> void:
	add_to_group(MOBILITY_GROUP)


func get_traffic_routes() -> Node:
	return get_node_or_null(traffic_routes_path)


func get_pedestrian_network() -> PedestrianNetwork3D:
	return get_node_or_null(pedestrian_network_path) as PedestrianNetwork3D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if territory_id == &"":
		warnings.append("Territory mobility needs a stable territory_id.")
	if get_traffic_routes() == null:
		warnings.append("Territory mobility has no traffic route root.")
	if get_pedestrian_network() == null:
		warnings.append("Territory mobility has no pedestrian network.")
	return warnings
