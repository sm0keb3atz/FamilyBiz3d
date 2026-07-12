extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_scene := load(
		"res://Scenes/Maps/World/world.tscn"
	) as PackedScene
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var dealer := world.get_node("Gameplay/EastDealer") as DealerNPC
	var other_dealer := world.get_node("Gameplay/WestDealer") as DealerNPC

	for level in range(1, 5):
		dealer.configure_dealer(level, false)
		var weapon := dealer.get_combat_weapon()
		assert(weapon != null)
		assert(weapon.weapon_id == (&"draco" if level >= 3 else &"pistol"))
		assert(dealer.uses_automatic_fire() == (level == 2 or level == 4))
		assert(dealer.get_combat_component().get_effective_gunshot_sound() != null)
		var expected_interval := 0.42 if level == 1 else (0.26 if level == 3 else weapon.full_auto_fire_interval)
		assert(is_equal_approx(dealer.get_combat_component().get_fire_interval(), expected_interval))
		if level == 2 or level == 4:
			var ai := dealer.get_ai_component()
			assert(is_equal_approx(
				float(ai.call("get_automatic_cadence_for_test")),
				weapon.full_auto_fire_interval
			))

	dealer.configure_dealer(1, true)
	assert(dealer.get_combat_weapon().weapon_id == &"draco")
	assert(dealer.uses_automatic_fire())
	dealer.configure_dealer(1, false)

	assert(not dealer.is_hostile())
	assert(not other_dealer.is_hostile())
	assert(dealer.can_interact(player))
	var weapon := player.get_node(
		"Components/WeaponComponent"
	) as PlayerWeaponComponent
	weapon.shot_resolved.emit(dealer, false, dealer.global_position + Vector3.UP)
	await process_frame
	assert(dealer.is_hostile())
	assert(not dealer.can_interact(player))
	assert(not other_dealer.is_hostile())
	assert(other_dealer.can_interact(player))

	var saved := dealer.export_save_data()
	dealer.import_save_data(saved)
	assert(not dealer.is_hostile())
	assert(dealer.can_interact(player))

	print("DEALER_COMBAT_SMOKE_TEST_PASS")
	quit()
