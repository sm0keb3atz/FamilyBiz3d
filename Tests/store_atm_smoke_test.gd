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
	var weapon := player.get_node("Components/WeaponComponent") as PlayerWeaponComponent
	var store := player.get_node("Components/GunStoreService") as GunStoreService
	assert(wallet != null and weapon != null and store != null)
	assert(weapon.get_weapon_slots().is_empty())

	assert(wallet.add_clean(5000, false))
	var pistol := weapon.pistol_definition
	assert(store.buy_weapon(pistol))
	assert(wallet.clean_cash == 4500)
	assert(weapon.owns_weapon(&"pistol"))
	assert(not store.buy_weapon(pistol))
	assert(store.buy_attachment(pistol, &"sights"))
	assert(weapon.owns_attachment(&"pistol", &"sights"))
	assert(not weapon.is_attachment_equipped(&"pistol", &"sights"))
	assert(store.set_attachment_equipped(pistol, &"sights", true))
	assert(weapon.is_attachment_equipped(&"pistol", &"sights"))
	var reserve_before := weapon.get_reserve_ammo_for(&"pistol")
	assert(store.buy_ammo(pistol))
	assert(weapon.get_reserve_ammo_for(&"pistol") == reserve_before + 30)

	assert(wallet.add_dirty(3000, false))
	var clean_before := wallet.clean_cash
	assert(wallet.deposit_dirty_to_clean(9999, "MON JAN 1 Y1") == 2500)
	assert(wallet.clean_cash == clean_before + 2500)
	assert(wallet.get_atm_remaining_limit("MON JAN 1 Y1") == 0)
	assert(wallet.deposit_dirty_to_clean(100, "MON JAN 1 Y1") == 0)
	assert(wallet.get_atm_remaining_limit("TUE JAN 2 Y1") == 2500)
	assert(wallet.withdraw_clean_to_dirty(200) == 200)

	var wallet_save := wallet.export_save_data()
	var wallet_copy := PlayerWalletComponent.new()
	root.add_child(wallet_copy)
	wallet_copy.import_save_data(wallet_save)
	assert(wallet_copy.clean_cash == wallet.clean_cash)
	assert(wallet_copy.get_atm_remaining_limit("TUE JAN 2 Y1") == 2500)

	var weapon_save := weapon.export_save_data()
	weapon.import_save_data(weapon_save)
	assert(weapon.owns_weapon(&"pistol"))
	assert(weapon.owns_attachment(&"pistol", &"sights"))
	assert(weapon.is_attachment_equipped(&"pistol", &"sights"))

	print("STORE_ATM_SMOKE_TEST_PASS")
	quit(0)
