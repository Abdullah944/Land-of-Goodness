# tools/cut_interior.gd
# Purpose: Cuts the house interior sheet into clean room pictures for the game.
# Run from the project root: Godot --headless --path . -s tools/cut_interior.gd

extends SceneTree

const SOURCE: String = "res://assets/building/house/house_interior.png"
const OUT: String = "res://assets/building/house/room/"
const TILE: float = 32.0 / 160.0
const ITEM: float = 0.3

## name: [left, top, right, bottom, scale]
const PARTS: Dictionary = {
	"floor": [385, 35, 535, 195, TILE],
	"wall": [770, 405, 915, 560, TILE],
	"wall_window": [935, 405, 1075, 560, TILE],
	"wall_shelf": [1255, 405, 1400, 575, TILE],
	"wall_pattern": [215, 212, 362, 372, TILE],
	"table": [548, 606, 714, 732, ITEM],
	"pot": [878, 612, 978, 738, ITEM],
	"jar": [1000, 642, 1078, 736, ITEM],
	"shelf": [1190, 585, 1392, 735, ITEM],
	"rug": [45, 802, 250, 900, ITEM],
	"mat": [272, 790, 400, 905, ITEM],
	"rug_green": [418, 792, 608, 900, ITEM],
	"cushion_red": [795, 795, 915, 905, ITEM * 0.8],
	"cushion_green": [945, 795, 1060, 905, ITEM * 0.8],
	"lamp_table": [1090, 745, 1192, 908, ITEM],
	"plant": [35, 908, 162, 1048, ITEM],
	"dates_bowl": [180, 945, 282, 1042, ITEM * 0.7],
	"bench": [320, 920, 482, 1042, ITEM],
	"basket": [630, 925, 748, 1042, ITEM * 0.8],
	"cushions": [948, 945, 1192, 1055, ITEM * 0.85],
	"lantern": [1225, 912, 1306, 1048, ITEM * 0.7],
	"plant_vase": [1315, 912, 1412, 1050, ITEM],
}

func _init() -> void:
	var sheet: Image = (load(SOURCE) as Texture2D).get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for part_name: String in PARTS:
		var row: Array = PARTS[part_name]
		var part: Image = sheet.get_region(Rect2i(row[0], row[1], row[2] - row[0], row[3] - row[1]))
		_clean(part)
		var used: Rect2i = part.get_used_rect()
		if used.size != Vector2i.ZERO:
			part = part.get_region(used)
		var factor: float = row[4]
		part.resize(maxi(1, int(part.get_width() * factor)), maxi(1, int(part.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
		part.save_png(OUT + part_name + ".png")
	print("CUT %d parts" % PARTS.size())
	quit(0)

## The sheet has a thin red and yellow fringe around each picture, so edge pixels with those colors go first.
func _clean(part: Image) -> void:
	for y: int in part.get_height():
		for x: int in part.get_width():
			if part.get_pixel(x, y).a < 0.6:
				part.set_pixel(x, y, Color(0, 0, 0, 0))
	for round_index: int in 6:
		var cleared: Array[Vector2i] = []
		for y: int in part.get_height():
			for x: int in part.get_width():
				var color: Color = part.get_pixel(x, y)
				if color.a > 0.0 and _is_fringe(color) and _touches_clear(part, x, y):
					cleared.append(Vector2i(x, y))
		for at: Vector2i in cleared:
			part.set_pixelv(at, Color(0, 0, 0, 0))

func _is_fringe(color: Color) -> bool:
	var pure_red: bool = color.r > 0.7 and color.g < 0.3 and color.b < 0.3
	var pure_yellow: bool = color.r > 0.8 and color.g > 0.8 and color.b < 0.4
	return pure_red or pure_yellow

func _touches_clear(part: Image, x: int, y: int) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var near: Vector2i = Vector2i(x, y) + offset
		if near.x < 0 or near.y < 0 or near.x >= part.get_width() or near.y >= part.get_height():
			return true
		if part.get_pixelv(near).a == 0.0:
			return true
	return false
