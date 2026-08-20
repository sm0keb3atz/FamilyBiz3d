@tool
class_name VehicleSeatMarker3D
extends Marker3D

const OCCUPANT_PREVIEW_SCENE := preload(
	"res://Scenes/Vehicles/VehicleOccupantVisual.tscn"
)

@export_category("Editor Driver Preview")
@export var preview_enabled := true:
	set(value):
		preview_enabled = value
		_queue_preview_refresh()
@export var preview_female := false:
	set(value):
		preview_female = value
		_queue_preview_refresh()
@export_range(0.0, 4.0, 0.01) var preview_time := 0.0:
	set(value):
		preview_time = value
		_queue_preview_refresh()

var _editor_preview: VehicleOccupantVisual
var _refresh_queued := false


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_queue_preview_refresh()


func _ready() -> void:
	if Engine.is_editor_hint():
		_queue_preview_refresh()


func _exit_tree() -> void:
	_remove_preview()


func _queue_preview_refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_preview")


func _refresh_preview() -> void:
	_refresh_queued = false
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if not preview_enabled:
		_remove_preview()
		return
	if not is_instance_valid(_editor_preview):
		_editor_preview = OCCUPANT_PREVIEW_SCENE.instantiate()
		_editor_preview.name = "EditorDriverPreview"
		_editor_preview.set_meta(&"_edit_lock_", true)
		add_child(_editor_preview, false, Node.INTERNAL_MODE_FRONT)
	_editor_preview.transform = Transform3D.IDENTITY
	_editor_preview.set_editor_preview(preview_female, preview_time)


func _remove_preview() -> void:
	if not is_instance_valid(_editor_preview):
		_editor_preview = null
		return
	var preview := _editor_preview
	_editor_preview = null
	if preview.get_parent() != null:
		preview.get_parent().remove_child(preview)
	preview.queue_free()
