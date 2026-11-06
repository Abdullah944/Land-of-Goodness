# src/scripts/World/mosque_carpet.gd
# Purpose: The prayer hall's one wall-to-wall carpet. Its rows (saff) run along the qibla wall,
# each row a line of small arches pointing toward the mihrab.

class_name MosqueCarpet
extends Node2D

const BASE: Color = Color("2f6a3f")
const SHADE: Color = Color("285c36")
const GOLD: Color = Color("d6b25e")
const EDGE: Color = Color("7a1f22")
const ROW: float = 26.0
const ARCH: float = 16.0

var area: Rect2 = Rect2()

func _draw() -> void:
	draw_rect(area, EDGE)
	var inner: Rect2 = area.grow(-3.0)
	draw_rect(inner, BASE)
	draw_rect(inner, GOLD, false, 1.0)
	var y: float = inner.position.y + 4.0
	var row: int = 0
	while y + ROW <= inner.end.y + 0.5:
		if row % 2 == 1:
			draw_rect(Rect2(inner.position.x + 1.0, y, inner.size.x - 2.0, ROW), SHADE)
		var x: float = inner.position.x + 3.0
		while x + ARCH <= inner.end.x - 2.0:
			_arch(Rect2(x + 1.5, y + 4.0, ARCH - 3.0, ROW - 7.0))
			x += ARCH
		y += ROW
		draw_line(Vector2(inner.position.x + 1.0, y), Vector2(inner.end.x - 1.0, y), GOLD, 1.0)
		row += 1

## One prayer place: a pointed arch with its top toward the qibla wall.
func _arch(box: Rect2) -> void:
	var top: Vector2 = Vector2(box.get_center().x, box.position.y)
	var shoulder: float = box.position.y + box.size.y * 0.35
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(box.position.x, box.end.y), Vector2(box.position.x, shoulder),
		Vector2(box.position.x + box.size.x * 0.2, shoulder - box.size.y * 0.2), top,
		Vector2(box.end.x - box.size.x * 0.2, shoulder - box.size.y * 0.2), Vector2(box.end.x, shoulder),
		Vector2(box.end.x, box.end.y),
	])
	draw_polyline(points, Color(GOLD, 0.75), 0.8)
