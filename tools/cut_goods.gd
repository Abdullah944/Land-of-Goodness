# tools/cut_goods.gd
# Purpose: Cuts the goods sheet into bag icons and sizes the world pictures that replace older art.
# Run from the project root: Godot --headless --path . -s tools/cut_goods.gd

extends SceneTree

const GOODS: String = "res://assets/items/goods_sheet.png"
const OBJECTS: String = "res://assets/props/world_objects.png"
const GRID: int = 4
const ICON_PIXELS: int = 32
const PLANTS: String = "res://assets/props/world_plants.png"
## Name: [column, row, how many times larger].
const PLANT_CUTS: Dictionary = {
	"ghaf": [0, 0, 2], "sidr": [1, 0, 2], "tamarisk": [2, 0, 2], "acacia": [3, 0, 2],
	"ghaf_autumn": [0, 1, 2], "sidr_autumn": [1, 1, 2], "ghaf_winter": [2, 1, 2], "sapling": [3, 1, 1],
	"bush": [0, 2, 1], "bush_pink": [1, 2, 1], "bush_white": [2, 2, 1], "bush_dry": [3, 2, 1],
	"outcrop": [0, 3, 1], "cliff": [1, 3, 2], "rocks_moss": [2, 3, 1], "dune_grass": [3, 3, 1],
}
const NAMES: Array[String] = [
	"wood", "stone", "copper", "copper_bar",
	"pearl", "dates", "forage", "eggs",
	"milk", "wool", "fish", "feed",
	"turnips", "tomatoes", "wheat", "watermelons",
]
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/items/goods"))
	var goods: Image = (load(GOODS) as Texture2D).get_image()
	for i: int in NAMES.size():
		var icon: Image = _cell(goods, Vector2i(i % GRID, int(float(i) / GRID)), ICON_PIXELS)
		icon.save_png("res://assets/items/goods/%s.png" % NAMES[i])
	var objects: Image = (load(OBJECTS) as Texture2D).get_image()
	var herb: Image = _cell(objects, Vector2i(1, 3), 26)
	herb.save_png("res://assets/nature/Wild herb.png")
	var boulder: Image = _cell(objects, Vector2i(2, 0), 44)
	boulder.save_png("res://assets/nature/Chunky desert rock sprite.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/nature/plants"))
	var plants: Image = (load(PLANTS) as Texture2D).get_image()
	var cell: int = int(float(plants.get_width()) / GRID)
	for plant_name: String in PLANT_CUTS:
		var row: Array = PLANT_CUTS[plant_name]
		var part: Image = plants.get_region(Rect2i(int(row[0]) * cell, int(row[1]) * cell, cell, cell))
		_keep_biggest_shape(part)
		var used: Rect2i = part.get_used_rect()
		if used.size != Vector2i.ZERO:
			part = part.get_region(used)
		part.resize(part.get_width() * int(row[2]), part.get_height() * int(row[2]), Image.INTERPOLATE_NEAREST)
		part.save_png("res://assets/nature/plants/%s.png" % plant_name)
	var leafy: Image = (load("res://assets/nature/Leafy 16-Bit Farm Tree Sprite.png") as Texture2D).get_image()
	var leafy_used: Rect2i = leafy.get_used_rect()
	if leafy_used.size != Vector2i.ZERO:
		leafy = leafy.get_region(leafy_used)
	var leafy_factor: float = 104.0 / float(maxi(leafy.get_width(), leafy.get_height()))
	leafy.resize(int(leafy.get_width() * leafy_factor), int(leafy.get_height() * leafy_factor), Image.INTERPOLATE_LANCZOS)
	leafy.save_png("res://assets/nature/plants/leafy.png")
	print("CUT goods")
	quit(0)

## A picture may reach into the next cell, so only the largest connected shape in a cell is kept.
func _keep_biggest_shape(part: Image) -> void:
	part.convert(Image.FORMAT_RGBA8)
	var width: int = part.get_width()
	var height: int = part.get_height()
	var seen: PackedInt32Array = PackedInt32Array()
	seen.resize(width * height)
	var best: int = 0
	var best_size: int = 0
	var group: int = 0
	for start: int in width * height:
		if seen[start] != 0 or part.get_pixel(start % width, int(float(start) / width)).a < 0.2:
			continue
		group += 1
		var count: int = 0
		var stack: PackedInt32Array = PackedInt32Array([start])
		seen[start] = group
		while not stack.is_empty():
			var at: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
			var x: int = at % width
			var y: int = int(float(at) / width)
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				var next: int = ny * width + nx
				if seen[next] == 0 and part.get_pixel(nx, ny).a >= 0.2:
					seen[next] = group
					stack.append(next)
		if count > best_size:
			best_size = count
			best = group
	for at: int in width * height:
		if seen[at] != best:
			part.set_pixel(at % width, int(float(at) / width), Color(0, 0, 0, 0))

func _cell(sheet: Image, at: Vector2i, pixels: int) -> Image:
	var size: int = int(float(sheet.get_width()) / GRID)
	var part: Image = sheet.get_region(Rect2i(at * size, Vector2i(size, size)))
	var used: Rect2i = part.get_used_rect()
	if used.size != Vector2i.ZERO:
		part = part.get_region(used)
	var factor: float = float(pixels) / float(maxi(part.get_width(), part.get_height()))
	part.resize(maxi(1, int(part.get_width() * factor)), maxi(1, int(part.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	return part
