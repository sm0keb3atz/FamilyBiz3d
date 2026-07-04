class_name PoliceRoleComponent
extends NPCRoleComponent

## Police identity boundary. Detection, pursuit, arrest, and combat should be
## added as focused components and coordinated by this role in the next pass.


func activate() -> void:
	npc.appearance_component.apply_police_uniform()
	npc.add_to_group("police_npc")
	npc.add_to_group("law_enforcement")
	npc.add_to_group("gunshot_listener")


func deactivate() -> void:
	npc.remove_from_group("police_npc")
	npc.remove_from_group("law_enforcement")
	npc.remove_from_group("gunshot_listener")
