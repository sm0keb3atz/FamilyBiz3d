class_name VehicleWheelVisualComponent
extends Node

var vehicle: BaseVehicle
var skeleton: Skeleton3D
var wheel_bones: Dictionary = {}
var wheel_spin: Dictionary = {}


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle
	call_deferred("bind_bones")


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


func update(delta: float) -> void:
	if skeleton == null or wheel_bones.is_empty():
		return
	var skeleton_inverse := skeleton.global_transform.affine_inverse()
	var down := -vehicle.global_basis.y
	for wheel in wheel_bones:
		var bone_index := int(wheel_bones[wheel])
		wheel_spin[wheel] = float(wheel_spin[wheel]) + (
			wheel.get_rpm() * TAU / 60.0 * delta
		)
		var center: Vector3 = wheel.global_position + (
			down * vehicle.definition.suspension_rest_length
		)
		if wheel.is_in_contact():
			center = wheel.get_contact_point() + (
				wheel.get_contact_normal() * vehicle.definition.wheel_radius
			)
		var rest := skeleton.get_bone_global_rest(bone_index)
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
			skeleton_inverse * center
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
