class_name CustomerLimboState
extends LimboState

@export var state_id := 0


func _enter() -> void:
	var customer := agent as CustomerNPC
	if customer != null:
		customer._limbo_state_enter(state_id)


func _update(delta: float) -> void:
	var customer := agent as CustomerNPC
	if customer != null:
		customer._limbo_state_update(state_id, delta)


func _exit() -> void:
	var customer := agent as CustomerNPC
	if customer != null:
		customer._limbo_state_exit(state_id)
