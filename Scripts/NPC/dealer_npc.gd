class_name DealerNPC
extends BaseNPC

## Dealer composition root. Shop behavior belongs to DealerRoleComponent.

@onready var role_component := (
	$Components/RoleComponent as DealerRoleComponent
)

var product: ProductDefinition:
	get:
		var role := get_role_component()
		return role.get_primary_product() if role != null else null

var _hostile := false
var _target_player: CharacterBody3D
@onready var bt_player := get_node_or_null("BTPlayer") as BTPlayer


func _ready() -> void:
	super()
	role_component = get_role_component()
	if role_component != null:
		role_component.initialize(self)
		role_component.activate()
	var combat := get_combat_component()
	if combat != null:
		combat.initialize(self)
	_target_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	var threat := get_threat_component()
	var ai := get_ai_component()
	if _target_player != null and threat != null and ai != null:
		threat.initialize(self, _target_player)
		ai.initialize(self, _target_player)
		threat.provoked.connect(provoke)
	damageable.damaged.connect(_on_damaged)
	_apply_combat_loadout()


func get_role_component() -> DealerRoleComponent:
	if role_component != null:
		return role_component
	return get_node_or_null("Components/RoleComponent") as DealerRoleComponent


func can_interact(player: CharacterBody3D) -> bool:
	var role := get_role_component()
	return not _hostile and role != null and role.can_interact(player)


func get_interaction_prompt(player: CharacterBody3D) -> String:
	var role := get_role_component()
	return role.get_interaction_prompt(player) if role != null else ""


func interact(player: CharacterBody3D) -> void:
	var role := get_role_component()
	if role != null:
		role.interact(player)


func try_purchase(
	player: CharacterBody3D,
	requested_product: ProductDefinition = null,
	amount := 1
) -> String:
	var purchase_product := requested_product
	if purchase_product == null:
		purchase_product = product
	var role := get_role_component()
	if role == null:
		return "Dealer is not ready."
	return role.try_purchase(player, purchase_product, amount)


func configure_dealer(level := 1, wholesaler := false) -> void:
	var role := get_role_component()
	if role != null:
		role.initialize(self)
		role.configure_dealer(level, wholesaler)
	_apply_combat_loadout()


func provoke(source: Node = null, world_position := Vector3.ZERO) -> void:
	if _hostile or is_defeated():
		return
	if source != null and not _is_player_source(source):
		return
	_hostile = true
	remove_from_group("interactable_npc")
	remove_from_group("interactable")
	var combat := get_combat_component()
	if combat != null:
		combat.set_equipped(true)
	var ai := get_ai_component()
	if ai != null:
		var incident_position := world_position
		if _target_player != null and _is_player_source(source):
			incident_position = _target_player.global_position
		ai.call("note_incident", incident_position)


func clear_hostility() -> void:
	if not _hostile:
		return
	_hostile = false
	var combat := get_combat_component()
	if combat != null:
		combat.clear_aim()
		combat.set_equipped(false)
	if role_component != null:
		role_component.activate()


func is_hostile() -> bool:
	return _hostile


func get_wanted_level() -> int:
	return 2 if _hostile else 0


func can_see_wanted_player() -> bool:
	var threat := get_threat_component()
	return _hostile and threat != null and bool(threat.call("can_see_player"))


func tick_ai_mode(mode: int, delta: float) -> void:
	var ai := get_ai_component()
	if ai != null:
		ai.call("tick_mode", mode, delta)


func get_combat_component() -> NPCCombatComponent:
	return get_node_or_null("Components/CombatComponent") as NPCCombatComponent


func get_threat_component() -> Node:
	return get_node_or_null("Components/ThreatComponent")


func get_ai_component() -> Node:
	return get_node_or_null("Components/AIComponent")


func get_combat_weapon() -> WeaponDefinition:
	var combat := get_combat_component()
	return combat.get_weapon_definition() if combat != null else null


func uses_automatic_fire() -> bool:
	var combat := get_combat_component()
	return combat != null and combat.is_fully_automatic()


func get_stock_items() -> Array[Dictionary]:
	var role := get_role_component()
	return role.get_stock_items() if role != null else []


func get_stock_quantity(stock_product: ProductDefinition) -> int:
	var role := get_role_component()
	return role.get_stock_quantity(stock_product) if role != null else 0


func get_dealer_level_text() -> String:
	var role := get_role_component()
	return role.get_display_level() if role != null else "Dealer"


func get_cooldown_remaining() -> float:
	var role := get_role_component()
	return role.get_cooldown_remaining() if role != null else 0.0


func force_restock() -> void:
	var role := get_role_component()
	if role != null:
		role.restock()


func export_save_data() -> Dictionary:
	var role := get_role_component()
	return role.export_save_data() if role != null else {}


func import_save_data(data: Dictionary) -> void:
	var role := get_role_component()
	if role != null:
		role.initialize(self)
		role.import_save_data(data)
	clear_hostility()
	_apply_combat_loadout()


func _apply_combat_loadout() -> void:
	var role := get_role_component()
	var combat := get_combat_component()
	if role == null or combat == null:
		return
	var effective_level := 4 if role.is_wholesaler else role.dealer_level
	var definition := load(
		"res://Scripts/Gameplay/Weapons/draco_definition.tres"
		if effective_level >= 3
		else "res://Scripts/Gameplay/Weapons/pistol_definition.tres"
	) as WeaponDefinition
	var automatic := effective_level == 2 or effective_level == 4
	var controlled_interval := -1.0
	if effective_level == 1:
		controlled_interval = 0.42
	elif effective_level == 3:
		controlled_interval = 0.26
	combat.configure_weapon(definition, automatic, controlled_interval)


func _on_damaged(
	_amount: float,
	_remaining_health: float,
	source: Node,
	hit_position: Vector3,
	_hit_direction: Vector3
) -> void:
	if _is_player_source(source):
		provoke(source, hit_position)


func _is_player_source(source: Node) -> bool:
	if source == _target_player:
		return true
	var current := source
	while current != null:
		if current.is_in_group(&"player"):
			return true
		current = current.get_parent()
	return false


func _on_defeated(
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	var role := get_role_component()
	if role != null:
		role.deactivate()
	var combat := get_combat_component()
	if combat != null:
		combat.set_equipped(false)
	if bt_player != null:
		bt_player.set_active(false)
	super(source, hit_position, hit_direction)
