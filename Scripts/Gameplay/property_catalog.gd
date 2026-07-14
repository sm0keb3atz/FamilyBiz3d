class_name PropertyCatalog
extends RefCounted

const PURCHASE_PRICE := 10000
const PROPERTY_IDS: Array[StringName] = [
	&"hood_east_house_1",
	&"hood_east_house_2",
	&"hood_east_house_3",
	&"hood_east_house_4",
]

static var _definitions: Array[PropertyDefinition] = []
static var _by_id: Dictionary[StringName, PropertyDefinition] = {}


static func get_all() -> Array[PropertyDefinition]:
	_ensure_catalog()
	return _definitions.duplicate()


static func get_by_id(property_id: StringName) -> PropertyDefinition:
	_ensure_catalog()
	return _by_id.get(property_id) as PropertyDefinition


static func _ensure_catalog() -> void:
	if not _definitions.is_empty():
		return
	for index in PROPERTY_IDS.size():
		var definition := PropertyDefinition.new(
			PROPERTY_IDS[index],
			"Hood House %d" % (index + 1),
			"Hood East",
			PURCHASE_PRICE
		)
		_definitions.append(definition)
		_by_id[definition.property_id] = definition
