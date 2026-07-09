class_name AimStrafeBlend
extends RefCounted


static func from_local_velocity(
	local_velocity: Vector3,
	reference_speed: float
) -> Vector2:
	var speed := maxf(reference_speed, 0.01)
	var blend := Vector2(
		local_velocity.x / speed,
		local_velocity.z / speed
	).limit_length(1.0)

	if absf(blend.x) > 0.2 and absf(blend.y) > 0.2:
		if absf(blend.x) >= absf(blend.y):
			blend.y = 0.0
		else:
			blend.x = 0.0

	if blend.y < -0.05 and absf(blend.x) > 0.05:
		var strafe_sign := signf(blend.x)
		var backward_strength := maxf(absf(blend.y), 0.75)
		var side_strength := maxf(absf(blend.x), 0.75)
		blend = Vector2(strafe_sign * side_strength, -backward_strength)

	return blend
