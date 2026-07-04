class_name VehicleAudioComponent
extends Node

const DEFAULT_TIRE_SCREECH := preload(
	"res://Assets/Audio/Vehicles/tires_squal_loop.wav"
)

var vehicle: BaseVehicle
var door: AudioStreamPlayer3D
var start: AudioStreamPlayer3D
var engine: AudioStreamPlayer3D
var stop: AudioStreamPlayer3D
var tires: AudioStreamPlayer3D
var sequence_id := 0
var engine_target_volume_db := 0.0
var start_target_volume_db := 0.0
var engine_ready := false
var engine_rpm := 850.0


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle
	door = vehicle.get_node("Audio/DoorPlayer") as AudioStreamPlayer3D
	start = vehicle.get_node("Audio/StartPlayer") as AudioStreamPlayer3D
	engine = vehicle.get_node("Audio/EnginePlayer") as AudioStreamPlayer3D
	stop = vehicle.get_node("Audio/StopPlayer") as AudioStreamPlayer3D
	tires = (
		vehicle.get_node("Audio/TireScreechPlayer")
		as AudioStreamPlayer3D
	)
	door.stream = vehicle.definition.door_stream
	start.stream = vehicle.definition.start_stream
	engine.stream = _loop_engine(vehicle.definition.engine_stream)
	stop.stream = vehicle.definition.stop_stream
	tires.stream = _loop_full(
		vehicle.definition.tire_screech_stream
		if vehicle.definition.tire_screech_stream != null
		else DEFAULT_TIRE_SCREECH
	)
	engine.pitch_scale = vehicle.definition.idle_pitch
	engine_rpm = vehicle.definition.idle_rpm
	engine_target_volume_db = engine.volume_db
	start_target_volume_db = start.volume_db


func _loop_full(stream: AudioStream) -> AudioStream:
	if stream is not AudioStreamWAV:
		return stream
	var result := stream.duplicate() as AudioStreamWAV
	result.loop_mode = AudioStreamWAV.LOOP_FORWARD
	result.loop_begin = 0
	result.loop_end = int(result.get_length() * result.mix_rate)
	return result


func _loop_engine(stream: AudioStream) -> AudioStream:
	if stream is not AudioStreamWAV:
		return stream
	var result := stream.duplicate() as AudioStreamWAV
	result.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var final_frame := int(result.get_length() * result.mix_rate)
	result.loop_begin = clampi(
		vehicle.definition.engine_loop_begin,
		0,
		maxi(final_frame - 2, 0)
	)
	result.loop_end = clampi(
		vehicle.definition.engine_loop_end,
		result.loop_begin + 1,
		maxi(final_frame - 1, 1)
	)
	return result


func begin_entry() -> void:
	cancel_entry()
	sequence_id += 1
	_play_entry(sequence_id)


func cancel_entry() -> void:
	sequence_id += 1
	door.stop()
	start.stop()
	vehicle.effects_component.set_exhaust_running(false)


func shutdown() -> void:
	engine_ready = false
	cancel_entry()
	start.stop()
	engine.stop()
	tires.stop()
	stop.play()
	door.volume_db = vehicle.definition.exit_door_volume_db
	door.play()


func _play_entry(id: int) -> void:
	engine.stop()
	engine.volume_db = engine_target_volume_db
	engine_ready = false
	if door.stream != null:
		door.volume_db = vehicle.definition.entry_door_volume_db
		door.play()
	if vehicle.definition.door_to_ignition_delay > 0.0:
		await vehicle.get_tree().create_timer(
			vehicle.definition.door_to_ignition_delay
		).timeout
	if not _sequence_valid(id):
		return
	if start.stream == null:
		vehicle.effects_component.play_startup_puff()
		engine.play()
		engine_ready = true
		vehicle.effects_component.set_exhaust_running(true)
		return
	start.volume_db = start_target_volume_db
	vehicle.effects_component.play_startup_puff()
	start.play()
	var wait_duration := maxf(
		start.stream.get_length() - vehicle.definition.ignition_idle_overlap,
		0.0
	)
	if wait_duration > 0.0:
		await vehicle.get_tree().create_timer(wait_duration).timeout
	if not _sequence_valid(id):
		return
	engine.play()
	engine_ready = true
	vehicle.effects_component.set_exhaust_running(true)


func _sequence_valid(id: int) -> bool:
	return id == sequence_id and vehicle.has_driver()


func update(delta: float) -> void:
	update_tires(delta)
	if not vehicle.has_driver() or not engine.playing:
		return
	var forward_speed := vehicle.linear_velocity.dot(vehicle.global_basis.z)
	var target_rpm := vehicle.powertrain_component.calculate_target_rpm(
		forward_speed,
		vehicle.drive_component.throttle_amount
	)
	if (
		(
			vehicle.tire_component.drift_amount > 0.0
			or vehicle.tire_component.burnout_amount > 0.0
		)
		and vehicle.drive_component.throttle_amount > 0.0
	):
		var drift_rpm := lerpf(
			vehicle.definition.drift_rpm_floor,
			vehicle.definition.maximum_rpm,
			vehicle.drive_component.throttle_amount * 0.65
		)
		target_rpm = maxf(
			target_rpm,
			lerpf(
				target_rpm,
				drift_rpm,
				maxf(
					vehicle.tire_component.drift_amount,
					vehicle.tire_component.burnout_amount
				)
			)
		)
	if vehicle.drive_component.service_braking:
		target_rpm = minf(target_rpm, engine_rpm)
	if vehicle.powertrain_component.shift_timer > 0.0:
		target_rpm = maxf(vehicle.definition.idle_rpm, target_rpm * 0.7)
	engine_rpm = move_toward(
		engine_rpm,
		target_rpm,
		9000.0 * delta
	)
	var rpm_ratio := clampf(
		(engine_rpm - vehicle.definition.idle_rpm)
		/ (
			vehicle.definition.maximum_rpm
			- vehicle.definition.idle_rpm
		),
		0.0,
		1.0
	)
	vehicle.effects_component.set_exhaust_intensity(
		lerpf(
			0.2,
			0.58,
			maxf(rpm_ratio, vehicle.drive_component.throttle_amount * 0.7)
		)
	)
	var target_pitch := lerpf(
		vehicle.definition.idle_pitch,
		vehicle.definition.maximum_pitch,
		clampf(
			rpm_ratio + vehicle.drive_component.throttle_amount * 0.12,
			0.0,
			1.0
		)
	)
	engine.pitch_scale = move_toward(
		engine.pitch_scale,
		target_pitch,
		2.5 * delta
	)


func update_tires(delta: float) -> void:
	if tires.stream == null:
		return
	var planar := Vector3(
		vehicle.linear_velocity.x,
		0.0,
		vehicle.linear_velocity.z
	)
	var speed := planar.length()
	var lateral := absf(planar.dot(vehicle.global_basis.x.normalized()))
	var grounded := false
	for wheel in vehicle._get_wheels():
		if wheel.is_in_contact():
			grounded = true
			break
	var intensity := maxf(
		maxf(
			clampf(
				inverse_lerp(
					vehicle.skid_mark_lateral_speed,
					vehicle.skid_mark_lateral_speed * 3.0,
					lateral
				),
				0.0,
				1.0
			),
			maxf(
				vehicle.tire_component.drift_amount,
				vehicle.tire_component.burnout_amount
			)
		),
		maxf(
			vehicle.tire_component.handbrake_amount * 0.9,
			clampf(speed / 12.0, 0.0, 1.0)
			if vehicle.drive_component.service_braking else 0.0
		)
	)
	if (
		not vehicle.has_driver()
		or not grounded
		or (
			speed < 5.0
			and vehicle.tire_component.burnout_amount <= 0.08
		)
	):
		intensity = 0.0
	if intensity > 0.02 and not tires.playing:
		tires.volume_db = -40.0
		tires.play()
	var target_volume := (
		lerpf(-18.0, vehicle.definition.tire_screech_volume_db, intensity)
		if intensity > 0.02 else -40.0
	)
	tires.volume_db = move_toward(
		tires.volume_db,
		target_volume,
		60.0 * delta
	)
	tires.pitch_scale = lerpf(0.88, 1.12, intensity)
	if intensity <= 0.02 and tires.volume_db <= -39.5:
		tires.stop()
