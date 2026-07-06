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
const AUTO_MESH_DIR := "res://Assets/BaseChracters/Player/Meshes/Auto"
const AUTO_MATERIAL_DIR := (
	"res://Assets/BaseChracters/Player/Materials/Variants"
)
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
		{"node": &"TOP_03_PoliceShirt", "name": "Police Shirt"},
	],
	SLOT_BOTTOM: [
		{"node": &"BOTTOM_01_Jeans", "name": "Jeans"},
		{"node": &"BOTTOM_02_Sweatpants", "name": "Sweatpants"},
		{"node": &"BOTTOM_03_PolicePants", "name": "Police Pants"},
	],
	SLOT_SHOES: [
		{"node": &"SHOES_01_Sneakers", "name": "Sneakers"},
		{"node": &"SHOES_02_Boots", "name": "Boots"},
		{"node": &"SHOES_03_PoliceBoots", "name": "Police Boots"},
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
var _material_variants: Dictionary = {}


func _ready() -> void:
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		push_error(
			"PlayerAppearanceComponent could not find GeneralSkeleton."
		)
		return
	_discover_auto_meshes()
	_discover_auto_materials()
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


func randomize_appearance(profile := &"all") -> void:
	var body_materials := _get_material_options(SLOT_BODY)
	_selected_material[SLOT_BODY] = randi_range(
		0,
		body_materials.size() - 1
	)
	_apply_material(SLOT_BODY)
	for slot in _options:
		var options: Array = _options[slot]
		if not options.is_empty():
			var maximum_index := (
				mini(1, options.size() - 1)
				if profile == &"civilian"
				else options.size() - 1
			)
			_selected[slot] = randi_range(0, maximum_index)
			var materials := _get_material_options(slot)
			_selected_material[slot] = randi_range(
				0,
				materials.size() - 1
			)
			_apply_slot(slot)
			_apply_material(slot)


func apply_police_uniform() -> void:
	for slot in _options:
		var options: Array = _options[slot]
		if options.size() < 3:
			continue
		_selected[slot] = 2
		_selected_material[slot] = 0
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
	_apply_body_visibility()
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
		&"TOP_03_PoliceShirt":
			materials = [
				{"name": "Original", "material": null},
			]
		&"BOTTOM_03_PolicePants":
			materials = [
				{"name": "Original", "material": null},
			]
		&"SHOES_03_PoliceBoots":
			materials = [
				{"name": "Original", "material": null},
			]
	if materials.is_empty():
		materials = [
			{"name": "Original", "material": null},
		]
	if _material_variants.has(node_name):
		var variants: Array = _material_variants[node_name]
		for variant in variants:
			materials.append(variant)
	return materials


func _discover_auto_materials() -> void:
	var directory := DirAccess.open(AUTO_MATERIAL_DIR)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir():
			_register_material_file(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()

	for node_name in _material_variants:
		var variants: Array = _material_variants[node_name]
		variants.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return str(a["name"]) < str(b["name"])
		)


func _register_material_file(file_name: String) -> void:
	var extension := file_name.get_extension().to_lower()
	if extension != "tres" and extension != "res":
		return
	var base_name := file_name.get_basename()
	var separator_index := base_name.find("__")
	if separator_index <= 0:
		return
	var node_name := StringName(base_name.substr(0, separator_index))
	var display_name := base_name.substr(separator_index + 2)
	if display_name.is_empty():
		return
	var material := load(
		AUTO_MATERIAL_DIR + "/" + file_name
	) as Material
	if material == null:
		return
	display_name = display_name.replace("_", " ")
	if not _material_variants.has(node_name):
		_material_variants[node_name] = []
	var variants: Array = _material_variants[node_name]
	variants.append(
		{"name": display_name, "material": material}
	)


func _discover_auto_meshes() -> void:
	var directory := DirAccess.open(AUTO_MESH_DIR)
	if directory == null:
		return
	var shared_skin := _find_shared_skin()
	if shared_skin == null:
		push_warning("FB clothing pipeline could not find the player skin.")
		return

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".res"):
			var node_name := file_name.get_basename()
			var mesh := load(
				AUTO_MESH_DIR + "/" + file_name
			) as ArrayMesh
			if mesh != null:
				_install_auto_mesh(node_name, mesh, shared_skin)
		file_name = directory.get_next()
	directory.list_dir_end()

	for slot in _options:
		var options: Array = _options[slot]
		options.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return str(a["node"]) < str(b["node"])
		)


func _find_shared_skin() -> Skin:
	for body_name in BODY_MESHES:
		var body_mesh := _skeleton.get_node_or_null(
			NodePath(str(body_name))
		) as MeshInstance3D
		if body_mesh != null and body_mesh.skin != null:
			return body_mesh.skin
	return null


func _install_auto_mesh(
	node_name: String,
	mesh: ArrayMesh,
	shared_skin: Skin
) -> void:
	var mesh_instance := _skeleton.get_node_or_null(
		NodePath(node_name)
	) as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = node_name
		mesh_instance.skin = shared_skin
		mesh_instance.skeleton = NodePath("..")
		_skeleton.add_child(mesh_instance)
	mesh_instance.mesh = mesh
	mesh_instance.visible = false

	var slot := _slot_from_node_name(node_name)
	if slot == &"" or _has_option(slot, node_name):
		return
	var options: Array = _options[slot]
	options.append(
		{
			"node": StringName(node_name),
			"name": _display_name_from_node_name(node_name),
		}
	)


func _slot_from_node_name(node_name: String) -> StringName:
	if node_name.begins_with("TOP_"):
		return SLOT_TOP
	if node_name.begins_with("BOTTOM_"):
		return SLOT_BOTTOM
	if node_name.begins_with("SHOES_"):
		return SLOT_SHOES
	return &""


func _has_option(slot: StringName, node_name: String) -> bool:
	var options: Array = _options[slot]
	for option in options:
		if str(option["node"]) == node_name:
			return true
	return false


func _display_name_from_node_name(node_name: String) -> String:
	var parts := node_name.split("_", false)
	if parts.size() < 3:
		return node_name
	var description := "_".join(parts.slice(2)).replace("_", " ")
	var camel_case := RegEx.new()
	camel_case.compile("([a-z0-9])([A-Z])")
	return camel_case.sub(description, "$1 $2", true)


func _apply_body_visibility() -> void:
	var selected_top := _selected_node_name(SLOT_TOP)
	var selected_bottom := _selected_node_name(SLOT_BOTTOM)
	_set_mesh_visible(&"BODY_Head", true)
	_set_mesh_visible(&"BODY_Hands", true)
	_set_mesh_visible(
		&"BODY_Torso",
		keep_body_torso_visible
		and selected_top != &"TOP_03_PoliceShirt"
	)
	_set_mesh_visible(
		&"BODY_Legs",
		selected_bottom != &"BOTTOM_03_PolicePants"
	)
	_set_mesh_visible(&"BODY_Feet", false)


func _selected_node_name(slot: StringName) -> StringName:
	if not _options.has(slot):
		return &""
	var options: Array = _options[slot]
	if options.is_empty():
		return &""
	var selected_index := int(_selected[slot])
	if selected_index < 0 or selected_index >= options.size():
		return &""
	return StringName(options[selected_index]["node"])


func _set_mesh_visible(mesh_name: StringName, visible: bool) -> void:
	var mesh := _skeleton.get_node_or_null(
		NodePath(str(mesh_name))
	) as MeshInstance3D
	if mesh != null:
		mesh.visible = visible
