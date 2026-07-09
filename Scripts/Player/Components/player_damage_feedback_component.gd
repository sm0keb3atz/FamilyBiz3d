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
@export var health_component_path := NodePath("../HealthComponent")
@export var animation_player_path := NodePath(
	"../../Visual/PlayerTest2/AnimationPlayer"
)
@export var skeleton_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton"
)
@export var bullet_impact_sounds: Array[AudioStream] = []
@export var bullet_whiz_sounds: Array[AudioStream] = []
@export_range(0.5, 3.0, 0.05) var head_hit_height := 1.45
@export_range(0.0, 0.5, 0.01) var reaction_blend_time := 0.08
@export_range(-12.0, 6.0, 0.5) var bullet_impact_volume_db := 1.0
@export_range(-30.0, 6.0, 0.5) var bullet_whiz_volume_db := -3.0
@export_range(0.0, 0.25, 0.01) var bullet_impact_pitch_variation := 0.08

@onready var body := get_node(body_path) as CharacterBody3D
@onready var stats := get_node(
	stats_component_path
) as PlayerStatsComponent
@onready var health := get_node(
	health_component_path
) as PlayerHealthComponent
@onready var animation_player := get_node(
	animation_player_path
) as AnimationPlayer
@onready var skeleton := get_node(skeleton_path) as Skeleton3D

var _reaction_player: AnimationPlayer
var _impact_player: AudioStreamPlayer
var _active_blood_effects: Array[BloodImpactVFX] = []


func _ready() -> void:
	_create_reaction_player()
	health.respawn_started.connect(_clear_player_hit_marks)
	_impact_player = AudioStreamPlayer.new()
	_impact_player.name = "IncomingBulletImpactPlayer"
	_impact_player.max_polyphony = 4
	add_child(_impact_player)


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
	_play_bullet_impact()
	_spawn_blood(hit_position, hit_direction, fatal)


func play_bullet_whiz() -> void:
	if _impact_player == null or bullet_whiz_sounds.is_empty():
		return
	var sound := bullet_whiz_sounds.pick_random() as AudioStream
	if sound == null:
		return
	_impact_player.stream = sound
	_impact_player.volume_db = bullet_whiz_volume_db
	_impact_player.pitch_scale = randf_range(
		1.0 - bullet_impact_pitch_variation,
		1.0 + bullet_impact_pitch_variation
	)
	_impact_player.play()


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
	_active_blood_effects.append(effect)
	effect.tree_exited.connect(
		_on_blood_effect_exited.bind(effect)
	)
	effect.setup_blood_hit(
		hit_position,
		-direction,
		direction,
		body,
		fatal
	)


func _clear_player_hit_marks() -> void:
	for effect in _active_blood_effects.duplicate():
		if is_instance_valid(effect):
			effect.clear_marks_attached_to(body)


func _on_blood_effect_exited(effect: BloodImpactVFX) -> void:
	_active_blood_effects.erase(effect)


func _play_bullet_impact() -> void:
	if _impact_player == null or bullet_impact_sounds.is_empty():
		return
	var sound := bullet_impact_sounds.pick_random() as AudioStream
	if sound == null:
		return
	_impact_player.stream = sound
	_impact_player.volume_db = bullet_impact_volume_db
	_impact_player.pitch_scale = randf_range(
		1.0 - bullet_impact_pitch_variation,
		1.0 + bullet_impact_pitch_variation
	)
	_impact_player.play()


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
