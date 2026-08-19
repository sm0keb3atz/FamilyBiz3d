class_name PlayerDamageFeedbackComponent
extends Node

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
@export var camera_component_path := NodePath("../CameraComponent")
@export var screen_feedback_path := NodePath("../../ScreenFeedback")
@export var bullet_impact_sounds: Array[AudioStream] = []
@export var bullet_whiz_sounds: Array[AudioStream] = []
@export_range(0.5, 3.0, 0.05) var head_hit_height := 1.45
@export_range(0.0, 0.5, 0.01) var reaction_blend_time := 0.08
@export_range(-12.0, 6.0, 0.5) var bullet_impact_volume_db := 1.0
@export_range(-30.0, 6.0, 0.5) var bullet_whiz_volume_db := -3.0
@export_range(0.0, 0.25, 0.01) var bullet_impact_pitch_variation := 0.08
@export_range(0.05, 0.5, 0.01) var bullet_whiz_cooldown := 0.12
@export_range(0.5, 6.0, 0.1) var bullet_whiz_radius := 2.0

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
@onready var camera_component := get_node(
	camera_component_path
) as PlayerCameraComponent
@onready var screen_feedback := get_node(
	screen_feedback_path
) as PlayerScreenFeedbackComponent

var _reaction_player: AnimationPlayer
var _impact_player: AudioStreamPlayer
var _last_damage_source: Node
var _whiz_players: Array[AudioStreamPlayer3D] = []
var _whiz_streams: Array[AudioStreamWAV] = []
var _whiz_cursor := 0
var _last_whiz_msec := -100000


func _ready() -> void:
	_create_reaction_player()
	health.respawn_started.connect(_clear_player_hit_marks)
	health.respawn_completed.connect(_clear_last_damage_source)
	_impact_player = AudioStreamPlayer.new()
	_impact_player.name = "IncomingBulletImpactPlayer"
	_impact_player.max_polyphony = 4
	add_child(_impact_player)
	_create_procedural_whiz_audio()


func receive_hit(
	amount: float,
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	if amount <= 0.0 or is_zero_approx(stats.health):
		return
	_last_damage_source = source
	stats.take_damage(amount)
	var fatal := is_zero_approx(stats.health)
	if not fatal:
		_play_hit_reaction(hit_position)
	_play_bullet_impact()
	_spawn_blood(hit_position, hit_direction, fatal)
	var damage_ratio := amount / maxf(stats.get_max_health(), 0.01)
	camera_component.add_damage_impulse(
		hit_direction,
		clampf(0.5 + damage_ratio * 2.0, 0.5, 1.25)
	)
	screen_feedback.show_damage(hit_direction, fatal, damage_ratio)


func was_last_damage_from_police() -> bool:
	var current := _last_damage_source
	while is_instance_valid(current):
		if (
			current.has_method("get_faction_id")
			and StringName(current.call("get_faction_id")) == &"police"
		):
			return true
		current = current.get_parent()
	return false


func _clear_last_damage_source() -> void:
	_last_damage_source = null


func play_bullet_whiz(
	closest_point: Vector3,
	bullet_direction: Vector3,
	miss_distance: float
) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_whiz_msec < roundi(bullet_whiz_cooldown * 1000.0):
		return
	if _whiz_players.is_empty() or _whiz_streams.is_empty():
		return
	_last_whiz_msec = now
	var proximity := 1.0 - clampf(
		miss_distance / maxf(bullet_whiz_radius, 0.01),
		0.0,
		1.0
	)
	var player := _whiz_players[_whiz_cursor]
	_whiz_cursor = (_whiz_cursor + 1) % _whiz_players.size()
	player.global_position = closest_point
	player.stream = _whiz_streams.pick_random()
	player.volume_db = bullet_whiz_volume_db + lerpf(-4.0, 2.0, proximity)
	player.pitch_scale = randf_range(
		1.0 - bullet_impact_pitch_variation,
		1.0 + bullet_impact_pitch_variation
	)
	player.play()
	camera_component.add_near_miss_impulse(bullet_direction, proximity)
	var manager := CombatVFXManager.find(get_tree())
	if manager != null:
		manager.spawn_near_miss_ribbon(
			closest_point,
			bullet_direction,
			proximity
		)


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
	var manager := CombatVFXManager.find(get_tree())
	if manager != null:
		manager.spawn_blood_hit(
			hit_position,
			-direction,
			direction,
			body,
			fatal
		)


func _clear_player_hit_marks() -> void:
	var manager := CombatVFXManager.find(get_tree())
	if manager != null:
		manager.clear_marks_attached_to(body)

func _create_procedural_whiz_audio() -> void:
	for variant in 3:
		_whiz_streams.append(_build_whiz_stream(variant))
		var player := AudioStreamPlayer3D.new()
		player.name = "BulletWhizPlayer%d" % (variant + 1)
		player.top_level = true
		player.max_distance = 14.0
		player.unit_size = 1.5
		player.max_polyphony = 1
		add_child(player)
		_whiz_players.append(player)


func _build_whiz_stream(variant: int) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var duration := 0.16 + float(variant) * 0.015
	var sample_count := roundi(float(SAMPLE_RATE) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7103 + variant * 977
	var filtered_noise := 0.0
	var phase := 0.0
	for sample_index in sample_count:
		var progress := float(sample_index) / float(sample_count)
		var envelope := sin(PI * progress) * exp(-progress * 2.4)
		var frequency := lerpf(1900.0 + variant * 130.0, 520.0, progress)
		phase += TAU * frequency / float(SAMPLE_RATE)
		filtered_noise = lerpf(
			filtered_noise,
			rng.randf_range(-1.0, 1.0),
			0.34
		)
		var crack := sin(phase) * 0.48 + filtered_noise * 0.46
		if sample_index < 90:
			crack += rng.randf_range(-1.0, 1.0) * (1.0 - float(sample_index) / 90.0) * 0.72
		var pcm := clampi(roundi(crack * envelope * 27000.0), -32768, 32767)
		data.encode_s16(sample_index * 2, pcm)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


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
