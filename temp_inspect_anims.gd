extends SceneTree


func _initialize() -> void:
	var output_lines: PackedStringArray = []
	var scene := load("res://Scenes/Player.tscn") as PackedScene
	if scene == null:
		output_lines.append("Failed to load player scene")
		_write_output(output_lines)
		quit(1)
		return

	var player := scene.instantiate()
	var animation_player := player.get_node_or_null(
		"Visual/PlayerTest2/AnimationPlayer"
	) as AnimationPlayer
	if animation_player == null:
		output_lines.append("AnimationPlayer not found")
		_write_output(output_lines)
		quit(1)
		return

	for animation_name in ["LeftStrafe", "RightStrafe", "Walk", "PistolAim"]:
		if not animation_player.has_animation(animation_name):
			output_lines.append("%s: missing" % animation_name)
			continue

		var animation := animation_player.get_animation(animation_name)
		output_lines.append("--- %s ---" % animation_name)
		for track_index in animation.get_track_count():
			output_lines.append("%s | %s" % [animation.track_get_type(track_index), animation.track_get_path(track_index)])

	_write_output(output_lines)
	quit()


func _write_output(lines: PackedStringArray) -> void:
	var file := FileAccess.open("res://temp_inspect_output.txt", FileAccess.WRITE)
	if file == null:
		return

	for line in lines:
		file.store_line(line)
