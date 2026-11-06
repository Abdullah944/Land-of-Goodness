# tools/cut_mosque_room.gd
# Purpose: Cuts the mosque's inside pieces out of the painted sheet into their own HD pictures,
# and builds the lamp post from the sheet's wall lamp. Run once after the sheet changes:
#   Godot --headless --path . -s tools/cut_mosque_room.gd   then   Godot --headless --path . --import

extends SceneTree

const SHEET: String = "res://assets/building/Mosque/MosqueInterior_Tileset.png"
const OUT: String = "res://assets/building/Mosque/room/%s.png"
const LAMP_POST: String = "res://assets/props/lamp_post.png"
## Stored pictures keep at most this many pixels per game pixel.
const DETAIL: float = 3.0

## name: [box on the sheet, size in the game]
const PIECES: Dictionary = {
	"floor": [Rect2i(159, 183, 123, 120), Vector2(32, 32)],
	"wall": [Rect2i(18, 342, 105, 144), Vector2(32, 44)],
	"wall_window": [Rect2i(144, 342, 117, 147), Vector2(32, 44)],
	"wall_lattice": [Rect2i(18, 708, 69, 156), Vector2(22, 50)],
	"mihrab": [Rect2i(111, 696, 141, 180), Vector2(56, 72)],
	"minbar": [Rect2i(354, 696, 138, 177), Vector2(46, 59)],
	"shoe_rack": [Rect2i(519, 720, 126, 147), Vector2(40, 47)],
	"bookcase": [Rect2i(666, 720, 147, 150), Vector2(50, 51)],
	"hanging_lamp": [Rect2i(1032, 708, 54, 162), Vector2(15, 45)],
	"pillar": [Rect2i(393, 906, 57, 135), Vector2(18, 43)],
	"fountain": [Rect2i(633, 936, 120, 111), Vector2(40, 37)],
}
const WALL_LAMP: Rect2i = Rect2i(1179, 720, 63, 105)

func _init() -> void:
	var sheet: Image = Image.load_from_file(SHEET)
	sheet.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/building/Mosque/room"))
	for key: String in PIECES:
		var row: Array = PIECES[key]
		_save(_cut(sheet, row[0]), OUT % key, row[1])
	_save(_lamp_post(_cut(sheet, WALL_LAMP)), LAMP_POST, Vector2(26, 64))
	print("mosque room pieces cut: ", PIECES.size() + 1)
	quit()

## One piece, a little wider than its box, trimmed to what is painted, with the sheet's red edge haze taken off.
func _cut(sheet: Image, box: Rect2i) -> Image:
	var part: Image = sheet.get_region(box.grow(4).intersection(Rect2i(Vector2i.ZERO, sheet.get_size())))
	for y: int in part.get_height():
		for x: int in part.get_width():
			var c: Color = part.get_pixel(x, y)
			var haze: bool = c.a < 0.95 and c.r > 0.45 and c.g < c.r * 0.55 and c.b < c.r * 0.4
			if c.a < 0.5 or haze:
				part.set_pixel(x, y, Color(0, 0, 0, 0))
	var used: Rect2i = part.get_used_rect()
	return part.get_region(used) if used.size != Vector2i.ZERO else part

## The wall lamp on a dark wooden post: the bracket's back plate meets the post near its top.
func _lamp_post(lamp: Image) -> Image:
	var post_w: int = 14
	var tall: int = 190
	var out: Image = Image.create(lamp.get_width() + post_w - 6, tall, false, Image.FORMAT_RGBA8)
	var wood: Color = Color("4a2e1a")
	var light: Color = Color("6e4628")
	var dark: Color = Color("2e1b0e")
	var left: int = 2
	for y: int in range(10, tall - 8):
		for x: int in post_w:
			var shade: Color = light if x < 4 else (dark if x > post_w - 4 else wood)
			out.set_pixel(left + x, y, shade)
	# A cap on top and a wider foot on the ground.
	for x: int in range(0, post_w + 4):
		for y: int in range(4, 12):
			out.set_pixel(x, y, dark if y > 9 else light)
		for y: int in range(tall - 10, tall):
			out.set_pixel(x, y, dark if y > tall - 4 else wood)
	out.blend_rect(lamp, Rect2i(Vector2i.ZERO, lamp.get_size()), Vector2i(post_w - 6, 14))
	return out

func _save(image: Image, path: String, game: Vector2) -> void:
	var most: Vector2i = Vector2i((game * DETAIL).round())
	if image.get_width() > most.x:
		image.resize(most.x, maxi(1, int(round(float(image.get_height()) * most.x / image.get_width()))), Image.INTERPOLATE_LANCZOS)
	image.save_png(path)
	var lines: Array[String] = ["[remap]", "", 'importer="khair_hd"', 'type="ImageTexture"']
	lines += ["", "[deps]", "", 'source_file="%s"' % path]
	lines += ["", "[params]", "", "game_size=Vector2(%s, %s)" % [game.x, game.y], ""]
	var out: FileAccess = FileAccess.open(path + ".import", FileAccess.WRITE)
	out.store_string("\n".join(lines))
