class_name TerritoryBoundary
extends Area3D

@export var territory_id: StringName
@export var display_name := "Unknown Territory"
@export var local_center := Vector3(64.0, 0.0, 0.0)
@export var local_half_extents := Vector3(73.0, 10.0, 126.5)
@export var stats_path := NodePath("../TerritoryStats")

@onready var stats := get_node(stats_path) as TerritoryStatsComponent


func _ready() -> void:
	add_to_group("territory_boundaries")
	if stats != null:
		stats.territory_id = territory_id


func contains_world_position(world_position: Vector3) -> bool:
	var local_position := to_local(world_position) - local_center
	return (
		absf(local_position.x) <= local_half_extents.x
		and absf(local_position.y) <= local_half_extents.y
		and absf(local_position.z) <= local_half_extents.z
	)


static func find_at_position(
	tree: SceneTree,
	world_position: Vector3
) -> TerritoryBoundary:
	for node in tree.get_nodes_in_group("territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.contains_world_position(world_position):
			return boundary
	return null
