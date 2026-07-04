class_name PlayerDamageFeedbackComponent
extends Node

const BLOOD_IMPACT_VFX := preload(
	"res://Scenes/VFX/BloodImpactVFX.tscn"
)
const HIT_REACTION_BONES := [
	&"Spine",
	&"Chest",
	&"UpperChest",
	&"Neck",
	&"Head",
]

@export var body_path := NodePath("../..")
@export var stats_component_path := NodePath("../StatsComponent")
@export var animation_player_path := NodePath(
	"../../Visual/PlayerTest2/AnimationPlayer"
)
@export var skeleton_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton"
)
@export_range(0.5, 3.0, 0.05) var head_hit_height := 1.45
@export_range(0.0, 0.5, 0.01) var reaction_blend_time := 0.08

@onready var body := get_node(body_path) as CharacterBody3D
@onready var stats := get_node(
	stats_component_path
) as PlayerStatsComponent
@onready var animation_player := get_node(
	animation_player_path
) as AnimationPlayer
@onready var skeleton := get_node(skeleton_path) as Skeleton3D

var _reaction_player: AnimationPlayer


func _ready() -> void:
	_create_reaction_player()


func receive_hit(
	amount: float,
	_source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	if amount <= 0.0 or is_zero_approx(stats.health):
		return
	stats.take_damage(amount)
	var fatal := is_zero_approx(stats.health)
	if not fatal:
		_play_hit_reaction(hit_position)
	_spawn_blood(hit_position, hit_direction, fatal)


func _play_hit_reaction(hit_position: Vector3) -> void:
	if _reaction_player == null:
		return
	var animation_name := (
		&"Hit_Head"
		if hit_position.y - body.global_position.y >= head_hit_height
		else &"Hit_Chest"
	)
	if not _reaction_player.has_animation(animation_name):
		return
	_reaction_player.play(animation_name, reaction_blend_time)
	_reaction_player.seek(0.0, true)


func _spawn_blood(
	hit_position: Vector3,
	hit_direction: Vector3,
	fatal: bool
) -> void:
	var direction := hit_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var effect := BLOOD_IMPACT_VFX.instantiate() as BloodImpactVFX
	get_tree().current_scene.add_child(effect)
	effect.setup_blood_hit(
		hit_position,
		-direction,
		direction,
		body,
		fatal
	)


func _create_reaction_player() -> void:
	var source_library := animation_player.get_animation_library(&"")
	if source_library == null:
		return
	var reaction_library := AnimationLibrary.new()
	for animation_name in [&"Hit_Head", &"Hit_Chest"]:
		if not source_library.has_animation(animation_name):
			continue
		reaction_library.add_animation(
			animation_name,
			_create_upper_body_reaction(
				source_library.get_animation(animation_name)
			)
		)
	_reaction_player = AnimationPlayer.new()
	_reaction_player.name = "PlayerHitReactionAnimationPlayer"
	animation_player.get_parent().add_child(_reaction_player)
	_reaction_player.root_node = animation_player.root_node
	_reaction_player.add_animation_library(&"", reaction_library)
	_reaction_player.animation_finished.connect(
		_on_reaction_finished
	)


func _create_upper_body_reaction(source: Animation) -> Animation:
	var reaction := source.duplicate(true) as Animation
	for track_index in range(reaction.get_track_count() - 1, -1, -1):
		var track_type := reaction.track_get_type(track_index)
		var track_path := reaction.track_get_path(track_index)
		var bone_name := (
			track_path.get_subname(0)
			if track_path.get_subname_count() > 0
			else &""
		)
		var remove_track := (
			track_type != Animation.TYPE_ROTATION_3D
			or bone_name.is_empty()
			or skeleton.find_bone(bone_name) < 0
			or bone_name not in HIT_REACTION_BONES
		)
		if remove_track:
			reaction.remove_track(track_index)
	reaction.loop_mode = Animation.LOOP_NONE
	return reaction


func _on_reaction_finished(_animation_name: StringName) -> void:
	if _reaction_player != null:
		_reaction_player.stop()
