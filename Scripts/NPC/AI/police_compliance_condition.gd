@tool
class_name PoliceComplianceCondition
extends BTCondition


func _generate_name() -> String:
	return "Player is visibly complying"


func _tick(_delta: float) -> Status:
	if agent == null or not agent.has_method("is_player_compliant"):
		return FAILURE
	return SUCCESS if bool(agent.call("is_player_compliant")) else FAILURE
