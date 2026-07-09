extends CharacterBody3D

## Composition root for the player. Gameplay behavior lives in child components.


func _ready() -> void:
	add_to_group(&"player")
