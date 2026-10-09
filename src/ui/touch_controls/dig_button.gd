# File: src/ui/touch_controls/dig_button.gd
# Purpose: show the Dig button with the gold square, and play the dig.

extends Button

var _action_tile: CanvasItem
var _player: Node

func _ready() -> void:
	_action_tile = get_tree().get_first_node_in_group("action_tile")
	_player = get_tree().get_first_node_in_group("player")
	visible = false
	pressed.connect(_on_pressed)

func _process(_delta: float) -> void:
	if _action_tile == null:
		return
	visible = _action_tile.visible

func _on_pressed() -> void:
	if _player != null:
		_player.dig()
