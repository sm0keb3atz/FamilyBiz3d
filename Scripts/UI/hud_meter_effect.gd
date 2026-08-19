extends ColorRect

const METER_SHADER := preload("res://Assets/UI/Shaders/hud_meter_fx.gdshader")

const PROFILE_EXPERIENCE := &"experience"
const PROFILE_HEALTH := &"health"
const PROFILE_STAMINA := &"stamina"
const PROFILE_REPUTATION := &"reputation"
const PROFILE_HEAT := &"heat"
const PROFILE_ESCAPE := &"escape"
const PROFILE_ARREST := &"arrest"
const PROFILE_VEHICLE_FUEL := &"vehicle_fuel"
const PROFILE_VEHICLE_DAMAGE := &"vehicle_damage"
const PROFILE_FUEL_PUMP := &"fuel_pump"

const WARNING_RED := Color(0.96, 0.10, 0.20)
const WARNING_AMBER := Color(0.98, 0.73, 0.08)

var _bar: ProgressBar
var _shader_material: ShaderMaterial
var _profile: StringName
var _base_accent := Color.WHITE
var _reverse_fill := false
var _visual_ratio := 0.0
var _target_ratio := 0.0
var _pulse := 0.0
var _trail_ratio := 0.0
var _trail_amount := 0.0
var _trail_hold := 0.0
var _flash := 0.0
var _rising := 0.0
var _rising_hold := 0.0


func setup(
	target_bar: ProgressBar,
	accent: Color,
	profile: StringName,
	reverse_fill: bool = false
) -> void:
	_bar = target_bar
	_base_accent = accent
	_profile = profile
	_reverse_fill = reverse_fill
	name = "%sFX" % target_bar.name
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 1.0
	offset_top = 1.0
	offset_right = -1.0
	offset_bottom = -1.0
	# Keep the source rect invisible if the shader ever fails to compile. The
	# shader writes its own final color, while the normal meter fill remains as
	# a safe visual fallback underneath it.
	color = Color.TRANSPARENT
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = METER_SHADER
	material = _shader_material
	_visual_ratio = _normalized_value()
	_target_ratio = _visual_ratio
	_trail_ratio = _visual_ratio
	_shader_material.set_shader_parameter("reverse_fill", _reverse_fill)
	_apply_shader_state()
	if not _bar.value_changed.is_connected(_on_value_changed):
		_bar.value_changed.connect(_on_value_changed)


func _process(delta: float) -> void:
	if not is_instance_valid(_bar):
		queue_free()
		return
	visible = _bar.is_visible_in_tree()
	if not visible:
		return
	var live_ratio := _normalized_value()
	if not is_equal_approx(live_ratio, _target_ratio):
		_set_target_ratio(live_ratio, false)
	var blend := 1.0 - exp(-delta * 12.0)
	if _profile == PROFILE_HEALTH and _trail_amount > 0.0:
		_visual_ratio = _target_ratio
	else:
		_visual_ratio = lerpf(_visual_ratio, _target_ratio, blend)
	if absf(_visual_ratio - _target_ratio) < 0.0005:
		_visual_ratio = _target_ratio
	_update_health_reaction(delta)
	_update_heat_reaction(delta)
	_pulse = move_toward(_pulse, 0.0, delta * 3.2)
	_apply_shader_state()


func _on_value_changed(_new_value: float) -> void:
	var next_ratio := _normalized_value()
	_set_target_ratio(next_ratio, true)


func _set_target_ratio(next_ratio: float, reactive: bool) -> void:
	if absf(next_ratio - _target_ratio) <= 0.0005:
		return
	var previous_ratio := _target_ratio
	var increased := next_ratio > _target_ratio
	var decreased := next_ratio < _target_ratio
	if reactive and _profile == PROFILE_HEALTH and decreased:
		_trail_ratio = maxf(maxf(_trail_ratio, previous_ratio), _visual_ratio)
		_trail_amount = 1.0
		_trail_hold = 0.18
		_flash = 1.0
		_visual_ratio = next_ratio
	elif _profile == PROFILE_HEALTH and increased:
		_trail_ratio = next_ratio
		_trail_amount = 0.0
	if reactive and _profile == PROFILE_HEAT and increased:
		_rising = 1.0
		_rising_hold = 0.32
	_target_ratio = next_ratio
	if reactive and (_profile != PROFILE_EXPERIENCE or increased):
		_pulse = 1.0


func _update_health_reaction(delta: float) -> void:
	if _profile != PROFILE_HEALTH:
		_trail_ratio = _visual_ratio
		_trail_amount = 0.0
		_flash = 0.0
		return
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	if _trail_hold > 0.0:
		_trail_hold = maxf(_trail_hold - delta, 0.0)
		return
	if _trail_ratio > _target_ratio + 0.0005:
		var trail_blend := 1.0 - exp(-delta * 8.0)
		_trail_ratio = lerpf(_trail_ratio, _target_ratio, trail_blend)
		return
	_trail_ratio = _target_ratio
	_trail_amount = move_toward(_trail_amount, 0.0, delta * 5.0)


func _update_heat_reaction(delta: float) -> void:
	if _profile != PROFILE_HEAT:
		_rising = 0.0
		return
	if _rising_hold > 0.0:
		_rising_hold = maxf(_rising_hold - delta, 0.0)
		return
	_rising = move_toward(_rising, 0.0, delta * 1.45)


func _normalized_value() -> float:
	if not is_instance_valid(_bar):
		return 0.0
	var span := _bar.max_value - _bar.min_value
	if span <= 0.0001:
		return 0.0
	return clampf((_bar.value - _bar.min_value) / span, 0.0, 1.0)


func _apply_shader_state() -> void:
	if _shader_material == null:
		return
	var accent := _base_accent
	var warning_color := WARNING_RED
	var warning := 0.0
	var speed := 0.14
	var glow := 0.2
	match _profile:
		PROFILE_EXPERIENCE:
			speed = 0.11
			glow = 0.2
		PROFILE_HEALTH:
			warning = clampf((0.25 - _target_ratio) / 0.25, 0.0, 1.0)
			speed = lerpf(0.13, 0.28, warning)
			glow = lerpf(0.2, 0.38, warning)
		PROFILE_STAMINA:
			speed = 0.2
			glow = 0.22
		PROFILE_REPUTATION:
			speed = 0.15
			glow = lerpf(0.2, 0.32, _target_ratio)
		PROFILE_HEAT:
			warning = clampf((_target_ratio - 0.6) / 0.4, 0.0, 1.0)
			speed = lerpf(0.15, 0.34, _target_ratio)
			glow = lerpf(0.2, 0.4, warning)
		PROFILE_ESCAPE:
			warning_color = WARNING_AMBER
			speed = lerpf(0.23, 0.34, _target_ratio)
			glow = lerpf(0.24, 0.38, _target_ratio)
		PROFILE_ARREST:
			warning_color = _base_accent
			warning = clampf((_target_ratio - 0.8) / 0.2, 0.0, 1.0)
			speed = lerpf(0.22, 0.38, _target_ratio)
			glow = lerpf(0.24, 0.42, _target_ratio)
		PROFILE_VEHICLE_FUEL:
			if _target_ratio <= 0.15:
				accent = WARNING_RED
				warning = 1.0
			elif _target_ratio <= 0.3:
				accent = WARNING_AMBER
				warning_color = WARNING_AMBER
				warning = 0.35
			speed = lerpf(0.13, 0.27, warning)
			glow = lerpf(0.2, 0.38, warning)
		PROFILE_VEHICLE_DAMAGE:
			warning = clampf((_target_ratio - 0.5) / 0.5, 0.0, 1.0)
			accent = _base_accent.lerp(WARNING_RED, warning)
			speed = lerpf(0.14, 0.3, warning)
			glow = lerpf(0.2, 0.4, warning)
		PROFILE_FUEL_PUMP:
			speed = 0.2
			glow = 0.25
	_shader_material.set_shader_parameter("accent_color", accent)
	_shader_material.set_shader_parameter("warning_color", warning_color)
	_shader_material.set_shader_parameter("fill_ratio", _visual_ratio)
	_shader_material.set_shader_parameter("trail_ratio", _trail_ratio)
	_shader_material.set_shader_parameter("trail_amount", _trail_amount)
	_shader_material.set_shader_parameter("flash_amount", _flash)
	_shader_material.set_shader_parameter("rising_amount", _rising)
	_shader_material.set_shader_parameter("warning_amount", warning)
	_shader_material.set_shader_parameter("pulse_amount", _pulse)
	_shader_material.set_shader_parameter("sheen_speed", speed)
	_shader_material.set_shader_parameter("glow_strength", glow)
