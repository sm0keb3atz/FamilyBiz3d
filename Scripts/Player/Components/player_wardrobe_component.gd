class_name PlayerWardrobeComponent
extends Node

signal ownership_changed(clothing_id: StringName, owned: bool)
signal equipped_changed(category: StringName, clothing_id: StringName)
signal clothing_color_changed(clothing_id: StringName, color: Color)

@export var appearance_component_path := NodePath("../AppearanceComponent")

var _owned: Dictionary[StringName, bool] = {}
var _equipped: Dictionary[StringName, StringName] = {
	ClothingCatalog.CATEGORY_TOP: &"base_hoodie",
	ClothingCatalog.CATEGORY_BOTTOM: &"jeans",
	ClothingCatalog.CATEGORY_SHOES: &"sneakers",
}
var _colors: Dictionary[StringName, Color] = {
	&"base_hoodie": Color.WHITE,
}

@onready var appearance := get_node(appearance_component_path) as PlayerAppearanceComponent


func _ready() -> void:
	_reset_to_starting_wardrobe()
	call_deferred("apply_equipped_outfit")


func owns(clothing_id: StringName) -> bool:
	return bool(_owned.get(clothing_id, false))


func unlock(clothing_id: StringName) -> bool:
	var definition := ClothingCatalog.get_by_id(clothing_id)
	if definition == null or owns(clothing_id):
		return false
	_owned[clothing_id] = true
	ownership_changed.emit(clothing_id, true)
	return true


func equip(clothing_id: StringName) -> bool:
	var definition := ClothingCatalog.get_by_id(clothing_id)
	if definition == null or not owns(clothing_id):
		return false
	_equipped[definition.category] = clothing_id
	_apply_definition(definition)
	equipped_changed.emit(definition.category, clothing_id)
	return true


func get_equipped_id(category: StringName) -> StringName:
	return StringName(_equipped.get(category, &""))


func get_equipped_definition(category: StringName) -> ClothingDefinition:
	return ClothingCatalog.get_by_id(get_equipped_id(category))


func set_item_color(clothing_id: StringName, color: Color) -> bool:
	var definition := ClothingCatalog.get_by_id(clothing_id)
	if definition == null or not definition.tintable or not owns(clothing_id):
		return false
	_colors[clothing_id] = color
	if get_equipped_id(definition.category) == clothing_id:
		_apply_definition(definition)
	clothing_color_changed.emit(clothing_id, color)
	return true


func get_item_color(clothing_id: StringName) -> Color:
	return _colors.get(clothing_id, Color.WHITE)


func get_owned_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for clothing_id in _owned:
		if bool(_owned[clothing_id]):
			result.append(clothing_id)
	return result


func get_outfit_state() -> Dictionary:
	var equipped_data := {}
	for category in _equipped:
		equipped_data[String(category)] = String(_equipped[category])
	var color_data := {}
	for clothing_id in _colors:
		color_data[String(clothing_id)] = get_item_color(clothing_id).to_html(true)
	return {
		"equipped": equipped_data,
		"colors": color_data,
	}


func apply_equipped_outfit() -> void:
	for category in [
		ClothingCatalog.CATEGORY_TOP,
		ClothingCatalog.CATEGORY_BOTTOM,
		ClothingCatalog.CATEGORY_SHOES,
	]:
		var definition := get_equipped_definition(category)
		if definition != null:
			_apply_definition(definition)


func apply_outfit_to(target: PlayerAppearanceComponent, trial_id := &"") -> void:
	if target == null:
		return
	for category in [
		ClothingCatalog.CATEGORY_TOP,
		ClothingCatalog.CATEGORY_BOTTOM,
		ClothingCatalog.CATEGORY_SHOES,
	]:
		var definition := get_equipped_definition(category)
		if definition != null:
			target.apply_clothing_definition(
				definition,
				get_item_color(definition.clothing_id)
			)
	var trial := ClothingCatalog.get_by_id(trial_id)
	if trial != null:
		target.apply_clothing_definition(trial, get_item_color(trial_id))


func export_save_data() -> Dictionary:
	var data := get_outfit_state()
	var owned_data: Array[String] = []
	for clothing_id in get_owned_ids():
		owned_data.append(String(clothing_id))
	data["owned"] = owned_data
	return data


func import_save_data(data: Dictionary) -> void:
	_reset_to_starting_wardrobe()
	if data.is_empty():
		apply_equipped_outfit()
		return
	var owned_data := data.get("owned", []) as Array
	for value in owned_data:
		var clothing_id := StringName(str(value))
		if ClothingCatalog.get_by_id(clothing_id) != null:
			_owned[clothing_id] = true
	var equipped_data := data.get("equipped", {}) as Dictionary
	for category_text in equipped_data:
		var category := StringName(str(category_text))
		var clothing_id := StringName(str(equipped_data[category_text]))
		var definition := ClothingCatalog.get_by_id(clothing_id)
		if definition != null and definition.category == category and owns(clothing_id):
			_equipped[category] = clothing_id
	var color_data := data.get("colors", {}) as Dictionary
	for id_text in color_data:
		var clothing_id := StringName(str(id_text))
		var definition := ClothingCatalog.get_by_id(clothing_id)
		if definition != null and definition.tintable:
			_colors[clothing_id] = Color.from_string(str(color_data[id_text]), Color.WHITE)
	apply_equipped_outfit()


func _apply_definition(definition: ClothingDefinition) -> void:
	appearance.apply_clothing_definition(
		definition,
		get_item_color(definition.clothing_id)
	)


func _reset_to_starting_wardrobe() -> void:
	_owned.clear()
	for clothing_id in ClothingCatalog.get_starting_ids():
		_owned[clothing_id] = true
	_equipped = {
		ClothingCatalog.CATEGORY_TOP: &"base_hoodie",
		ClothingCatalog.CATEGORY_BOTTOM: &"jeans",
		ClothingCatalog.CATEGORY_SHOES: &"sneakers",
	}
	_colors = {&"base_hoodie": Color.WHITE}
