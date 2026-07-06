@tool
class_name PoliceVisualContactCondition
extends BTCondition


func _generate_name() -> String:
	return "Police has visual contact"


func _tick(_delta: float) -> Status:
	if agent == null or not agent.has_method("can_see_wanted_player"):
		return FAILURE
	return (
		SUCCESS
		if bool(agent.call("can_see_wanted_player"))
		else FAILURE
	)
