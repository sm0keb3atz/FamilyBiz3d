extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var roster := PlayerGirlfriendComponent.new()
	root.add_child(roster)
	assert(roster.get_aura_requirement(1) == 50)
	assert(roster.get_aura_requirement(2) == 75)
	assert(roster.get_aura_requirement(3) == 100)
	assert(roster.get_aura_requirement(4) == 150)

	var inventory_scene := load("res://Scenes/UI/PlayerInventoryMenu.tscn") as PackedScene
	assert(inventory_scene != null)
	var inventory_menu := inventory_scene.instantiate()
	assert(inventory_menu.get_node("MenuRoot/Panel/Margin/Content/TabContainer/Girlfriends") != null)
	assert(inventory_menu.get_node("MenuRoot/Panel/Margin/Content/TabContainer/Girlfriends/GirlfriendScroll/GirlfriendList") != null)
	inventory_menu.free()

	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	assert(player_scene != null)
	var player := player_scene.instantiate()
	assert(player.get_node("Components/GirlfriendComponent") is PlayerGirlfriendComponent)
	root.add_child(player)
	await process_frame
	var appearance := player.get_node("Components/AppearanceComponent") as PlayerAppearanceComponent
	assert(appearance.get_current_aura() == 0)
	appearance.set_option(PlayerAppearanceComponent.SLOT_SHOES, 1)
	assert(appearance.get_current_aura() == 50)
	appearance.set_option(PlayerAppearanceComponent.SLOT_SHOES, 0)
	assert(appearance.get_current_aura() == 0)
	var found_amiri := false
	for _index in 32:
		if appearance.get_material_name(PlayerAppearanceComponent.SLOT_TOP).begins_with("Amiri"):
			found_amiri = true
			break
		appearance.cycle_material(PlayerAppearanceComponent.SLOT_TOP, 1)
	assert(found_amiri)
	assert(appearance.get_current_aura() == 100)

	var player_roster := player.get_node("Components/GirlfriendComponent") as PlayerGirlfriendComponent
	player_roster.set_process(false)
	var fake_girlfriend := CustomerNPC.new()
	player_roster._entries.append({
		"npc": fake_girlfriend,
		"name": "Test Girlfriend",
		"level": 4,
		"status": PlayerGirlfriendComponent.STATUS_FOLLOWING,
		"relationship": 0,
		"relationship_elapsed": 0.0,
	})
	player_roster._update_relationships(10.0)
	assert(player_roster.get_relationship(fake_girlfriend) == 1)
	assert(is_equal_approx(player_roster.get_following_heat_decay_bonus(), 1.0))
	player_roster.adjust_relationship(fake_girlfriend, 99)
	assert(player_roster.get_relationship(fake_girlfriend) == 100)
	assert(is_equal_approx(player_roster.get_following_heat_decay_bonus(), 2.0))
	var wallet := player.get_node("Components/WalletComponent") as PlayerWalletComponent
	var cash_before := wallet.dirty_cash
	assert(player_roster.purchase_gift(fake_girlfriend, 10, 5))
	assert(wallet.dirty_cash == cash_before - 10)
	player_roster._entries[0]["status"] = PlayerGirlfriendComponent.STATUS_HOME
	player_roster._entries[0]["relationship"] = 0
	player_roster._entries[0]["relationship_elapsed"] = 0.0
	player_roster._update_relationships(30.0)
	assert(player_roster.get_relationship(fake_girlfriend) == -1)
	assert(is_zero_approx(player_roster.get_following_heat_decay_bonus()))
	fake_girlfriend.free()
	print("GIRLFRIEND_SYSTEM_SMOKE_TEST_PASS")
	quit(0)
