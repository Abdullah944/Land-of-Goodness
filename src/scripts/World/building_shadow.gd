# src/scripts/World/building_shadow.gd
# Purpose: Lays a building sprite's shadow on the ground behind it, so the farmhouse stands in the world like the village houses.

extends Node2D

@export var sprite_path: NodePath = ^"../Sprite2D"

func _ready() -> void:
	show_behind_parent = true
	queue_redraw()

func _draw() -> void:
	var sprite: Sprite2D = get_node_or_null(sprite_path) as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var size: Vector2 = sprite.texture.get_size() * sprite.scale
	var at: Vector2 = sprite.position - position - (size * 0.5 if sprite.centered else Vector2.ZERO)
	UiStyle.draw_building_shadow(self, sprite.texture, Rect2(at, size))
