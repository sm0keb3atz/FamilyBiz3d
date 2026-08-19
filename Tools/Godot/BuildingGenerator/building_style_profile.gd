@tool
class_name BuildingStyleProfile
extends Resource

@export var display_name := "Building Style"
@export_multiline var description := ""
@export var trim_color := Color(0.085, 0.085, 0.085, 1.0)

@export_group("Facade Modules")
@export var regular_facade_a: BuildingTileDefinition
@export var regular_facade_b: BuildingTileDefinition
@export var regular_facade_c: BuildingTileDefinition
@export var regular_facade_d: BuildingTileDefinition
@export var ground_facade: BuildingTileDefinition
@export var entrance_a: BuildingTileDefinition
@export var entrance_b: BuildingTileDefinition

@export_group("Structure")
@export var corner: BuildingTileDefinition
@export var attic_wall: BuildingTileDefinition
@export var attic_corner: BuildingTileDefinition
@export var cornice: BuildingTileDefinition
@export var cornice_corner: BuildingTileDefinition
@export var floor_tile: BuildingTileDefinition
@export var roof_tile: BuildingTileDefinition

@export_group("Exterior Props")
@export var prop_a: BuildingTileDefinition
@export var prop_b: BuildingTileDefinition
@export var prop_c: BuildingTileDefinition
@export var prop_d: BuildingTileDefinition
@export var prop_e: BuildingTileDefinition


func regular_facades() -> Array[BuildingTileDefinition]:
	return _valid_tiles([
		regular_facade_a,
		regular_facade_b,
		regular_facade_c,
		regular_facade_d,
	])


func ground_facades() -> Array[BuildingTileDefinition]:
	if ground_facade != null and ground_facade.has_visual():
		return [ground_facade]
	return regular_facades()


func entrances() -> Array[BuildingTileDefinition]:
	return _valid_tiles([entrance_a, entrance_b])


func exterior_props() -> Array[BuildingTileDefinition]:
	return _valid_tiles([prop_a, prop_b, prop_c, prop_d, prop_e])


func _valid_tiles(values: Array) -> Array[BuildingTileDefinition]:
	var result: Array[BuildingTileDefinition] = []
	for value in values:
		var tile := value as BuildingTileDefinition
		if tile != null and tile.has_visual():
			result.append(tile)
	return result
