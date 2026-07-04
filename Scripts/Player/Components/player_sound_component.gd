class_name PlayerSoundComponent
extends Node

signal footstep_played(is_sprinting: bool)

@export_category("Scene References")
@export var body_path := NodePath("../..")

@export_category("Sounds")
@export var footstep_sounds: Array[AudioStream] = []
@export var reload_sounds: Array[AudioStream] = []
@export var gunshot_sound: AudioStream
@export var npc_impact_sounds: Array[AudioStream] = []

@export_category("Footsteps")
@export_range(-30.0, 0.0, 0.5) var walk_volume_db := -14.0
@export_range(-30.0, 0.0, 0.5) var sprint_volume_db := -11.0
@export_range(0.0, 6.0, 0.1) var pitch_variation_semitones := 1.0
@export_range(0.0, 6.0, 0.1) var volume_variation_db := 0.75
@export_range(0, 250, 1) var duplicate_guard_ms := 80

@export_category("Weapon Audio")
@export_range(-30.0, 6.0, 0.5) var reload_volume_db := 0.0
@export_range(-30.0, 6.0, 0.5) var equip_volume_db := -2.0
@export_range(0, 10, 1) var equip_sound_index := 0
@export_range(-30.0, 6.0, 0.5) var gunshot_volume_db := 0.0
@export_range(-30.0, 6.0, 0.5) var impact_volume_db := -3.0
@export_range(0.0, 0.25, 0.01) var gunshot_pitch_variation := 0.035
@export_range(0.0, 0.25, 0.01) var impact_pitch_variation := 0.08

@onready var footstep_player := $FootstepPlayer as AudioStreamPlayer3D
@onready var reload_player := $ReloadPlayer as AudioStreamPlayer3D
@onready var gunshot_player := $GunshotPlayer as AudioStreamPlayer3D
@onready var body := get_node(body_path) as CharacterBody3D

var _last_footstep_time_ms := -1000
var _footstep_playback_id := 0
var _reload_playback_id := 0
var _footsteps_enabled := true


func play_footstep(
	clip_index: int,
	is_sprinting: bool,
	start_offset := 0.0,
	end_offset := 0.0
) -> void:
	if not _footsteps_enabled:
		return
	if clip_index < 0 or clip_index >= footstep_sounds.size():
		return

	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_footstep_time_ms < duplicate_guard_ms:
		return
	_last_footstep_time_ms = now_ms

	var sound := footstep_sounds[clip_index]
	if sound == null:
		return

	_footstep_playback_id += 1
	footstep_player.global_position = body.global_position
	footstep_player.stream = sound
	footstep_player.pitch_scale = pow(
		2.0,
		randf_range(
			-pitch_variation_semitones,
			pitch_variation_semitones
		) / 12.0
	)
	footstep_player.volume_db = (
		sprint_volume_db if is_sprinting else walk_volume_db
	) + randf_range(-volume_variation_db, volume_variation_db)
	footstep_player.play(start_offset)
	footstep_played.emit(is_sprinting)
	_stop_at_end_offset(
		footstep_player,
		sound,
		start_offset,
		end_offset,
		_footstep_playback_id,
		false
	)


func play_reload_clip(
	clip_index: int,
	start_offset := 0.0,
	end_offset := 0.0
) -> void:
	if clip_index < 0 or clip_index >= reload_sounds.size():
		return

	var sound := reload_sounds[clip_index]
	if sound == null:
		return

	_reload_playback_id += 1
	reload_player.global_position = body.global_position
	reload_player.stream = sound
	reload_player.pitch_scale = 1.0
	reload_player.volume_db = reload_volume_db
	reload_player.play(start_offset)
	_stop_at_end_offset(
		reload_player,
		sound,
		start_offset,
		end_offset,
		_reload_playback_id,
		true
	)


func stop_reload() -> void:
	_reload_playback_id += 1
	reload_player.stop()


func stop_footsteps() -> void:
	_footstep_playback_id += 1
	footstep_player.stop()


func set_footsteps_enabled(enabled: bool) -> void:
	_footsteps_enabled = enabled
	if not enabled:
		stop_footsteps()


func are_footsteps_enabled() -> bool:
	return _footsteps_enabled


func play_equip_sound() -> void:
	if equip_sound_index < 0 or equip_sound_index >= reload_sounds.size():
		return

	var sound := reload_sounds[equip_sound_index]
	if sound == null:
		return

	_reload_playback_id += 1
	reload_player.global_position = body.global_position
	reload_player.stream = sound
	reload_player.pitch_scale = 1.05
	reload_player.volume_db = reload_volume_db + equip_volume_db
	reload_player.play()


func play_gunshot(position: Vector3) -> void:
	if gunshot_sound == null:
		return

	gunshot_player.global_position = position
	gunshot_player.stream = gunshot_sound
	gunshot_player.pitch_scale = randf_range(
		1.0 - gunshot_pitch_variation,
		1.0 + gunshot_pitch_variation
	)
	gunshot_player.volume_db = gunshot_volume_db
	gunshot_player.play()


func play_npc_impact(position: Vector3) -> void:
	if npc_impact_sounds.is_empty():
		return

	var sound := npc_impact_sounds.pick_random() as AudioStream
	if sound == null:
		return

	var player := AudioStreamPlayer3D.new()
	get_tree().current_scene.add_child(player)
	player.global_position = position
	player.stream = sound
	player.pitch_scale = randf_range(
		1.0 - impact_pitch_variation,
		1.0 + impact_pitch_variation
	)
	player.volume_db = impact_volume_db
	player.max_distance = 22.0
	player.finished.connect(player.queue_free)
	player.play()


func _stop_at_end_offset(
	player: AudioStreamPlayer3D,
	sound: AudioStream,
	start_offset: float,
	end_offset: float,
	playback_id: int,
	is_reload: bool
) -> void:
	if end_offset <= 0.0:
		return

	var playback_duration := maxf(
		sound.get_length() - start_offset - end_offset,
		0.0
	)
	if is_zero_approx(playback_duration):
		player.stop()
		return

	get_tree().create_timer(playback_duration).timeout.connect(
		func() -> void:
			var current_id := (
				_reload_playback_id
				if is_reload
				else _footstep_playback_id
			)
			if current_id == playback_id:
				player.stop()
	)
