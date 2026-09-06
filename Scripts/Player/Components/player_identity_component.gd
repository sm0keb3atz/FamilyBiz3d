class_name PlayerIdentityComponent
extends Node

signal display_name_changed(display_name: String)

const DEFAULT_DISPLAY_NAME := "Player"
const MIN_NAME_LENGTH := 2
const MAX_NAME_LENGTH := 24

var _display_name := DEFAULT_DISPLAY_NAME


func set_display_name(value: String) -> bool:
	var sanitized := value.strip_edges()
	if not is_valid_display_name(sanitized):
		return false
	if sanitized == _display_name:
		return true
	_display_name = sanitized
	display_name_changed.emit(_display_name)
	return true


func get_display_name() -> String:
	return _display_name


func export_save_data() -> Dictionary:
	return {"display_name": _display_name}


func import_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var saved_name := str(data.get("display_name", "")).strip_edges()
	if is_valid_display_name(saved_name):
		set_display_name(saved_name)


func reset_to_new_game() -> void:
	_display_name = DEFAULT_DISPLAY_NAME
	display_name_changed.emit(_display_name)


static func is_valid_display_name(value: String) -> bool:
	var sanitized := value.strip_edges()
	if (
		sanitized.length() < MIN_NAME_LENGTH
		or sanitized.length() > MAX_NAME_LENGTH
	):
		return false
	for character in sanitized:
		if character.unicode_at(0) < 32:
			return false
	return true
