extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var marker := ReticleHitmarker.new()
	canvas.add_child(marker)
	await process_frame

	var viewport_center := root.get_visible_rect().size * 0.5
	assert(marker.get_global_rect().get_center().is_equal_approx(viewport_center))
	marker.trigger(false, 0.18)
	assert(marker.visible)
	assert(is_equal_approx(marker._remaining, 0.18))
	marker._process(0.18)
	assert(not marker.visible)

	marker.trigger(true, 0.18)
	assert(marker.visible)
	assert(marker._is_fatal)
	print("HIT_MARKER_SMOKE_TEST_PASS")
	quit(0)
