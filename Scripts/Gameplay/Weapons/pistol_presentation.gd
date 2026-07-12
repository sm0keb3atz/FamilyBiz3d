@tool
class_name WeaponPresentation
extends Node3D

const ATTACHMENT_NODE_NAMES := {
	&"sights": [&"Sights", &"Sight", &"Scope", &"Optic"],
	&"laser": [&"Lazer", &"Laser"],
	&"standard": [&"Clip", &"StandardClip", &"StandardMag"],
	&"extended": [
		&"ExtendedClip",
		&"ExtenedClip",
		&"ExtendedMag",
		&"ExtendedMagazine",
	],
	&"drum": [&"DrumMag", &"Drum", &"DrumMagazine"],
	&"switch": [&"Switch", &"AutoSwitch"],
}

var _laser_beam: MeshInstance3D
var _laser_beam_material: StandardMaterial3D


func _ready() -> void:
	if not Engine.is_editor_hint():
		_create_laser_beam()
	apply_attachment_visuals(false, false, 0, false)


func apply_attachment_visuals(
	sights_enabled: bool,
	laser_enabled: bool,
	magazine_type: int,
	switch_enabled: bool
) -> void:
	_set_attachment_visible(&"sights", sights_enabled)
	_set_attachment_visible(&"laser", laser_enabled)
	_set_attachment_visible(&"standard", magazine_type == 0)
	_set_attachment_visible(&"extended", magazine_type == 1)
	_set_attachment_visible(&"drum", magazine_type == 2)
	_set_attachment_visible(&"switch", switch_enabled)
	if not laser_enabled and _laser_beam != null:
		_laser_beam.visible = false


func update_laser_beam(target_position: Vector3) -> void:
	var laser_attachment := _get_attachment_node(&"laser")
	var laser_origin := get_node_or_null("LaserOrigin") as Node3D
	if laser_attachment == null or laser_origin == null or not laser_attachment.visible:
		if _laser_beam != null:
			_laser_beam.visible = false
		return
	var segment := target_position - laser_origin.global_position
	var length := segment.length()
	if length <= 0.05:
		_laser_beam.visible = false
		return
	var beam_mesh := _laser_beam.mesh as BoxMesh
	beam_mesh.size = Vector3(0.008, 0.008, length)
	_laser_beam.global_position = laser_origin.global_position + segment * 0.5
	_laser_beam.look_at(target_position, Vector3.UP)
	_laser_beam.visible = true


func hide_laser_beam() -> void:
	if _laser_beam != null:
		_laser_beam.visible = false


func is_attachment_visible(attachment_id: StringName) -> bool:
	var node := _get_attachment_node(attachment_id)
	return node != null and node.visible


func _set_attachment_visible(attachment_id: StringName, is_visible: bool) -> void:
	var node := _get_attachment_node(attachment_id)
	if node != null:
		node.visible = is_visible


func _get_attachment_node(attachment_id: StringName) -> Node3D:
	if not ATTACHMENT_NODE_NAMES.has(attachment_id):
		return null
	for node_name in ATTACHMENT_NODE_NAMES[attachment_id]:
		var node := find_child(node_name, true, false) as Node3D
		if node != null:
			return node
	return null


func _create_laser_beam() -> void:
	_laser_beam = MeshInstance3D.new()
	_laser_beam.name = "LaserBeam"
	_laser_beam.top_level = true
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.008, 0.008, 1.0)
	_laser_beam_material = StandardMaterial3D.new()
	_laser_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_beam_material.albedo_color = Color(1.0, 0.02, 0.02, 0.92)
	_laser_beam_material.emission_enabled = true
	_laser_beam_material.emission = Color(4.0, 0.0, 0.0)
	_laser_beam_material.emission_energy_multiplier = 3.0
	beam_mesh.material = _laser_beam_material
	_laser_beam.mesh = beam_mesh
	_laser_beam.visible = false
	add_child(_laser_beam)
