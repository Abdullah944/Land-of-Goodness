# src/scripts/World/place_bounds.gd
# Purpose: Puts invisible walls around a place so the boy cannot walk off the map.

extends Node2D

@export var area: Rect2 = Rect2(-180, -110, 360, 240)
@export var thickness: float = 16.0
## Solid patches inside the area, such as deep water beside a dock.
@export var blocks: Array[Rect2] = []

func _ready() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	var half: float = thickness * 0.5
	_wall(body, Vector2(area.get_center().x, area.position.y - half), Vector2(area.size.x + thickness * 2.0, thickness))
	_wall(body, Vector2(area.get_center().x, area.end.y + half), Vector2(area.size.x + thickness * 2.0, thickness))
	_wall(body, Vector2(area.position.x - half, area.get_center().y), Vector2(thickness, area.size.y))
	_wall(body, Vector2(area.end.x + half, area.get_center().y), Vector2(thickness, area.size.y))
	for patch: Rect2 in blocks:
		_wall(body, patch.get_center(), patch.size)

func _wall(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = center
	body.add_child(shape_node)
