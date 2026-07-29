extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_case_math()
	var world_scene := load("res://Scenes/Maps/World/world.tscn") as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var legal := player.get_node("Components/LegalComponent") as PlayerLegalComponent
	var inventory := player.get_node("Components/InventoryComponent") as PlayerInventoryComponent
	var weapon := player.get_node("Components/WeaponComponent") as PlayerWeaponComponent
	var wallet := player.get_node("Components/WalletComponent") as PlayerWalletComponent
	var wanted := player.get_node("Components/WantedComponent") as PlayerWantedComponent
	var world_time := world.get_node("WorldTimeComponent") as WorldTimeComponent
	assert(legal != null)
	assert(get_nodes_in_group(&"lawyer_npc").size() == 4)

	wallet.import_save_data({"dirty_cash": 200000, "clean_cash": 200000})
	inventory.add_product(EconomyCatalog.WEED_BRICK, 1)
	inventory.add_product(EconomyCatalog.COKE_1G, 10)
	inventory.add_product(EconomyCatalog.FENT_1G, 5)
	weapon.grant_weapon(weapon.pistol_definition)
	weapon.import_save_data({
		"owned_weapon_ids": ["pistol"],
		"attachment_unlocks": {
			"pistol": {"switch": true, "extended": true},
		},
		"attachment_states": {
			"pistol": {"switch": true, "magazine_type": PlayerWeaponComponent.MagazineType.EXTENDED},
		},
	})
	wanted.report_police_incident(
		player.global_position,
		PoliceIncident.CrimeType.WEAPON_DISCHARGE,
		2
	)
	var snapshot := legal.build_evidence_snapshot()
	assert(_sum_points(snapshot) == 735)
	var before_booking := world_time.get_absolute_minute()
	var legal_case := legal.begin_police_custody()
	assert(legal_case != null)
	assert(legal_case.get_total_points() == 735)
	assert(inventory.get_quantity(EconomyCatalog.WEED_BRICK) == 0)
	assert(not weapon.owns_weapon(&"pistol"))
	assert(wallet.dirty_cash == 180000)
	assert(wallet.clean_cash == 180000)
	assert(
		world_time.get_absolute_minute()
		== before_booking + 3 * WorldTimeComponent.MINUTES_PER_DAY
	)
	assert(
		legal_case.hearing_absolute_minute
		== (
			(before_booking / WorldTimeComponent.MINUTES_PER_DAY + 6)
			* WorldTimeComponent.MINUTES_PER_DAY + 600
		)
	)

	assert(legal.hire_lawyer(&"lawyer_level_4"))
	assert(legal.assign_lawyer(legal_case.case_id, &"lawyer_level_4"))
	assert(legal.get_defense_range(legal_case) == Vector2i(900, 1500))
	var chance := legal.get_win_chance(legal_case)
	assert(is_equal_approx(chance, 1.0))
	var saved := legal.export_save_data()
	var seed := legal_case.defense_seed
	var first_result := legal.adjudicate_case(legal_case.case_id)
	legal.import_save_data(saved)
	var loaded_case := legal.get_case(legal_case.case_id)
	assert(loaded_case.defense_seed == seed)
	var second_result := legal.adjudicate_case(loaded_case.case_id)
	assert(first_result.roll == second_result.roll)

	print("LEGAL_SYSTEM_SMOKE_TEST_PASS")
	quit(0)


func _test_case_math() -> void:
	var legal_case := LegalCase.new()
	var charge := LegalCharge.new()
	charge.unit_points = 100
	charge.count = 12
	legal_case.charges = [charge]
	assert(legal_case.get_total_points() == 1200)
	var possible := 1500 - 900 + 1
	var winning := 1500 - 1200
	assert(is_equal_approx(float(winning) / float(possible), 300.0 / 601.0))
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 8086
	rng_b.seed = 8086
	assert(rng_a.randi_range(900, 1500) == rng_b.randi_range(900, 1500))
	assert(not (1200 > 1200))


func _sum_points(charges: Array[LegalCharge]) -> int:
	var total := 0
	for charge in charges:
		total += charge.get_total_points()
	return total
