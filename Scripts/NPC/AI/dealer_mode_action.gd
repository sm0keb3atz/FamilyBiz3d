@tool
class_name DealerModeAction
extends BTAction

enum Mode {
	NEUTRAL,
	COMBAT,
	SEARCH,
}

@export var mode := Mode.NEUTRAL


func _generate_name() -> String:
	return "Dealer: %s" % Mode.keys()[mode]


func _tick(delta: float) -> Status:
	if agent == null or not agent.has_method("tick_dealer_ai_mode"):
		return FAILURE
	agent.call("tick_dealer_ai_mode", mode, delta)
	return RUNNING
