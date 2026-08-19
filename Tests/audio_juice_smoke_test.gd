extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	var customer_scene := load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	var police_scene := load("res://Scenes/NPC/PoliceNPC.tscn") as PackedScene
	assert(player_scene != null)
	assert(customer_scene != null)
	assert(police_scene != null)

	var player := player_scene.instantiate() as CharacterBody3D
	var customer := customer_scene.instantiate() as CustomerNPC
	var police := police_scene.instantiate() as PoliceNPC
	root.add_child(player)
	root.add_child(customer)
	root.add_child(police)
	await process_frame

	assert(customer.audio_component is NPCAudioComponent)
	assert(customer.audio_component.get_node("FootstepPlayer") is AudioStreamPlayer3D)
	assert(customer.audio_component.get_node("VoicePlayer") is AudioStreamPlayer3D)
	assert(customer.audio_component.walk_volume_db <= -24.0)
	assert(customer.audio_component.footstep_max_distance <= 12.0)
	assert(NPCAudioComponent.CROWD_FOOTSTEP_LIMIT <= 3)
	var npc_footsteps: Array[AudioStream] = customer.audio_component.get(
		"_footstep_streams"
	)
	var player_footsteps := player.get_node(
		"Components/SoundComponent"
	) as PlayerSoundComponent
	assert(npc_footsteps == player_footsteps.footstep_sounds)

	customer.audio_component.play_customer_solicitation(false)
	await create_timer(
		float(NPCAudioComponent.CUSTOMER_RESPONSE_DELAY_MS + 100) * 0.001
	).timeout
	var customer_voice := customer.audio_component.get_node(
		"VoicePlayer"
	) as AudioStreamPlayer3D
	assert(customer_voice.stream != null)
	assert("Male Customer" in customer_voice.stream.resource_path)
	assert(
		is_equal_approx(
			customer_voice.position.y,
			customer.audio_component.voice_emitter_height
		)
	)
	assert(
		is_equal_approx(
			customer_voice.unit_size,
			customer.audio_component.customer_voice_unit_size
		)
	)
	assert(
		is_equal_approx(
			customer_voice.max_distance,
			customer.audio_component.customer_voice_max_distance
		)
	)
	assert(customer_voice.panning_strength > 1.0)
	assert(customer_voice.attenuation_filter_cutoff_hz < 5000.0)
	customer.audio_component.play_panic(true)
	assert("FemaleCustomer/panic" in customer_voice.stream.resource_path)
	assert(
		is_equal_approx(
			customer_voice.unit_size,
			customer.audio_component.voice_unit_size
		)
	)
	assert(
		is_equal_approx(
			customer_voice.max_distance,
			customer.audio_component.voice_max_distance
		)
	)

	police.visible = true
	police.process_mode = Node.PROCESS_MODE_INHERIT
	police.add_to_group(&"police_npc")
	police.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)
	police.audio_component.play_police_aggro()
	var police_voice := police.audio_component.get_node(
		"VoicePlayer"
	) as AudioStreamPlayer3D
	assert(police_voice.stream != null)
	assert("NPCs/Police" in police_voice.stream.resource_path)
	police.audio_component.call("_update_police_radio")
	var radio := police.audio_component.get_node(
		"RadioPlayer"
	) as AudioStreamPlayer3D
	assert(radio.stream is AudioStreamMP3)
	assert((radio.stream as AudioStreamMP3).loop)
	assert(radio.playing)

	var menu_controller := player.get_node(
		"Components/MenuController"
	) as PlayerMenuController
	assert(menu_controller.get_node("UIClickPlayer") is AudioStreamPlayer)
	assert(menu_controller.get_node("MenuTogglePlayer") is AudioStreamPlayer)
	var test_button := Button.new()
	root.add_child(test_button)
	await process_frame
	test_button.pressed.emit()
	assert(
		(menu_controller.get_node("UIClickPlayer") as AudioStreamPlayer).playing
	)
	assert(menu_controller.request_open(&"audio_smoke"))
	assert(
		(menu_controller.get_node("MenuTogglePlayer") as AudioStreamPlayer).playing
	)
	assert(menu_controller.close(&"audio_smoke"))

	var solicitation := player.get_node(
		"Components/SolicitationComponent"
	) as PlayerSolicitationComponent
	solicitation.call("_play_solicitation_voice")
	var solicitation_voice := player.get_node(
		"SolicitationVoicePlayer"
	) as AudioStreamPlayer3D
	assert(solicitation_voice != null)
	assert(solicitation_voice.stream != null)
	assert("solicitation" in solicitation_voice.stream.resource_path)

	print("AUDIO_JUICE_SMOKE_TEST_PASS")
	quit()
