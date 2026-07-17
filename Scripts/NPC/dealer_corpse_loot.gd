class_name DealerCorpseLoot
extends Node3D

var dealer: DealerNPC
var _remaining := 20.0


func setup(owner_dealer: DealerNPC, lifetime := 20.0) -> void:
	dealer = owner_dealer
	_remaining = maxf(lifetime, 0.1)
	add_to_group(&"interactable")
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(dealer) or not dealer.has_corpse_loot():
		queue_free()
		return
	global_position = dealer.get_vfx_pool_origin()
	_remaining = maxf(_remaining - delta, 0.0)
	if is_zero_approx(_remaining):
		dealer.expire_corpse_loot()
		queue_free()


func can_interact(_player: CharacterBody3D) -> bool:
	return is_instance_valid(dealer) and dealer.has_corpse_loot()


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return "E - Search Dealer"


func interact(player: CharacterBody3D) -> void:
	if is_instance_valid(dealer):
		dealer.collect_corpse_loot(player)
	queue_free()
