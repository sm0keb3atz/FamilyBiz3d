@tool
class_name TrafficIntersectionVisual3D
extends Node3D

@export var intersection_id: StringName:
	set(value):
		intersection_id = value
@export var swap_signal_groups := false


func _ready() -> void:
	_apply_controller_id()


func _apply_controller_id() -> void:
	for child in find_children("*", "TrafficSignalVisual3D", true, false):
		var visual := child as TrafficSignalVisual3D
		if visual == null:
			continue
		var authored_group := visual.signal_group
		if visual.has_meta(&"authored_signal_group"):
			authored_group = visual.get_meta(&"authored_signal_group") as StringName
		else:
			visual.set_meta(&"authored_signal_group", authored_group)
		if swap_signal_groups:
			visual.signal_group = (
				&"east_west" if authored_group == &"north_south" else &"north_south"
			)
		else:
			visual.signal_group = authored_group
		visual.signal_controller_id = intersection_id
		visual.refresh_controller_binding()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if intersection_id == &"":
		warnings.append("Assign the stable territory intersection ID on each instance.")
	return warnings
