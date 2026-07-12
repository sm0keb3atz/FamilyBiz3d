extends SceneTree

const TimeComponentScript := preload("res://Scripts/Gameplay/world_time_component.gd")
const WalletScript := preload("res://Scripts/Player/Components/player_wallet_component.gd")


func _initialize() -> void:
	var time: Node = TimeComponentScript.new()
	var wallet: Node = WalletScript.new()
	root.add_child(time)
	root.add_child(wallet)
	time.connect_wallet(wallet)

	assert(time.get_formatted_date() == "MON JAN 1")
	assert(time.get_formatted_time() == "8:00 AM")
	time.minute_of_day = 0
	time.advance_real_seconds(600.0)
	assert(time.day == 2)
	assert(time.weekday == 1)
	assert(time.minute_of_day == 0)
	assert(time.get_formatted_time() == "12:00 AM")

	time.minute_of_day = 12 * 60
	assert(time.get_formatted_time() == "12:00 PM")
	time.minute_of_day = 13 * 60 + 7
	assert(time.get_formatted_time() == "1:07 PM")

	assert(wallet.add_dirty(250))
	assert(wallet.spend_dirty(70))
	assert(wallet.add_clean(40))
	assert(time.daily_earned == 290)
	assert(time.daily_spent == 70)
	assert(wallet.add_dirty(10, false))
	assert(time.daily_earned == 290)

	var saved: Dictionary = time.export_save_data()
	var restored: Node = TimeComponentScript.new()
	root.add_child(restored)
	restored.import_save_data(saved)
	assert(restored.year == time.year)
	assert(restored.month == time.month)
	assert(restored.day == time.day)
	assert(restored.minute_of_day == time.minute_of_day)
	assert(restored.daily_earned == 290)
	assert(restored.daily_spent == 70)

	var hud_scene := load("res://Scenes/UI/PlayerHUD.tscn") as PackedScene
	assert(hud_scene != null)
	var world_scene := load("res://Scenes/Maps/World/world.tscn") as PackedScene
	assert(world_scene != null)
	print("TIME_CYCLE_SMOKE_TEST_PASS")
	quit(0)
