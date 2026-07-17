class_name DebugCommandConsole
extends CanvasLayer

@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var wallet := get_node(wallet_component_path) as PlayerWalletComponent
@onready var menu_controller := get_node(menu_controller_path) as PlayerMenuController

var _root: Control
var _output: RichTextLabel
var _input_line: LineEdit
var _is_open := false
var _history: Array[String] = []
var _history_index := 0


func _ready() -> void:
	_build_ui()
	_root.visible = false


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_QUOTELEFT:
		if _is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif _is_open and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif _is_open and event.physical_keycode == KEY_UP:
		_move_history(-1)
		get_viewport().set_input_as_handled()
	elif _is_open and event.physical_keycode == KEY_DOWN:
		_move_history(1)
		get_viewport().set_input_as_handled()


func open() -> void:
	if not menu_controller.request_open(&"debug_console"):
		return
	_is_open = true
	_root.visible = true
	_history_index = _history.size()
	_input_line.clear()
	_input_line.call_deferred("grab_focus")


func close() -> void:
	if not _is_open or not menu_controller.close(&"debug_console"):
		return
	_is_open = false
	_root.visible = false
	_input_line.release_focus()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.36)
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = -18
	panel.offset_bottom = 440
	panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "DEVELOPER COMMAND CONSOLE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))
	header.add_child(title)
	var hint := Label.new()
	hint.text = "` or ESC to close"
	hint.add_theme_color_override("font_color", Color(0.55, 0.62, 0.58))
	header.add_child(hint)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_size_override("normal_font_size", 16)
	box.add_child(_output)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Enter command..."
	_input_line.custom_minimum_size.y = 46
	_input_line.add_theme_font_size_override("font_size", 18)
	_input_line.text_submitted.connect(_submit_command)
	box.add_child(_input_line)
	_print_info("Type [b]help[/b] to list commands.")


func _submit_command(raw_command: String) -> void:
	var command := raw_command.strip_edges()
	_input_line.clear()
	if command.is_empty():
		return
	_history.append(command)
	_history_index = _history.size()
	_output.append_text("[color=#8fa69a]> %s[/color]\n" % command)
	_execute(command)


func _execute(command: String) -> void:
	var parts := command.split(" ", false)
	if parts.is_empty():
		return
	var verb := parts[0].to_lower()
	match verb:
		"help":
			_print_help()
		"clear":
			_output.clear()
		"give_money", "give_dirty_money":
			_give_money(parts, 1, false)
		"give_clean_money":
			_give_money(parts, 1, true)
		"give_rep":
			_change_reputation(parts, 1, false)
		"set_rep":
			_change_reputation(parts, 1, true)
		"territory_status":
			_print_territory_status(parts, 1)
		"start_gang_war":
			_start_gang_war(parts, 1)
		"end_gang_war":
			_end_gang_war(parts, 1)
		"clear_gang_war_cooldown":
			_clear_gang_war_cooldown()
		"give":
			_execute_spaced_give(parts)
		"set_time":
			_set_time(command.trim_prefix(parts[0]).strip_edges())
		"set":
			if parts.size() >= 3 and parts[1].to_lower() == "time":
				_set_time(" ".join(parts.slice(2)))
			elif parts.size() >= 3 and parts[1].to_lower() == "rep":
				_change_reputation(parts, 2, true)
			else:
				_print_error("Unknown command. Type help.")
		"start":
			if parts.size() >= 3 and parts[1].to_lower() == "gang" and parts[2].to_lower() == "war":
				_start_gang_war(parts, 3)
			else:
				_print_error("Unknown command. Type help.")
		"end":
			if parts.size() >= 3 and parts[1].to_lower() == "gang" and parts[2].to_lower() == "war":
				_end_gang_war(parts, 3)
			else:
				_print_error("Unknown command. Type help.")
		_:
			_print_error("Unknown command: %s" % parts[0])


func _execute_spaced_give(parts: PackedStringArray) -> void:
	if parts.size() >= 3 and parts[1].to_lower() == "money":
		_give_money(parts, 2, false)
	elif parts.size() >= 4 and parts[1].to_lower() == "clean" and parts[2].to_lower() == "money":
		_give_money(parts, 3, true)
	elif parts.size() >= 3 and parts[1].to_lower() == "rep":
		_change_reputation(parts, 2, false)
	else:
		_print_error("Use: give money <amount>, give clean money <amount>, or give rep <amount>")


func _give_money(parts: PackedStringArray, amount_index: int, clean: bool) -> void:
	if parts.size() <= amount_index or not parts[amount_index].is_valid_int():
		_print_error("Amount must be a positive whole number.")
		return
	var amount := int(parts[amount_index])
	if amount <= 0:
		_print_error("Amount must be greater than zero.")
		return
	var success := wallet.add_clean(amount) if clean else wallet.add_dirty(amount)
	if not success:
		_print_error("Money could not be added.")
		return
	_print_success("Added $%d %s money." % [amount, "clean" if clean else "dirty"])


func _set_time(value: String) -> void:
	var time_component := _get_world_time()
	if time_component == null:
		_print_error("World time component was not found.")
		return
	var normalized := value.strip_edges().to_upper()
	var suffix := ""
	if normalized.ends_with(" AM") or normalized.ends_with(" PM"):
		suffix = normalized.right(2)
		normalized = normalized.left(-3).strip_edges()
	var pieces := normalized.split(":", false)
	if pieces.is_empty() or pieces.size() > 2 or not pieces[0].is_valid_int():
		_print_error("Use 24-hour time like 14:30 or 12-hour time like 2:30 PM.")
		return
	var hour := int(pieces[0])
	var minute := 0
	if pieces.size() == 2:
		if not pieces[1].is_valid_int():
			_print_error("Minutes must be between 00 and 59.")
			return
		minute = int(pieces[1])
	if not suffix.is_empty():
		if hour < 1 or hour > 12:
			_print_error("12-hour time must use an hour from 1 to 12.")
			return
		hour %= 12
		if suffix == "PM":
			hour += 12
	if not time_component.set_time_of_day(hour, minute):
		_print_error("Time must be between 00:00 and 23:59.")
		return
	_print_success("Time set to %s." % time_component.get_formatted_time())


func _change_reputation(
	parts: PackedStringArray,
	value_index: int,
	set_value: bool
) -> void:
	if parts.size() <= value_index or not parts[value_index].is_valid_float():
		_print_error("Reputation must be a number from -100 to 100.")
		return
	var boundary := _get_territory_boundary(
		parts[value_index + 1] if parts.size() > value_index + 1 else ""
	)
	if boundary == null or boundary.stats == null:
		_print_error("No territory found. Use hood_east or hood_west.")
		return
	var amount := float(parts[value_index])
	if set_value:
		boundary.stats.set_reputation(amount)
	else:
		boundary.stats.add_reputation(amount)
	_print_success("%s Rep is now %.1f." % [
		String(boundary.territory_id).replace("_", " ").capitalize(),
		boundary.stats.reputation,
	])


func _start_gang_war(parts: PackedStringArray, tier_index: int) -> void:
	var encounter := _get_territory_encounter()
	if encounter == null:
		_print_error("Territory encounter controller was not found.")
		return
	var tier := 0
	if parts.size() > tier_index:
		if not parts[tier_index].is_valid_int():
			_print_error("Gang-war tier must be 1, 2, 3, or 4.")
			return
		tier = int(parts[tier_index])
		if tier < 1 or tier > 4:
			_print_error("Gang-war tier must be 1, 2, 3, or 4.")
			return
	if not encounter.debug_start_gang_war(tier):
		_print_error("A gang war is already active or could not be started.")
		return
	_print_success("Gang war started at tier %d." % encounter.get_active_tier())
	close()


func _end_gang_war(parts: PackedStringArray, result_index: int) -> void:
	if parts.size() <= result_index:
		_print_error("Use: end_gang_war win or end_gang_war lose")
		return
	var result := parts[result_index].to_lower()
	if result not in ["win", "won", "lose", "loss", "lost"]:
		_print_error("Result must be win or lose.")
		return
	var encounter := _get_territory_encounter()
	if encounter == null or not encounter.debug_finish_gang_war(result in ["win", "won"]):
		_print_error("There is no active gang war.")
		return
	_print_success("Gang war ended as a %s." % ("win" if result in ["win", "won"] else "loss"))


func _clear_gang_war_cooldown() -> void:
	var encounter := _get_territory_encounter()
	if encounter == null:
		_print_error("Territory encounter controller was not found.")
		return
	encounter.debug_clear_gang_war_cooldown()
	_print_success("Hood East gang-war cooldown cleared.")


func _print_territory_status(parts: PackedStringArray, territory_index: int) -> void:
	var boundary := _get_territory_boundary(
		parts[territory_index] if parts.size() > territory_index else ""
	)
	if boundary == null or boundary.stats == null:
		_print_error("No territory found. Use hood_east or hood_west.")
		return
	var encounter := _get_territory_encounter()
	var wins := encounter.get_war_wins(boundary.territory_id) if encounter != null else 0
	var cooldown := encounter.get_cooldown_minutes(boundary.territory_id) if encounter != null else 0
	_print_info("[b]%s[/b] - Rep %.1f, Heat %.1f, Owner %d, War wins %d/3, Cooldown %d min" % [
		boundary.display_name,
		boundary.stats.reputation,
		boundary.stats.heat,
		int(boundary.stats.owner_faction),
		wins,
		cooldown,
	])


func _get_territory_boundary(requested: String) -> TerritoryBoundary:
	var territory_id := requested.strip_edges().to_lower()
	if territory_id == "east":
		territory_id = "hood_east"
	elif territory_id == "west":
		territory_id = "hood_west"
	if territory_id.is_empty():
		var current_player := wallet.get_parent().get_parent() as CharacterBody3D
		if current_player == null:
			return null
		return TerritoryBoundary.find_at_position(
			get_tree(), current_player.global_position
		)
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and String(boundary.territory_id) == territory_id:
			return boundary
	return null


func _get_territory_encounter() -> TerritoryEncounterController:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null(
		"TerritoryEncounterController"
	) as TerritoryEncounterController


func _get_world_time() -> WorldTimeComponent:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("WorldTimeComponent") as WorldTimeComponent


func _move_history(direction: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + direction, 0, _history.size())
	_input_line.text = "" if _history_index == _history.size() else _history[_history_index]
	_input_line.caret_column = _input_line.text.length()


func _print_help() -> void:
	_print_info("[b]give_money 500[/b]  - add dirty cash")
	_print_info("[b]give_clean_money 500[/b]  - add clean bank money")
	_print_info("[b]set_time 14:30[/b] or [b]set_time 2:30 PM[/b]")
	_print_info("Spaced forms also work: [b]give money 500[/b], [b]give clean money 500[/b], [b]set time 14:30[/b]")
	_print_info("[b]set_rep -50 [hood_east][/b]  - set territory Rep")
	_print_info("[b]give_rep 15 [hood_east][/b]  - add or subtract Rep")
	_print_info("[b]territory_status [hood_east][/b]  - show territory state")
	_print_info("[b]start_gang_war [1-4][/b]  - force a gang war and close console")
	_print_info("[b]end_gang_war win|lose[/b]  - force the active result")
	_print_info("[b]clear_gang_war_cooldown[/b]  - allow another war")
	_print_info("[b]clear[/b]  - clear console output")


func _print_success(message: String) -> void:
	_output.append_text("[color=#62d98a]%s[/color]\n" % message)


func _print_error(message: String) -> void:
	_output.append_text("[color=#ff6b61]%s[/color]\n" % message)


func _print_info(message: String) -> void:
	_output.append_text("[color=#b8c7bf]%s[/color]\n" % message)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.02, 0.97)
	style.border_color = Color(0.18, 0.62, 0.34, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 14
	return style
