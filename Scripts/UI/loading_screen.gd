class_name StartupLoadingScreen
extends Control

const MINIMUM_DISPLAY_SECONDS := 0.8
const ACCENT := Color(0.73, 0.38, 0.96, 1.0)

var _progress_bar: ProgressBar
var _status_label: Label
var _started_at_msec := 0
var _resource_loaded := false
var _entering_world := false
var _startup_flow: Variant


func _ready() -> void:
	_startup_flow = get_node("/root/StartupFlow")
	_build_ui()
	_started_at_msec = Time.get_ticks_msec()
	var error := ResourceLoader.load_threaded_request(_startup_flow.WORLD_SCENE)
	if error != OK:
		_fail("The city could not begin loading.")
		return
	set_process(true)


func _process(_delta: float) -> void:
	if _entering_world:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(
		_startup_flow.WORLD_SCENE,
		progress
	)
	if not progress.is_empty():
		_progress_bar.value = clampf(float(progress[0]) * 100.0, 0.0, 100.0)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_status_label.text = "PREPARING THE CITY  %d%%" % int(_progress_bar.value)
		ResourceLoader.THREAD_LOAD_LOADED:
			_resource_loaded = true
			_progress_bar.value = 100.0
			_status_label.text = "YOUR STORY IS READY"
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("The game world could not be loaded.")
	if _resource_loaded and _elapsed_seconds() >= MINIMUM_DISPLAY_SECONDS:
		_enter_world()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.007, 0.004, 0.012, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(720, 310)
	content.add_theme_constant_override("separation", 20)
	center.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "FAMILY BUSINESS"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 22)
	eyebrow.add_theme_color_override("font_color", ACCENT)
	content.add_child(eyebrow)

	var title := Label.new()
	title.text = "BUILDING YOUR EMPIRE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 47)
	title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.98))
	content.add_child(title)

	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 3
	divider.color = ACCENT.darkened(0.15)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)

	_status_label = Label.new()
	_status_label.name = "LoadingStatusLabel"
	_status_label.text = "PREPARING THE CITY  0%"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override(
		"font_color",
		Color(0.74, 0.69, 0.77)
	)
	content.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "LoadingProgressBar"
	_progress_bar.custom_minimum_size.y = 24
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override(
		"background",
		_bar_style(Color(0.08, 0.06, 0.1), Color(0.22, 0.14, 0.28))
	)
	_progress_bar.add_theme_stylebox_override(
		"fill",
		_bar_style(ACCENT.darkened(0.15), ACCENT)
	)
	content.add_child(_progress_bar)

	var tip := Label.new()
	tip.text = "YOUR CHOICES ARE BEING SAVED BEFORE THE CITY OPENS."
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.47, 0.43, 0.5))
	content.add_child(tip)


func _enter_world() -> void:
	_entering_world = true
	set_process(false)
	var packed := ResourceLoader.load_threaded_get(
		_startup_flow.WORLD_SCENE
	) as PackedScene
	if packed == null:
		_fail("The loaded city data was invalid.")
		return
	var world := packed.instantiate()
	if world == null:
		_fail("The game world could not be created.")
		return
	get_tree().root.add_child(world)
	if not _startup_flow.apply_pending_to_world(world):
		world.queue_free()
		_fail(_startup_flow.get_last_error())
		return
	get_tree().current_scene = world
	queue_free()


func _fail(message: String) -> void:
	set_process(false)
	_startup_flow.show_main_menu(message)


func _elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - _started_at_msec) / 1000.0


func _bar_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style
