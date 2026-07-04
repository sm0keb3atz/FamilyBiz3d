@tool
class_name PoliceModeAction
extends BTAction

enum Mode {
	PATROL,
	ARREST,
	COMBAT,
}

@export var mode := Mode.PATROL


func _generate_name() -> String:
	return "Police: %s" % Mode.keys()[mode]


func _tick(delta: float) -> Status:
	if agent == null or not agent.has_method("tick_ai_mode"):
		return FAILURE
	agent.call("tick_ai_mode", mode, delta)
	return SUCCESS
