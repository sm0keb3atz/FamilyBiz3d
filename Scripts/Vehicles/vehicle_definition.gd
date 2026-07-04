class_name VehicleDefinition
extends Resource

@export_category("Identity")
@export var display_name := "Vehicle"
@export var visual_scene: PackedScene
@export var visual_rotation_degrees := Vector3(0.0, -90.0, 0.0)
@export var visual_offset := Vector3.ZERO

@export_category("Chassis")
@export_range(100.0, 5000.0, 10.0) var mass := 1250.0
@export_range(-1.0, 2.0, 0.05) var center_of_mass_height := 0.15
@export_range(1.0, 15000.0, 10.0) var engine_force := 7500.0
@export_range(1.0, 10000.0, 10.0) var reverse_engine_force := 3500.0
@export_range(1.0, 250.0, 1.0) var service_brake_force := 90.0
@export_range(1.0, 400.0, 1.0) var handbrake_force := 220.0
@export_range(1.0, 100.0, 0.5) var max_forward_speed := 35.0
@export_range(1.0, 50.0, 0.5) var max_reverse_speed := 12.0

@export_category("Steering")
@export_range(1.0, 60.0, 0.5) var max_steering_degrees := 24.0
@export_range(0.1, 20.0, 0.1) var steering_speed := 3.5
@export_range(0.05, 1.0, 0.05) var high_speed_steering_ratio := 0.2

@export_category("Transmission")
@export var forward_gear_speed_limits: Array[float] = [
	9.0,
	16.0,
	23.0,
	30.0,
	38.0,
]
@export var forward_gear_force_multipliers: Array[float] = [
	1.55,
	1.35,
	1.18,
	1.0,
	0.88,
]
@export_range(0.0, 1.0, 0.01) var shift_duration := 0.22
@export_range(100.0, 2000.0, 50.0) var idle_rpm := 850.0
@export_range(2000.0, 10000.0, 100.0) var maximum_rpm := 6500.0
@export_range(1000.0, 9000.0, 100.0) var drift_rpm_floor := 4200.0
@export_range(1.0, 3.0, 0.05) var drift_torque_multiplier := 1.45
@export_range(0.0, 1.0, 0.05) var drift_throttle_threshold := 0.25
@export_range(0.0, 1.0, 0.05) var drift_slip_start := 0.18
@export_range(0.1, 1.0, 0.05) var drift_slip_full := 0.65

@export_category("Suspension")
@export_range(0.1, 1.0, 0.01) var wheel_radius := 0.38
@export_range(0.05, 1.0, 0.01) var suspension_rest_length := 0.22
@export_range(0.01, 0.5, 0.01) var suspension_travel := 0.18
@export_range(1.0, 200.0, 1.0) var suspension_stiffness := 40.0
@export_range(0.0, 1.0, 0.01) var damping_compression := 0.4
@export_range(0.0, 1.0, 0.01) var damping_relaxation := 0.55
@export_range(1000.0, 30000.0, 100.0) var suspension_max_force := 9000.0
@export_range(0.1, 20.0, 0.05) var front_wheel_friction_slip := 1.45
@export_range(0.1, 20.0, 0.05) var rear_wheel_friction_slip := 1.4
@export_range(0.1, 20.0, 0.05) var power_slide_rear_friction_slip := 1.05
@export_range(0.1, 20.0, 0.05) var handbrake_rear_friction_slip := 0.5
@export_range(0.0, 1.0, 0.05) var power_slide_strength := 0.65
@export_range(0.1, 20.0, 0.1) var traction_loss_speed := 3.0
@export_range(0.1, 20.0, 0.1) var traction_recovery_speed := 4.5
@export_range(0.1, 20.0, 0.1) var drift_engagement_speed := 5.0
@export_range(0.1, 20.0, 0.1) var drift_release_speed := 2.5
@export_range(0.1, 5.0, 0.1) var burnout_start_max_speed := 2.5
@export_range(0.0, 1.0, 0.05) var burnout_throttle_threshold := 0.65
@export_range(0.1, 20.0, 0.1) var burnout_engagement_speed := 7.0
@export_range(0.05, 5.0, 0.05) var burnout_grip_recovery_speed := 0.25
@export_range(0.1, 10.0, 0.1) var burnout_traction_slip_speed := 1.5
@export_range(0.1, 20.0, 0.05) var burnout_rear_friction_slip := 0.35
@export_range(1.0, 400.0, 1.0) var burnout_front_brake_force := 180.0
@export_range(0.0, 1.0, 0.01) var wheel_roll_influence := 0.05

@export_category("Stability")
@export_range(0.0, 100000.0, 100.0) var anti_roll_stiffness := 24000.0
@export_range(0.0, 20000.0, 100.0) var maximum_anti_roll_force := 4500.0
@export_range(0.0, 50000.0, 100.0) var roll_leveling_torque := 9000.0
@export_range(0.0, 20000.0, 100.0) var roll_damping_torque := 3800.0
@export_range(0.0, 5000.0, 50.0) var drift_lateral_assist := 800.0
@export_range(0.0, 10000.0, 50.0) var drift_yaw_damping := 3000.0
@export_range(0.0, 100.0, 0.5) var downforce_coefficient := 10.0
@export_range(0.0, 30000.0, 100.0) var max_downforce := 9000.0

@export_category("Camera")
@export_range(1.0, 15.0, 0.1) var camera_distance := 6.5
@export_range(0.5, 5.0, 0.1) var camera_height := 1.8
@export_range(0.0005, 0.02, 0.0005) var camera_sensitivity := 0.003
@export_range(0.0, 5.0, 0.1) var camera_speed_distance_bonus := 1.5
@export_range(30.0, 120.0, 1.0) var camera_base_fov := 72.0
@export_range(0.0, 30.0, 0.5) var camera_speed_fov_bonus := 8.0
@export_range(0.1, 30.0, 0.1) var camera_response_speed := 3.0
@export_range(0.0, 1.0, 0.01) var camera_turn_lag_strength := 0.28
@export_range(0.0, 60.0, 1.0) var camera_max_turn_lag_degrees := 20.0
@export_range(0.1, 20.0, 0.1) var camera_turn_lag_response := 2.0
@export_range(0.0, 10.0, 0.1) var camera_recenter_speed := 1.1
@export_range(0.0, 5.0, 0.1) var camera_recenter_delay := 1.0
@export_range(0.0, 0.5, 0.01) var camera_acceleration_distance := 0.08
@export_range(0.0, 0.5, 0.01) var camera_braking_distance := 0.05
@export_range(0.0, 2.0, 0.05) var camera_acceleration_pitch_degrees := 0.3
@export_range(0.1, 20.0, 0.1) var camera_acceleration_response := 3.0

@export_category("Audio")
@export var door_stream: AudioStream
@export var start_stream: AudioStream
@export var engine_stream: AudioStream
@export var stop_stream: AudioStream
@export var tire_screech_stream: AudioStream
@export_range(-40.0, 6.0, 0.5) var entry_door_volume_db := 0.0
@export_range(-40.0, 6.0, 0.5) var exit_door_volume_db := -12.0
@export_range(-40.0, 6.0, 0.5) var tire_screech_volume_db := -5.0
@export_range(0.1, 2.0, 0.05) var idle_pitch := 0.75
@export_range(0.5, 3.0, 0.05) var maximum_pitch := 1.75
@export_range(0.0, 2.0, 0.05) var door_to_ignition_delay := 0.3
@export_range(0.0, 2.0, 0.05) var ignition_idle_overlap := 1.0
@export_range(0, 100000, 1) var engine_loop_begin := 9174
@export_range(0, 100000, 1) var engine_loop_end := 29350

@export_category("Wheel Bones")
@export var front_left_bone := &"wheelFL"
@export var front_right_bone := &"wheelFR"
@export var rear_left_bone := &"wheelRL"
@export var rear_right_bone := &"wheelRR"
