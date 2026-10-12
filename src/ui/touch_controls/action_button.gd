# File: src/ui/touch_controls/action_button.gd
# Purpose: show the right button for dig, pickup, or plant.

extends Button

var _action_tile: Node
var _player: Node
var _inventory: Node
var _hoe_icon: Texture2D

func _ready() -> void:
	_action_tile = get_tree().get_first_node_in_group("action_tile")
	_player = get_tree().get_first_node_in_group("player")
	_inventory = get_tree().get_first_node_in_group("inventory")
	_hoe_icon = icon
	visible = false
	pressed.connect(_on_pressed)

func _process(_delta: float) -> void:
	var pack := _pack_in_front()
	if pack != null:
		visible = true
		icon = pack.item.icon
		return
	if _can_plant():
		visible = true
		icon = _inventory.equipped_icon()
		return
	icon = _hoe_icon
	visible = _action_tile != null and _action_tile.visible

func _on_pressed() -> void:
	if _player == null:
		return
	var pack := _pack_in_front()
	if pack != null:
		_player.pickup(pack)
	elif _can_plant():
		_action_tile.plant_here()
	else:
		_player.dig()

func _can_plant() -> bool:
	return _action_tile != null and _inventory != null and _action_tile.can_plant() and _inventory.has_seed_equipped()

func _pack_in_front() -> Node:
	if _player == null:
		return null
	for pack in get_tree().get_nodes_in_group("pickup"):
		if pack.has_method("is_in_front_of") and pack.is_in_front_of(_player):
			return pack
	return null