# tools/cut_props.gd
# Purpose: Cuts props and ground tiles out of the project tilesets at game scale.
# Run: Godot --headless --path . --script res://tools/cut_props.gd

extends SceneTree

const MARKET: String = "res://assets/building/Market/HarborMarket_Tileset.png"
const MINE: String = "res://assets/building/Farm/FarmShop_Tileset.png"
const WATER: String = "res://assets/nature/Cozy pixel-art fishing water tile.png"
const OUT: String = "res://assets/props/"

# name: [sheet, source rect, target width, tile (crop to a square inside the edges)]
const CUTS: Dictionary = {
	"ground_sand": [MARKET, Rect2i(20, 160, 124, 128), 16, true],
	"ground_cobble": [MARKET, Rect2i(160, 160, 124, 128), 16, true],
	"ground_planks": [MARKET, Rect2i(436, 160, 124, 128), 16, true],
	"ground_mat": [MARKET, Rect2i(580, 160, 124, 128), 16, true],
	"ground_cave": [MINE, Rect2i(12, 152, 124, 132), 16, true],
	"ground_water": [WATER, Rect2i(200, 200, 854, 854), 16, true],
	"wall_window": [MARKET, Rect2i(156, 316, 120, 144), 32, false],
	"wall_plain": [MARKET, Rect2i(20, 316, 116, 144), 32, false],
	"wall_door": [MARKET, Rect2i(392, 316, 136, 144), 36, false],
	"counter": [MARKET, Rect2i(16, 484, 340, 132), 64, false],
	"stall_produce": [MARKET, Rect2i(760, 488, 164, 132), 44, false],
	"stall_pots": [MARKET, Rect2i(940, 492, 180, 136), 44, false],
	"shelf_seeds": [MARKET, Rect2i(372, 644, 164, 144), 40, false],
	"crate_fish": [MARKET, Rect2i(208, 644, 148, 140), 32, false],
	"sack": [MARKET, Rect2i(20, 804, 80, 88), 16, false],
	"crate": [MARKET, Rect2i(280, 816, 88, 80), 18, false],
	"basket": [MARKET, Rect2i(656, 816, 92, 80), 18, false],
	"pot_big": [MARKET, Rect2i(16, 916, 84, 104), 16, false],
	"pot_green": [MARKET, Rect2i(184, 932, 80, 88), 16, false],
	"plant": [MARKET, Rect2i(964, 932, 104, 116), 22, false],
	"lantern": [MARKET, Rect2i(1124, 1048, 56, 104), 10, false],
	"barrel": [MARKET, Rect2i(12, 1044, 72, 96), 16, false],
	"table": [MARKET, Rect2i(228, 1052, 104, 84), 26, false],
	"ore_copper": [MINE, Rect2i(224, 788, 96, 100), 18, false],
	"ore_iron": [MINE, Rect2i(120, 788, 92, 96), 18, false],
	"ore_rock": [MINE, Rect2i(540, 792, 88, 92), 18, false],
	"cave_wall": [MINE, Rect2i(16, 316, 116, 148), 32, false],
	"mine_door": [MINE, Rect2i(392, 316, 148, 148), 40, false],
	"oasis": [MINE, Rect2i(864, 152, 188, 132), 64, false],
	"torch": [MINE, Rect2i(1036, 704, 40, 60), 10, false],
	"mine_cart": [MINE, Rect2i(8, 1052, 128, 120), 28, false],
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sheets: Dictionary = {}
	for name: String in CUTS:
		var spec: Array = CUTS[name]
		var path: String = spec[0]
		if not sheets.has(path):
			var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
			image.convert(Image.FORMAT_RGBA8)
			sheets[path] = image
		var sheet: Image = sheets[path]
		var piece: Image = sheet.get_region(spec[1])
		var used: Rect2i = piece.get_used_rect()
		if used.size != Vector2i.ZERO:
			piece = piece.get_region(used)
		var width: int = spec[2]
		if bool(spec[3]):
			var inset: int = int(min(piece.get_width(), piece.get_height()) * 0.12)
			var side: int = min(piece.get_width(), piece.get_height()) - inset * 2
			piece = piece.get_region(Rect2i(inset, inset, side, side))
			piece.resize(width, width, Image.INTERPOLATE_LANCZOS)
			_fill_alpha(piece)
		else:
			var height: int = maxi(1, int(round(float(piece.get_height()) * width / float(piece.get_width()))))
			piece.resize(width, height, Image.INTERPOLATE_LANCZOS)
			_snap_alpha(piece)
		piece.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		print("CUT %s %dx%d" % [name, piece.get_width(), piece.get_height()])
	quit()

func _fill_alpha(image: Image) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			c.a = 1.0
			image.set_pixel(x, y, c)

func _snap_alpha(image: Image) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			c.a = 1.0 if c.a >= 0.5 else 0.0
			image.set_pixel(x, y, c)
