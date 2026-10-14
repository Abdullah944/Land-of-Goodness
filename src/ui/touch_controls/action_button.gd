# File: src/ui/touch_controls/action_button.gd
# Purpose: use the tool equipped in the five squares.

extends Button

var _action_tile: Node
var _player: Node
var _inventory: Node
var _tools: Node
var _hoe_icon: Texture2D

func _ready() -> void:
	_action_tile = get_tree().get_first_node_in_group("action_tile")
	_player = get_tree().get_first_node_in_group("player")
	_inventory = get_tree().get_first_node_in_group("inventory")
	_tools = get_tree().get_first_node_in_group("tool_bar")
	_hoe_icon = icon
	visible = false
	pressed.connect(_on_pressed)

func _process(_delta: float) -> void:
	var pack := _pack_in_front()
	if pack != null:
		visible = true
		icon = pack.item.icon
		return
	if _tool_is(&"hoe") and _action_tile != null and _action_tile.visible:
		visible = true
		icon = _hoe_icon
		return
	if _tool_is(&"seed") and _can_plant():
		visible = true
		icon = _inventory.equipped_icon()
		return
	visible = false

func _on_pressed() -> void:
	if _player == null:
		return
	var pack := _pack_in_front()
	if pack != null:
		_player.pickup(pack)
	elif _tool_is(&"hoe"):
		_player.dig()
	elif _tool_is(&"seed") and _can_plant():
		_action_tile.plant_here()

func _tool_is(tool_name: StringName) -> bool:
	return _tools != null and _tools.tool_id() == tool_name

func _can_plant() -> bool:
	return _action_tile != null and _inventory != null and _action_tile.can_plant() and _inventory.has_seed_equipped()

func _pack_in_front() -> Node:
	if _player == null:
		return null
	for pack in get_tree().get_nodes_in_group("pickup"):
		if pack.has_method("is_in_front_of") and pack.is_in_front_of(_player):
			return pack
	return null