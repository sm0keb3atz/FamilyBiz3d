class_name PlayerInventoryMenu
extends CanvasLayer

@export var inventory_component_path := NodePath(
	"../Components/InventoryComponent"
)
@export var menu_controller_path := NodePath("../Components/MenuController")

@onready var menu_root := %MenuRoot as Control
@onready var product_list := %ProductList as VBoxContainer
@onready var empty_label := %EmptyLabel as Label
@onready var inventory := (
	get_node(inventory_component_path) as PlayerInventoryComponent
)
@onready var menu_controller := (
	get_node(menu_controller_path) as PlayerMenuController
)

var _is_open := false


func _ready() -> void:
	inventory.quantity_changed.connect(_on_quantity_changed)
	menu_root.visible = false
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		set_menu_open(not _is_open)
		get_viewport().set_input_as_handled()
	elif (
		_is_open
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_ESCAPE
	):
		set_menu_open(false)
		get_viewport().set_input_as_handled()


func set_menu_open(open: bool) -> void:
	if open:
		if not menu_controller.request_open(&"inventory"):
			return
	elif not menu_controller.close(&"inventory"):
		return

	_is_open = open
	menu_root.visible = _is_open
	if _is_open:
		_refresh()


func _refresh() -> void:
	for child in product_list.get_children():
		child.queue_free()

	var products := inventory.get_known_products()
	empty_label.visible = products.is_empty()
	for product in products:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		var quantity_label := Label.new()
		name_label.text = product.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quantity_label.text = "x%d" % inventory.get_quantity(product)
		quantity_label.add_theme_font_size_override("font_size", 20)
		row.add_child(name_label)
		row.add_child(quantity_label)
		product_list.add_child(row)


func _on_quantity_changed(
	_product: ProductDefinition,
	_quantity: int
) -> void:
	if _is_open:
		_refresh()
