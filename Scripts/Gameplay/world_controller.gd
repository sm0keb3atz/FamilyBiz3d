class_name WorldController
extends Node

const SAVE_VERSION := 2
const SAVE_PATH := "user://family_business_save.json"

@export var player_path := NodePath("../Gameplay/Player")

@onready var player := get_node(player_path) as CharacterBody3D
@onready var wallet := player.get_node(
	"Components/WalletComponent"
) as PlayerWalletComponent
@onready var inventory := player.get_node(
	"Components/InventoryComponent"
) as PlayerInventoryComponent
@onready var stats := player.get_node(
	"Components/StatsComponent"
) as PlayerStatsComponent
@onready var wanted := player.get_node(
	"Components/WantedComponent"
) as PlayerWantedComponent
@onready var vehicle_component: Variant = player.get_node(
	"Components/VehicleComponent"
)
@onready var hud := player.get_node("PlayerHUD") as PlayerHUD
@onready var world_time := get_node("../WorldTimeComponent") as WorldTimeComponent


func _ready() -> void:
	world_time.connect_wallet(wallet)
	world_time.time_changed.connect(hud.update_clock)
	world_time.day_ended.connect(_on_day_ended)
	hud.update_clock(world_time.get_formatted_date(), world_time.get_formatted_time())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_F5:
		save_game()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_F9:
		load_game()
		get_viewport().set_input_as_handled()


func save_game() -> bool:
	var territories := {}
	for node in get_tree().get_nodes_in_group("territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.stats != null:
			territories[String(boundary.territory_id)] = (
				boundary.stats.export_save_data()
			)
	var dealers := {}
	for node in get_tree().get_nodes_in_group("dealer_npc"):
		var dealer := node as DealerNPC
		if dealer != null:
			dealers[String(dealer.get_path())] = dealer.export_save_data()

	var data := {
		"version": SAVE_VERSION,
		"world_time": world_time.export_save_data(),
		"player": {
			"position": _vector_to_array(
				vehicle_component.get_effective_position()
			),
			"rotation_y": player.rotation.y,
			"wallet": wallet.export_save_data(),
			"inventory": inventory.export_save_data(),
			"stats": stats.export_save_data(),
			"wanted": wanted.export_save_data(),
		},
		"territories": territories,
		"dealers": dealers,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		hud.show_feedback("Save failed.")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	hud.show_feedback("Game saved.")
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		hud.show_feedback("No save found. Starting values kept.")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		hud.show_feedback("Save could not be opened.")
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not _is_valid_save(parsed):
		hud.show_feedback("Save is damaged or incompatible.")
		return false

	var data := parsed as Dictionary
	var player_data := data.get("player", {}) as Dictionary
	vehicle_component.prepare_for_load()
	wallet.import_save_data(player_data.get("wallet", {}) as Dictionary)
	inventory.import_save_data(player_data.get("inventory", {}) as Dictionary)
	stats.import_save_data(player_data.get("stats", {}) as Dictionary)
	wanted.import_save_data(
		player_data.get("wanted", {}) as Dictionary
	)
	world_time.import_save_data(data.get("world_time", {}) as Dictionary)
	var position_data := player_data.get("position", []) as Array
	if position_data.size() == 3:
		player.global_position = Vector3(
			float(position_data[0]),
			float(position_data[1]),
			float(position_data[2])
		)
	player.rotation.y = float(player_data.get("rotation_y", 0.0))
	player.velocity = Vector3.ZERO

	var territory_data := data.get("territories", {}) as Dictionary
	for node in get_tree().get_nodes_in_group("territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary == null or boundary.stats == null:
			continue
		var territory_id := String(boundary.territory_id)
		if territory_data.has(territory_id):
			boundary.stats.import_save_data(
				territory_data[territory_id] as Dictionary
			)
	var dealer_data := data.get("dealers", {}) as Dictionary
	for path_text in dealer_data.keys():
		var dealer := get_node_or_null(NodePath(String(path_text))) as DealerNPC
		if dealer != null:
			dealer.import_save_data(dealer_data[path_text] as Dictionary)
	hud.show_feedback("Game loaded.")
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _is_valid_save(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	var data := value as Dictionary
	var version := int(data.get("version", -1))
	return (
		version >= 1 and version <= SAVE_VERSION
		and data.get("player", null) is Dictionary
		and data.get("territories", null) is Dictionary
	)


func _on_day_ended(report_date: String, earned: int, spent: int) -> void:
	hud.show_daily_report(report_date, earned, spent)


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
