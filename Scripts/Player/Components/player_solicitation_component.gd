class_name PlayerSolicitationComponent
extends Node

@export var player_path := NodePath("../..")
@export var hud_path := NodePath("../../PlayerHUD")
@export var pulse_mesh_path := NodePath(
	"../../CameraPivot/SpringArm3D/Camera3D/SolicitationPulse"
)
@export var wanted_component_path := NodePath("../WantedComponent")
@export_range(1.0, 30.0, 0.5) var solicitation_radius := 8.0
@export_range(0.1, 10.0, 0.1) var pulse_duration := 0.65
@export_range(0.05, 8.0, 0.05) var pulse_width := 0.65
@export_range(0.0, 4.0, 0.05) var pulse_energy := 1.25
@export var pulse_color := Color(0.16, 0.95, 1.0, 0.82)
@export_range(0.0, 1.0, 0.05) var pulse_fade_start := 0.62
@export var solicit_action: StringName = &"solicit"

@onready var player := get_node(player_path) as CharacterBody3D
@onready var hud := get_node(hud_path) as PlayerHUD
@onready var pulse_mesh := get_node_or_null(pulse_mesh_path) as MeshInstance3D
@onready var wanted := get_node(
	wanted_component_path
) as PlayerWantedComponent
@onready var stats := player.get_node(
	"Components/StatsComponent"
) as PlayerStatsComponent
@onready var inventory := player.get_node(
	"Components/InventoryComponent"
) as PlayerInventoryComponent

var _gameplay_enabled := true
var _pulse_tween: Tween
var _pulse_material: ShaderMaterial


func _ready() -> void:
	if pulse_mesh == null:
		push_warning("Solicitation pulse mesh was not found.")
		return
	_pulse_material = pulse_mesh.get_active_material(0) as ShaderMaterial
	pulse_mesh.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _gameplay_enabled and event.is_action_pressed(solicit_action):
		solicit()
		get_viewport().set_input_as_handled()


func set_gameplay_enabled(enabled: bool) -> void:
	_gameplay_enabled = enabled
	set_process_unhandled_input(enabled)


func solicit() -> void:
	_play_pulse()
	wanted.report_solicitation(
		player.global_position,
		solicitation_radius
	)
	var customers := _select_customers()
	if customers.is_empty():
		hud.show_feedback("No customers buying what you carry.")
		return

	var responding_count := 0
	for customer in customers:
		if customer.respond_to_solicitation(player):
			responding_count += 1
	if responding_count == 1:
		hud.show_feedback("A customer is coming over.")
	elif responding_count > 1:
		hud.show_feedback("%d customers are coming over." % responding_count)
	else:
		hud.show_feedback("No customers buying what you carry.")


func _select_customers() -> Array[CustomerNPC]:
	var available := _get_unreserved_inventory()
	var candidates: Array[CustomerNPC] = []
	for node in get_tree().get_nodes_in_group("customer_npc"):
		var customer := node as CustomerNPC
		if customer == null or not customer.can_respond_to_solicitation():
			continue
		var distance := player.global_position.distance_to(customer.global_position)
		if distance <= solicitation_radius:
			candidates.append(customer)
	candidates.sort_custom(func(a: CustomerNPC, b: CustomerNPC) -> bool:
		var a_distance := player.global_position.distance_squared_to(
			a.global_position
		)
		var b_distance := player.global_position.distance_squared_to(
			b.global_position
		)
		return a_distance < b_distance
	)

	var selected: Array[CustomerNPC] = []
	for customer in candidates:
		if selected.size() >= stats.get_hustle_customer_limit():
			break
		var product := _get_largest_available_product(available)
		if product == null:
			break
		var remaining := int(available.get(product.product_id, 0))
		var order_cap := get_customer_inventory_cap(remaining)
		var amount := mini(customer.roll_solicitation_amount(), order_cap)
		if amount <= 0:
			continue
		customer.assign_solicitation_order(product, amount)
		available[product.product_id] = remaining - amount
		selected.append(customer)
	return selected


func get_customer_inventory_cap(available_quantity: int) -> int:
	if available_quantity <= 1:
		return maxi(available_quantity, 0)
	var inventory_share := 0.50 + float(stats.hustle - 1) * 0.025
	return clampi(
		ceili(float(available_quantity) * inventory_share),
		1,
		available_quantity - 1
	)


func _get_unreserved_inventory() -> Dictionary[StringName, int]:
	var available: Dictionary[StringName, int] = {}
	for product in EconomyCatalog.get_gram_products():
		available[product.product_id] = inventory.get_quantity(product)
	for node in get_tree().get_nodes_in_group("customer_npc"):
		var customer := node as CustomerNPC
		if customer == null or not customer.is_committed_to_solicitation(player):
			continue
		if customer.product_wanted == null or customer.product_wanted.is_brick():
			continue
		var product_id := customer.product_wanted.product_id
		available[product_id] = maxi(
			int(available.get(product_id, 0)) - customer.amount_wanted,
			0
		)
	return available


func _get_largest_available_product(
	available: Dictionary[StringName, int]
) -> ProductDefinition:
	var best: ProductDefinition
	var best_quantity := 0
	for product in EconomyCatalog.get_gram_products():
		var quantity := int(available.get(product.product_id, 0))
		if quantity > best_quantity:
			best = product
			best_quantity = quantity
	return best


func _play_pulse() -> void:
	if pulse_mesh == null:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_update_pulse_shader_parameters()
	pulse_mesh.visible = true

	_pulse_tween = create_tween()
	_pulse_tween.set_parallel(true)
	_pulse_tween.tween_method(
		_set_pulse_radius,
		0.0,
		solicitation_radius,
		pulse_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fade_delay := pulse_duration * clampf(pulse_fade_start, 0.0, 0.95)
	_pulse_tween.tween_method(
		_set_pulse_opacity,
		1.0,
		0.0,
		maxf(pulse_duration - fade_delay, 0.01)
	).set_delay(fade_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_pulse_tween.chain().tween_callback(_hide_pulse)


func _update_pulse_shader_parameters() -> void:
	if _pulse_material == null:
		return

	_pulse_material.set_shader_parameter("start_point", player.global_transform)
	_pulse_material.set_shader_parameter("radius", 0.0)
	_pulse_material.set_shader_parameter("pulse_width", pulse_width)
	_pulse_material.set_shader_parameter("pulse_energy", pulse_energy)
	_pulse_material.set_shader_parameter("pulse_opacity", 1.0)
	_pulse_material.set_shader_parameter("pulse_color", pulse_color)


func _set_pulse_radius(radius: float) -> void:
	if _pulse_material != null:
		_pulse_material.set_shader_parameter("radius", radius)


func _set_pulse_opacity(opacity: float) -> void:
	if _pulse_material != null:
		_pulse_material.set_shader_parameter("pulse_opacity", opacity)


func _hide_pulse() -> void:
	_set_pulse_radius(0.0)
	_set_pulse_opacity(0.0)
	if pulse_mesh != null:
		pulse_mesh.visible = false
