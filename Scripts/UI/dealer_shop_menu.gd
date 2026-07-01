class_name DealerShopMenu
extends CanvasLayer

@export var player_path := NodePath("..")
@export var inventory_component_path := NodePath(
	"../Components/InventoryComponent"
)
@export var wallet_component_path := NodePath("../Components/WalletComponent")
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var menu_root := %MenuRoot as Control
@onready var product_name_label := %ProductNameLabel as Label
@onready var price_label := %PriceLabel as Label
@onready var owned_label := %OwnedLabel as Label
@onready var cash_label := %CashLabel as Label
@onready var feedback_label := %FeedbackLabel as Label
@onready var buy_button := %BuyButton as Button
@onready var close_button := %CloseButton as Button
@onready var player := get_node(player_path) as CharacterBody3D
@onready var inventory := (
	get_node(inventory_component_path) as PlayerInventoryComponent
)
@onready var wallet := (
	get_node(wallet_component_path) as PlayerWalletComponent
)
@onready var menu_controller := (
	get_node(menu_controller_path) as PlayerMenuController
)

var _dealer: DealerNPC
var _is_open := false


func _ready() -> void:
	menu_root.visible = false
	buy_button.pressed.connect(_purchase)
	close_button.pressed.connect(close)
	inventory.quantity_changed.connect(_on_inventory_changed)
	wallet.money_changed.connect(_on_money_changed)


func _input(event: InputEvent) -> void:
	if (
		_is_open
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_ESCAPE
	):
		close()
		get_viewport().set_input_as_handled()


func open_for(dealer: DealerNPC) -> void:
	if dealer == null or dealer.product == null:
		return
	if not menu_controller.request_open(&"dealer_shop"):
		return

	_dealer = dealer
	_is_open = true
	menu_root.visible = true
	feedback_label.text = ""
	_refresh()
	buy_button.grab_focus()


func close() -> void:
	if not _is_open or not menu_controller.close(&"dealer_shop"):
		return

	_is_open = false
	_dealer = null
	menu_root.visible = false


func _purchase() -> void:
	if _dealer == null:
		return

	feedback_label.text = _dealer.try_purchase(player)
	_refresh()


func _refresh() -> void:
	if _dealer == null or _dealer.product == null:
		return

	var product := _dealer.product
	product_name_label.text = product.display_name
	price_label.text = "Dealer price: $%d Dirty Cash" % product.dealer_price
	owned_label.text = "Owned: %d" % inventory.get_quantity(product)
	cash_label.text = "Dirty Cash: $%d" % wallet.dirty_cash
	buy_button.disabled = not wallet.can_spend_dirty(product.dealer_price)
	buy_button.text = "BUY 1 — $%d" % product.dealer_price


func _on_inventory_changed(
	_product: ProductDefinition,
	_quantity: int
) -> void:
	if _is_open:
		_refresh()


func _on_money_changed(_dirty_cash: int, _clean_cash: int) -> void:
	if _is_open:
		_refresh()
