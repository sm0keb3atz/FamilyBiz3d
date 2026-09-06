extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world := (
		load("res://Scenes/Maps/World/world.tscn") as PackedScene
	).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var hud := player.get_node("PlayerHUD") as PlayerHUD
	var hit_marker := hud.get_node("HitMarker") as ReticleHitmarker
	assert(hit_marker != null)
	var viewport_center := root.get_visible_rect().size * 0.5
	assert(hit_marker.get_global_rect().get_center().is_equal_approx(viewport_center))
	var weapon := player.get_node("Components/WeaponComponent") as PlayerWeaponComponent
	weapon.hit_confirmed.emit(false)
	assert(hit_marker.visible)
	assert(hit_marker._remaining > 0.0)
	assert(hud.get_node("TimePanel") is PanelContainer)
	assert(hud.get_node("ReputationPanel") is PanelContainer)
	var territory_fx := hud.get_node(
		"ReputationPanel/TerritoryPanelFX"
	) as ColorRect
	assert(territory_fx.material is ShaderMaterial)
	var market_quotes := hud.find_child(
		"MarketQuoteRow", true, false
	) as HBoxContainer
	assert(market_quotes != null)
	assert(is_equal_approx(market_quotes.custom_minimum_size.y, 58.0))
	assert(hud.find_child("NegativeReputation", true, false) is ProgressBar)
	assert(hud.find_child("PositiveReputation", true, false) is ProgressBar)
	assert(hud.get_node("HeatPanel") is PanelContainer)
	assert(hud.get_node("HeatPanel/Margin/Content/WantedStars") is Label)
	assert(
		hud.get_node("HeatPanel/Margin/Content/EscapePanel")
		is PanelContainer
	)
	assert(hud.get_node("WeaponPanel") is PanelContainer)
	var money_summary := hud.find_child(
		"MoneySummary", true, false
	) as PanelContainer
	assert(money_summary != null)
	assert(is_equal_approx(money_summary.custom_minimum_size.y, 52.0))
	var money_cluster := hud.find_child(
		"MoneyPanel", true, false
	) as PanelContainer
	assert(money_cluster != null)
	assert(is_equal_approx(money_cluster.size.y, 220.0))
	assert(hud.find_child("ExperienceBar", true, false) != null)
	assert(hud.find_child("VehiclePanel", true, false) != null)
	assert(hud.find_child("FuelPumpPanel", true, false) != null)
	var frame_surface := Color(0.012, 0.019, 0.027, 0.94)
	var inset_surface := Color(0.018, 0.027, 0.037, 0.96)
	var frame_border := Color(0.21, 0.26, 0.31, 0.94)
	for panel_name in [
		"TimePanel",
		"ReputationPanel",
		"HeatPanel",
		"WeaponPanel",
		"MoneyPanel",
		"VehiclePanel",
		"FuelPumpPanel",
		"FeedbackPanel",
		"SaleInteractionPanel",
	]:
		var panel := hud.find_child(panel_name, true, false) as PanelContainer
		assert(panel != null)
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert(style.bg_color.is_equal_approx(frame_surface))
		assert(style.border_color.is_equal_approx(frame_border))
	for panel_name in ["MoneySummary", "StatsPanel", "EscapePanel"]:
		var panel := hud.find_child(panel_name, true, false) as PanelContainer
		assert(panel != null)
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert(style.bg_color.is_equal_approx(inset_surface))
		assert(style.border_color.is_equal_approx(frame_border))
	var expected_meter_heights := {
		"HealthBar": 16.0,
		"StaminaBar": 15.0,
		"ExperienceBar": 11.0,
		"ReputationBar": 26.0,
		"HeatBar": 20.0,
		"EscapeBar": 15.0,
		"ArrestBar": 15.0,
		"FuelMeter": 15.0,
		"DamageMeter": 15.0,
		"PumpFuelMeter": 17.0,
	}
	for meter_name in expected_meter_heights:
		var meter := hud.find_child(meter_name, true, false) as ProgressBar
		assert(meter != null)
		assert(is_equal_approx(
			meter.custom_minimum_size.y,
			float(expected_meter_heights[meter_name])
		))
	for effect_name in [
		"HealthBarFX",
		"StaminaBarFX",
		"ExperienceBarFX",
		"NegativeReputationFX",
		"PositiveReputationFX",
		"HeatBarFX",
		"EscapeBarFX",
		"ArrestBarFX",
		"FuelMeterFX",
		"DamageMeterFX",
		"PumpFuelMeterFX",
	]:
		var effect := hud.find_child(effect_name, true, false) as ColorRect
		assert(effect != null)
		assert(effect.material is ShaderMaterial)
	var shader_code := FileAccess.get_file_as_string(
		"res://Assets/UI/Shaders/hud_meter_fx.gdshader"
	)
	assert(not shader_code.contains("return;"))
	assert(shader_code.contains("trail_ratio"))
	assert(shader_code.contains("rising_amount"))
	var health_meter := hud.find_child("HealthBar", true, false) as ProgressBar
	var health_fx := hud.find_child("HealthBarFX", true, false) as ColorRect
	health_meter.max_value = 100.0
	health_meter.value = 100.0
	health_meter.value = 65.0
	health_fx.call("_process", 0.016)
	var health_material := health_fx.material as ShaderMaterial
	assert(float(health_material.get_shader_parameter("flash_amount")) > 0.0)
	assert(
		float(health_material.get_shader_parameter("trail_ratio"))
		> float(health_material.get_shader_parameter("fill_ratio"))
	)
	var heat_meter := hud.find_child("HeatBar", true, false) as ProgressBar
	var heat_fx := hud.find_child("HeatBarFX", true, false) as ColorRect
	heat_meter.value = 0.0
	heat_meter.value = 50.0
	heat_fx.call("_process", 0.016)
	var heat_material := heat_fx.material as ShaderMaterial
	assert(float(heat_material.get_shader_parameter("rising_amount")) > 0.0)
	hud.set_interaction_prompt("E — INTERACT")
	assert((hud.get_node("InteractionPrompt") as Label).visible)
	hud.set_interaction_prompt("", {
		"product_name": "WEED",
		"grams": 1,
		"payout": 10,
	})
	assert((hud.get_node("SaleInteractionPanel") as PanelContainer).visible)
	hud.show_feedback("SAVED", 0.1)
	var feedback := hud.get_node("FeedbackPanel") as PanelContainer
	assert(feedback.visible)
	var feedback_style := feedback.get_theme_stylebox("panel") as StyleBoxFlat
	assert(feedback_style.bg_color.is_equal_approx(frame_surface))
	assert(feedback_style.border_color.is_equal_approx(frame_border))
	print("GAMEPLAY_HUD_OVERHAUL_SMOKE_TEST_PASS")
	quit(0)
