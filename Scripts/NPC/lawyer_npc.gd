class_name LawyerNPC
extends BaseNPC

@export var lawyer_id: StringName = &"lawyer_level_1"
@export var lawyer_level := 1

var _waiting_for_next_day := false
var _home_transform: Transform3D


func _ready() -> void:
	super()
	_home_transform = global_transform
	add_to_group(&"interactable")
	add_to_group(&"lawyer_npc")
	remove_from_group(&"traffic_obstacle")
	$RoleLabel.text = "LEVEL %d LAWYER" % lawyer_level
	var random := RandomNumberGenerator.new()
	random.seed = lawyer_id.hash()
	appearance_component.randomize_civilian_appearance(random)
	animation_component.play_activity_animation(
		&"Talking" if lawyer_level % 2 == 0 else &"Idle"
	)
	var world_time := get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if world_time != null:
		world_time.day_ended.connect(_on_day_ended)


func can_interact(_player: CharacterBody3D) -> bool:
	return not _waiting_for_next_day


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return "Talk to Level %d Lawyer" % lawyer_level


func interact(player: CharacterBody3D) -> void:
	var menu := player.get_node_or_null("LawyerMenu")
	if menu != null and menu.has_method("open_for_lawyer"):
		menu.call("open_for_lawyer", lawyer_id)


func get_faction_id() -> StringName:
	return &"civilian"


func _on_defeated(
	_source: Node,
	_hit_position: Vector3,
	_hit_direction: Vector3
) -> void:
	if _waiting_for_next_day:
		return
	_waiting_for_next_day = true
	remove_from_group(&"interactable")
	remove_from_group(&"lock_target")
	visible = false
	body_collision.set_deferred("disabled", true)
	set_physics_process(false)


func _on_day_ended(_date: String, _earned: int, _spent: int) -> void:
	if not _waiting_for_next_day:
		return
	_waiting_for_next_day = false
	global_transform = _home_transform
	damageable.restore_full_health()
	visible = true
	body_collision.set_deferred("disabled", false)
	add_to_group(&"interactable")
	add_to_group(&"lock_target")
	set_physics_process(true)
	animation_component.play_activity_animation(
		&"Talking" if lawyer_level % 2 == 0 else &"Idle"
	)
