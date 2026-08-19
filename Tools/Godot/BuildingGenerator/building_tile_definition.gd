@tool
class_name BuildingTileDefinition
extends Resource

enum TileRole {
	STRUCTURE,
	FACADE,
	WINDOW,
	ENTRANCE,
	FLOOR,
	ROOF,
	ATTIC,
	CORNICE,
	PROP,
}

enum PropPlacement {
	ANY_WALL,
	FRONT_WALL,
	GROUND_FRONT,
}

@export var display_name := "Building Tile"
@export var node_name_prefix := "GeneratedTile"
@export var role := TileRole.FACADE
@export var mesh: Mesh
@export var scene: PackedScene

## Facades use a two-meter cell, so a normal four-meter tile spans two cells.
@export_range(1, 8, 1) var facade_cells := 2
@export_range(0.01, 100.0, 0.01) var weight := 1.0
@export_flags("Front", "Right", "Back", "Left") var allowed_sides := 15
@export var placement_offset := Vector3.ZERO
@export var yaw_offset_degrees := 0.0
## Optional visual that is placed with this tile, using its own local offset.
@export var paired_detail: BuildingTileDefinition

@export_group("Material Surfaces")
@export var facade_surfaces := PackedInt32Array()
@export var trim_surfaces := PackedInt32Array()
@export_range(-1, 32, 1) var window_surface := -1

@export_group("Exterior Prop")
@export var prop_placement := PropPlacement.ANY_WALL
@export_range(0.0, 100.0, 0.1) var prop_min_height := 0.0
@export_range(0.0, 100.0, 0.1) var prop_max_height := 3.0
@export_range(0.0, 4.0, 0.05) var prop_outward_offset := 0.2


func has_visual() -> bool:
	return mesh != null or scene != null


func is_allowed_on_side(side: int) -> bool:
	return side >= 0 and side < 4 and (allowed_sides & (1 << side)) != 0


func source_path() -> String:
	if mesh != null:
		return mesh.resource_path
	if scene != null:
		return scene.resource_path
	return ""
