class_name CourtArea
extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var legal := body.get_node_or_null("Components/LegalComponent") as PlayerLegalComponent
	if legal != null:
		legal.set_court_presence(true)


func _on_body_exited(body: Node3D) -> void:
	var legal := body.get_node_or_null("Components/LegalComponent") as PlayerLegalComponent
	if legal != null:
		legal.set_court_presence(false)
