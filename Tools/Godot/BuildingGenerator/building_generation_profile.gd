@tool
class_name BuildingGenerationProfile
extends Resource

enum Preset {
	CLASSIC_MIXED_USE,
	BRICK_RETAIL,
	OFFICE_HIGH_RISE,
}

enum MaterialPalette {
	DEFAULT,
	WHITE_BRICK,
	RED_BRICK,
	VIOLET_BRICK,
	YELLOW_BRICK,
}

enum PropDensity {
	NONE,
	LOW,
	MEDIUM,
	HIGH,
}

@export_group("Shape")
@export_range(2, 12, 1, "or_greater") var width_modules := 4
@export_range(2, 12, 1, "or_greater") var depth_modules := 3
@export_range(2, 20, 1, "or_greater") var story_count := 3

@export_group("Appearance")
@export var preset := Preset.CLASSIC_MIXED_USE
@export var material_palette := MaterialPalette.WHITE_BRICK
@export var prop_density := PropDensity.LOW

@export_group("Layout")
## A negative value picks a deterministic front module from the seed.
@export_range(-1, 64, 1, "or_greater") var entrance_module := -1
@export_range(0, 2147483647, 1) var seed := 1337


func _init() -> void:
	resource_local_to_scene = true


func sanitize() -> void:
	width_modules = maxi(width_modules, 2)
	depth_modules = maxi(depth_modules, 2)
	story_count = maxi(story_count, 2)
	# The verified building fronts face +X, so their horizontal facade span is
	# the footprint depth.
	entrance_module = clampi(entrance_module, -1, depth_modules - 1)
	seed = maxi(seed, 0)
