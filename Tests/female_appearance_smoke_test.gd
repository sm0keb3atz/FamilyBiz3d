extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var visual_scene := load(
		"res://Scenes/PlayerVisualModular.tscn"
	) as PackedScene
	assert(visual_scene != null)
	var visual := visual_scene.instantiate() as Node3D
	assert(visual != null)
	root.add_child(visual)

	var appearance := PlayerAppearanceComponent.new()
	appearance.skeleton_path = NodePath(
		"../Armature/GeneralSkeleton"
	)
	visual.add_child(appearance)
	await process_frame

	var skeleton := visual.get_node(
		"Armature/GeneralSkeleton"
	) as Skeleton3D
	assert(skeleton != null)
	for mesh_name in PlayerAppearanceComponent.FEMALE_BODY_MESHES:
		assert(skeleton.get_node(NodePath(str(mesh_name))) is MeshInstance3D)

	appearance.set_body_variant(
		PlayerAppearanceComponent.BODY_VARIANT_FEMALE
	)
	assert(appearance.get_body_variant() == &"female")
	assert(not (skeleton.get_node("BODY_Head") as MeshInstance3D).visible)
	assert(
		(skeleton.get_node("BODY_Female_Head") as MeshInstance3D).visible
	)
	assert(
		(skeleton.get_node("TOP_Female_01_HoodieCrop") as MeshInstance3D).visible
	)
	assert(
		(skeleton.get_node("BOTTOM_Female_01_Leggins") as MeshInstance3D).visible
	)
	assert(
		(skeleton.get_node("SHOES_Female_01_FemaleSneakers") as MeshInstance3D).visible
	)

	appearance.set_body_variant(PlayerAppearanceComponent.BODY_VARIANT_MALE)
	assert((skeleton.get_node("BODY_Head") as MeshInstance3D).visible)
	assert(
		not (skeleton.get_node("BODY_Female_Head") as MeshInstance3D).visible
	)
	assert(
		not (skeleton.get_node("TOP_Female_01_HoodieCrop") as MeshInstance3D).visible
	)

	var random := RandomNumberGenerator.new()
	random.seed = 77123
	appearance.randomize_civilian_appearance(random)
	var first_variant := appearance.get_body_variant()
	var first_top := appearance.get_option_name(
		PlayerAppearanceComponent.SLOT_TOP
	)
	random.seed = 77123
	appearance.randomize_civilian_appearance(random)
	assert(appearance.get_body_variant() == first_variant)
	assert(
		appearance.get_option_name(PlayerAppearanceComponent.SLOT_TOP)
		== first_top
	)
	assert(not first_top.contains("Police"))
	appearance.set_body_variant(
		PlayerAppearanceComponent.BODY_VARIANT_FEMALE
	)
	random.seed = 44812
	appearance.randomize_appearance(&"civilian", random)
	for mesh_name in PlayerAppearanceComponent.FEMALE_CLOTHING_MESHES:
		var garment := skeleton.get_node(
			NodePath(str(mesh_name))
		) as MeshInstance3D
		assert(garment.material_override is BaseMaterial3D)
		assert(
			(garment.material_override as BaseMaterial3D).albedo_color
			!= Color.WHITE
		)

	var npc_scene := load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	var police_scene := load("res://Scenes/NPC/PoliceNPC.tscn") as PackedScene
	var female_npc := npc_scene.instantiate() as CustomerNPC
	var male_npc := npc_scene.instantiate() as CustomerNPC
	var police_npc := police_scene.instantiate() as PoliceNPC
	root.add_child(female_npc)
	root.add_child(male_npc)
	root.add_child(police_npc)
	await process_frame
	assert(female_npc.animation_player.has_animation(&"FemaleWalk"))
	var regular_walk := male_npc.animation_player.get_animation(&"Walk")
	female_npc.appearance_component.set_body_variant(
		PlayerAppearanceComponent.BODY_VARIANT_FEMALE
	)
	assert(female_npc.animation_player.get_animation(&"FemaleWalk").get_track_count() > 30)
	assert(male_npc.animation_player.get_animation(&"Walk") == regular_walk)
	assert(female_npc.animation_component.get_walk_variant() == &"FemaleWalk")
	assert(male_npc.animation_component.get_walk_variant() == &"Walk")
	assert(female_npc.animation_component.get_locomotion_walk_animation() == &"FemaleWalk")
	assert(male_npc.animation_component.get_locomotion_walk_animation() == &"Walk")
	assert(female_npc.animation_tree.tree_root != male_npc.animation_tree.tree_root)
	assert(police_npc.animation_component.get_locomotion_walk_animation() == &"Walk")
	assert(female_npc.animation_component.set_walk_variant(&"TextingWalking1"))
	assert(
		female_npc.animation_component.get_locomotion_walk_animation()
		== &"TextingWalking1"
	)
	assert(police_npc.animation_component.get_locomotion_walk_animation() == &"Walk")
	female_npc.appearance_component.set_body_variant(
		PlayerAppearanceComponent.BODY_VARIANT_MALE
	)
	assert(female_npc.animation_component.get_locomotion_walk_animation() == &"Walk")
	assert(male_npc.animation_player.get_animation(&"Walk") == regular_walk)
	female_npc.appearance_component.set_body_variant(
		PlayerAppearanceComponent.BODY_VARIANT_FEMALE
	)
	assert(female_npc.animation_component.get_walk_variant() == &"FemaleWalk")
	assert(female_npc.animation_component.get_locomotion_walk_animation() == &"FemaleWalk")
	assert(male_npc.animation_component.get_locomotion_walk_animation() == &"Walk")
	female_npc.queue_free()
	male_npc.queue_free()
	police_npc.queue_free()
	visual.queue_free()
	await process_frame

	print("FEMALE_APPEARANCE_SMOKE_TEST_PASS")
	quit(0)
