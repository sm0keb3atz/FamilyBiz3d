extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world := (load("res://Scenes/Maps/World/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var wanted := player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	var dispatch := world.get_node(
		"PoliceDispatchController"
	) as PoliceDispatchController
	var profile := dispatch.response_profile
	assert(profile.officer_targets == PackedInt32Array([0, 2, 3, 4, 6, 8, 10]))
	assert(profile.cruiser_limits == PackedInt32Array([0, 1, 1, 2, 3, 4, 5]))

	var expected_roles := {
		4: [&"lead", &"cutoff", &"containment_a"],
		5: [&"lead", &"trailing", &"cutoff", &"containment_a"],
		6: [&"lead", &"trailing", &"cutoff", &"containment_a", &"containment_b"],
	}
	var responses := dispatch.get("_responses") as Array
	for level in expected_roles:
		responses.clear()
		wanted.set_wanted_level(level)
		for expected_role in expected_roles[level]:
			assert(dispatch.call("_choose_response_role") == expected_role)
			var response := PoliceDispatchController.ResponseUnit.new()
			response.state = PoliceDispatchController.ResponseUnit.State.EN_ROUTE
			responses.append(response)

	print("POLICE_DISPATCH_PROFILE_SMOKE_TEST_PASS")
	quit(0)
