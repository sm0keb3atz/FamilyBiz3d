@tool
class_name DealerHostileCondition
extends BTCondition


func _generate_name() -> String:
	return "Dealer is hostile"


func _tick(_delta: float) -> Status:
	return SUCCESS if agent != null and agent.has_method("is_hostile") and bool(agent.call("is_hostile")) else FAILURE
