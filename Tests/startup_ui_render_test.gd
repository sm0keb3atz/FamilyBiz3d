extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu_scene := load(
		"res://Scenes/UI/StartupMenu.tscn"
	) as PackedScene
	var creator_scene := load(
		"res://Scenes/UI/CharacterCreator.tscn"
	) as PackedScene
	var menu := menu_scene.instantiate() as StartupMenu
	root.add_child(menu)
	current_scene = menu
	for _frame in range(12):
		await process_frame
	var menu_image := root.get_viewport().get_texture().get_image()
	assert(not menu_image.is_empty())
	assert(menu_image.save_png("user://startup_menu_render.png") == OK)
	menu.queue_free()
	await process_frame

	var creator := creator_scene.instantiate() as CharacterCreator
	root.add_child(creator)
	current_scene = creator
	for _frame in range(12):
		await process_frame
	var name_edit := creator.find_child(
		"DisplayNameEdit",
		true,
		false
	) as LineEdit
	name_edit.text = "VITO"
	var creator_image := root.get_viewport().get_texture().get_image()
	assert(not creator_image.is_empty())
	assert(creator_image.save_png("user://character_creator_render.png") == OK)
	print(
		"STARTUP_UI_RENDER_TEST_PASS ",
		ProjectSettings.globalize_path("user://startup_menu_render.png"),
		" ",
		ProjectSettings.globalize_path("user://character_creator_render.png")
	)
	quit(0)
