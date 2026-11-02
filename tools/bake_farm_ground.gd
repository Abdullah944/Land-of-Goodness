# tools/bake_farm_ground.gd
# Purpose: Paints the farm's ground once: a natural clearing of grass and dirt, with dark forest around it.
# Run from the project root: Godot --headless --path . -s tools/bake_farm_ground.gd

extends SceneTree

const OUT: String = "res://assets/building/Farm/farm_ground.png"
const WIDTH: int = 1200
const HEIGHT: int = 840
const BLOCK: int = 4
## Roads the ground keeps clear. [from, to, half width]
const ROADS: Array = [
	[Vector2(-136, -62), Vector2(-70, -62), 11.0], [Vector2(-70, -62), Vector2(-40, 10), 11.0], [Vector2(-40, 10), Vector2(60, 76), 11.0],
	[Vector2(60, 76), Vector2(260, 56), 11.0], [Vector2(260, 56), Vector2(600, 40), 11.0], [Vector2(-70, -62), Vector2(-200, -210), 9.0],
	[Vector2(-200, -210), Vector2(-380, -210), 9.0], [Vector2(60, 76), Vector2(130, 180), 9.0], [Vector2(130, 180), Vector2(250, 200), 9.0],
	[Vector2(60, 76), Vector2(0, 180), 11.0], [Vector2(0, 180), Vector2(0, 420), 11.0],
]

func _init() -> void:
	var grass: Image = (load("res://assets/props/ground_grass.png") as Texture2D).get_image()
	grass.convert(Image.FORMAT_RGBA8)
	var patches: FastNoiseLite = FastNoiseLite.new()
	patches.seed = 12
	patches.frequency = 0.009
	var image: Image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = 4
	for by: int in range(0, HEIGHT, BLOCK):
		for bx: int in range(0, WIDTH, BLOCK):
			var world: Vector2 = Vector2(bx - WIDTH * 0.5, by - HEIGHT * 0.5)
			var kind: int = _kind(world, patches)
			for y: int in range(by, by + BLOCK):
				for x: int in range(bx, bx + BLOCK):
					image.set_pixel(x, y, _color(kind, x, y, grass, roll))
	image.save_png(OUT)
	print("BAKED farm ground")
	quit(0)

## 0 is forest floor, 1 is grass, 2 is dirt, 3 is a road.
func _kind(world: Vector2, patches: FastNoiseLite) -> int:
	for road: Array in ROADS:
		if _to_segment(world, road[0], road[1]) < float(road[2]):
			return 3
	if PlaceDecor.farm_edge(world) > 1.0 and not PlaceDecor.in_exit(world):
		return 0
	var field: Rect2 = Rect2(-196, -84, 124, 124)
	if field.has_point(world):
		return 2
	return 2 if patches.get_noise_2d(world.x, world.y) > 0.08 else 1

func _color(kind: int, x: int, y: int, grass: Image, roll: RandomNumberGenerator) -> Color:
	var picked: Color = grass.get_pixel(x % grass.get_width(), y % grass.get_height())
	match kind:
		0:
			return picked.darkened(0.62).lerp(Color("123b2a"), 0.45)
		1:
			return picked
		2:
			var dirt: Color = Color("d9a35c")
			var spot: float = roll.randf()
			return dirt.darkened(0.14) if spot < 0.08 else (dirt.lightened(0.12) if spot > 0.94 else dirt)
	var road_color: Color = Color("c8a06a")
	return road_color.darkened(0.1) if roll.randf() < 0.1 else road_color

func _to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to))
