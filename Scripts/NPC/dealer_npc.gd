class_name DealerNPC
extends BaseNPC

## Dealer composition root. Shop behavior belongs to DealerRoleComponent.

@onready var role_component := (
	$Components/RoleComponent as DealerRoleComponent
)

var product: ProductDefinition:
	get:
		return role_component.product


func _ready() -> void:
	super()
	role_component.initialize(self)
	role_component.activate()


func can_interact(player: CharacterBody3D) -> bool:
	return role_component.can_interact(player)


func get_interaction_prompt(player: CharacterBody3D) -> String:
	return role_component.get_interaction_prompt(player)


func interact(player: CharacterBody3D) -> void:
	role_component.interact(player)


func try_purchase(player: CharacterBody3D) -> String:
	return role_component.try_purchase(player)


func _on_defeated(
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	role_component.deactivate()
	super(source, hit_position, hit_direction)
