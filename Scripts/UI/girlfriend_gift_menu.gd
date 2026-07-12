class_name GirlfriendGiftMenu
extends CanvasLayer

const MENU_ID := &"girlfriend_gift"
const GIFTS := [
	{"cost": 10, "gain": 5},
	{"cost": 50, "gain": 20},
	{"cost": 100, "gain": 35},
]

@export var roster_component_path := NodePath("../Components/GirlfriendComponent")
@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

var _roster: PlayerGirlfriendComponent
var _wallet: PlayerWalletComponent
var _menu_controller: PlayerMenuController
var _target: CustomerNPC
var _root: Control
var _title: Label
var _buttons: Array[Button] = []
var _is_open := false


func _ready() -> void:
	_roster = get_node(roster_component_path) as PlayerGirlfriendComponent
	_wallet = get_node(wallet_component_path) as PlayerWalletComponent
	_menu_controller = get_node(menu_controller_path) as PlayerMenuController
	_build_menu()
	_wallet.money_changed.connect(_on_money_changed)
	_roster.roster_changed.connect(_validate_target)
	_root.visible = false


func _input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open_for(npc: CustomerNPC) -> void:
	if npc == null or not npc.can_receive_gift(get_parent() as CharacterBody3D):
		return
	if not _menu_controller.request_open(MENU_ID):
		return
	_target = npc
	_is_open = true
	_root.visible = true
	_refresh()


func close() -> void:
	if not _is_open:
		return
	_menu_controller.close(MENU_ID)
	_is_open = false
	_target = null
	_root.visible = false


func _build_menu() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.55)
	_root.add_child(dimmer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -150)
	panel.custom_minimum_size = Vector2(380, 300)
	_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	content.add_child(_title)
	var cash := Label.new()
	cash.name = "CashLabel"
	cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cash)
	for gift in GIFTS:
		var button := Button.new()
		button.custom_minimum_size.y = 42
		button.text = "GIVE $%d   (+%d RELATIONSHIP)" % [gift["cost"], gift["gain"]]
		button.pressed.connect(_purchase.bind(int(gift["cost"]), int(gift["gain"])))
		content.add_child(button)
		_buttons.append(button)
	var close_button := Button.new()
	close_button.text = "CANCEL"
	close_button.pressed.connect(close)
	content.add_child(close_button)


func _refresh() -> void:
	if not is_instance_valid(_target):
		close()
		return
	_title.text = "GIFT FOR %s" % _target.get_civilian_name().to_upper()
	var cash_label := _root.find_child("CashLabel", true, false) as Label
	cash_label.text = "Dirty Cash: $%d" % _wallet.dirty_cash
	var relationship := _roster.get_relationship(_target)
	for index in _buttons.size():
		_buttons[index].disabled = relationship >= 100 or not _wallet.can_spend_dirty(int(GIFTS[index]["cost"]))


func _purchase(cost: int, gain: int) -> void:
	if is_instance_valid(_target) and _roster.purchase_gift(_target, cost, gain):
		close()
	else:
		_refresh()


func _on_money_changed(_dirty: int, _clean: int) -> void:
	if _is_open:
		_refresh()


func _validate_target() -> void:
	if _is_open and (not is_instance_valid(_target) or not _roster.has_girlfriend(_target)):
		close()
