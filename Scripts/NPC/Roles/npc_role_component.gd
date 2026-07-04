class_name NPCRoleComponent
extends Node

## Base contract for behavior that defines what kind of NPC this is.
## Shared body capabilities belong in BaseNPC components; role-specific
## interaction and identity belong in subclasses of this component.

var npc


func initialize(owner_npc: BaseNPC) -> void:
	npc = owner_npc


func activate() -> void:
	pass


func deactivate() -> void:
	pass


func can_interact(_player: CharacterBody3D) -> bool:
	return false


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return ""


func interact(_player: CharacterBody3D) -> void:
	pass
