# tools/bake_farm_ground.gd
# Purpose: Paints each place's ground once from the shapes in WorldShapes: grass, dirt, sand, roads, water, and bridges.
# It writes a small colored map (used by the world map) and three mask maps that tell the ground shader
# which painted texture lies where (see WorldShapes.mask_path and src/shaders/ground_blend.gdshader).
# Run from the project root: Godot --headless --path . -s tools/bake_farm_ground.gd

extends SceneTree

const BLOCK: int = 4
const MARGIN: Vector2 = Vector2(140, 140)
## Which mask channel each kind of ground lights: 0-2 the first mask's red, green, blue, 3-5 the second, 6-7 the third.
## How far, in mask pixels, each ground kind fades into its neighbors.
const SOFTEN: int = 2
const MASK_SLOTS: Dictionary = {
	WorldShapes.GRASS: 0, WorldShapes.DIRT: 1, WorldShapes.SAND: 2, WorldShapes.SHORE: 2,
	WorldShapes.ROAD: 3, WorldShapes.COBBLE: 4, WorldShapes.WATER: 5,
	WorldShapes.PLANKS: 6, WorldShapes.FOREST_FLOOR: 7,
}

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
	var masks: Array[Image] = []
	for i: int in 3:
		masks.append(Image.create(int(ceil(float(width) / BLOCK)), int(ceil(float(height) / BLOCK)), false, Image.FORMAT_RGB8))
	for by: int in range(0, height, BLOCK):
		for bx: int in range(0, width, BLOCK):
			var world: Vector2 = Vector2(bx - width * 0.5, by - height * 0.5)
			var kind: int = _kind(place, shape, world, patches)
			var depth: float = WorldShapes.water_depth(place, world)
			for y: int in range(by, by + BLOCK):
				for x: int in range(bx, bx + BLOCK):
					image.set_pixel(x, y, _color(kind, x, y, depth, grass, roll))
			_mark(masks, Vector2i(bx / BLOCK, by / BLOCK), kind, depth)
	image.save_png(WorldShapes.ground_path(place))
	for i: int in 3:
		_soften(masks[i], SOFTEN)
		_soften(masks[i], SOFTEN)
		masks[i].save_png(WorldShapes.mask_path(place, i))

## A box blur across and then down, so the shader's noise has a soft slope to carve wavy edges from.
func _soften(mask: Image, radius: int) -> void:
	for pass_down: int in 2:
		var copy: Image = mask.duplicate() as Image
		var size: Vector2i = mask.get_size()
		var step: Vector2i = Vector2i(0, 1) if pass_down == 1 else Vector2i(1, 0)
		for y: int in size.y:
			for x: int in size.x:
				var sum: Color = Color(0, 0, 0)
				for k: int in range(-radius, radius + 1):
					var at: Vector2i = (Vector2i(x, y) + step * k).clamp(Vector2i.ZERO, size - Vector2i.ONE)
					sum += copy.get_pixelv(at)
				mask.set_pixel(x, y, sum / float(radius * 2 + 1))

## Lights the one mask channel that stands for this kind of ground. The third mask's blue holds water depth.
func _mark(masks: Array[Image], at: Vector2i, kind: int, depth: float) -> void:
	var slot: int = int(MASK_SLOTS[kind])
	var colors: Array[Color] = [Color.BLACK, Color.BLACK, Color.BLACK]
	colors[slot / 3][slot % 3] = 1.0
	if kind == WorldShapes.WATER:
		colors[2].b = clampf(depth / 90.0, 0.0, 1.0)
	for i: int in 3:
		masks[i].set_pixelv(at, colors[i])

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
