class_name VehicleEffectsComponent
extends Node

var vehicle: BaseVehicle
var skid_emitters: Dictionary
var smoke_emitters: Dictionary
var idle_exhausts: Array[GPUParticles3D]
var startup_exhausts: Array[GPUParticles3D]
var traffic_detail_enabled := true


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle
	skid_emitters = vehicle._skid_mark_emitters
	smoke_emitters = vehicle._tire_smoke_emitters
	idle_exhausts = vehicle._tailpipe_idle_exhausts
	startup_exhausts = vehicle._tailpipe_startup_exhausts


func play_startup_puff() -> void:
	if vehicle != null and vehicle.is_managed_traffic() and not traffic_detail_enabled:
		return
	for exhaust in startup_exhausts:
		exhaust.emitting = true
		exhaust.restart()


func set_exhaust_running(running: bool) -> void:
	for exhaust in idle_exhausts:
		var can_emit := running and (
			not vehicle.is_managed_traffic()
			or traffic_detail_enabled
		)
		exhaust.emitting = can_emit
		exhaust.amount_ratio = 0.2 if can_emit else 0.0
	if not running:
		for exhaust in startup_exhausts:
			exhaust.emitting = false


func set_exhaust_intensity(intensity: float) -> void:
	if vehicle.is_managed_traffic() and not traffic_detail_enabled:
		for exhaust in idle_exhausts:
			exhaust.amount_ratio = 0.0
		return
	for exhaust in idle_exhausts:
		exhaust.amount_ratio = intensity


func set_traffic_detail_enabled(enabled: bool) -> void:
	traffic_detail_enabled = enabled
	if enabled:
		if vehicle != null and vehicle.is_managed_traffic():
			set_exhaust_running(true)
		return
	for exhaust in idle_exhausts:
		exhaust.emitting = false
		exhaust.amount_ratio = 0.0
	for exhaust in startup_exhausts:
		exhaust.emitting = false
	for wheel_key in skid_emitters:
		var wheel := wheel_key as VehicleWheel3D
		var marks := skid_emitters[wheel] as GPUParticles3D
		var smoke := smoke_emitters[wheel] as GPUParticles3D
		marks.emitting = false
		smoke.emitting = false
		smoke.amount_ratio = 0.0


func update() -> void:
	if vehicle.is_managed_traffic() and not traffic_detail_enabled:
		return
	var planar := Vector3(
		vehicle.linear_velocity.x,
		0.0,
		vehicle.linear_velocity.z
	)
	var lateral_speed := absf(
		planar.dot(vehicle.global_basis.x.normalized())
	)
	var braking_can_mark := (
		vehicle.drive_component.service_braking
		and not vehicle.is_managed_traffic()
	)
	var sliding := (
		vehicle.tire_component.handbrake_amount > 0.1
		or vehicle.tire_component.drift_amount > 0.12
		or vehicle.tire_component.burnout_amount > 0.08
		or lateral_speed >= vehicle.skid_mark_lateral_speed
		or braking_can_mark
	)
	var can_mark := (
		(vehicle.has_driver() or vehicle.is_managed_traffic())
		and (
			planar.length() >= vehicle.skid_mark_minimum_speed
			or vehicle.tire_component.burnout_amount > 0.08
		)
		and sliding
	)
	var lateral_smoke := clampf(
		inverse_lerp(
			vehicle.skid_mark_lateral_speed,
			vehicle.skid_mark_lateral_speed * 3.0,
			lateral_speed
		),
		0.0,
		1.0
	)
	var intensity := clampf(
		maxf(
			maxf(
				maxf(lateral_smoke, vehicle.tire_component.drift_amount),
				vehicle.tire_component.burnout_amount
			),
			maxf(
				vehicle.tire_component.handbrake_amount * 0.85,
				0.45 if braking_can_mark else 0.0
			)
		),
		0.18,
		1.0
	)
	for wheel_key in skid_emitters:
		var wheel := wheel_key as VehicleWheel3D
		var marks := skid_emitters[wheel] as GPUParticles3D
		var smoke := smoke_emitters[wheel] as GPUParticles3D
		var grounded := wheel.is_in_contact()
		marks.emitting = can_mark and grounded
		smoke.emitting = can_mark and grounded
		smoke.amount_ratio = intensity if can_mark and grounded else 0.0
		if not grounded:
			continue
		var normal := wheel.get_contact_normal().normalized()
		var contact := wheel.get_contact_point() + normal * 0.012
		marks.global_position = contact
		smoke.global_position = contact + normal * 0.06
		var forward := vehicle.global_basis.z.slide(normal).normalized()
		if forward.is_zero_approx():
			forward = Vector3.FORWARD
		marks.global_basis = Basis.looking_at(forward, normal, true)
