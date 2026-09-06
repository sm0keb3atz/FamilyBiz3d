extends SceneTree

const SCREENSHOT_PATH := "res://.runtime_appdata/depth_of_field_focus.png"

var _shot_event_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	assert(player_scene != null)
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	await physics_frame

	var camera := player.get_node(
		"CameraPivot/SpringArm3D/Camera3D"
	) as Camera3D
	var camera_component := player.get_node(
		"Components/CameraComponent"
	) as PlayerCameraComponent
	var weapon := player.get_node(
		"Components/WeaponComponent"
	) as PlayerWeaponComponent
	var target_lock := player.get_node(
		"Components/TargetLockComponent"
	) as PlayerTargetLockComponent
	assert(camera != null)
	assert(camera_component != null)
	assert(weapon != null)
	assert(target_lock != null)
	target_lock.set_process(false)
	weapon.shot_resolved.connect(_on_shot_resolved)
	assert(weapon.pistol_definition != null)
	assert(weapon.grant_weapon(weapon.pistol_definition))
	assert(weapon.equip_slot(1))

	var screen_center := camera.get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_direction := camera.project_ray_normal(screen_center)
	var center_target := _make_collision_box(
		ray_origin + ray_direction * 12.0,
		Vector3(3.0, 3.0, 1.0)
	)
	await physics_frame

	var center_prediction := weapon.get_predicted_aim_position()
	var center_distance := ray_origin.distance_to(center_prediction)
	assert(absf(center_distance - 11.5) < 0.75)
	assert(_shot_event_count == 0)

	var lock_point := (
		ray_origin
		+ ray_direction * 18.0
		+ camera.global_basis.x.normalized() * 3.0
	)
	var lock_anchor := Node3D.new()
	lock_anchor.position = lock_point - Vector3.UP * target_lock.lock_point_height
	root.add_child(lock_anchor)
	var lock_collider := _make_collision_box(
		lock_point,
		Vector3(2.0, 2.0, 2.0)
	)
	target_lock.call("_set_locked_target", lock_anchor)
	weapon.set("_laser_enabled", true)
	await physics_frame

	var center_before_lock := weapon.get_predicted_aim_position()
	assert(center_before_lock.distance_to(center_prediction) < 0.1)
	center_target.collision_layer = 0
	await physics_frame
	var assisted_prediction := weapon.get_predicted_aim_position()
	assert(assisted_prediction.distance_to(lock_point) < 2.0)
	assert(_shot_event_count == 0)

	target_lock.clear_lock()
	lock_collider.collision_layer = 0
	await physics_frame
	var empty_prediction := weapon.get_predicted_aim_position(30.0, false)
	assert(absf(ray_origin.distance_to(empty_prediction) - 30.0) < 0.1)
	assert(_shot_event_count == 0)

	center_target.position = ray_origin + ray_direction * 18.0
	center_target.collision_layer = 1
	await physics_frame
	camera_component.set("_dof_focus_distance", 35.0)
	camera_component.set("_dof_target_focus_distance", 35.0)
	camera_component.set("_dof_aim_blend", 0.0)
	camera_component._update_aim_depth_of_field(1.0, true)
	var attributes := camera.attributes as CameraAttributesPractical
	assert(attributes.auto_exposure_enabled)
	assert(is_equal_approx(attributes.auto_exposure_min_sensitivity, 80.0))
	assert(is_equal_approx(attributes.auto_exposure_max_sensitivity, 220.0))
	assert(is_equal_approx(attributes.auto_exposure_speed, 0.65))
	assert(is_equal_approx(attributes.auto_exposure_scale, 0.45))
	var predicted_focus := ray_origin.distance_to(
		weapon.get_predicted_aim_position()
	)
	assert(absf(
		float(camera_component.get("_dof_target_focus_distance"))
		- predicted_focus
	) < 0.25)
	assert(absf(
		float(camera_component.get("_dof_focus_distance"))
		- predicted_focus
	) < 0.5)
	assert(attributes.dof_blur_far_enabled)
	assert(attributes.dof_blur_near_enabled)
	assert(absf(
		attributes.dof_blur_amount - camera_component.aim_dof_blur_amount
	) < 0.001)
	assert(attributes.dof_blur_far_distance > predicted_focus)
	assert(attributes.dof_blur_far_distance - predicted_focus < 3.25)
	assert(attributes.dof_blur_far_transition <= 12.1)
	assert(attributes.dof_blur_near_distance <= 0.36)

	center_target.position = ray_origin + ray_direction * 45.0
	await physics_frame
	camera_component.set("_dof_sample_remaining", 0.0)
	var ambient_focus_before := float(
		camera_component.get("_dof_focus_distance")
	)
	camera_component._update_aim_depth_of_field(0.1, false)
	var ambient_focus_after := float(
		camera_component.get("_dof_focus_distance")
	)
	var ambient_target := float(
		camera_component.get("_dof_target_focus_distance")
	)
	assert(ambient_target > ambient_focus_before + 20.0)
	assert(ambient_focus_after > ambient_focus_before)
	assert(ambient_focus_after - ambient_focus_before < 5.0)
	camera_component._update_aim_depth_of_field(3.0, false)
	assert(not attributes.dof_blur_near_enabled)
	assert(absf(
		attributes.dof_blur_amount - camera_component.default_dof_blur_amount
	) < 0.0005)
	assert(attributes.dof_blur_far_transition > 19.0)

	camera_component.default_depth_of_field_enabled = false
	camera_component.aim_depth_of_field_enabled = false
	camera_component._update_aim_depth_of_field(3.0, false)
	assert(not attributes.dof_blur_far_enabled)
	assert(not attributes.dof_blur_near_enabled)
	assert(is_zero_approx(attributes.dof_blur_amount))

	camera_component.default_depth_of_field_enabled = true
	camera_component.aim_depth_of_field_enabled = true
	camera_component._update_aim_depth_of_field(2.0, true)
	for _frame in 12:
		await process_frame
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(SCREENSHOT_PATH) == OK)
	print("DEPTH_OF_FIELD_FOCUS_SMOKE_TEST_PASS")
	quit(0)


func _make_collision_box(
	world_position: Vector3,
	size: Vector3
) -> StaticBody3D:
	var collision_body := StaticBody3D.new()
	collision_body.position = world_position
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0
	var collision_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision_shape.shape = box
	collision_body.add_child(collision_shape)
	root.add_child(collision_body)
	return collision_body


func _on_shot_resolved(
	_target: Node,
	_fatal: bool,
	_hit_position: Vector3
) -> void:
	_shot_event_count += 1
