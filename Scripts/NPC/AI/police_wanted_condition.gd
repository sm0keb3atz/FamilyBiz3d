@tool
class_name PoliceWantedCondition
extends BTCondition

@export_range(0, 3, 1) var minimum_level := 0
@export_range(0, 3, 1) var maximum_level := 3


func _generate_name() -> String:
	return "Wanted level %d..%d" % [minimum_level, maximum_level]


func _tick(_delta: float) -> Status:
	if agent == null or not agent.has_method("get_wanted_level"):
		return FAILURE
	var level: int = int(agent.call("get_wanted_level"))
	return (
		SUCCESS
		if level >= minimum_level and level <= maximum_level
		else FAILURE
	)
