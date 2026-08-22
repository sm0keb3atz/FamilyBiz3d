class_name ReticleHitmarker
extends Control

var _remaining := 0.0
var _duration := 0.2
var _is_fatal := false
var _scale_mult := 1.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	size = Vector2(48, 48)
	position = -size * 0.5
	visible = false
	set_process(true)


func trigger(fatal: bool, duration := 0.22) -> void:
	_is_fatal = fatal
	_duration = duration
	_remaining = duration
	_scale_mult = 1.4 if fatal else 1.15
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		if visible:
			visible = false
		return
	_remaining = maxf(_remaining - delta, 0.0)
	var progress := _remaining / _duration
	_scale_mult = lerpf(1.0, _scale_mult, progress)
	if is_zero_approx(_remaining):
		visible = false
	queue_redraw()


func _draw() -> void:
	if _remaining <= 0.0:
		return
	var progress := _remaining / _duration
	var alpha := clampf(progress * 1.3, 0.0, 1.0)
	var main_color := (
		Color(1.0, 0.2, 0.22, alpha)
		if _is_fatal
		else Color(1.0, 1.0, 1.0, alpha)
	)
	var shadow_color := Color(0.04, 0.04, 0.04, alpha * 0.75)
	var center := size * 0.5
	var inner_radius := 6.0 * _scale_mult
	var outer_radius := (14.5 if _is_fatal else 11.5) * _scale_mult
	var line_width := 2.6 if _is_fatal else 1.85
	var shadow_width := line_width + 1.4

	var directions := [
		Vector2(1.0, 1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(1.0, -1.0).normalized(),
		Vector2(-1.0, -1.0).normalized(),
	]

	# Draw subtle dark outline for contrast against light environments
	for dir in directions:
		draw_line(
			center + dir * inner_radius,
			center + dir * outer_radius,
			shadow_color,
			shadow_width
		)
	# Draw main crisp hit ticks
	for dir in directions:
		draw_line(
			center + dir * inner_radius,
			center + dir * outer_radius,
			main_color,
			line_width
		)
