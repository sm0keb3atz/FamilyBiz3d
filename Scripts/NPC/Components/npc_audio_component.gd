class_name NPCAudioComponent
extends Node3D

const MALE_CUSTOMER_STREAMS := [
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer1.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer2.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer3.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer4.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer5.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer6.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer7.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer8.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer9.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer10.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer11.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/malecustomer12.ogg"),
]
const FEMALE_CUSTOMER_STREAMS := [
	preload("res://Assets/Audio/NPCs/FemaleCustomer/femalecustomer1.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/femalecustomer2.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/femalecustomer3.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/femalecustomer4.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/femalecustomer5.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/femalecustomer6.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/femalecustomer7.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/femalecustomer8.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/femalecustomer9.ogg"),
]
const MALE_PANIC_STREAMS := [
	preload("res://Assets/Audio/NPCs/Male Customer/Panic/male-scream1.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/Panic/male-scream5.ogg"),
	preload("res://Assets/Audio/NPCs/Male Customer/Panic/male-screams3.ogg"),
]
const FEMALE_PANIC_STREAMS := [
	preload("res://Assets/Audio/NPCs/FemaleCustomer/panic/female-scream1.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/panic/female-scream2.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/panic/female-scream3.ogg"),
	preload("res://Assets/Audio/NPCs/FemaleCustomer/panic/female-scream4.ogg"),
]
const POLICE_COMMAND_STREAMS := [
	preload("res://Assets/Audio/NPCs/Police/police_freeze.ogg"),
	preload("res://Assets/Audio/NPCs/Police/police_getontheground.ogg"),
	preload("res://Assets/Audio/NPCs/Police/police_getyourhandsbehindyourback.ogg"),
	preload("res://Assets/Audio/NPCs/Police/police_layontheground.ogg"),
	preload("res://Assets/Audio/NPCs/Police/police_ontheground.ogg"),
	preload("res://Assets/Audio/NPCs/Police/police_stoporillshoot.ogg"),
	preload("res://Assets/Audio/NPCs/Police/police_stopresisting.ogg"),
	preload("res://Assets/Audio/NPCs/Police/police_stopresisting2.ogg"),
	preload("res://Assets/Audio/NPCs/Police/police_stopresisting3.ogg"),
	preload("res://Assets/Audio/NPCs/Police/police_wehaveyousurrounded.ogg"),
]
const POLICE_RADIO_STREAM := preload(
	"res://Assets/Audio/NPCs/Police/RadioChatter/618971__mrrap4food__radio-police-inside-car.mp3"
)

const CROWD_FOOTSTEP_WINDOW_MS := 180
const CROWD_FOOTSTEP_LIMIT := 3
const PANIC_WINDOW_MS := 1400
const PANIC_VOICE_LIMIT := 4
const CUSTOMER_RESPONSE_DELAY_MS := 1150
const CUSTOMER_VOICE_SPACING_MS := 900
const POLICE_COMMAND_SPACING_MS := 2200

@export_category("Crowd Footsteps")
@export_range(-40.0, 0.0, 0.5) var walk_volume_db := -27.0
@export_range(-40.0, 0.0, 0.5) var run_volume_db := -24.0
@export_range(4.0, 30.0, 0.5) var footstep_max_distance := 12.0
@export_range(0.1, 1.0, 0.01) var walk_step_interval := 0.46
@export_range(0.1, 1.0, 0.01) var run_step_interval := 0.29
@export_range(0.0, 4.0, 0.1) var footstep_pitch_semitones := 1.25

@export_category("Voices")
@export_range(-30.0, 6.0, 0.5) var customer_voice_volume_db := -3.0
@export_range(-30.0, 6.0, 0.5) var panic_voice_volume_db := -4.0
@export_range(-30.0, 6.0, 0.5) var police_voice_volume_db := -5.0
@export_range(5.0, 60.0, 1.0) var voice_max_distance := 34.0
@export_range(5.0, 30.0, 0.5) var customer_voice_max_distance := 20.0
@export_range(0.25, 5.0, 0.05) var customer_voice_unit_size := 2.4
@export_range(0.25, 8.0, 0.05) var voice_unit_size := 2.5
@export_range(0.5, 2.2, 0.05) var voice_panning_strength := 1.2
@export_range(0.5, 2.0, 0.05) var voice_emitter_height := 1.62

@export_category("Police Radio")
@export_range(-40.0, 0.0, 0.5) var radio_volume_db := -29.0
@export_range(4.0, 40.0, 0.5) var radio_proximity_distance := 20.0

static var _crowd_footstep_times: Array[int] = []
static var _panic_voice_times: Array[int] = []
static var _next_customer_voice_time_ms := 0
static var _last_police_command_time_ms := -10000

var npc: BaseNPC
var _listener: Node3D
var _footstep_player: AudioStreamPlayer3D
var _voice_player: AudioStreamPlayer3D
var _radio_player: AudioStreamPlayer3D
var _random := RandomNumberGenerator.new()
var _footstep_streams: Array[AudioStream] = []
var _step_remaining := 0.0
var _listener_refresh_remaining := 0.0
var _last_footstep_index := -1
var _last_voice_index := -1
var _voice_request_id := 0


func _ready() -> void:
	_random.randomize()
	_footstep_player = _create_spatial_player(
		"FootstepPlayer", footstep_max_distance, 1
	)
	_voice_player = _create_spatial_player(
		"VoicePlayer", voice_max_distance, 1
	)
	_voice_player.position.y = voice_emitter_height
	_voice_player.unit_size = voice_unit_size
	_voice_player.panning_strength = voice_panning_strength
	_voice_player.attenuation_filter_cutoff_hz = 4500.0
	_voice_player.attenuation_filter_db = -18.0
	_radio_player = _create_spatial_player(
		"RadioPlayer", radio_proximity_distance, 1
	)
	var radio_stream := POLICE_RADIO_STREAM.duplicate() as AudioStreamMP3
	radio_stream.loop = true
	_radio_player.stream = radio_stream
	_radio_player.volume_db = radio_volume_db
	_step_remaining = _random.randf_range(0.05, walk_step_interval)


func initialize(owner_npc: BaseNPC) -> void:
	npc = owner_npc
	_refresh_listener()


func reset_for_reuse() -> void:
	stop_all()
	_step_remaining = _random.randf_range(0.05, walk_step_interval)
	_listener_refresh_remaining = 0.0


func stop_all() -> void:
	_voice_request_id += 1
	if _footstep_player != null:
		_footstep_player.stop()
	if _voice_player != null:
		_voice_player.stop()
	if _radio_player != null:
		_radio_player.stop()


func play_customer_solicitation(is_female: bool) -> void:
	var streams := (
		FEMALE_CUSTOMER_STREAMS if is_female else MALE_CUSTOMER_STREAMS
	)
	var now_ms := Time.get_ticks_msec()
	var scheduled_ms := maxi(
		now_ms + CUSTOMER_RESPONSE_DELAY_MS,
		_next_customer_voice_time_ms
	)
	if scheduled_ms - now_ms > CUSTOMER_RESPONSE_DELAY_MS + 4500:
		return
	_next_customer_voice_time_ms = scheduled_ms + CUSTOMER_VOICE_SPACING_MS
	var stream := _pick_stream(streams)
	if stream == null:
		return
	_voice_request_id += 1
	var request_id := _voice_request_id
	var delay := float(scheduled_ms - now_ms) * 0.001
	if delay <= 0.0:
		_play_deferred_customer_voice(stream, request_id)
	else:
		get_tree().create_timer(delay).timeout.connect(
			_play_deferred_customer_voice.bind(stream, request_id)
		)


func play_panic(is_female: bool) -> void:
	var now_ms := Time.get_ticks_msec()
	_prune_times(_panic_voice_times, now_ms, PANIC_WINDOW_MS)
	if _panic_voice_times.size() >= PANIC_VOICE_LIMIT:
		return
	_panic_voice_times.append(now_ms)
	_voice_request_id += 1
	var streams := FEMALE_PANIC_STREAMS if is_female else MALE_PANIC_STREAMS
	_play_voice(_pick_stream(streams), panic_voice_volume_db, 0.035)


func play_police_aggro() -> void:
	_refresh_listener()
	if _listener == null:
		return
	if global_position.distance_squared_to(_listener.global_position) > voice_max_distance * voice_max_distance:
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_police_command_time_ms < POLICE_COMMAND_SPACING_MS:
		return
	_last_police_command_time_ms = now_ms
	_voice_request_id += 1
	_play_voice(
		_pick_stream(POLICE_COMMAND_STREAMS),
		police_voice_volume_db,
		0.025
	)


func _physics_process(delta: float) -> void:
	if npc == null or not npc.visible or npc.is_defeated():
		if _radio_player != null and _radio_player.playing:
			_radio_player.stop()
		return

	_listener_refresh_remaining -= delta
	if _listener_refresh_remaining <= 0.0:
		_listener_refresh_remaining = 0.35
		_refresh_listener()
		_update_police_radio()

	_update_footsteps(delta)


func _update_footsteps(delta: float) -> void:
	var speed := npc.get_horizontal_speed()
	if speed < 0.65 or not npc.is_on_floor():
		_step_remaining = minf(_step_remaining, 0.12)
		return
	if (
		_listener == null
		or global_position.distance_squared_to(_listener.global_position)
		> footstep_max_distance * footstep_max_distance
	):
		return

	_step_remaining -= delta
	if _step_remaining > 0.0:
		return
	var speed_blend := clampf((speed - 2.0) / 4.5, 0.0, 1.0)
	_step_remaining = lerpf(
		walk_step_interval,
		run_step_interval,
		speed_blend
	) * _random.randf_range(0.92, 1.08)

	var now_ms := Time.get_ticks_msec()
	_prune_times(
		_crowd_footstep_times,
		now_ms,
		CROWD_FOOTSTEP_WINDOW_MS
	)
	if _crowd_footstep_times.size() >= CROWD_FOOTSTEP_LIMIT:
		return
	_crowd_footstep_times.append(now_ms)

	var stream := _pick_footstep_stream()
	if stream == null:
		return
	_footstep_player.stream = stream
	_footstep_player.volume_db = lerpf(
		walk_volume_db,
		run_volume_db,
		speed_blend
	) + _random.randf_range(-0.75, 0.5)
	_footstep_player.pitch_scale = pow(
		2.0,
		_random.randf_range(
			-footstep_pitch_semitones,
			footstep_pitch_semitones
		) / 12.0
	)
	_footstep_player.play()


func _update_police_radio() -> void:
	if _radio_player == null or not npc.is_in_group(&"police_npc"):
		return
	if (
		_listener == null
		or global_position.distance_squared_to(_listener.global_position)
		> radio_proximity_distance * radio_proximity_distance
		or not _is_nearest_police_to_listener()
	):
		if _radio_player.playing:
			_radio_player.stop()
		return
	if not _radio_player.playing:
		_radio_player.play()


func _is_nearest_police_to_listener() -> bool:
	var nearest: Node3D
	var nearest_distance_squared := INF
	for node in get_tree().get_nodes_in_group(&"police_npc"):
		var officer := node as Node3D
		if officer == null or not officer.visible:
			continue
		var distance_squared := officer.global_position.distance_squared_to(
			_listener.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest = officer
			nearest_distance_squared = distance_squared
	return nearest == npc


func _refresh_listener() -> void:
	_listener = get_tree().get_first_node_in_group(&"player") as Node3D
	if _listener == null:
		return
	var player_sounds := _listener.get_node_or_null(
		"Components/SoundComponent"
	) as PlayerSoundComponent
	if player_sounds == null or player_sounds.footstep_sounds.is_empty():
		return
	_footstep_streams.assign(player_sounds.footstep_sounds)


func _play_deferred_customer_voice(
	stream: AudioStream,
	request_id: int
) -> void:
	if (
		request_id != _voice_request_id
		or npc == null
		or not npc.visible
		or npc.is_defeated()
	):
		return
	_play_voice(
		stream,
		customer_voice_volume_db,
		0.025,
		customer_voice_max_distance,
		customer_voice_unit_size
	)


func _play_voice(
	stream: AudioStream,
	volume_db: float,
	pitch_variation: float,
	max_distance_override := -1.0,
	unit_size_override := -1.0
) -> void:
	if stream == null or _voice_player == null:
		return
	_voice_player.max_distance = (
		max_distance_override
		if max_distance_override > 0.0
		else voice_max_distance
	)
	_voice_player.unit_size = (
		unit_size_override
		if unit_size_override > 0.0
		else voice_unit_size
	)
	_voice_player.stream = stream
	_voice_player.volume_db = volume_db
	_voice_player.pitch_scale = _random.randf_range(
		1.0 - pitch_variation,
		1.0 + pitch_variation
	)
	_voice_player.play()


func _pick_stream(streams: Array) -> AudioStream:
	if streams.is_empty():
		return null
	var index := _random.randi_range(0, streams.size() - 1)
	if streams.size() > 1 and index == _last_voice_index:
		index = (index + 1) % streams.size()
	_last_voice_index = index
	return streams[index] as AudioStream


func _pick_footstep_stream() -> AudioStream:
	if _footstep_streams.is_empty():
		return null
	var index := _random.randi_range(0, _footstep_streams.size() - 1)
	if _footstep_streams.size() > 1 and index == _last_footstep_index:
		index = (index + 1) % _footstep_streams.size()
	_last_footstep_index = index
	return _footstep_streams[index]


func _create_spatial_player(
	player_name: String,
	max_distance: float,
	polyphony: int
) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.max_distance = max_distance
	player.max_polyphony = polyphony
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	return player


func _prune_times(times: Array[int], now_ms: int, window_ms: int) -> void:
	for index in range(times.size() - 1, -1, -1):
		if now_ms - times[index] > window_ms:
			times.remove_at(index)
