# src/scripts/ui/world_map.gd
# Purpose: The Map tab. Draws the whole land, its roads, and a mark where the boy is now.

class_name WorldMap
extends Control

const SEA: Color = Color("4f9fb8")
const SEA_DEEP: Color = Color("3f8aa6")
const SAND: Color = Color("edd29a")
const GREEN: Color = Color("86ad62")
const FOREST: Color = Color("3f6d4a")
const ROAD: Color = Color("b98c54")
const ICON_SIZE: float = 34.0

## key: [spot on the map, picture, name, pixels]
const PLACES: Dictionary = {
	"Home": [Vector2(74, 74), "res://assets/building/house/Desert Adobe Rooftop House Sprite.png", "to_home"],
	"Cave": [Vector2(26, 28), "res://assets/building/Cave/Sandstone Cave Entrance.png", "to_cave"],
	"Road": [Vector2(174, 24), "res://assets/props/stall_produce.png", "to_road"],
	"Forest": [Vector2(146, 118), "res://assets/nature/Leafy 16-Bit Farm Tree Sprite.png", "to_forest"],
	"Village": [Vector2(262, 74), "res://assets/building/house/Desert Adobe Rooftop House Sprite.png", "to_village"],
	"Orchard": [Vector2(178, 74), "res://assets/nature/Date palm.png", "to_orchard"],
	"Harbor": [Vector2(362, 66), "res://assets/building/harbor/Dhow.png", "to_harbor"],
}
const LINKS: Array = [
	["Home", "Road"], ["Road", "Village"], ["Home", "Forest"], ["Forest", "Village"], ["Village", "Orchard"], ["Village", "Harbor"], ["Home", "Cave"],
]
const SPOTS: Dictionary = {"HouseInside": "Home"}

var _icons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

## Where the boy's mark goes.
func current_spot() -> Vector2:
	var stead: Node = get_tree().current_scene.get_node_or_null("Systems/Stead")
	var place: String = str(stead.get("place_name")) if stead != null else "Home"
	place = str(SPOTS.get(place, place))
	return PLACES[place][0] if PLACES.has(place) else Vector2(PLACES["Home"][0])

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	_wave_lines()
	var land: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(330, 0), Vector2(338, 34), Vector2(322, 60), Vector2(330, 92), Vector2(296, 112),
		Vector2(250, 128), Vector2(190, 142), Vector2(0, 142),
	])
	draw_colored_polygon(land, SAND)
	draw_polyline(_closed(land), UiStyle.BROWN, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 40), Vector2(40, 34), Vector2(120, 42), Vector2(132, 96), Vector2(92, 118), Vector2(0, 112)]), GREEN)
	draw_colored_polygon(PackedVector2Array([Vector2(96, 104), Vector2(180, 98), Vector2(202, 122), Vector2(190, 142), Vector2(84, 142)]), FOREST)
	draw_colored_polygon(PackedVector2Array([Vector2(150, 54), Vector2(204, 52), Vector2(208, 92), Vector2(154, 94)]), GREEN)
	for peak: Vector2 in [Vector2(70, 18), Vector2(100, 24), Vector2(128, 14)]:
		draw_colored_polygon(PackedVector2Array([peak + Vector2(-16, 14), peak + Vector2(0, -12), peak + Vector2(16, 14)]), Color("a98a66"))
		draw_colored_polygon(PackedVector2Array([peak + Vector2(-5, -4), peak + Vector2(0, -12), peak + Vector2(5, -4)]), UiStyle.CREAM)
	for link: Array in LINKS:
		draw_line(PLACES[link[0]][0], PLACES[link[1]][0], ROAD, 2.0)
	for key: String in PLACES:
		_draw_place(key)
	_draw_you()
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BROWN, false, 2.0)

func _draw_place(key: String) -> void:
	var row: Array = PLACES[key]
	var icon: Texture2D = _icon(str(row[1]))
	var at: Vector2 = row[0]
	if icon != null:
		var drawn: Vector2 = icon.get_size()
		draw_texture_rect(icon, Rect2(at - drawn * 0.5 - Vector2(0, 4), drawn), false)
	var font: Font = ThemeDB.fallback_font
	var title: String = Locale.t(str(row[2]))
	var wide: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var spot: Vector2 = at + Vector2(-wide * 0.5, 22.0)
	spot.x = clampf(spot.x, 3.0, size.x - wide - 3.0)
	draw_string_outline(font, spot, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, UiStyle.DARK)
	draw_string(font, spot, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiStyle.CREAM)

func _draw_you() -> void:
	var at: Vector2 = current_spot()
	var beat: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 220.0)
	draw_arc(at, 16.0 + beat * 3.0, 0.0, TAU, 28, UiStyle.GOLD, 2.0)
	draw_circle(at + Vector2(0, -20), 3.0, UiStyle.GOLD)

func _wave_lines() -> void:
	var drift: float = fmod(float(Time.get_ticks_msec()) / 90.0, 34.0)
	for row: int in 6:
		for column: int in 14:
			var at: Vector2 = Vector2(column * 34.0 + drift - 30.0 + row % 2 * 16.0, 10.0 + row * 24.0)
			if at.x < size.x - 8.0:
				draw_line(at, at + Vector2(8, 0), SEA_DEEP, 1.0)

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var ring: PackedVector2Array = points.duplicate()
	ring.append(points[0])
	return ring

func _icon(path: String) -> Texture2D:
	if _icons.has(path):
		return _icons[path]
	var source: Texture2D = load(path) as Texture2D
	if source == null:
		return null
	var image: Image = source.get_image()
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	var factor: float = ICON_SIZE / float(maxi(image.get_width(), image.get_height()))
	image.resize(maxi(1, int(image.get_width() * factor)), maxi(1, int(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	var icon: Texture2D = ImageTexture.create_from_image(image)
	_icons[path] = icon
	return icon
