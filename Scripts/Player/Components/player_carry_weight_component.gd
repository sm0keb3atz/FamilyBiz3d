class_name PlayerCarryWeightComponent
extends Node

signal weight_changed(current_grams: int, maximum_grams: int)

@export var stats_component_path := NodePath("../StatsComponent")
@export var inventory_component_path := NodePath("../InventoryComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")

@onready var stats := get_node(stats_component_path) as PlayerStatsComponent
@onready var inventory := (
	get_node(inventory_component_path) as PlayerInventoryComponent
)
@onready var weapons := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)


func _ready() -> void:
	inventory.quantity_changed.connect(_on_inventory_quantity_changed)
	weapons.loadout_changed.connect(_on_weapon_loadout_changed)
	weapons.attachments_changed.connect(_on_weapon_attachments_changed)
	stats.strength_changed.connect(_on_strength_changed)
	call_deferred("notify_weight_changed")


func get_current_weight_grams() -> int:
	var total := 0
	for product in inventory.get_known_products():
		if product != null:
			total += inventory.get_quantity(product) * product.package_size_grams
	for definition in weapons.get_weapon_slots():
		total += definition.get_carry_weight_grams(
			weapons.get_attachment_state(definition.weapon_id)
		)
	return total


func get_max_weight_grams() -> int:
	return stats.get_max_carry_weight_grams()


func get_available_weight_grams() -> int:
	return maxi(get_max_weight_grams() - get_current_weight_grams(), 0)


func is_overweight() -> bool:
	return get_current_weight_grams() > get_max_weight_grams()


func can_add_weight(additional_grams: int) -> bool:
	return (
		additional_grams <= 0
		or get_current_weight_grams() + additional_grams
		<= get_max_weight_grams()
	)


func can_add_product(product: ProductDefinition, amount: int = 1) -> bool:
	return (
		product != null
		and amount > 0
		and can_add_weight(product.package_size_grams * amount)
	)


func can_add_products(entries: Array) -> bool:
	var additional := 0
	for entry_value in entries:
		if entry_value is not Dictionary:
			return false
		var entry := entry_value as Dictionary
		var product := entry.get("product") as ProductDefinition
		var amount := int(entry.get("quantity", entry.get("amount", 0)))
		if product == null or amount <= 0:
			return false
		additional += product.package_size_grams * amount
	return can_add_weight(additional)


func can_add_weapon(
	definition: WeaponDefinition,
	attachment_state: Dictionary = {}
) -> bool:
	return (
		definition != null
		and can_add_weight(
			definition.get_carry_weight_grams(attachment_state)
		)
	)


func can_change_weapon_state(
	definition: WeaponDefinition,
	current_state: Dictionary,
	next_state: Dictionary
) -> bool:
	if definition == null:
		return false
	var delta := (
		definition.get_carry_weight_grams(next_state)
		- definition.get_carry_weight_grams(current_state)
	)
	return can_add_weight(delta)


func get_capacity_failure_message(additional_grams: int) -> String:
	return "Need %dg free; %dg available." % [
		maxi(additional_grams, 0),
		get_available_weight_grams(),
	]


func notify_weight_changed() -> void:
	weight_changed.emit(get_current_weight_grams(), get_max_weight_grams())


func _on_inventory_quantity_changed(
	_product: ProductDefinition,
	_quantity: int
) -> void:
	notify_weight_changed()


func _on_weapon_loadout_changed() -> void:
	notify_weight_changed()


func _on_weapon_attachments_changed() -> void:
	notify_weight_changed()


func _on_strength_changed(_current: int) -> void:
	notify_weight_changed()
