class_name PoliceDispatchZone
extends Resource

@export var territory_id: StringName
@export var traffic_network_path: NodePath
@export var population_manager_path: NodePath


func is_configured() -> bool:
	return (
		territory_id != &""
		and not traffic_network_path.is_empty()
		and not population_manager_path.is_empty()
	)
