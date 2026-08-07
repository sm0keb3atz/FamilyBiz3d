class_name VehicleWheelVisualComponent
extends Node

var vehicle: BaseVehicle
var skeleton: Skeleton3D
var wheel_bones: Dictionary = {}
var wheel_spin: Dictionary = {}


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func has_valid_bones() -> bool:
	return skeleton != null and wheel_bones.size() == 4


func bind_bones() -> void:
	skeleton = _find_skeleton(vehicle.visual_root)
	if skeleton == null:
		push_warning("%s could not find its vehicle skeleton." % vehicle.name)
		return
	var bindings := {
		vehicle.front_left_wheel: vehicle.definition.front_left_bone,
		vehicle.front_right_wheel: vehicle.definition.front_right_bone,
		vehicle.rear_left_wheel: vehicle.definition.rear_left_bone,
		vehicle.rear_right_wheel: vehicle.definition.rear_right_bone,
	}
	for wheel in bindings:
		var bone_index := skeleton.find_bone(bindings[wheel])
		if bone_index < 0:
			push_warning(
				"%s is missing wheel bone %s."
				% [vehicle.name, bindings[wheel]]
			)
			continue
		wheel_bones[wheel] = bone_index
		wheel_spin[wheel] = 0.0
	_align_physics_wheels_to_bones()


func get_maximum_rest_alignment_error() -> float:
	if not has_valid_bones():
		return INF
	var maximum_error := 0.0
	for wheel in wheel_bones:
		var bone_index := int(wheel_bones[wheel])
		var rest_center: Vector3 = vehicle.to_local(
			skeleton.global_transform * skeleton.get_bone_global_rest(bone_index).origin
		)
		var horizontal_error := Vector2(
			wheel.position.x - rest_center.x,
			wheel.position.z - rest_center.z
		).length()
		var radius_error := absf(wheel.wheel_radius - rest_center.y)
		maximum_error = maxf(maximum_error, maxf(horizontal_error, radius_error))
	return maximum_error


func get_rest_alignment_diagnostics() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not has_valid_bones():
		return results
	for wheel in wheel_bones:
		var bone_index := int(wheel_bones[wheel])
		var rest_center: Vector3 = vehicle.to_local(
			skeleton.global_transform * skeleton.get_bone_global_rest(bone_index).origin
		)
		results.append({
			"wheel": wheel.name,
			"rest_center": rest_center,
			"anchor": wheel.position,
			"rest_length": wheel.wheel_rest_length,
			"radius": wheel.wheel_radius,
		})
	return results


func _align_physics_wheels_to_bones() -> void:
	if not has_valid_bones():
		return
	for wheel in wheel_bones:
		var bone_index := int(wheel_bones[wheel])
		var rest_center: Vector3 = vehicle.to_local(
			skeleton.global_transform * skeleton.get_bone_global_rest(bone_index).origin
		)
		wheel.position = rest_center + Vector3.UP * wheel.wheel_rest_length
		# These assets are authored on a zero-height ground plane, so the wheel
		# bone's rest height is also its model-specific tire radius.
		wheel.wheel_radius = clampf(rest_center.y, 0.1, 1.0)
	vehicle._cache_wheel_anchors()


func update(delta: float) -> void:
	if skeleton == null or wheel_bones.is_empty():
		return
	var skeleton_inverse := skeleton.global_transform.affine_inverse()
	for wheel in wheel_bones:
		var bone_index := int(wheel_bones[wheel])
		wheel_spin[wheel] = float(wheel_spin[wheel]) + (
			wheel.get_rpm() * TAU / 60.0 * delta
		)
		var rest := skeleton.get_bone_global_rest(bone_index)
		var target_origin := rest.origin
		if not vehicle.definition.preserve_authored_wheel_positions:
			var center: Vector3 = wheel.global_position
			if wheel.is_in_contact():
				center = wheel.get_contact_point() + (
					wheel.get_contact_normal() * wheel.wheel_radius
				)
			target_origin = skeleton_inverse * center
		var steer_angle := (
			vehicle.drive_component.steering_input
			if (
				wheel == vehicle.front_left_wheel
				or wheel == vehicle.front_right_wheel
			)
			else 0.0
		)
		var target := Transform3D(
			rest.basis
			* Basis(Vector3.UP, steer_angle)
			* Basis(Vector3.FORWARD, -float(wheel_spin[wheel])),
			target_origin
		)
		skeleton.set_bone_global_pose(bone_index, target)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null
