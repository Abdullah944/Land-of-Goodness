# tools/bake_farm_ground.gd
# Purpose: Paints each place's ground once from the shapes in WorldShapes: grass, dirt, sand, roads, water, and bridges.
# Run from the project root: Godot --headless --path . -s tools/bake_farm_ground.gd

extends SceneTree

const BLOCK: int = 4
const MARGIN: Vector2 = Vector2(140, 140)

func _init() -> void:
	var grass: Image = (load("res://assets/props/ground_grass.png") as Texture2D).get_image()
	grass.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/world"))
	for place: String in WorldShapes.PLACES:
		_bake(place, grass)
	print("BAKED %d places" % WorldShapes.PLACES.size())
	quit(0)

func _bake(place: String, grass: Image) -> void:
	var shape: Dictionary = WorldShapes.PLACES[place]
	var half: Vector2 = shape["half"]
	var width: int = int(half.x * 2.0 + MARGIN.x * 2.0)
	var height: int = int(half.y * 2.0 + MARGIN.y * 2.0)
	var patches: FastNoiseLite = FastNoiseLite.new()
	patches.seed = int(shape["seed"])
	patches.frequency = 0.009
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = int(shape["seed"])
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for by: int in range(0, height, BLOCK):
		for bx: int in range(0, width, BLOCK):
			var world: Vector2 = Vector2(bx - width * 0.5, by - height * 0.5)
			var kind: int = _kind(place, shape, world, patches)
			var depth: float = WorldShapes.water_depth(place, world)
			for y: int in range(by, by + BLOCK):
				for x: int in range(bx, bx + BLOCK):
					image.set_pixel(x, y, _color(kind, x, y, depth, grass, roll))
	image.save_png(WorldShapes.ground_path(place))

func _kind(place: String, shape: Dictionary, world: Vector2, patches: FastNoiseLite) -> int:
	if WorldShapes.on_planks(place, world):
		return WorldShapes.PLANKS
	var depth: float = WorldShapes.water_depth(place, world)
	if depth > 0.0:
		return WorldShapes.WATER
	if depth > -14.0:
		return WorldShapes.SHORE
	for box: Rect2 in shape.get("cobble", []):
		if box.has_point(world):
			return WorldShapes.COBBLE
	if WorldShapes.on_road(place, world):
		return WorldShapes.ROAD
	var wooded: bool = bool(shape["wooded"])
	if wooded and WorldShapes.edge(place, world) > 1.0 and not WorldShapes.in_exit(place, world):
		return WorldShapes.FOREST_FLOOR
	for box: Rect2 in shape["dirt"]:
		if box.has_point(world):
			return WorldShapes.DIRT
	var patch: float = patches.get_noise_2d(world.x, world.y)
	if bool(shape["sandy"]):
		return WorldShapes.GRASS if patch > 0.2 else WorldShapes.SAND
	return WorldShapes.DIRT if patch > 0.08 else WorldShapes.GRASS

func _color(kind: int, x: int, y: int, depth: float, grass: Image, roll: RandomNumberGenerator) -> Color:
	var picked: Color = grass.get_pixel(x % grass.get_width(), y % grass.get_height())
	var spot: float = roll.randf()
	match kind:
		WorldShapes.FOREST_FLOOR:
			return picked.darkened(0.62).lerp(Color("123b2a"), 0.45)
		WorldShapes.GRASS:
			return picked
		WorldShapes.DIRT:
			var dirt: Color = Color("d9a35c")
			return dirt.darkened(0.14) if spot < 0.08 else (dirt.lightened(0.12) if spot > 0.94 else dirt)
		WorldShapes.ROAD:
			return Color("c8a06a").darkened(0.1) if spot < 0.1 else Color("c8a06a")
		WorldShapes.COBBLE:
			var stone: Color = Color("c9b08c")
			var seam: bool = x % 16 < 2 or (y + (int(float(x) / 16.0) % 2) * 8) % 16 < 2
			return stone.darkened(0.25) if seam else (stone.lightened(0.08) if spot > 0.9 else stone)
		WorldShapes.WATER:
			var water: Color = Color("55afc4") if depth < 20.0 else Color("3f93b0")
			if depth > 70.0:
				water = Color("2f7b9c")
			var ripple: bool = (x + y * 3) % 37 == 0 or (x * 2 - y) % 53 == 0
			return water.lightened(0.18) if ripple else water
		WorldShapes.SHORE:
			return Color("ecd29a").darkened(0.08) if spot < 0.12 else Color("ecd29a")
		WorldShapes.SAND:
			var sand: Color = Color("f0d8a4")
			return sand.darkened(0.08) if spot < 0.07 else (sand.lightened(0.08) if spot > 0.95 else sand)
		WorldShapes.PLANKS:
			var plank: Color = Color("8a5a34")
			return plank.darkened(0.3) if y % 12 < 2 else (plank.lightened(0.07) if spot > 0.9 else plank)
	return picked
