extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	assert(player_scene != null)
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	var wallet := player.get_node("Components/WalletComponent") as PlayerWalletComponent
	var wardrobe := player.get_node("Components/WardrobeComponent") as PlayerWardrobeComponent
	var store := player.get_node("Components/ClothingStoreService") as ClothingStoreService
	var appearance := player.get_node("Components/AppearanceComponent") as PlayerAppearanceComponent
	assert(wallet != null and wardrobe != null and store != null and appearance != null)

	var catalog := ClothingCatalog.get_all()
	assert(catalog.size() == 16)
	for definition in catalog:
		assert(not definition.display_name.contains("Police"))
		assert(not String(definition.mesh_name).contains("Police"))
	assert(ClothingCatalog.get_by_id(&"base_hoodie").price == 100)
	assert(ClothingCatalog.get_by_id(&"base_hoodie").tintable)
	assert(ClothingCatalog.get_by_id(&"tshirt_white").tintable)
	assert(ClothingCatalog.get_by_id(&"basic_hoodie_1") == null)
	assert(ClothingCatalog.get_by_id(&"tshirt_original") == null)
	assert(ClothingCatalog.get_by_id(&"mason_black_gold").price == 900)
	assert(ClothingCatalog.get_by_id(&"mason_black_gold").aura == 60)
	assert(ClothingCatalog.get_by_id(&"amiri_black").price == 1500)
	assert(ClothingCatalog.get_by_id(&"amiri_black").aura == 100)
	assert(ClothingCatalog.get_by_id(&"boots").aura == 50)
	assert(wardrobe.owns(&"base_hoodie"))
	assert(wardrobe.owns(&"sweatpants"))
	assert(not wardrobe.owns(&"boots"))
	assert(not wardrobe.owns(&"amiri_black"))

	assert(wallet.add_dirty(5000, false))
	assert(not store.buy(&"amiri_black"))
	assert(wallet.dirty_cash == 5100)
	assert(not wardrobe.owns(&"amiri_black"))
	assert(wallet.add_clean(5000, false))
	assert(store.buy(&"mason_black_gold"))
	assert(wallet.clean_cash == 4100)
	assert(wardrobe.get_equipped_id(&"top") == &"mason_black_gold")
	assert(appearance.get_current_aura() == 60)
	var clean_before_duplicate := wallet.clean_cash
	assert(not store.buy(&"mason_black_gold"))
	assert(wallet.clean_cash == clean_before_duplicate)
	assert(store.buy(&"boots"))
	assert(appearance.get_current_aura() == 110)
	assert(store.buy(&"amiri_black"))
	assert(appearance.get_current_aura() == 150)
	assert(store.equip(&"base_hoodie"))
	assert(appearance.get_current_aura() == 50)

	var chosen_color := Color(0.18, 0.42, 0.76, 1.0)
	var clean_before_color := wallet.clean_cash
	assert(store.buy_color_change(&"base_hoodie", chosen_color))
	assert(
		wallet.clean_cash
		== clean_before_color - ClothingStoreService.COLOR_CHANGE_PRICE
	)
	assert(wardrobe.get_item_color(&"base_hoodie").is_equal_approx(chosen_color))
	var save_data := wardrobe.export_save_data()
	wardrobe.import_save_data(save_data)
	assert(wardrobe.owns(&"amiri_black"))
	assert(wardrobe.owns(&"boots"))
	assert(wardrobe.get_equipped_id(&"top") == &"base_hoodie")
	assert(wardrobe.get_equipped_id(&"shoes") == &"boots")
	assert(wardrobe.get_item_color(&"base_hoodie").is_equal_approx(chosen_color))

	var preview_scene := load("res://Scenes/PlayerVisualModular.tscn") as PackedScene
	var preview_visual := preview_scene.instantiate() as Node3D
	root.add_child(preview_visual)
	var preview_appearance := PlayerAppearanceComponent.new()
	preview_appearance.skeleton_path = NodePath("../Armature/GeneralSkeleton")
	preview_visual.add_child(preview_appearance)
	await process_frame
	var live_top_before := wardrobe.get_equipped_id(&"top")
	wardrobe.apply_outfit_to(preview_appearance, &"amiri_black")
	assert(wardrobe.get_equipped_id(&"top") == live_top_before)
	assert(preview_appearance.get_current_aura() == 150)

	wardrobe.import_save_data({})
	assert(wardrobe.owns(&"base_hoodie"))
	assert(wardrobe.owns(&"jeans"))
	assert(wardrobe.owns(&"sneakers"))
	assert(not wardrobe.owns(&"amiri_black"))

	var store_scene := load("res://Scenes/Maps/Buildings/ClothingStore.tscn") as PackedScene
	var store_building := store_scene.instantiate() as Node3D
	root.add_child(store_building)
	await process_frame
	var interaction := store_building.get_node("StoreInteraction") as ClothingStoreInteraction
	assert(interaction != null)
	assert(interaction.is_in_group(&"interactable"))
	assert(interaction.can_interact(player))
	assert(interaction.get_interaction_prompt(player) == "E - Browse Clothing")

	print("CLOTHING_STORE_SMOKE_TEST_PASS")
	quit(0)
