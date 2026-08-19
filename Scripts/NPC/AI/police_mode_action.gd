@tool
class_name PoliceModeAction
extends BTAction

enum Mode {
	PATROL,
	ARREST,
	COMBAT,
	SEARCH_ARREST,
	SEARCH_COMBAT,
	CHALLENGE,
	SEARCH_CHALLENGE,
	INVESTIGATE,
	SURRENDER,
}

@export var mode := Mode.PATROL


func _generate_name() -> String:
	return "Police: %s" % Mode.keys()[mode]


func _tick(delta: float) -> Status:
	if agent == null or not agent.has_method("tick_ai_mode"):
		return FAILURE
	if blackboard != null and agent.has_method("get_police_blackboard_state"):
		var state := agent.call("get_police_blackboard_state") as Dictionary
		for key in state:
			blackboard.set_var(key, state[key])
	agent.call("tick_ai_mode", mode, delta)
	return RUNNING


func _exit() -> void:
	if agent != null and agent.has_method("abort_police_ai_mode"):
		agent.call("abort_police_ai_mode", mode)
