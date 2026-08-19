@tool
class_name PoliceInvestigationCondition
extends BTCondition


func _generate_name() -> String:
	return "Police has anonymous observation"


func _tick(_delta: float) -> Status:
	if agent == null or not agent.has_method("has_active_police_investigation"):
		return FAILURE
	return SUCCESS if bool(agent.call("has_active_police_investigation")) else FAILURE
