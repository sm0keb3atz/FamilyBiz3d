class_name GunStoreService
extends Node

signal transaction_finished(message: String, success: bool)

const ATTACHMENT_PRICES := {
	&"sights": 200,
	&"laser": 350,
	&"extended": 300,
	&"switch": 500,
	&"drum": 750,
}
const ATTACHMENT_NAMES := {
	&"sights": "Sights",
	&"laser": "Laser",
	&"extended": "Extended Magazine",
	&"switch": "Full-Auto Switch",
	&"drum": "Drum Magazine",
}

@export var wallet_component_path := NodePath("../WalletComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var weapon := get_node(weapon_component_path) as PlayerWeaponComponent


func buy_weapon(definition: WeaponDefinition) -> bool:
	if definition == null:
		return _finish("Weapon is unavailable.", false)
	if weapon.owns_weapon(definition.weapon_id):
		return _finish("%s is already owned." % definition.display_name, false)
	if not wallet.can_spend_clean(definition.purchase_price):
		return _finish("Not enough clean money.", false)
	if not weapon.grant_weapon(definition):
		return _finish("Purchase could not be completed.", false)
	if not wallet.spend_clean(definition.purchase_price):
		return _finish("Purchase could not be completed.", false)
	return _finish("Purchased %s." % definition.display_name, true)


func buy_ammo(definition: WeaponDefinition) -> bool:
	if definition == null or not weapon.owns_weapon(definition.weapon_id):
		return _finish("Own this weapon before buying ammo.", false)
	if not wallet.can_spend_clean(definition.ammo_bundle_price):
		return _finish("Not enough clean money.", false)
	if not weapon.add_reserve_ammo_for(definition.weapon_id, definition.ammo_bundle_amount):
		return _finish("Ammo purchase could not be completed.", false)
	if not wallet.spend_clean(definition.ammo_bundle_price):
		return _finish("Ammo purchase could not be completed.", false)
	return _finish("Added %d rounds for %s." % [definition.ammo_bundle_amount, definition.display_name], true)


func buy_attachment(definition: WeaponDefinition, attachment_id: StringName) -> bool:
	if definition == null or not weapon.owns_weapon(definition.weapon_id):
		return _finish("Own this weapon before buying attachments.", false)
	if not ATTACHMENT_PRICES.has(attachment_id):
		return _finish("Attachment is unavailable.", false)
	if weapon.owns_attachment(definition.weapon_id, attachment_id):
		return _finish("Attachment is already owned.", false)
	var price := get_attachment_price(attachment_id)
	if not wallet.can_spend_clean(price):
		return _finish("Not enough clean money.", false)
	if not weapon.unlock_attachment(definition.weapon_id, attachment_id):
		return _finish("Attachment purchase could not be completed.", false)
	if not wallet.spend_clean(price):
		return _finish("Attachment purchase could not be completed.", false)
	return _finish("Unlocked %s for %s." % [get_attachment_name(attachment_id), definition.display_name], true)


func set_attachment_equipped(definition: WeaponDefinition, attachment_id: StringName, enabled: bool) -> bool:
	if definition == null or not weapon.equip_attachment(definition.weapon_id, attachment_id, enabled):
		return _finish("Attachment could not be changed.", false)
	return _finish("%s %s." % [get_attachment_name(attachment_id), "equipped" if enabled else "removed"], true)


func get_attachment_price(attachment_id: StringName) -> int:
	return int(ATTACHMENT_PRICES.get(attachment_id, 0))


func get_attachment_name(attachment_id: StringName) -> String:
	return String(ATTACHMENT_NAMES.get(attachment_id, String(attachment_id).capitalize()))


func _finish(message: String, success: bool) -> bool:
	transaction_finished.emit(message, success)
	return success
