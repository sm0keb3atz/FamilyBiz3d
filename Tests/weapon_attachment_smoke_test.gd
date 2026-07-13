extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	assert(player_scene != null)
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	await physics_frame

	var weapon := player.get_node(
		"Components/WeaponComponent"
	) as PlayerWeaponComponent
	assert(weapon != null)
	assert(weapon.get_weapon_slots().is_empty())
	assert(weapon.grant_weapon(weapon.pistol_definition))
	assert(weapon.grant_weapon(weapon.draco_definition))
	assert(weapon.get_weapon_slots().size() == 2)
	assert(weapon.equip_slot(1))
	assert(weapon.get_magazine_capacity() == 15)
	var pistol_definition := weapon.get_equipped_weapon()

	var presentation := player.get_node(
		"Visual/PlayerTest2/Armature/GeneralSkeleton/WeaponSocket/EquippedWeapon"
	) as WeaponPresentation
	assert(presentation != null)
	assert(presentation.find_child("PistolModel", true, false) != null)
	assert(not presentation.is_attachment_visible(&"sights"))

	assert(not weapon.set_sights_enabled(true))
	assert(weapon.unlock_attachment(&"pistol", &"sights"))
	assert(weapon.unlock_attachment(&"pistol", &"laser"))
	assert(weapon.unlock_attachment(&"pistol", &"switch"))
	assert(weapon.unlock_attachment(&"pistol", &"extended"))
	assert(weapon.unlock_attachment(&"pistol", &"drum"))
	weapon.set_sights_enabled(true)
	assert(weapon.get_aim_distance_override() == 0.75)
	assert(presentation.is_attachment_visible(&"sights"))
	weapon.set_laser_enabled(true)
	assert(weapon.is_target_lock_enabled())
	assert(presentation.is_attachment_visible(&"laser"))
	weapon.set_switch_enabled(true)
	assert(weapon.is_fully_automatic())
	assert(presentation.is_attachment_visible(&"switch"))

	weapon.set_magazine_type(PlayerWeaponComponent.MagazineType.EXTENDED)
	assert(weapon.get_magazine_capacity() == 30)
	assert(presentation.is_attachment_visible(&"extended"))
	weapon.set_magazine_type(PlayerWeaponComponent.MagazineType.DRUM)
	assert(weapon.get_magazine_capacity() == 75)
	assert(presentation.is_attachment_visible(&"drum"))
	assert(not presentation.is_attachment_visible(&"extended"))

	weapon._magazine_ammo[&"pistol"] = 75
	var reserve_before := weapon.get_reserve_ammo()
	weapon.set_magazine_type(PlayerWeaponComponent.MagazineType.STANDARD)
	assert(weapon.get_magazine_ammo() == 15)
	assert(weapon.get_reserve_ammo() == reserve_before + 60)
	weapon.add_reserve_ammo(30)
	assert(weapon.get_reserve_ammo() == reserve_before + 90)

	assert(weapon.equip_slot(2))
	assert(weapon.get_equipped_weapon().weapon_id == &"draco")
	for attachment_id in PlayerWeaponComponent.STORE_ATTACHMENT_IDS:
		assert(weapon.unlock_attachment(&"draco", attachment_id))
	assert(weapon.get_magazine_capacity() == 32)
	assert(weapon.get_equipped_weapon().gunshot_sound != pistol_definition.gunshot_sound)
	presentation = player.get_node(
		"Visual/PlayerTest2/Armature/GeneralSkeleton/WeaponSocket/EquippedWeapon"
	) as WeaponPresentation
	assert(presentation != null)
	assert(presentation.find_child("DracoModel", true, false) != null)
	assert(presentation.is_attachment_visible(&"standard"))
	assert(not presentation.is_attachment_visible(&"extended"))
	assert(not presentation.is_attachment_visible(&"drum"))
	weapon.set_switch_enabled(false)
	assert(not weapon.is_fully_automatic())
	weapon.set_switch_enabled(true)
	assert(weapon.is_fully_automatic())
	weapon.set_magazine_type(PlayerWeaponComponent.MagazineType.EXTENDED)
	assert(weapon.get_magazine_capacity() == 50)
	assert(not presentation.is_attachment_visible(&"standard"))
	assert(presentation.is_attachment_visible(&"extended"))
	assert(not presentation.is_attachment_visible(&"drum"))
	weapon.set_magazine_type(PlayerWeaponComponent.MagazineType.DRUM)
	assert(weapon.get_magazine_capacity() == 100)
	assert(not presentation.is_attachment_visible(&"standard"))
	assert(not presentation.is_attachment_visible(&"extended"))
	assert(presentation.is_attachment_visible(&"drum"))
	assert(weapon.equip_slot(0))
	assert(weapon.get_equipped_weapon() == null)

	var target_lock := player.get_node(
		"Components/TargetLockComponent"
	) as PlayerTargetLockComponent
	assert(target_lock != null)
	weapon.set_laser_enabled(false)
	assert(not weapon.is_target_lock_enabled())

	var saved := weapon.export_save_data()
	weapon.import_save_data(saved)
	assert(weapon.owns_weapon(&"pistol"))
	assert(weapon.owns_weapon(&"draco"))
	assert(weapon.owns_attachment(&"pistol", &"sights"))

	print("WEAPON_ATTACHMENT_SMOKE_TEST_PASS")
	quit(0)
