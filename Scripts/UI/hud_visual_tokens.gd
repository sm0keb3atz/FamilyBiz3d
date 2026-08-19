extends RefCounted

const SURFACE := Color(0.018, 0.027, 0.037, 0.96)
const SURFACE_RAISED := Color(0.027, 0.039, 0.051, 0.97)
const SURFACE_SOFT := Color(0.04, 0.054, 0.068, 0.94)
const BORDER := Color(0.19, 0.24, 0.29, 0.96)
const BORDER_SOFT := Color(0.13, 0.18, 0.22, 0.88)
const FRAME_SURFACE := Color(0.012, 0.019, 0.027, 0.94)
const FRAME_BORDER := Color(0.21, 0.26, 0.31, 0.94)
const FRAME_SHADOW := Color(0, 0, 0, 0.52)
const TEXT := Color(0.93, 0.96, 0.98)
const MUTED := Color(0.52, 0.59, 0.65)
const BLUE := Color(0.23, 0.63, 0.98)
const CYAN := Color(0.24, 0.83, 0.88)
const GREEN := Color(0.2, 0.9, 0.42)
const AMBER := Color(0.98, 0.73, 0.08)
const ORANGE := Color(1.0, 0.39, 0.09)
const RED := Color(0.96, 0.1, 0.2)
const SHADOW := Color(0, 0, 0, 0.5)


static func stylebox(
	background: Color = SURFACE,
	border: Color = BORDER,
	border_width: int = 1,
	corner_radius: int = 7,
	shadow_color: Color = Color.TRANSPARENT,
	shadow_size: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	return style


static func meter_background(radius: int = 3) -> StyleBoxFlat:
	return stylebox(
		Color(0.035, 0.05, 0.062, 1.0),
		Color(0.18, 0.22, 0.26, 0.95),
		1,
		radius
	)


static func meter_fill(color: Color, radius: int = 3) -> StyleBoxFlat:
	var fill := stylebox(color.darkened(0.08), color, 1, radius)
	fill.expand_margin_top = 1.0
	fill.expand_margin_bottom = 1.0
	return fill


static func frame_style(
	radius: int = 9,
	border_width: int = 2,
	shadow_size: int = 8
) -> StyleBoxFlat:
	return stylebox(
		FRAME_SURFACE,
		FRAME_BORDER,
		border_width,
		radius,
		FRAME_SHADOW,
		shadow_size
	)


static func inset_style(
	radius: int = 7,
	border_width: int = 1
) -> StyleBoxFlat:
	return stylebox(SURFACE, FRAME_BORDER, border_width, radius)
