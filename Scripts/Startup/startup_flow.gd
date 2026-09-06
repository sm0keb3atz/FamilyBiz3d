class_name StartupFlowController
extends Node

const MAIN_MENU_SCENE := "res://Scenes/UI/StartupMenu.tscn"
const CHARACTER_CREATOR_SCENE := "res://Scenes/UI/CharacterCreator.tscn"
const LOADING_SCREEN_SCENE := "res://Scenes/UI/LoadingScreen.tscn"
const WORLD_SCENE := "res://Scenes/Maps/World/world.tscn"
const SAVE_PATH := "user://family_business_save.json"
const SUPPORTED_SAVE_VERSION := 20

enum LaunchMode {
	NONE,
	NEW_GAME,
	CONTINUE,
}

var launch_mode := LaunchMode.NONE
var pending_profile: Dictionary = {}
var _last_error := ""


func show_main_menu(error_message := "") -> void:
	launch_mode = LaunchMode.NONE
	pending_profile.clear()
	_last_error = error_message
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("Could not open the startup menu: %s" % error_string(error))


func show_character_creator() -> void:
	var error := get_tree().change_scene_to_file(CHARACTER_CREATOR_SCENE)
	if error != OK:
		show_main_menu("The character creator could not be opened.")


func begin_new_game(profile: Dictionary) -> void:
	launch_mode = LaunchMode.NEW_GAME
	pending_profile = profile.duplicate(true)
	_open_loading_screen()


func begin_continue() -> void:
	launch_mode = LaunchMode.CONTINUE
	pending_profile.clear()
	_open_loading_screen()


func has_valid_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return false
	var data := parsed as Dictionary
	var version := int(data.get("version", -1))
	return (
		version >= 1
		and version <= SUPPORTED_SAVE_VERSION
		and data.get("player", null) is Dictionary
		and data.get("territories", null) is Dictionary
	)


func consume_last_error() -> String:
	var result := _last_error
	_last_error = ""
	return result


func apply_pending_to_world(world: Node) -> bool:
	if world == null:
		_last_error = "The game world could not be created."
		return false
	var controller := world.get_node_or_null("WorldController") as WorldController
	if controller == null:
		_last_error = "The game world is missing its save controller."
		return false
	if launch_mode == LaunchMode.CONTINUE:
		if not controller.load_game():
			_last_error = "The saved game could not be loaded."
			return false
	elif launch_mode == LaunchMode.NEW_GAME:
		if not _apply_new_profile(controller.player):
			return false
		if not controller.save_game():
			_last_error = "The new character could not be saved."
			return false
	else:
		_last_error = "No startup action was selected."
		return false
	launch_mode = LaunchMode.NONE
	pending_profile.clear()
	_last_error = ""
	return true


func get_last_error() -> String:
	return _last_error


func _open_loading_screen() -> void:
	var error := get_tree().change_scene_to_file(LOADING_SCREEN_SCENE)
	if error != OK:
		show_main_menu("The loading screen could not be opened.")


func _apply_new_profile(player: Node) -> bool:
	if player == null:
		_last_error = "The new player could not be created."
		return false
	var identity := player.get_node_or_null(
		"Components/IdentityComponent"
	) as PlayerIdentityComponent
	var appearance := player.get_node_or_null(
		"Components/AppearanceComponent"
	) as PlayerAppearanceComponent
	var wardrobe := player.get_node_or_null(
		"Components/WardrobeComponent"
	) as PlayerWardrobeComponent
	if identity == null or appearance == null or wardrobe == null:
		_last_error = "The player customization components are unavailable."
		return false
	identity.import_save_data(
		pending_profile.get("identity", {}) as Dictionary
	)
	appearance.import_save_data(
		pending_profile.get("appearance", {}) as Dictionary
	)
	wardrobe.import_save_data(
		pending_profile.get("wardrobe", {}) as Dictionary
	)
	return true
