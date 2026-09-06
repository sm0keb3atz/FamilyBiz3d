class_name PlayerLensFinishComponent
extends CanvasLayer

const LENS_SHADER := preload(
	"res://Assets/VFX/Shaders/grounded_lens_finish.gdshader"
)
const DEFAULT_VISUAL_PROFILE := preload(
	"res://Assets/VFX/GrittyCinematicWorldVisualProfile.tres"
)

@export var visual_profile: WorldVisualProfile = DEFAULT_VISUAL_PROFILE

var _overlay: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 3
	_build_overlay()
	_apply_profile()


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "GroundedLensFinish"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = LENS_SHADER
	_overlay.material = _material
	add_child(_overlay)


func _apply_profile() -> void:
	if visual_profile == null:
		visible = false
		return
	visible = visual_profile.lens_finish_enabled
	_material.set_shader_parameter(
		"vignette_strength",
		visual_profile.lens_vignette_strength
	)
	_material.set_shader_parameter(
		"grain_strength",
		visual_profile.lens_grain_strength
	)
	_material.set_shader_parameter(
		"dither_strength",
		visual_profile.lens_dither_strength
	)
