class_name WholesalerSpawnPoint3D
extends Marker3D

const REQUIRED_REPUTATION := 100.0
const MINIMUM_DAILY_STOCK := 50
const MAXIMUM_DAILY_STOCK := 100
const PLAYER_KILL_REPUTATION_PENALTY := 25.0

@export var territory_id: StringName
@export var wholesaler_scene: PackedScene

var offer_date := ""
var offer_product_id: StringName
var remaining_stock := 0
var defeated_today := false

var _dealer: DealerNPC
var _territory_stats: TerritoryStatsComponent
var _world_time: WorldTimeComponent
var _random := RandomNumberGenerator.new()
var _suppress_stock_sync := false
var _initialized := false


func _ready() -> void:
	add_to_group(&"wholesaler_spawn_point")
	_random.randomize()
	call_deferred("_initialize")


func _initialize() -> void:
	if _initialized:
		return
	_world_time = get_tree().get_first_node_in_group(
		&"world_time"
	) as WorldTimeComponent
	_territory_stats = _find_territory_stats()
	if _world_time == null or _territory_stats == null:
		push_error(
			"Wholesaler spawn point %s could not resolve territory/time services."
			% name
		)
		return
	_initialized = true
	if not _territory_stats.reputation_changed.is_connected(
		_on_reputation_changed
	):
		_territory_stats.reputation_changed.connect(_on_reputation_changed)
	if not _world_time.day_ended.is_connected(_on_day_ended):
		_world_time.day_ended.connect(_on_day_ended)
	if not _world_time.calendar_skipped.is_connected(_on_calendar_skipped):
		_world_time.calendar_skipped.connect(_on_calendar_skipped)
	_ensure_offer_for_current_date()
	_refresh_presence()


func export_save_data() -> Dictionary:
	_initialize()
	if _initialized:
		_ensure_offer_for_current_date()
	_sync_stock_from_dealer()
	return {
		"territory_id": String(territory_id),
		"offer_date": offer_date,
		"product_id": String(offer_product_id),
		"remaining_stock": remaining_stock,
		"defeated_today": defeated_today,
	}


func import_save_data(data: Dictionary) -> void:
	_initialize()
	if not _initialized:
		return
	var current_date := _world_time.get_date_key()
	var imported_product := EconomyCatalog.get_product(
		StringName(String(data.get("product_id", "")))
	)
	var imported_stock := int(data.get("remaining_stock", -1))
	var valid_offer := (
		String(data.get("offer_date", "")) == current_date
		and imported_product != null
		and imported_product.is_brick()
		and imported_stock >= 0
		and imported_stock <= MAXIMUM_DAILY_STOCK
	)
	if valid_offer:
		offer_date = current_date
		offer_product_id = imported_product.product_id
		remaining_stock = imported_stock
		defeated_today = bool(data.get("defeated_today", false))
	else:
		_roll_daily_offer(current_date)
	_apply_offer_to_dealer()
	_refresh_presence()


func get_spawned_wholesaler() -> DealerNPC:
	return (
		_dealer
		if is_instance_valid(_dealer) and not _dealer.is_defeated()
		else null
	)


func get_offer_product() -> ProductDefinition:
	return EconomyCatalog.get_product(offer_product_id)


func is_defeated_for_current_day() -> bool:
	return defeated_today and offer_date == _get_current_date()


func _on_reputation_changed(_current: float) -> void:
	_refresh_presence()


func _on_day_ended(
	_report_date: String,
	_earned: int,
	_spent: int
) -> void:
	_reset_for_date(_world_time.get_date_key())


func _on_calendar_skipped(
	_from_absolute_minute: int,
	_to_absolute_minute: int,
	_reason: StringName
) -> void:
	_ensure_offer_for_current_date()
	_refresh_presence()


func _reset_for_date(date_key: String) -> void:
	if date_key.is_empty():
		return
	_roll_daily_offer(date_key)
	if is_instance_valid(_dealer):
		_despawn_dealer(false)
	_refresh_presence()


func _ensure_offer_for_current_date() -> void:
	var current_date := _get_current_date()
	var offer_product := get_offer_product()
	if (
		offer_date != current_date
		or offer_product == null
		or not offer_product.is_brick()
		or remaining_stock < 0
		or remaining_stock > MAXIMUM_DAILY_STOCK
	):
		_roll_daily_offer(current_date)


func _roll_daily_offer(date_key: String) -> void:
	var brick_products := EconomyCatalog.get_brick_products()
	offer_date = date_key
	defeated_today = false
	if brick_products.is_empty():
		offer_product_id = &""
		remaining_stock = 0
		return
	var offer_product := brick_products[
		_random.randi_range(0, brick_products.size() - 1)
	]
	offer_product_id = offer_product.product_id
	remaining_stock = _random.randi_range(
		MINIMUM_DAILY_STOCK,
		MAXIMUM_DAILY_STOCK
	)


func _refresh_presence() -> void:
	if not _initialized:
		return
	_ensure_offer_for_current_date()
	var should_exist := (
		_territory_stats.reputation >= REQUIRED_REPUTATION
		and not defeated_today
	)
	if not should_exist:
		if is_instance_valid(_dealer) and not _dealer.is_defeated():
			_despawn_dealer(true)
		return
	if is_instance_valid(_dealer):
		_apply_offer_to_dealer()
		return
	_spawn_dealer()


func _spawn_dealer() -> void:
	if wholesaler_scene == null:
		push_error("Wholesaler spawn point %s has no NPC scene." % name)
		return
	var spawned := wholesaler_scene.instantiate() as DealerNPC
	if spawned == null:
		push_error("Wholesaler scene at %s does not instantiate DealerNPC." % name)
		return
	spawned.name = "WholesalerNPC"
	add_child(spawned)
	spawned.position = Vector3.ZERO
	_dealer = spawned
	var role := spawned.get_role_component()
	if role != null:
		if not role.stock_changed.is_connected(_on_dealer_stock_changed):
			role.stock_changed.connect(_on_dealer_stock_changed)
	_apply_offer_to_dealer()
	if not spawned.damageable.depleted.is_connected(_on_dealer_defeated):
		spawned.damageable.depleted.connect(_on_dealer_defeated)
	spawned.tree_exited.connect(_on_dealer_tree_exited.bind(spawned))


func _despawn_dealer(preserve_stock: bool) -> void:
	if not is_instance_valid(_dealer):
		_dealer = null
		return
	var departing := _dealer
	if preserve_stock and not departing.is_defeated():
		_sync_stock_from_dealer()
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null:
		var shop_menu := player.get_node_or_null("DealerShopMenu")
		if shop_menu != null and shop_menu.has_method("close_if_open_for"):
			shop_menu.call("close_if_open_for", departing)
	var role := departing.get_role_component()
	if role != null:
		role.deactivate()
	departing.visible = false
	_dealer = null
	departing.queue_free()


func _apply_offer_to_dealer() -> void:
	if not is_instance_valid(_dealer) or _dealer.is_defeated():
		return
	var role := _dealer.get_role_component()
	if role == null:
		return
	_suppress_stock_sync = true
	role.territory_id = territory_id
	role.configure_wholesaler_offer(get_offer_product(), remaining_stock)
	_suppress_stock_sync = false


func _on_dealer_stock_changed() -> void:
	if not _suppress_stock_sync:
		_sync_stock_from_dealer()


func _sync_stock_from_dealer() -> void:
	if not is_instance_valid(_dealer):
		return
	var offer_product := get_offer_product()
	if offer_product == null:
		remaining_stock = 0
		return
	remaining_stock = clampi(
		_dealer.get_stock_quantity(offer_product),
		0,
		MAXIMUM_DAILY_STOCK
	)


func _on_dealer_defeated(
	source: Node,
	_hit_position: Vector3,
	_hit_direction: Vector3
) -> void:
	defeated_today = true
	remaining_stock = 0
	if _is_player_source(source):
		_territory_stats.add_reputation(
			-PLAYER_KILL_REPUTATION_PENALTY
		)


func _on_dealer_tree_exited(departed: DealerNPC) -> void:
	if departed != _dealer:
		return
	_dealer = null
	if not defeated_today:
		call_deferred("_refresh_presence")


func _find_territory_stats() -> TerritoryStatsComponent:
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.territory_id == territory_id:
			return boundary.stats
	return null


func _get_current_date() -> String:
	return _world_time.get_date_key() if _world_time != null else ""


func _is_player_source(source: Node) -> bool:
	var current := source
	while current != null:
		if current.is_in_group(&"player"):
			return true
		current = current.get_parent()
	return false
