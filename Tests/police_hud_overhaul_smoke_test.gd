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
	var hud := player.get_node("PlayerHUD") as PlayerHUD
	var heat_content := hud.get_node("HeatPanel/Margin/Content")
	var stars := hud.get_node("HeatPanel/Margin/Content/WantedStars") as Label
	var status := hud.get_node("HeatPanel/Margin/Content/PoliceStatus") as Label
	var escape := hud.get_node("HeatPanel/Margin/Content/EscapePanel") as PanelContainer
	var star_display := stars.get_node("WantedStarDisplay") as HBoxContainer
	var panel_fx := hud.get_node("HeatPanel/HeatPanelFX") as ColorRect

	assert(stars.get_parent() == heat_content)
	assert(status.get_parent() == heat_content)
	assert(escape.get_parent() == heat_content)
	assert(star_display != null)
	assert(star_display.get_child_count() == PlayerWantedComponent.MAX_WANTED_LEVEL)
	assert(panel_fx.material is ShaderMaterial)
	wanted.report_police_incident(
		player.global_position,
		PoliceIncident.CrimeType.OFFICER_DOWN,
		6
	)
	wanted.set_wanted_level(6)
	assert(stars.visible)
	assert(stars.text.length() == 6)
	assert(status.visible)
	assert(star_display.call("get_level") == 6)
	for index in PlayerWantedComponent.MAX_WANTED_LEVEL:
		var star_material := star_display.call("get_star_material", index) as ShaderMaterial
		assert(star_material != null)
		assert(is_equal_approx(
			float(star_material.get_shader_parameter("filled")),
			1.0
		))

	print("POLICE_HUD_OVERHAUL_SMOKE_TEST_PASS")
	quit(0)
