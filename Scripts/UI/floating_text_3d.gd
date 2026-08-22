class_name FloatingText3D
extends Node3D


static func spawn(
	tree: SceneTree,
	world_position: Vector3,
	text: String,
	color: Color = Color(0.22, 1.0, 0.45),
	font_size: int = 42,
	duration: float = 1.35
) -> void:
	if tree == null:
		return
	var host: Node = tree.current_scene
	if host == null:
		host = tree.root
	if host == null:
		return

	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0.04, 0.04, 0.04, 0.95)
	label.outline_size = 8
	label.font_size = font_size
	label.pixel_size = 0.0035
	label.render_priority = 10
	# Add to tree first so global_position is valid
	host.add_child(label)
	label.global_position = world_position + Vector3(
		randf_range(-0.15, 0.15),
		0.0,
		randf_range(-0.15, 0.15)
	)

	var start_y := label.global_position.y
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", start_y + 1.1, duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * 1.3, 0.14).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE, 0.28).set_delay(0.14)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.45).set_delay(
		duration * 0.55
	)
	tween.chain().tween_callback(label.queue_free)


static func spawn_cash_and_xp(
	tree: SceneTree,
	world_position: Vector3,
	cash_amount: int,
	xp_amount: float
) -> void:
	if tree == null:
		return
	var origin := world_position + Vector3.UP * 1.95
	spawn(tree, origin, "+$%d 💵" % cash_amount, Color(0.24, 1.0, 0.42), 46, 1.4)
	if xp_amount > 0.0:
		tree.create_timer(0.18).timeout.connect(func() -> void:
			spawn(tree, origin + Vector3(0.12, -0.18, 0.0), "+%.0f EXP ★" % xp_amount, Color(0.95, 0.78, 0.22), 34, 1.25)
		)
