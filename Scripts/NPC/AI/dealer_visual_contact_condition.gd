@tool
class_name DealerVisualContactCondition
extends BTCondition


func _generate_name() -> String:
	return "Dealer has visual contact"


func _tick(_delta: float) -> Status:
	return SUCCESS if agent != null and agent.has_method("can_see_combat_target") and bool(agent.call("can_see_combat_target")) else FAILURE
