extends SceneTree

const StreetLightScene := preload("res://Scenes/Maps/RoadPieces/street_light.tscn")
const TimeComponentScript := preload("res://Scripts/Gameplay/world_time_component.gd")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var street_light := StreetLightScene.instantiate()
	root.add_child(street_light)

	var world_time: WorldTimeComponent = TimeComponentScript.new()
	root.add_child(world_time)
	await process_frame

	var night_lighting := street_light.get_node("NightLighting") as Node3D
	var light := street_light.get_node("NightLighting/KeyLight") as SpotLight3D
	assert(light != null)
	assert(not night_lighting.visible)

	assert(world_time.set_time_of_day(19, 29))
	assert(not night_lighting.visible)
	assert(world_time.set_time_of_day(19, 30))
	assert(night_lighting.visible)
	assert(world_time.set_time_of_day(5, 59))
	assert(night_lighting.visible)
	assert(world_time.set_time_of_day(6, 0))
	assert(not night_lighting.visible)

	print("STREET_LIGHT_SMOKE_TEST_PASS")
	quit(0)
