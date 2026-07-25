class_name WorldEventBus
extends Node

signal event_published(event: WorldEvent)
signal crime_report_submitted(report: CrimeReport)
signal trace_recorded(record: Dictionary)

@export_range(16, 2048, 1) var trace_capacity := 256

var _next_event_id := 1
var _trace_buffer: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(&"world_event_bus")


static func find(tree: SceneTree) -> WorldEventBus:
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"world_event_bus") as WorldEventBus


func publish_event(event: WorldEvent) -> WorldEvent:
	if event == null:
		return null
	if event.event_id <= 0:
		event.event_id = _next_event_id
		_next_event_id += 1
	event.created_at_seconds = Time.get_ticks_msec() * 0.001
	if is_instance_valid(event.source_actor):
		event.source_actor_id = event.source_actor.get_instance_id()
	if event.territory_id == &"":
		var boundary := TerritoryBoundary.find_at_position(get_tree(), event.world_position)
		if boundary != null:
			event.territory_id = boundary.territory_id
	_record_trace(&"world_event", {
		"event_id": event.event_id,
		"event_type": event.event_type,
		"position": event.world_position,
		"source_actor_id": event.source_actor_id,
		"territory_id": String(event.territory_id),
	})
	event_published.emit(event)
	get_tree().call_group(&"world_event_listener", &"handle_world_event", event)
	return event


func publish_gunshot(source_actor: Node, world_position: Vector3, audible_radius: float, source_faction: StringName = &"unknown") -> WorldEvent:
	var event := WorldEvent.new()
	event.event_type = WorldEvent.Type.GUNSHOT
	event.source_actor = source_actor
	event.world_position = world_position
	event.audible_radius = maxf(audible_radius, 0.0)
	event.source_faction = source_faction
	event.severity = 2
	return publish_event(event)


func publish_spatial_event(
	event_type: WorldEvent.Type,
	source_actor: Node,
	world_position: Vector3,
	reaction_radius: float,
	severity: int = 1,
	source_faction: StringName = &"unknown",
	metadata := {}
) -> WorldEvent:
	var event := WorldEvent.new()
	event.event_type = event_type
	event.source_actor = source_actor
	event.world_position = world_position
	event.audible_radius = maxf(reaction_radius, 0.0)
	event.source_faction = source_faction
	event.severity = maxi(severity, 1)
	event.metadata = metadata.duplicate(true)
	return publish_event(event)


func submit_crime_report(report: CrimeReport) -> void:
	if report == null or report.interrupted:
		return
	report.completed = true
	if is_instance_valid(report.reporter):
		report.reporter_id = report.reporter.get_instance_id()
	if is_instance_valid(report.suspect):
		report.suspect_id = report.suspect.get_instance_id()
	_record_trace(&"crime_report", {
		"event_id": report.event_id,
		"reporter_id": report.reporter_id,
		"suspect_id": report.suspect_id,
		"confidence": report.confidence,
		"severity": report.severity,
	})
	crime_report_submitted.emit(report)


func record_state_transition(category: StringName, actor: Node, previous_state: Variant, next_state: Variant, reason: StringName, context := {}) -> void:
	var record := context.duplicate(true)
	record["actor_id"] = actor.get_instance_id() if is_instance_valid(actor) else 0
	record["previous_state"] = previous_state
	record["next_state"] = next_state
	record["reason"] = String(reason)
	_record_trace(category, record)


func get_trace_snapshot() -> Array[Dictionary]:
	return _trace_buffer.duplicate(true)


func clear_trace() -> void:
	_trace_buffer.clear()


func _record_trace(category: StringName, fields: Dictionary) -> void:
	var record := fields.duplicate(true)
	record["timestamp_seconds"] = Time.get_ticks_msec() * 0.001
	record["category"] = String(category)
	_trace_buffer.append(record)
	while _trace_buffer.size() > trace_capacity:
		_trace_buffer.pop_front()
	trace_recorded.emit(record)
