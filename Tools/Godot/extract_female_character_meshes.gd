extends SceneTree

const SOURCE := preload(
	"res://Assets/BaseChracters/Player/Meshes/Female/FB_Female_NPC_Variant.glb"
)
const OUTPUT_DIR := "res://Assets/BaseChracters/Player/Meshes/Female"
const ANIMATION_PATH := (
	"res://Assets/Animations/Female_Catwalk_Walk_Forward_Crossed.anim"
)
const MAIN_ANIMATION_LIBRARY := (
	"res://Assets/Animations/MainAnimationLibary.res"
)
const FEMALE_NAMES := [
	&"BODY_Female_Head",
	&"BODY_Female_Torso",
	&"BODY_Female_LeftArm",
	&"BODY_Female_RightArm",
	&"BODY_Female_Legs",
	&"TOP_Female_01_HoodieCrop",
	&"BOTTOM_Female_01_Leggins",
	&"SHOES_Female_01_FemaleSneakers",
]


func _initialize() -> void:
	var source := SOURCE.instantiate() as Node3D
	if source == null:
		push_error("Could not instantiate female modular character GLB.")
		quit(1)
		return
	var error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIR)
	)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Could not create female mesh output directory.")
		quit(1)
		return

	var saved := 0
	for node_name in FEMALE_NAMES:
		var mesh_node := source.find_child(str(node_name), true, false)
		if not mesh_node is MeshInstance3D:
			push_error("Missing female mesh in GLB: %s" % node_name)
			continue
		var mesh := (mesh_node as MeshInstance3D).mesh
		if mesh == null:
			push_error("Female mesh has no ArrayMesh: %s" % node_name)
			continue
		var destination := "%s/%s.res" % [OUTPUT_DIR, node_name]
		var save_error := ResourceSaver.save(mesh, destination)
		if save_error != OK:
			push_error("Failed to save %s: %s" % [node_name, save_error])
			continue
		var skin := (mesh_node as MeshInstance3D).skin
		if skin == null:
			push_error("Female mesh has no skin: %s" % node_name)
			continue
		var skin_destination := "%s/%s_Skin.res" % [OUTPUT_DIR, node_name]
		save_error = ResourceSaver.save(skin, skin_destination)
		if save_error != OK:
			push_error("Failed to save skin for %s: %s" % [node_name, save_error])
			continue
		saved += 1

	var animation_player := source.find_child(
		"AnimationPlayer", true, false
	) as AnimationPlayer
	if animation_player == null:
		push_error("Female GLB has no AnimationPlayer.")
		quit(1)
		return
	var animation_name := &"Female_Catwalk_Walk_Forward_Crossed"
	var animation := animation_player.get_animation(animation_name)
	if animation == null:
		push_error("Female GLB is missing the catwalk animation.")
		quit(1)
		return
	var animation_error := ResourceSaver.save(
		animation.duplicate(true), ANIMATION_PATH
	)
	if animation_error != OK:
		push_error("Failed to save female catwalk animation: %s" % animation_error)
		quit(1)
		return
	var library := load(MAIN_ANIMATION_LIBRARY) as AnimationLibrary
	if library == null:
		push_error("Could not load the main animation library.")
		quit(1)
		return
	if library.has_animation(&"FemaleWalk"):
		library.remove_animation(&"FemaleWalk")
	library.add_animation(&"FemaleWalk", animation.duplicate(true))
	animation_error = ResourceSaver.save(library, MAIN_ANIMATION_LIBRARY)
	if animation_error != OK:
		push_error("Failed to update the main animation library: %s" % animation_error)
		quit(1)
		return

	source.free()
	if saved != FEMALE_NAMES.size():
		quit(1)
		return
	print("FEMALE_CHARACTER_MESH_EXTRACTION_PASS")
	quit(0)
