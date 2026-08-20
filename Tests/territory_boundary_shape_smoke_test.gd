extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var territory_root := Node3D.new()
	var hood_east := _make_boundary(
		territory_root,
		&"hood_east",
		Vector3(57.95, 0.0, 0.0),
		Vector3(133.9, 20.0, 253.0)
	)
	var downtown_east := _make_boundary(
		territory_root,
		&"downtown_east",
		Vector3(201.45, 0.0, 0.0),
		Vector3(153.1, 20.0, 253.0)
	)
	root.add_child(territory_root)
	await process_frame

	var hood_side_of_avenue := Vector3(124.5, 0.0, 0.0)
	var downtown_side_of_avenue := Vector3(126.0, 0.0, 0.0)
	assert(hood_east.contains_world_position(hood_side_of_avenue))
	assert(not hood_east.contains_world_position(downtown_side_of_avenue))
	assert(downtown_east.contains_world_position(downtown_side_of_avenue))
	assert(
		TerritoryBoundary.find_at_position(self, downtown_side_of_avenue)
		== downtown_east
	)

	print("TERRITORY_BOUNDARY_SHAPE_SMOKE_TEST_PASS")
	territory_root.queue_free()
	await process_frame
	quit(0)


func _make_boundary(
	parent: Node3D,
	id: StringName,
	shape_center: Vector3,
	shape_size: Vector3
) -> TerritoryBoundary:
	var territory := Node3D.new()
	parent.add_child(territory)

	var stats := TerritoryStatsComponent.new()
	stats.name = "TerritoryStats"
	territory.add_child(stats)

	var boundary := TerritoryBoundary.new()
	boundary.name = "TerritoryBoundary"
	boundary.territory_id = id
	# These intentionally overlap the avenue. The collision box must override
	# them, proving that reshaping the scene boundary drives gameplay lookup.
	boundary.local_center = Vector3(64.0, 0.0, 0.0)
	boundary.local_half_extents = Vector3(73.0, 10.0, 126.5)
	territory.add_child(boundary)

	var collision_shape := CollisionShape3D.new()
	collision_shape.position = shape_center
	var box := BoxShape3D.new()
	box.size = shape_size
	collision_shape.shape = box
	boundary.add_child(collision_shape)
	return boundary
