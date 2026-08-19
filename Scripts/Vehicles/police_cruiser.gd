class_name PoliceCruiser
extends BaseVehicle

@onready var siren := $Emergency/Siren as AudioStreamPlayer3D
@onready var red_light := $Emergency/RedLight as OmniLight3D
@onready var blue_light := $Emergency/BlueLight as OmniLight3D
@onready var officer_exit_left := $OfficerExitLeft as Marker3D
@onready var officer_exit_right := $OfficerExitRight as Marker3D

var _emergency_active := false
var _flash_elapsed := 0.0

@export_range(10.0, 200.0, 1.0) var pursuit_sight_range := 85.0
@export_range(30.0, 180.0, 1.0) var pursuit_fov_degrees := 110.0
@export_flags_3d_physics var pursuit_sight_mask := 3


func _ready() -> void:
	super()
	set_emergency_active(false)


func _process(delta: float) -> void:
	super(delta)
	if not _emergency_active:
		return
	_flash_elapsed += delta
	var red_phase := int(floor(_flash_elapsed / 0.16)) % 2 == 0
	red_light.visible = red_phase
	blue_light.visible = not red_phase


func set_emergency_active(active: bool, audible := true) -> void:
	_emergency_active = active
	_flash_elapsed = 0.0
	if red_light != null:
		red_light.visible = active
	if blue_light != null:
		blue_light.visible = false
	if siren != null:
		if active and audible:
			if not siren.playing:
				siren.play()
		else:
			siren.stop()


func silence_siren() -> void:
	if siren != null:
		siren.stop()


func get_officer_exit_position(index: int) -> Vector3:
	return (
		officer_exit_left.global_position
		if index % 2 == 0
		else officer_exit_right.global_position
	)


func can_see_target(target: Node3D) -> bool:
	if target == null:
		return false
	var origin := global_position + Vector3.UP * 1.35
	var destination := target.global_position + Vector3.UP
	if origin.distance_squared_to(destination) > pursuit_sight_range * pursuit_sight_range:
		return false
	var offset := destination - origin
	var flat_offset := Vector3(offset.x, 0.0, offset.z)
	if flat_offset.length() > 8.0:
		var forward := global_basis.z.normalized()
		if forward.dot(flat_offset.normalized()) < cos(deg_to_rad(pursuit_fov_degrees * 0.5)):
			return false
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = pursuit_sight_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var node := hit.get("collider") as Node
	while node != null:
		if node == target:
			return true
		node = node.get_parent()
	return false
