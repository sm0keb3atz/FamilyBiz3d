extends HBoxContainer

const STAR_SHADER := preload("res://Assets/UI/Shaders/wanted_star_fx.gdshader")

const STAR_COUNT := 6
const STAR_SIZE := Vector2(43.0, 43.0)

var _stars: Array[ColorRect] = []
var _materials: Array[ShaderMaterial] = []
var _burst_values: Array[float] = []
var _burst_delays: Array[float] = []
var _level := 0


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stars()
	_apply_level(false)


func set_level(value: int, animate := true) -> void:
	var next_level := clampi(value, 0, STAR_COUNT)
	var previous_level := _level
	_level = next_level
	if not is_node_ready():
		return
	_apply_level(animate and next_level > previous_level)


func get_level() -> int:
	return _level


func get_star_material(index: int) -> ShaderMaterial:
	if index < 0 or index >= _materials.size():
		return null
	return _materials[index]


func _build_stars() -> void:
	if not _stars.is_empty():
		return
	for index in STAR_COUNT:
		var star := ColorRect.new()
		star.name = "Star%d" % (index + 1)
		star.custom_minimum_size = STAR_SIZE
		star.color = Color.WHITE
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var star_material := ShaderMaterial.new()
		star_material.shader = STAR_SHADER
		star_material.set_shader_parameter("star_index", float(index))
		star.material = star_material
		add_child(star)
		_stars.append(star)
		_materials.append(star_material)
		_burst_values.append(0.0)
		_burst_delays.append(0.0)


func _apply_level(animate: bool) -> void:
	for index in _materials.size():
		var is_filled := index < _level
		_materials[index].set_shader_parameter("filled", 1.0 if is_filled else 0.0)
		if animate and is_filled:
			_burst_values[index] = 1.0
			_burst_delays[index] = float(index) * 0.055
		else:
			_burst_values[index] = 0.0
			_burst_delays[index] = 0.0
			_materials[index].set_shader_parameter("burst", 0.0)
	set_process(animate)


func _process(delta: float) -> void:
	var has_active_burst := false
	for index in _materials.size():
		if _burst_delays[index] > 0.0:
			_burst_delays[index] = maxf(_burst_delays[index] - delta, 0.0)
			has_active_burst = true
			continue
		if _burst_values[index] <= 0.0:
			continue
		_burst_values[index] = move_toward(_burst_values[index], 0.0, delta * 2.6)
		_materials[index].set_shader_parameter("burst", _burst_values[index])
		has_active_burst = has_active_burst or _burst_values[index] > 0.0
	set_process(has_active_burst)
