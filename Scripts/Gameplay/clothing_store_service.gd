class_name ClothingStoreService
extends Node

signal transaction_finished(message: String, success: bool)

const COLOR_CHANGE_PRICE := 50

@export var wallet_component_path := NodePath("../WalletComponent")
@export var wardrobe_component_path := NodePath("../WardrobeComponent")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var wardrobe := get_node(wardrobe_component_path) as PlayerWardrobeComponent


func buy(clothing_id: StringName) -> bool:
	var definition := ClothingCatalog.get_by_id(clothing_id)
	if definition == null:
		return _finish("Clothing is unavailable.", false)
	if wardrobe.owns(clothing_id):
		return _finish("%s is already owned." % definition.display_name, false)
	if not wallet.can_spend_clean(definition.price):
		return _finish("Not enough clean money.", false)
	if not wallet.spend_clean(definition.price):
		return _finish("Purchase could not be completed.", false)
	if not wardrobe.unlock(clothing_id):
		wallet.add_clean(definition.price, false)
		return _finish("Purchase could not be completed.", false)
	wardrobe.equip(clothing_id)
	return _finish("Purchased and equipped %s." % definition.display_name, true)


func equip(clothing_id: StringName) -> bool:
	var definition := ClothingCatalog.get_by_id(clothing_id)
	if definition == null or not wardrobe.owns(clothing_id):
		return _finish("Own this item before equipping it.", false)
	if wardrobe.get_equipped_id(definition.category) == clothing_id:
		return _finish("%s is already equipped." % definition.display_name, false)
	if not wardrobe.equip(clothing_id):
		return _finish("Clothing could not be equipped.", false)
	return _finish("Equipped %s." % definition.display_name, true)


func buy_color_change(clothing_id: StringName, color: Color) -> bool:
	var definition := ClothingCatalog.get_by_id(clothing_id)
	if definition == null or not definition.tintable or not wardrobe.owns(clothing_id):
		return _finish("Own this base item before changing its color.", false)
	if wardrobe.get_item_color(clothing_id).is_equal_approx(color):
		return _finish("Choose a different color first.", false)
	if not wallet.can_spend_clean(COLOR_CHANGE_PRICE):
		return _finish("Not enough clean money for the color change.", false)
	if not wallet.spend_clean(COLOR_CHANGE_PRICE):
		return _finish("Color change could not be completed.", false)
	if not wardrobe.set_item_color(clothing_id, color):
		wallet.add_clean(COLOR_CHANGE_PRICE, false)
		return _finish("Color change could not be completed.", false)
	return _finish("Color applied to %s." % definition.display_name, true)


func _finish(message: String, success: bool) -> bool:
	transaction_finished.emit(message, success)
	return success
