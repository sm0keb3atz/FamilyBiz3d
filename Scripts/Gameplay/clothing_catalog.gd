class_name ClothingCatalog
extends RefCounted

const CATEGORY_TOP := &"top"
const CATEGORY_BOTTOM := &"bottom"
const CATEGORY_SHOES := &"shoes"
const TYPE_HOODIE := &"hoodie"
const TYPE_TSHIRT := &"tshirt"
const TYPE_BOTTOM := &"bottom"
const TYPE_SHOES := &"shoes"

const MATERIALS := {
	&"base_hoodie": preload("res://Assets/BaseChracters/Player/Materials/Variants/TOP_01_Hoodie__White.tres"),
	&"modernist_green": preload("res://Assets/BaseChracters/Player/Materials/Variants/ModernistHoodieGreen.tres"),
	&"mason_black_gold": preload("res://Assets/BaseChracters/Player/Materials/Variants/MasonNoirHoodieBlackGold.tres"),
	&"mason_black_white": preload("res://Assets/BaseChracters/Player/Materials/Variants/MasonNoirHoodieBlackWhite.tres"),
	&"mason_blue": preload("res://Assets/BaseChracters/Player/Materials/Variants/MasonNoirHoodieBlue.tres"),
	&"mason_cream": preload("res://Assets/BaseChracters/Player/Materials/Variants/MasonNoirHoodieCream.tres"),
	&"mason_red": preload("res://Assets/BaseChracters/Player/Materials/Variants/MasonNoirHoodieRed.tres"),
	&"amiri_black": preload("res://Assets/BaseChracters/Player/Materials/Variants/AmiriHoodieBlack.tres"),
	&"amiri_blue": preload("res://Assets/BaseChracters/Player/Materials/Variants/AmiriHoodieBlue.tres"),
	&"amiri_cream": preload("res://Assets/BaseChracters/Player/Materials/Variants/AmiriHoodieCream.tres"),
	&"amiri_white": preload("res://Assets/BaseChracters/Player/Materials/Variants/AmiriHoodieWhite.tres"),
	&"tshirt_white": preload("res://Assets/BaseChracters/Player/Materials/Variants/TOP_02_TShirt__White.tres"),
	&"jeans": preload("res://Assets/BaseChracters/Player/Materials/Modular/Jeans_Original.tres"),
	&"sweatpants": preload("res://Assets/BaseChracters/Player/Materials/Modular/Sweatpants_Original.tres"),
	&"sneakers": preload("res://Assets/BaseChracters/Player/Materials/Modular/Sneakers_Original.tres"),
	&"boots": preload("res://Assets/BaseChracters/Player/Materials/Modular/Boots_Original.tres"),
}

static var _items: Array[ClothingDefinition] = []
static var _by_id: Dictionary[StringName, ClothingDefinition] = {}


static func get_all() -> Array[ClothingDefinition]:
	_ensure_catalog()
	return _items.duplicate()


static func get_by_id(clothing_id: StringName) -> ClothingDefinition:
	_ensure_catalog()
	return _by_id.get(clothing_id) as ClothingDefinition


static func get_for_category(category: StringName) -> Array[ClothingDefinition]:
	_ensure_catalog()
	var matches: Array[ClothingDefinition] = []
	for definition in _items:
		if definition.category == category:
			matches.append(definition)
	return matches


static func get_filtered(
	category: StringName,
	clothing_type := &"",
	brand := ""
) -> Array[ClothingDefinition]:
	var matches: Array[ClothingDefinition] = []
	for definition in get_for_category(category):
		if not clothing_type.is_empty() and definition.clothing_type != clothing_type:
			continue
		if not brand.is_empty() and definition.brand != brand:
			continue
		matches.append(definition)
	return matches


static func get_brands(
	category: StringName,
	clothing_type: StringName
) -> Array[String]:
	var brands: Array[String] = []
	for definition in get_filtered(category, clothing_type):
		if definition.brand not in brands:
			brands.append(definition.brand)
	return brands


static func get_starting_ids() -> Array[StringName]:
	_ensure_catalog()
	var ids: Array[StringName] = []
	for definition in _items:
		if definition.starting_owned:
			ids.append(definition.clothing_id)
	return ids


static func _ensure_catalog() -> void:
	if not _items.is_empty():
		return
	_add(&"base_hoodie", "Base Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Base", "White", &"TOP_01_Hoodie", 100, 0, true, true)
	_add(&"modernist_green", "Modernist Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Modernist", "Green", &"TOP_01_Hoodie", 500, 25)
	_add(&"mason_black_gold", "Mason Noir Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Mason Noir", "Black / Gold", &"TOP_01_Hoodie", 900, 60)
	_add(&"mason_black_white", "Mason Noir Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Mason Noir", "Black / White", &"TOP_01_Hoodie", 900, 60)
	_add(&"mason_blue", "Mason Noir Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Mason Noir", "Blue", &"TOP_01_Hoodie", 900, 60)
	_add(&"mason_cream", "Mason Noir Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Mason Noir", "Cream", &"TOP_01_Hoodie", 900, 60)
	_add(&"mason_red", "Mason Noir Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Mason Noir", "Red", &"TOP_01_Hoodie", 900, 60)
	_add(&"amiri_black", "Amiri Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Amiri", "Black", &"TOP_01_Hoodie", 1500, 100)
	_add(&"amiri_blue", "Amiri Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Amiri", "Blue", &"TOP_01_Hoodie", 1500, 100)
	_add(&"amiri_cream", "Amiri Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Amiri", "Cream", &"TOP_01_Hoodie", 1500, 100)
	_add(&"amiri_white", "Amiri Hoodie", CATEGORY_TOP, TYPE_HOODIE, "Amiri", "White", &"TOP_01_Hoodie", 1500, 100)
	_add(&"tshirt_white", "Base T-Shirt", CATEGORY_TOP, TYPE_TSHIRT, "Base", "White", &"TOP_02_TShirt", 125, 0, true, true)
	_add(&"jeans", "Jeans", CATEGORY_BOTTOM, TYPE_BOTTOM, "Base", "Blue Denim", &"BOTTOM_01_Jeans", 200, 0, false, true)
	_add(&"sweatpants", "Sweatpants", CATEGORY_BOTTOM, TYPE_BOTTOM, "Base", "Grey", &"BOTTOM_02_Sweatpants", 150, 0, false, true)
	_add(&"sneakers", "Sneakers", CATEGORY_SHOES, TYPE_SHOES, "Base", "Classic", &"SHOES_01_Sneakers", 175, 0, false, true)
	_add(&"boots", "Boots", CATEGORY_SHOES, TYPE_SHOES, "Base", "Leather", &"SHOES_02_Boots", 450, 50)


static func _add(
	clothing_id: StringName,
	display_name: String,
	category: StringName,
	clothing_type: StringName,
	brand: String,
	variant_name: String,
	mesh_name: StringName,
	price: int,
	aura: int,
	tintable := false,
	starting_owned := false
) -> void:
	var definition := ClothingDefinition.new()
	definition.clothing_id = clothing_id
	definition.display_name = display_name
	definition.category = category
	definition.clothing_type = clothing_type
	definition.brand = brand
	definition.variant_name = variant_name
	definition.mesh_name = mesh_name
	definition.material = MATERIALS[clothing_id] as Material
	definition.price = price
	definition.aura = aura
	definition.tintable = tintable
	definition.starting_owned = starting_owned
	_items.append(definition)
	_by_id[clothing_id] = definition
