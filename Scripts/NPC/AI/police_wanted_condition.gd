@tool
class_name PoliceWantedCondition
extends BTCondition

@export_range(0, 6, 1) var minimum_level := 0
@export_range(0, 6, 1) var maximum_level := 6
@export var require_force_authorized := false
@export var require_force_not_authorized := false


func _generate_name() -> String:
	return "Wanted level %d..%d" % [minimum_level, maximum_level]


func _tick(_delta: float) -> Status:
	if agent == null or not agent.has_method("get_wanted_level"):
		return FAILURE
	var level: int = int(agent.call("get_wanted_level"))
	if level < minimum_level or level > maximum_level:
		return FAILURE
	var force_authorized := (
		bool(agent.call("is_force_authorized"))
		if agent.has_method("is_force_authorized") else level >= 3
	)
	if require_force_authorized and not force_authorized:
		return FAILURE
	if require_force_not_authorized and force_authorized:
		return FAILURE
	if (
		agent.has_method("is_response_assigned")
		and not bool(agent.call("is_response_assigned"))
	):
		return (
			SUCCESS
			if (
				agent.has_method("can_see_wanted_player")
				and bool(agent.call("can_see_wanted_player"))
			) or (
				agent.has_method("has_confirmed_wanted_player_location")
				and bool(agent.call("has_confirmed_wanted_player_location"))
			)
			else FAILURE
		)
	return (
		SUCCESS
	)
