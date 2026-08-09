extends SceneTree

class FakeGirlfriend extends CustomerNPC:
	var assigned_slot := -1
	var started_following := false
	var sent_home := false

	func get_customer_level() -> int:
		return 1

	func begin_girlfriend_relationship(
		_player: CharacterBody3D,
		_roster: PlayerGirlfriendComponent,
		_display_name: String,
		start_following: bool,
		follow_slot: int
	) -> void:
		started_following = start_following
		assigned_slot = follow_slot

	func set_girlfriend_follow_slot(slot: int) -> void:
		assigned_slot = slot

	func call_girlfriend(_player: CharacterBody3D, follow_slot: int) -> void:
		started_following = true
		sent_home = false
		assigned_slot = follow_slot

	func send_girlfriend_home() -> void:
		started_following = false
		sent_home = true

	func end_girlfriend_relationship() -> void:
		started_following = false


var _dummy_slot := -1
var _dummy_released := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := (load("res://Scenes/Player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame
	var stats := player.get_node("Components/StatsComponent") as PlayerStatsComponent
	var entourage := player.get_node(
		"Components/EntourageComponent"
	) as PlayerEntourageComponent
	var girlfriends := player.get_node(
		"Components/GirlfriendComponent"
	) as PlayerGirlfriendComponent
	assert(stats.motion == 1)
	assert(entourage.get_limit() == 1)

	var girlfriend := FakeGirlfriend.new()
	girlfriends._entries.append({
		"npc": girlfriend,
		"name": "Motion Test",
		"level": 1,
		"status": PlayerGirlfriendComponent.STATUS_HOME,
		"relationship": 0,
		"relationship_elapsed": 0.0,
	})
	assert(girlfriends.call_girlfriend(girlfriend))
	assert(entourage.get_active_count() == 1)
	assert(girlfriend.assigned_slot == 0)

	var dummy_dealer := Node.new()
	assert(not entourage.try_register_follower(
		dummy_dealer,
		Callable(self, "_set_dummy_slot"),
		Callable(self, "_release_dummy").bind(entourage, dummy_dealer)
	))
	assert(girlfriends.send_home(girlfriend))
	assert(entourage.try_register_follower(
		dummy_dealer,
		Callable(self, "_set_dummy_slot"),
		Callable(self, "_release_dummy").bind(entourage, dummy_dealer)
	))
	assert(_dummy_slot == 0)

	stats.import_save_data({"motion": 2})
	assert(girlfriends.call_girlfriend(girlfriend))
	assert(entourage.get_active_count() == 2)
	assert(_dummy_slot == 0)
	assert(girlfriend.assigned_slot == 1)
	entourage.unregister_follower(dummy_dealer)
	assert(girlfriend.assigned_slot == 0)

	assert(entourage.try_register_follower(
		dummy_dealer,
		Callable(self, "_set_dummy_slot"),
		Callable(self, "_release_dummy").bind(entourage, dummy_dealer)
	))
	var appearance := player.get_node(
		"Components/AppearanceComponent"
	) as PlayerAppearanceComponent
	appearance.set_option(PlayerAppearanceComponent.SLOT_SHOES, 1)
	var recruited_at_capacity := FakeGirlfriend.new()
	assert(girlfriends.recruit(recruited_at_capacity))
	var recruited_entry: Dictionary = girlfriends.get_roster().back() as Dictionary
	assert(recruited_entry.status == PlayerGirlfriendComponent.STATUS_HOME)
	assert(not recruited_at_capacity.started_following)

	stats.import_save_data({})
	assert(stats.motion == 1)
	assert(entourage.get_active_count() == 1)
	assert(_dummy_released)

	girlfriend.free()
	recruited_at_capacity.free()
	dummy_dealer.free()
	print("MOTION_ATTRIBUTE_SMOKE_TEST_PASS")
	quit(0)


func _set_dummy_slot(slot: int) -> void:
	_dummy_slot = slot


func _release_dummy(
	entourage: PlayerEntourageComponent,
	dummy_dealer: Node
) -> void:
	_dummy_released = true
	entourage.unregister_follower(dummy_dealer)
