
# File: src/gameplay/pickups/pickup.gd
# Purpose: give the boy whatever item this pack is holding.

extends Node2D

@export var item: GameItem

func _ready() -> void:
	if item != null and item.icon != null:
		$Sprite2D.texture = item.icon
		$Sprite2D.scale = Vector2(0.06, 0.06)

func is_in_front_of(player: Node2D) -> bool:
	var ahead := player.global_position + Vector2(player.get_facing_cell()) * 90.0
	return global_position.distance_to(ahead) < 70.0

func take() -> void:
	var inventory := get_tree().get_first_node_in_group("inventory")
	if inventory != null and item != null:
		inventory.add_item(item)
	queue_free()
