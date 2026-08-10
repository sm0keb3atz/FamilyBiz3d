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
		"start_robbery":
			_start_robbery(parts, 1)
		"end_robbery":
			_end_robbery(parts, 1)
		"clear_event_cooldown":
			_clear_event_cooldown(parts, 1)
		"weather", "set_weather":
			_execute_weather(parts, 1)
		"weather_status":
			_print_weather_status()
		"lightning":
			_trigger_lightning()
		"give":
			_execute_spaced_give(parts)
		"set_time":
			_set_time(command.trim_prefix(parts[0]).strip_edges())
		"set_date":
			_set_date(command.trim_prefix(parts[0]).strip_edges())
		"set":
			if parts.size() >= 3 and parts[1].to_lower() == "time":
				_set_time(" ".join(parts.slice(2)))
			elif parts.size() >= 3 and parts[1].to_lower() == "date":
				_set_date(" ".join(parts.slice(2)))
			elif parts.size() >= 3 and parts[1].to_lower() == "rep":
				_change_reputation(parts, 2, true)
			else:
				_print_error("Unknown command. Type help.")
		"start":
			if parts.size() >= 3 and parts[1].to_lower() == "gang" and parts[2].to_lower() == "war":
				_start_gang_war(parts, 3)
			elif parts.size() >= 2 and parts[1].to_lower() == "robbery":
				_start_robbery(parts, 2)
			else:
				_print_error("Unknown command. Type help.")
		"end":
			if parts.size() >= 3 and parts[1].to_lower() == "gang" and parts[2].to_lower() == "war":
				_end_gang_war(parts, 3)
			elif parts.size() >= 2 and parts[1].to_lower() == "robbery":
				_end_robbery(parts, 2)
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
	var success := (
		wallet.add_clean(amount, true, "Debug Adjustment", "Console cash grant")
		if clean
		else wallet.add_dirty(amount, true, "Debug Adjustment", "Console cash grant")
	)
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


func _set_date(value: String) -> void:
	var time_component := _get_world_time()
	if time_component == null:
		_print_error("World time component was not found.")
		return
	var normalized := value.strip_edges()
	var separator := "-" if normalized.contains("-") else "/"
	var pieces := normalized.split(separator, false)
	if pieces.size() != 3:
		_print_error("Use YYYY-MM-DD or MM/DD/YYYY, for example 2026-07-29.")
		return
	for piece in pieces:
		if not piece.is_valid_int():
			_print_error("The date must contain only whole numbers.")
			return
	var value_year := 0
	var value_month := 0
	var value_day := 0
	if separator == "-":
		value_year = int(pieces[0])
		value_month = int(pieces[1])
		value_day = int(pieces[2])
	else:
		value_month = int(pieces[0])
		value_day = int(pieces[1])
		value_year = int(pieces[2])
	if not time_component.set_calendar_date(
		value_year,
		value_month,
		value_day
	):
		_print_error("That calendar date is not valid.")
		return
	_print_success(
		"Date set to %s. Pending court dates remain on their exact scheduled dates."
		% time_component.get_formatted_date_with_year()
	)


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


func _start_robbery(parts: PackedStringArray, territory_index: int) -> void:
	var encounter := _get_territory_encounter()
	if encounter == null:
		_print_error("Territory encounter controller was not found.")
		return
	var territory_id: StringName = &""
	if parts.size() > territory_index:
		var boundary := _get_territory_boundary(parts[territory_index])
		if boundary == null:
			_print_error("No territory found. Use hood_east or hood_west.")
			return
		territory_id = boundary.territory_id
	if not encounter.debug_start_robbery(territory_id):
		_print_error(
			"Robbery could not start. Be in an unowned territory with stealable loot."
		)
		return
	_print_success("Robbery started in %s." % String(
		encounter.get_active_territory_id()
	).replace("_", " ").capitalize())
	close()


func _end_robbery(parts: PackedStringArray, result_index: int) -> void:
	if parts.size() <= result_index:
		_print_error("Use: end_robbery win or lose")
		return
	var result := parts[result_index].to_lower()
	if result not in ["win", "won", "lose", "loss", "lost"]:
		_print_error("Result must be win or lose.")
		return
	var encounter := _get_territory_encounter()
	if encounter == null or not encounter.debug_finish_robbery(
		result in ["win", "won"]
	):
		_print_error("There is no active robbery.")
		return
	_print_success(
		"Robbery ended as a %s."
		% ("win" if result in ["win", "won"] else "loss")
	)


func _clear_event_cooldown(
	parts: PackedStringArray,
	territory_index: int
) -> void:
	var encounter := _get_territory_encounter()
	if encounter == null:
		_print_error("Territory encounter controller was not found.")
		return
	var boundary := _get_territory_boundary(
		parts[territory_index] if parts.size() > territory_index else ""
	)
	if boundary == null:
		_print_error("No territory found. Use hood_east or hood_west.")
		return
	encounter.debug_clear_event_cooldown(boundary.territory_id)
	_print_success("%s encounter cooldown cleared." % String(
		boundary.territory_id
	).replace("_", " ").capitalize())


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


func _get_weather_system() -> WeatherSystem:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("WeatherSystem") as WeatherSystem


func _execute_weather(parts: PackedStringArray, value_index: int) -> void:
	var weather := _get_weather_system()
	if weather == null:
		_print_error("Weather system was not found.")
		return
	if parts.size() <= value_index:
		_print_weather_status()
		return
	var requested := parts[value_index].to_lower()
	if requested == "auto":
		var enabled := true
		if parts.size() > value_index + 1:
			var toggle := parts[value_index + 1].to_lower()
			if toggle not in ["on", "off"]:
				_print_error("Use: weather auto on or weather auto off")
				return
			enabled = toggle == "on"
		weather.set_random_weather_enabled(enabled)
		_print_success("Random weather %s." % ("enabled" if enabled else "disabled"))
		return
	if requested == "random":
		var selected := weather.force_random_weather()
		_print_success("Random weather started: %s." % String(selected).replace("_", " ").capitalize())
		return
	if not weather.debug_set_weather(StringName(requested)):
		_print_error("Use: weather clear|rain|heavy_rain|storm|random|auto on|off")
		return
	_print_success("Weather changing to %s (manual mode)." % requested.replace("_", " ").capitalize())


func _print_weather_status() -> void:
	var weather := _get_weather_system()
	if weather == null:
		_print_error("Weather system was not found.")
		return
	_print_info("[b]Weather:[/b] %s" % weather.get_status_text())


func _trigger_lightning() -> void:
	var weather := _get_weather_system()
	if weather == null:
		_print_error("Weather system was not found.")
		return
	weather.debug_trigger_lightning()
	_print_success("Lightning flash triggered.")


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
	_print_info("[b]set_date 2026-07-29[/b] or [b]set_date 07/29/2026[/b]")
	_print_info("Spaced forms also work: [b]set time 14:30[/b] and [b]set date 2026-07-29[/b]")
	_print_info("[b]set_rep -50 [hood_east][/b]  - set territory Rep")
	_print_info("[b]give_rep 15 [hood_east][/b]  - add or subtract Rep")
	_print_info("[b]territory_status [hood_east][/b]  - show territory state")
	_print_info("[b]start_gang_war [1-4][/b]  - force a gang war and close console")
	_print_info("[b]end_gang_war win|lose[/b]  - force the active result")
	_print_info("[b]clear_gang_war_cooldown[/b]  - allow another war")
	_print_info("[b]start_robbery [territory][/b]  - force a robbery")
	_print_info("[b]end_robbery win|lose[/b]  - force the robbery result")
	_print_info("[b]clear_event_cooldown [territory][/b]  - clear shared cooldown")
	_print_info("[b]weather clear|rain|heavy_rain|storm[/b]  - set weather manually")
	_print_info("[b]weather random[/b] or [b]weather auto on|off[/b]  - control random events")
	_print_info("[b]weather_status[/b]  - show current weather and intensity")
	_print_info("[b]lightning[/b]  - trigger a lightning flash")
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
