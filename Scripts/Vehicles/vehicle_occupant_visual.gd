@tool
class_name VehicleOccupantVisual
extends Node3D

const DRIVING_ANIMATION := &"Driving"
const PROFILE_CIVILIAN := &"civilian"
const PROFILE_POLICE := &"police"
const BODY_VARIANT_MALE := &"male"
const BODY_VARIANT_FEMALE := &"female"
const MALE_BODY_MESHES := [
	&"BODY_Head",
	&"BODY_Hands",
	&"BODY_Torso",
	&"BODY_Legs",
	&"BODY_Feet",
]
const FEMALE_BODY_MESHES := [
	&"BODY_Female_Head",
	&"BODY_Female_Torso",
	&"BODY_Female_LeftArm",
	&"BODY_Female_RightArm",
	&"BODY_Female_Legs",
]
const MALE_CLOTHING_MESHES := [
	&"TOP_01_Hoodie",
	&"TOP_02_TShirt",
	&"TOP_03_PoliceShirt",
	&"BOTTOM_01_Jeans",
	&"BOTTOM_02_Sweatpants",
	&"BOTTOM_03_PolicePants",
	&"SHOES_01_Sneakers",
	&"SHOES_02_Boots",
	&"SHOES_03_PoliceBoots",
]
const FEMALE_CLOTHING_MESHES := [
	&"TOP_Female_01_HoodieCrop",
	&"BOTTOM_Female_01_Leggins",
	&"SHOES_Female_01_FemaleSneakers",
]

@export var animation_player_path := NodePath(
	"Visual/PlayerTest2/AnimationPlayer"
)
@export var appearance_component_path := NodePath("AppearanceComponent")
@export var skeleton_path := NodePath(
	"Visual/PlayerTest2/Armature/GeneralSkeleton"
)

@onready var animation_player := get_node_or_null(
	animation_player_path
) as AnimationPlayer
@onready var appearance_component := get_node_or_null(
	appearance_component_path
) as PlayerAppearanceComponent
@onready var skeleton := get_node_or_null(skeleton_path) as Skeleton3D

var _traffic_active := false
var _detail_enabled := true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func activate(seed: int, profile := PROFILE_CIVILIAN) -> void:
	if Engine.is_editor_hint() or appearance_component == null:
		return
	var random := RandomNumberGenerator.new()
	if seed >= 0:
		random.seed = seed
	else:
		random.randomize()
	if profile == PROFILE_POLICE:
		appearance_component.reset_appearance()
		appearance_component.set_body_variant(BODY_VARIANT_MALE)
		appearance_component.apply_police_uniform()
	else:
		appearance_component.randomize_civilian_appearance(random)
	_traffic_active = true
	_refresh_runtime_state(true)


func deactivate() -> void:
	if Engine.is_editor_hint():
		return
	_traffic_active = false
	_refresh_runtime_state(false)


func set_detail_enabled(enabled: bool) -> void:
	if Engine.is_editor_hint() or _detail_enabled == enabled:
		return
	_detail_enabled = enabled
	_refresh_runtime_state(false)


func is_traffic_active() -> bool:
	return _traffic_active


func is_detail_enabled() -> bool:
	return _detail_enabled


func is_driving_animation_playing() -> bool:
	return (
		animation_player != null
		and animation_player.is_playing()
		and animation_player.current_animation == DRIVING_ANIMATION
	)


func get_body_variant() -> StringName:
	if appearance_component == null:
		return &""
	return appearance_component.get_body_variant()


func set_editor_preview(is_female: bool, preview_time: float) -> void:
	if not Engine.is_editor_hint():
		return
	visible = true
	_apply_editor_body_variant(is_female)
	if animation_player == null:
		return
	if not animation_player.has_animation(DRIVING_ANIMATION):
		return
	animation_player.play(DRIVING_ANIMATION)
	var animation := animation_player.get_animation(DRIVING_ANIMATION)
	var sample_time := clampf(preview_time, 0.0, animation.length)
	animation_player.seek(sample_time, true)
	animation_player.pause()


func _refresh_runtime_state(restart_animation: bool) -> void:
	var should_render := _traffic_active and _detail_enabled
	visible = should_render
	process_mode = (
		Node.PROCESS_MODE_INHERIT
		if should_render
		else Node.PROCESS_MODE_DISABLED
	)
	if not should_render or animation_player == null:
		return
	if (
		restart_animation
		or not animation_player.is_playing()
		or animation_player.current_animation != DRIVING_ANIMATION
	):
		animation_player.play(DRIVING_ANIMATION)


func _apply_editor_body_variant(is_female: bool) -> void:
	for mesh_name in MALE_BODY_MESHES:
		_set_mesh_visible(mesh_name, not is_female)
	for mesh_name in FEMALE_BODY_MESHES:
		_set_mesh_visible(mesh_name, is_female)
	for mesh_name in MALE_CLOTHING_MESHES:
		_set_mesh_visible(mesh_name, false)
	for mesh_name in FEMALE_CLOTHING_MESHES:
		_set_mesh_visible(mesh_name, is_female)
	if not is_female:
		_set_mesh_visible(&"TOP_01_Hoodie", true)
		_set_mesh_visible(&"BOTTOM_01_Jeans", true)
		_set_mesh_visible(&"SHOES_01_Sneakers", true)
		_set_mesh_visible(&"BODY_Feet", false)


func _set_mesh_visible(mesh_name: StringName, enabled: bool) -> void:
	if skeleton == null:
		return
	var mesh := skeleton.get_node_or_null(NodePath(String(mesh_name))) as MeshInstance3D
	if mesh != null:
		mesh.visible = enabled
