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
	var loading_scene := load(
		"res://Scenes/UI/LoadingScreen.tscn"
	) as PackedScene
	assert(menu_scene != null and creator_scene != null and loading_scene != null)

	var menu := menu_scene.instantiate() as StartupMenu
	root.add_child(menu)
	await process_frame
	await process_frame
	assert(menu.find_child("NewGameButton", true, false) != null)
	assert(menu.find_child("ContinueButton", true, false) != null)
	assert(menu.find_child("QuitButton", true, false) != null)
	assert(menu.find_child("OverwriteConfirmation", true, false) != null)
	assert(not menu.is_continue_available())
	menu.queue_free()
	await process_frame

	var creator := creator_scene.instantiate() as CharacterCreator
	root.add_child(creator)
	await process_frame
	await process_frame
	var name_edit := creator.find_child(
		"DisplayNameEdit",
		true,
		false
	) as LineEdit
	var slider := creator.find_child(
		"DifficultySlider",
		true,
		false
	) as HSlider
	assert(name_edit != null and slider != null)
	assert(int(slider.value) == 1)
	assert(creator.build_profile().is_empty())
	name_edit.text = "Vito Test"
	var profile := creator.build_profile()
	assert(not profile.is_empty())
	assert(profile.identity.display_name == "Vito Test")
	assert(profile.appearance.body_variant == "male")
	assert(profile.appearance.skin_preset == "medium")

	var available_ids := creator.get_available_clothing_ids()
	assert(&"base_hoodie" in available_ids)
	assert(&"tshirt_white" in available_ids)
	assert(&"jeans" in available_ids)
	assert(&"sweatpants" in available_ids)
	assert(&"sneakers" in available_ids)
	assert(&"boots" not in available_ids)
	assert(&"amiri_black" not in available_ids)
	creator.queue_free()
	await process_frame

	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	var identity := player.get_node(
		"Components/IdentityComponent"
	) as PlayerIdentityComponent
	var appearance := player.get_node(
		"Components/AppearanceComponent"
	) as PlayerAppearanceComponent
	var wardrobe := player.get_node(
		"Components/WardrobeComponent"
	) as PlayerWardrobeComponent
	assert(identity != null and appearance != null and wardrobe != null)

	identity.import_save_data(profile.identity)
	appearance.import_save_data(profile.appearance)
	wardrobe.import_save_data(profile.wardrobe)
	assert(identity.get_display_name() == "Vito Test")
	assert(appearance.get_body_variant() == &"male")
	assert(appearance.get_skin_preset() == &"medium")
	assert(wardrobe.get_equipped_id(&"top") == &"base_hoodie")
	assert(not wardrobe.owns(&"boots"))

	assert(appearance.set_skin_difficulty(0))
	assert(
		appearance.get_body_material_resource_path()
		== "res://Assets/BaseChracters/Player/Materials/Modular/Body_Texture_02.tres"
	)
	assert(appearance.set_skin_difficulty(1))
	assert(
		appearance.get_body_material_resource_path()
		== "res://Assets/BaseChracters/Player/Materials/Modular/AsainMale.tres"
	)
	assert(appearance.set_skin_difficulty(2))
	assert(
		appearance.get_body_material_resource_path()
		== "res://Assets/BaseChracters/Player/Materials/Modular/Body_Texture_01.tres"
	)
	assert(
		appearance.get_body_material_resource_path().findn("spanish") < 0
	)

	appearance.set_skin_difficulty(1)
	var identity_save := identity.export_save_data()
	var appearance_save := appearance.export_save_data()
	var wardrobe_save := wardrobe.export_save_data()
	identity.reset_to_new_game()
	appearance.reset_appearance()
	wardrobe.reset_to_new_game()
	identity.import_save_data(identity_save)
	appearance.import_save_data(appearance_save)
	wardrobe.import_save_data(wardrobe_save)
	assert(identity.get_display_name() == "Vito Test")
	assert(appearance.get_skin_preset() == &"medium")
	assert(wardrobe.get_equipped_id(&"top") == &"base_hoodie")

	var legacy_preset := appearance.get_skin_preset()
	appearance.import_save_data({})
	identity.import_save_data({})
	assert(appearance.get_skin_preset() == legacy_preset)
	assert(identity.get_display_name() == "Vito Test")
	assert(WorldController.SAVE_VERSION == 20)

	print("STARTUP_FLOW_SMOKE_TEST_PASS")
	quit(0)
