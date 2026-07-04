class_name VehicleEffectsComponent
extends Node

var vehicle: BaseVehicle
var skid_emitters: Dictionary
var smoke_emitters: Dictionary
var idle_exhausts: Array[GPUParticles3D]
var startup_exhausts: Array[GPUParticles3D]


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle
	skid_emitters = vehicle._skid_mark_emitters
	smoke_emitters = vehicle._tire_smoke_emitters
	idle_exhausts = vehicle._tailpipe_idle_exhausts
	startup_exhausts = vehicle._tailpipe_startup_exhausts


func play_startup_puff() -> void:
	for exhaust in startup_exhausts:
		exhaust.emitting = true
		exhaust.restart()


func set_exhaust_running(running: bool) -> void:
	for exhaust in idle_exhausts:
		exhaust.emitting = running
		exhaust.amount_ratio = 0.2 if running else 0.0
	if not running:
		for exhaust in startup_exhausts:
			exhaust.emitting = false


func set_exhaust_intensity(intensity: float) -> void:
	for exhaust in idle_exhausts:
		exhaust.amount_ratio = intensity


func update() -> void:
	var planar := Vector3(
		vehicle.linear_velocity.x,
		0.0,
		vehicle.linear_velocity.z
	)
	var lateral_speed := absf(
		planar.dot(vehicle.global_basis.x.normalized())
	)
	var sliding := (
		vehicle.tire_component.handbrake_amount > 0.1
		or vehicle.tire_component.drift_amount > 0.12
		or vehicle.tire_component.burnout_amount > 0.08
		or lateral_speed >= vehicle.skid_mark_lateral_speed
		or vehicle.drive_component.service_braking
	)
	var can_mark := (
		vehicle.has_driver()
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
				0.45 if vehicle.drive_component.service_braking else 0.0
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
