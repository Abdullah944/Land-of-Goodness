# src/scripts/World/room_frame.gd
# Purpose: A thick wooden frame around a room: beams along the four sides, square posts at the corners,
# and a gap in the front beam where the door is, with a worn plank step across it.

class_name RoomFrame
extends Node2D

const BEAM: float = 12.0
const POST: float = 16.0
const WOOD: Color = Color("7a4a24")
const WOOD_LIGHT: Color = Color("a8703c")
const WOOD_DARK: Color = Color("3e2210")
const STEP: Color = Color("d9b98a")

## The floor and back wall together, inside the frame.
var inside: Rect2 = Rect2()
## The door gap in the front beam: [left x, right x].
var door: Vector2 = Vector2.ZERO

func _draw() -> void:
	var top: float = inside.position.y - BEAM
	var bottom: float = inside.end.y
	var left: float = inside.position.x - BEAM
	var right: float = inside.end.x
	_beam(Rect2(left, top, inside.size.x + BEAM * 2.0, BEAM), true)
	_beam(Rect2(left, top, BEAM, inside.size.y + BEAM * 2.0), false)
	_beam(Rect2(right, top, BEAM, inside.size.y + BEAM * 2.0), false)
	_beam(Rect2(left, bottom, door.x - left, BEAM), true)
	_beam(Rect2(door.y, bottom, right + BEAM - door.y, BEAM), true)
	# The step in the doorway, lighter where feet have worn it.
	draw_rect(Rect2(door.x, bottom + 2.0, door.y - door.x, BEAM - 4.0), STEP)
	draw_rect(Rect2(door.x + 4.0, bottom + 4.0, door.y - door.x - 8.0, 2.0), STEP.lightened(0.2))
	for corner: Vector2 in [Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)]:
		_post(corner + Vector2(BEAM, BEAM) * 0.5)

## A beam with a light top edge, a dark lower edge, and a few grain lines along it.
func _beam(box: Rect2, along: bool) -> void:
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	draw_rect(box, WOOD)
	if along:
		draw_rect(Rect2(box.position, Vector2(box.size.x, 2.0)), WOOD_LIGHT)
		draw_rect(Rect2(box.position.x, box.end.y - 2.0, box.size.x, 2.0), WOOD_DARK)
		var x: float = box.position.x + 14.0
		while x < box.end.x - 6.0:
			draw_line(Vector2(x, box.position.y + 4.0), Vector2(x + 7.0, box.position.y + 4.0), WOOD_DARK.lerp(WOOD, 0.5), 1.0)
			x += 23.0
	else:
		draw_rect(Rect2(box.position, Vector2(2.0, box.size.y)), WOOD_LIGHT)
		draw_rect(Rect2(box.end.x - 2.0, box.position.y, 2.0, box.size.y), WOOD_DARK)
		var y: float = box.position.y + 14.0
		while y < box.end.y - 6.0:
			draw_line(Vector2(box.position.x + 5.0, y), Vector2(box.position.x + 5.0, y + 7.0), WOOD_DARK.lerp(WOOD, 0.5), 1.0)
			y += 23.0

func _post(middle: Vector2) -> void:
	var box: Rect2 = Rect2(middle - Vector2(POST, POST) * 0.5, Vector2(POST, POST))
	draw_rect(box, WOOD_DARK)
	draw_rect(box.grow(-1.5), WOOD_LIGHT)
	draw_rect(box.grow(-4.0), WOOD)
	draw_rect(Rect2(box.position + Vector2(4.0, 4.0), Vector2(POST - 8.0, 2.0)), WOOD_LIGHT.lightened(0.15))
