extends SceneTree


const HIPS_PATH := NodePath("%GeneralSkeleton:Hips")
const CHEST_PATH := NodePath("%GeneralSkeleton:Chest")
const LEFT_UP_LEG_PATH := NodePath("%GeneralSkeleton:LeftUpperLeg")


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
	var animation_component := player.get_node(
		"Components/AnimationComponent"
	) as PlayerAnimationComponent
	assert(weapon != null)
	assert(animation_component != null)
	assert(weapon.grant_weapon(weapon.draco_definition))
	assert(weapon.equip_slot(1))

	var locomotion_tree := animation_component._get_locomotion_tree()
	assert(locomotion_tree != null)
	var carry_blend := locomotion_tree.get_node(
		&"CarryBlend"
	) as AnimationNodeBlend2
	assert(carry_blend != null)
	assert(carry_blend.filter_enabled)
	assert(carry_blend.is_path_filtered(CHEST_PATH))
	assert(not carry_blend.is_path_filtered(HIPS_PATH))
	assert(not carry_blend.is_path_filtered(LEFT_UP_LEG_PATH))

	Input.action_press(&"crouch")
	for frame in 12:
		await physics_frame
		await process_frame
	Input.action_release(&"crouch")

	assert(animation_component._is_crouching)
	assert(animation_component._current_crouch_blend > 0.9)
	assert(animation_component._current_carry_blend > 0.9)

	print("DRACO_CROUCH_SMOKE_TEST_PASS")
	quit(0)
