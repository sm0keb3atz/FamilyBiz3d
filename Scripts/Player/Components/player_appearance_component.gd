class_name PlayerAppearanceComponent
extends Node

signal appearance_changed(
	slot: StringName,
	option_index: int,
	option_name: String
)
signal material_changed(
	slot: StringName,
	material_index: int,
	material_name: String
)

const SLOT_TOP := &"top"
const SLOT_BOTTOM := &"bottom"
const SLOT_SHOES := &"shoes"
const SLOT_BODY := &"body"
const BODY_TEXTURE_01 := preload(
	"res://Assets/BaseChracters/Player/Materials/Modular/Body_Texture_01.tres"
)
const BODY_TEXTURE_02 := preload(
	"res://Assets/BaseChracters/Player/Materials/Modular/Body_Texture_02.tres"
)
const HOODIE_TEXTURE_01 := preload(
	"res://Assets/BaseChracters/Player/Materials/Modular/Hoodie_Texture_01.tres"
)
const HOODIE_TEXTURE_02 := preload(
	"res://Assets/BaseChracters/Player/Materials/Modular/Hoodie_Texture_02.tres"
)
const TSHIRT_ORIGINAL := preload(
	"res://Assets/BaseChracters/Player/Materials/Modular/TShirt_Original.tres"
)
const JEANS_ORIGINAL := preload(
	"res://Assets/BaseChracters/Player/Materials/Modular/Jeans_Original.tres"
)
const SWEATPANTS_ORIGINAL := preload(
	"res://Assets/BaseChracters/Player/Materials/Modular/Sweatpants_Original.tres"
)
const SNEAKERS_ORIGINAL := preload(
	"res://Assets/BaseChracters/Player/Materials/Modular/Sneakers_Original.tres"
)
const BOOTS_ORIGINAL := preload(
	"res://Assets/BaseChracters/Player/Materials/Modular/Boots_Original.tres"
)
const BODY_MESHES := [
	&"BODY_Head",
	&"BODY_Hands",
	&"BODY_Torso",
	&"BODY_Legs",
	&"BODY_Feet",
]

@export var skeleton_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton"
)
@export var keep_body_torso_visible := true

var _skeleton: Skeleton3D
var _options := {
	SLOT_TOP: [
		{"node": &"TOP_01_Hoodie", "name": "Hoodie"},
		{"node": &"TOP_02_TShirt", "name": "T-Shirt"},
	],
	SLOT_BOTTOM: [
		{"node": &"BOTTOM_01_Jeans", "name": "Jeans"},
		{"node": &"BOTTOM_02_Sweatpants", "name": "Sweatpants"},
	],
	SLOT_SHOES: [
		{"node": &"SHOES_01_Sneakers", "name": "Sneakers"},
		{"node": &"SHOES_02_Boots", "name": "Boots"},
	],
}
var _selected := {
	SLOT_TOP: 0,
	SLOT_BOTTOM: 0,
	SLOT_SHOES: 0,
}
var _selected_material := {
	SLOT_BODY: 0,
	SLOT_TOP: 0,
	SLOT_BOTTOM: 0,
	SLOT_SHOES: 0,
}


func _ready() -> void:
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		push_error(
			"PlayerAppearanceComponent could not find GeneralSkeleton."
		)
		return
	_apply_body_visibility()
	_apply_material(SLOT_BODY)
	for slot in _options:
		_apply_slot(slot)
		_apply_material(slot)


func cycle_option(slot: StringName, direction: int) -> void:
	if not _options.has(slot):
		return
	var options: Array = _options[slot]
	if options.is_empty():
		return
	var current := int(_selected[slot])
	_selected[slot] = wrapi(current + direction, 0, options.size())
	_selected_material[slot] = 0
	_apply_slot(slot)
	_apply_material(slot)


func set_option(slot: StringName, option_index: int) -> void:
	if not _options.has(slot):
		return
	var options: Array = _options[slot]
	if option_index < 0 or option_index >= options.size():
		return
	_selected[slot] = option_index
	_selected_material[slot] = 0
	_apply_slot(slot)
	_apply_material(slot)


func get_option_name(slot: StringName) -> String:
	if not _options.has(slot):
		return ""
	var options: Array = _options[slot]
	if options.is_empty():
		return ""
	var option: Dictionary = options[int(_selected[slot])]
	return str(option["name"])


func randomize_appearance() -> void:
	var body_materials := _get_material_options(SLOT_BODY)
	_selected_material[SLOT_BODY] = randi_range(
		0,
		body_materials.size() - 1
	)
	_apply_material(SLOT_BODY)
	for slot in _options:
		var options: Array = _options[slot]
		if not options.is_empty():
			_selected[slot] = randi_range(0, options.size() - 1)
			var materials := _get_material_options(slot)
			_selected_material[slot] = randi_range(
				0,
				materials.size() - 1
			)
			_apply_slot(slot)
			_apply_material(slot)


func reset_appearance() -> void:
	_selected_material[SLOT_BODY] = 0
	_apply_material(SLOT_BODY)
	for slot in _selected:
		_selected[slot] = 0
		_selected_material[slot] = 0
		_apply_slot(slot)
		_apply_material(slot)


func cycle_material(slot: StringName, direction: int) -> void:
	if slot != SLOT_BODY and not _options.has(slot):
		return
	var materials := _get_material_options(slot)
	if materials.is_empty():
		return
	_selected_material[slot] = wrapi(
		int(_selected_material[slot]) + direction,
		0,
		materials.size()
	)
	_apply_material(slot)


func get_material_name(slot: StringName) -> String:
	if slot != SLOT_BODY and not _options.has(slot):
		return ""
	var materials := _get_material_options(slot)
	if materials.is_empty():
		return ""
	return str(materials[int(_selected_material[slot])]["name"])


func set_ragdoll_visibility(_active: bool) -> void:
	if _skeleton == null:
		return
	_apply_body_visibility()


func _apply_slot(slot: StringName) -> void:
	if _skeleton == null:
		return
	var options: Array = _options[slot]
	var selected_index := int(_selected[slot])
	for index in options.size():
		var option: Dictionary = options[index]
		var mesh := _skeleton.get_node_or_null(
			NodePath(str(option["node"]))
		) as MeshInstance3D
		if mesh == null:
			push_warning(
				"Missing appearance mesh: %s" % option["node"]
			)
			continue
		mesh.visible = index == selected_index
	var selected_option: Dictionary = options[selected_index]
	appearance_changed.emit(
		slot,
		selected_index,
		str(selected_option["name"])
	)


func _apply_material(slot: StringName) -> void:
	if _skeleton == null:
		return
	var materials := _get_material_options(slot)
	var material_index := int(_selected_material[slot])
	var material_option: Dictionary = materials[material_index]
	var material: Material = material_option.get("material") as Material
	if slot == SLOT_BODY:
		for mesh_name in BODY_MESHES:
			var body_mesh := _skeleton.get_node_or_null(
				NodePath(str(mesh_name))
			) as MeshInstance3D
			if body_mesh != null:
				body_mesh.material_override = material
	else:
		var option: Dictionary = _options[slot][int(_selected[slot])]
		var mesh := _skeleton.get_node_or_null(
			NodePath(str(option["node"]))
		) as MeshInstance3D
		if mesh == null:
			return
		mesh.material_override = material
	material_changed.emit(
		slot,
		material_index,
		str(material_option["name"])
	)


func _get_material_options(slot: StringName) -> Array:
	if slot == SLOT_BODY:
		return [
			{"name": "Body 1", "material": BODY_TEXTURE_01},
			{"name": "Body 2", "material": BODY_TEXTURE_02},
		]
	var option: Dictionary = _options[slot][int(_selected[slot])]
	var node_name := StringName(option["node"])
	var materials: Array = []
	match node_name:
		&"TOP_01_Hoodie":
			materials = [
				{"name": "Hoodie 1", "material": HOODIE_TEXTURE_01},
				{"name": "Hoodie 2", "material": HOODIE_TEXTURE_02},
			]
		&"TOP_02_TShirt":
			materials = [
				{"name": "Original", "material": TSHIRT_ORIGINAL},
			]
		&"BOTTOM_01_Jeans":
			materials = [
				{"name": "Original", "material": JEANS_ORIGINAL},
			]
		&"BOTTOM_02_Sweatpants":
			materials = [
				{"name": "Original", "material": SWEATPANTS_ORIGINAL},
			]
		&"SHOES_01_Sneakers":
			materials = [
				{"name": "Original", "material": SNEAKERS_ORIGINAL},
			]
		&"SHOES_02_Boots":
			materials = [
				{"name": "Original", "material": BOOTS_ORIGINAL},
			]
	return materials


func _apply_body_visibility() -> void:
	_set_mesh_visible(&"BODY_Head", true)
	_set_mesh_visible(&"BODY_Hands", true)
	_set_mesh_visible(&"BODY_Torso", keep_body_torso_visible)
	_set_mesh_visible(&"BODY_Legs", true)
	_set_mesh_visible(&"BODY_Feet", false)


func _set_mesh_visible(mesh_name: StringName, visible: bool) -> void:
	var mesh := _skeleton.get_node_or_null(
		NodePath(str(mesh_name))
	) as MeshInstance3D
	if mesh != null:
		mesh.visible = visible
