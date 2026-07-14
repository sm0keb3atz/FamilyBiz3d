class_name PropertyBuilding
extends Node3D

@export var property_id: StringName = &"hood_east_house_1"

@onready var for_sale_sign := get_node_or_null("ForSaleSign") as Area3D
@onready var for_sale_visual := get_node_or_null("SM_billboard_forSale") as Node3D

var property_component: PlayerPropertyComponent


func _ready() -> void:
	add_to_group(&"property_buildings")
	set_process(true)
	call_deferred("_bind_property_component")


func _process(_delta: float) -> void:
	if property_component == null:
		_bind_property_component()
		return
	var should_be_visible := not property_component.owns(property_id)
	if for_sale_visual != null and for_sale_visual.visible != should_be_visible:
		_sync_sign()


func get_definition() -> PropertyDefinition:
	return PropertyCatalog.get_by_id(property_id)


func is_owned() -> bool:
	return property_component != null and property_component.owns(property_id)


func _bind_property_component() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if player == null:
		return
	property_component = player.get_node_or_null(
		"Components/PropertyComponent"
	) as PlayerPropertyComponent
	if property_component == null:
		return
	if not property_component.ownership_changed.is_connected(_on_ownership_changed):
		property_component.ownership_changed.connect(_on_ownership_changed)
	_sync_sign()


func _on_ownership_changed(changed_id: StringName, _owned: bool) -> void:
	if changed_id == property_id:
		_sync_sign()


func _sync_sign() -> void:
	var available := not is_owned()
	if for_sale_visual != null:
		for_sale_visual.visible = available
	if for_sale_sign != null:
		for_sale_sign.set_deferred("monitoring", available)
		for_sale_sign.set_deferred("monitorable", available)
