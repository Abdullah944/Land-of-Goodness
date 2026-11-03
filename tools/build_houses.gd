# tools/build_houses.gd
# Purpose: Makes the town's other buildings from the home's art: a wide majlis, a wind-tower house, a shop, painted-door houses,
# a coral harbor house, a palm-frond hut, and a fort tower. Each is new, so the town is not one house copied many times.
# Run from the project root: Godot --headless --path . -s tools/build_houses.gd

extends SceneTree

const HOUSE: String = "res://assets/building/house/Desert Adobe Rooftop House Sprite.png"
const OUT: String = "res://assets/building/town/%s.png"
## The home picture is about 11 screen pixels per art pixel.
const P: int = 11
## Hand-drawn buildings are saved at this many pixels per art pixel, close to the home's size once halved.
const DRAWN: int = 6

const CREAM: Color = Color("fce5bf")
const CREAM_LIGHT: Color = Color("fff8d8")
const CREAM_SHADE: Color = Color("ecc898")
const CREAM_DARK: Color = Color("d9ae7c")
const INK: Color = Color("492015")
const INK_DEEP: Color = Color("3c160d")
const PLINTH: Color = Color("d79654")
const PLINTH_SHADE: Color = Color("c68144")
const WOOD: Color = Color("8a401f")
const WOOD_DARK: Color = Color("6e3016")
const BEAM: Color = Color("a25b2e")
const FROND: Color = Color("d2b072")
const FROND_DARK: Color = Color("b08a4c")
const FROND_DEEP: Color = Color("8c6630")
const AWNING: Color = Color("3f7a4a")
const AWNING_DARK: Color = Color("2e5c37")
const CLOTH: Color = Color("9a3a2c")

## Door and shutter boxes on the home picture.
const DOOR_BOX: Rect2i = Rect2i(440, 770, 200, 270)
const WINDOW_BOX: Rect2i = Rect2i(815, 760, 190, 180)

var _noise: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/building/town"))
	var house: Image = (load(HOUSE) as Texture2D).get_image()
	house.convert(Image.FORMAT_RGBA8)
	_save(_wide(house), "majlis")
	_save(_wind_tower(house), "house_tower")
	_save(_shop(house), "shop")
	var blue: Image = house.duplicate() as Image
	_paint_wood(blue, Color("2f6f8f"))
	_recolor_walls(blue, 0.45, 1.02, 0.0)
	blue.flip_x()
	_save(blue, "house_blue")
	var green: Image = house.duplicate() as Image
	_paint_wood(green, Color("3d7a52"))
	green = _wind_tower(green)
	green.flip_x()
	_save(green, "house_green")
	var coral: Image = house.duplicate() as Image
	_paint_wood(coral, Color("2c8a86"))
	_recolor_walls(coral, 0.25, 0.94, 0.02)
	_save(coral, "house_coral")
	_save_drawn(_barasti(), "barasti")
	_save_drawn(_burj(), "burj")
	print("BUILT houses")
	quit(0)

func _save(picture: Image, file_name: String) -> void:
	var used: Rect2i = picture.get_used_rect()
	picture = picture.get_region(used)
	picture.resize(int(picture.get_width() / 2.0), int(picture.get_height() / 2.0), Image.INTERPOLATE_LANCZOS)
	picture.save_png(OUT % file_name)

func _save_drawn(picture: Image, file_name: String) -> void:
	picture.resize(picture.get_width() * DRAWN, picture.get_height() * DRAWN, Image.INTERPOLATE_NEAREST)
	picture.save_png(OUT % file_name)

## A longer house with a second window, for the elders' majlis.
func _wide(house: Image) -> Image:
	# Join between the door and the window, where the wall and the roof are plain.
	var insert_at: int = 750
	var roof_split: int = 460
	var roof_strip: Rect2i = Rect2i(665, 0, 75, roof_split)
	var wall_cols: Array[Vector2i] = [Vector2i(750, 1035)]
	var added: int = 0
	for cols: Vector2i in wall_cols:
		added += cols.y - cols.x
	var wide: Image = Image.create(house.get_width() + added, house.get_height(), false, Image.FORMAT_RGBA8)
	wide.blit_rect(house, Rect2i(0, 0, insert_at, house.get_height()), Vector2i.ZERO)
	var x: int = insert_at
	for cols: Vector2i in wall_cols:
		for col: int in range(cols.x, cols.y):
			var roof_col: int = roof_strip.position.x + (x - insert_at) % roof_strip.size.x
			wide.blit_rect(house, Rect2i(roof_col, 0, 1, roof_split), Vector2i(x, 0))
			wide.blit_rect(house, Rect2i(col, roof_split, 1, house.get_height() - roof_split), Vector2i(x, roof_split))
			x += 1
	wide.blit_rect(house, Rect2i(insert_at, 0, house.get_width() - insert_at, house.get_height()), Vector2i(x, 0))
	return wide

## The home with a tall wind tower on the roof in place of the small roof room.
func _wind_tower(house: Image) -> Image:
	var lift: int = 34 * P
	var tall: Image = Image.create(house.get_width(), house.get_height() + lift, false, Image.FORMAT_RGBA8)
	tall.blit_rect(house, Rect2i(Vector2i.ZERO, house.get_size()), Vector2i(0, lift))
	# Cover the roof room with plain roof before the tower goes up.
	var floor_part: Image = house.get_region(Rect2i(620, 150, 120, 270))
	for x: int in range(290, 520, 120):
		tall.blit_rect(floor_part, Rect2i(0, 0, mini(120, 520 - x), 270), Vector2i(x, 150 + lift))
	_patch_parapet(tall, house, lift)
	var left: int = 300 / P
	var top: int = 0
	var width: int = 22
	var bottom: int = (420 + lift) / P
	# Shadow on the roof to the right.
	_rect(tall, left + width, bottom - 22, 4, 22, Color(0.4, 0.22, 0.1, 0.18))
	_rect(tall, left - 1, top + 3, width + 2, bottom - top - 2, INK)
	_rect(tall, left, top + 4, width, bottom - top - 4, CREAM)
	_rect(tall, left, top + 4, 2, bottom - top - 4, CREAM_LIGHT)
	_rect(tall, left + width - 3, top + 4, 3, bottom - top - 4, CREAM_SHADE)
	# Pointed crown along the top.
	for i: int in 6:
		var cx: int = left + 1 + i * 4
		_rect(tall, cx - 1, top, 4, 5, INK)
		_rect(tall, cx, top + 1, 2, 4, CREAM_LIGHT if i == 0 else CREAM)
	_rect(tall, left - 2, top + 5, width + 4, 2, INK)
	_rect(tall, left - 1, top + 5, width + 2, 1, CREAM_LIGHT)
	# Two tall vents with wooden bars, to catch the wind.
	for vent_x: int in [left + 3, left + 12]:
		_rect(tall, vent_x, top + 9, 7, 18, INK)
		_rect(tall, vent_x + 1, top + 10, 5, 16, INK_DEEP)
		_rect(tall, vent_x + 1, top + 10, 5, 1, Color("5a2a18"))
		for bar_y: int in range(top + 13, top + 26, 4):
			_rect(tall, vent_x + 1, bar_y, 5, 1, BEAM)
	# Beam ends poking out.
	for beam_y: int in [top + 30, bottom - 8]:
		_rect(tall, left - 2, beam_y, 2, 2, WOOD)
		_rect(tall, left + width, beam_y, 2, 2, WOOD)
		for i: int in 3:
			_rect(tall, left + 4 + i * 6, beam_y, 2, 2, WOOD)
	_speckle(tall, Rect2i((left + 2) * P, (top + 6) * P, (width - 5) * P, (bottom - top - 8) * P), 0.05)
	return tall

## The roof room peeked over the front wall; keep the parapet line whole.
func _patch_parapet(tall: Image, house: Image, lift: int) -> void:
	var strip: Image = house.get_region(Rect2i(665, 420, 60, 110))
	for x: int in range(270, 540, 60):
		tall.blit_rect(strip, Rect2i(0, 0, 60, 110), Vector2i(x, 420 + lift))

## The home with a green awning, a sign and two posts: Jassim's shop.
func _shop(house: Image) -> Image:
	var shop: Image = house.duplicate() as Image
	var left: int = 360 / P
	var right: int = 1060 / P
	var top: int = 690 / P
	# Posts down to the step.
	for post_x: int in [left + 1, right - 3]:
		_rect(shop, post_x - 1, top + 6, 4, 33, INK)
		_rect(shop, post_x, top + 6, 2, 32, WOOD)
		_rect(shop, post_x, top + 6, 1, 32, BEAM)
	# Striped cloth with a scalloped edge.
	_rect(shop, left - 1, top - 1, right - left + 2, 9, INK)
	var stripe: int = 0
	for x: int in range(left, right, 4):
		var color: Color = AWNING if stripe % 2 == 0 else Color("f4e6c8")
		var w: int = mini(4, right - x)
		_rect(shop, x, top, w, 7, color)
		_rect(shop, x, top + 7, w, 1, color)
		_rect(shop, x + 1, top + 8, maxi(1, w - 2), 1, color)
		_rect(shop, x, top + 8, 1, 1, INK)
		_rect(shop, x + 1, top + 9, maxi(1, w - 2), 1, INK)
		stripe += 1
	_rect(shop, left, top, right - left, 1, CREAM_LIGHT)
	_rect(shop, left, top + 6, right - left, 1, Color(0, 0, 0, 0.12))
	# A small sign above, with a date palm on it.
	var sign_left: int = 560 / P
	var sign_top: int = 560 / P
	_rect(shop, sign_left - 1, sign_top - 1, 20, 9, INK)
	_rect(shop, sign_left, sign_top, 18, 7, AWNING_DARK)
	_rect(shop, sign_left + 1, sign_top + 1, 16, 5, AWNING)
	_rect(shop, sign_left + 8, sign_top + 2, 2, 4, BEAM)
	_rect(shop, sign_left + 6, sign_top + 1, 6, 1, Color("8fd18a"))
	_rect(shop, sign_left + 5, sign_top + 2, 2, 1, Color("8fd18a"))
	_rect(shop, sign_left + 11, sign_top + 2, 2, 1, Color("8fd18a"))
	return shop

## A fisher's hut of palm fronds, the old Gulf barasti.
func _barasti() -> Image:
	var hut: Image = Image.create(72, 62, false, Image.FORMAT_RGBA8)
	# Roof seen from the front and above.
	for y: int in range(2, 26):
		var inset: int = int((25 - y) * 0.35)
		_px_row(hut, 3 + inset, 69 - inset, y, FROND)
	for y: int in range(2, 26):
		var inset: int = int((25 - y) * 0.35)
		for x: int in range(3 + inset, 69 - inset):
			if (x + y * 2) % 7 == 0 or (x * 3 + y) % 11 == 0:
				hut.set_pixel(x, y, FROND_DARK)
			elif (x + y) % 13 == 0:
				hut.set_pixel(x, y, Color("e6c98c"))
		hut.set_pixel(2 + inset, y, INK)
		hut.set_pixel(69 - inset, y, INK)
	_px_row(hut, 10, 62, 1, INK)
	_px_row(hut, 9, 63, 2, BEAM)
	_px_row(hut, 9, 63, 3, WOOD)
	_px_row(hut, 1, 71, 26, INK)
	_px_row(hut, 2, 70, 25, FROND_DEEP)
	# Frond ends hanging over the edge.
	for x: int in range(3, 70, 3):
		hut.set_pixel(x, 27, FROND_DEEP)
		hut.set_pixel(x, 28, INK)
	# Front wall of tied palm stems.
	for x: int in range(7, 65):
		for y: int in range(27, 58):
			hut.set_pixel(x, y, FROND if (x / 2) % 2 == 0 else FROND_DARK)
	for tie_y: int in [33, 44, 54]:
		_px_row(hut, 7, 65, tie_y, FROND_DEEP)
	_px_row(hut, 7, 65, 27, Color(0.3, 0.18, 0.08, 1.0))
	_px_row(hut, 7, 65, 28, FROND_DEEP)
	for y: int in range(27, 59):
		hut.set_pixel(6, y, INK)
		hut.set_pixel(65, y, INK)
	_px_row(hut, 6, 66, 58, INK)
	# Corner posts.
	for post_x: int in [7, 62]:
		_rect_px(hut, post_x, 26, 3, 32, WOOD)
		_rect_px(hut, post_x, 26, 1, 32, BEAM)
	# Doorway with a red curtain tied to one side.
	_rect_px(hut, 30, 38, 12, 20, INK)
	_rect_px(hut, 31, 39, 10, 19, INK_DEEP)
	_rect_px(hut, 31, 39, 4, 15, CLOTH)
	_rect_px(hut, 31, 42, 4, 1, Color("f0d9a8"))
	_rect_px(hut, 31, 46, 4, 1, Color("2b1b16"))
	_rect_px(hut, 33, 54, 2, 2, CLOTH)
	# A small window hole with a mat.
	_rect_px(hut, 48, 37, 8, 7, INK)
	_rect_px(hut, 49, 38, 6, 5, INK_DEEP)
	_rect_px(hut, 49, 38, 6, 2, FROND_DARK)
	# Sand step at the door.
	_rect_px(hut, 28, 58, 16, 3, INK)
	_rect_px(hut, 29, 58, 14, 2, PLINTH)
	return hut

## A round mud-brick watchtower, like the old forts along the coast.
func _burj() -> Image:
	var tower: Image = Image.create(46, 92, false, Image.FORMAT_RGBA8)
	var left: int = 6
	var right: int = 40
	var mid: float = (left + right) * 0.5
	var half: float = (right - left) * 0.5
	for x: int in range(left, right):
		var t: float = (x + 0.5 - mid) / half
		var color: Color = CREAM_LIGHT if t < -0.55 else CREAM if t < 0.25 else CREAM_SHADE if t < 0.7 else CREAM_DARK
		var curve: int = int(round((1.0 - sqrt(maxf(0.0, 1.0 - t * t))) * 3.0))
		for y: int in range(14, 84 + curve):
			tower.set_pixel(x, y, color)
		tower.set_pixel(x, 84 + curve, INK)
	for y: int in range(14, 86):
		tower.set_pixel(left - 1, y, INK)
		tower.set_pixel(right, y, INK)
	# Brick texture.
	for y: int in range(18, 82, 5):
		for x: int in range(left + 1 + (y % 2) * 3, right - 1, 7):
			if tower.get_pixel(x, y).a > 0.0:
				tower.set_pixel(x, y, tower.get_pixel(x, y).darkened(0.08))
				tower.set_pixel(x + 1, y, tower.get_pixel(x + 1, y).darkened(0.08))
	# Wider rim and pointed battlements.
	_rect_px(tower, left - 3, 12, right - left + 6, 4, INK)
	_rect_px(tower, left - 2, 13, right - left + 4, 2, CREAM)
	_rect_px(tower, left - 2, 13, right - left + 4, 1, CREAM_LIGHT)
	for i: int in 6:
		var cx: int = left - 2 + i * 7
		_rect_px(tower, cx, 4, 5, 9, INK)
		_rect_px(tower, cx + 1, 6, 3, 7, CREAM if i < 4 else CREAM_SHADE)
		_rect_px(tower, cx + 2, 4, 1, 2, INK)
		tower.set_pixel(cx + 2, 5, CREAM_LIGHT)
	# Rows of beam ends.
	for beam_y: int in [20, 50]:
		for x: int in range(left + 2, right - 1, 5):
			_rect_px(tower, x, beam_y, 2, 2, WOOD)
			tower.set_pixel(x, beam_y, BEAM)
		_rect_px(tower, left - 3, beam_y, 2, 2, WOOD)
		_rect_px(tower, right + 1, beam_y, 2, 2, WOOD)
	# Slits for looking out.
	for slit: Vector2i in [Vector2i(22, 28), Vector2i(14, 38), Vector2i(30, 38)]:
		_rect_px(tower, slit.x - 1, slit.y - 1, 3, 9, INK)
		_rect_px(tower, slit.x, slit.y, 1, 7, INK_DEEP)
	# Arched wooden door.
	_rect_px(tower, 16, 66, 14, 20, INK)
	_rect_px(tower, 17, 68, 12, 18, WOOD)
	_rect_px(tower, 18, 67, 10, 1, WOOD)
	for x: int in range(19, 29, 3):
		_rect_px(tower, x, 68, 1, 18, WOOD_DARK)
	for stud: Vector2i in [Vector2i(18, 72), Vector2i(27, 72), Vector2i(18, 80), Vector2i(27, 80)]:
		tower.set_pixel(stud.x, stud.y, Color("d9a441"))
	tower.set_pixel(25, 77, Color("d9a441"))
	# Mud plinth.
	_rect_px(tower, left - 3, 84, right - left + 6, 6, INK)
	_rect_px(tower, left - 2, 84, right - left + 4, 4, PLINTH)
	_rect_px(tower, left - 2, 87, right - left + 4, 1, PLINTH_SHADE)
	_rect_px(tower, 15, 85, 16, 3, PLINTH_SHADE)
	_rect_px(tower, 15, 85, 16, 1, PLINTH)
	return tower

## Turns the door, shutters and their frames to a painted color, like the blue and green doors of old Gulf houses.
func _paint_wood(picture: Image, paint: Color) -> void:
	for box: Rect2i in [DOOR_BOX, WINDOW_BOX]:
		for y: int in range(box.position.y, box.end.y):
			for x: int in range(box.position.x, box.end.x):
				var c: Color = picture.get_pixel(x, y)
				if c.a < 0.5 or c.v > 0.62 or c.s < 0.4 or c.h > 0.12:
					continue
				var shade: float = clampf(c.v / 0.55, 0.35, 1.15)
				var painted: Color = Color.from_hsv(paint.h, paint.s, clampf(paint.v * shade, 0.0, 1.0), c.a)
				picture.set_pixel(x, y, painted)

## Shifts the cream walls: less warm makes whitewash, a little blue makes grey coral stone.
func _recolor_walls(picture: Image, keep_warmth: float, brightness: float, cool: float) -> void:
	for y: int in picture.get_height():
		for x: int in picture.get_width():
			var c: Color = picture.get_pixel(x, y)
			if c.a < 0.05 or c.v < 0.7 or c.h > 0.14 or c.s > 0.62:
				continue
			var warm: Color = Color.from_hsv(c.h, c.s * keep_warmth, clampf(c.v * brightness, 0.0, 1.0), c.a)
			picture.set_pixel(x, y, Color(warm.r - cool, warm.g, warm.b + cool, c.a))

## Fills a box measured in art pixels on a full-size picture.
func _rect(picture: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var box: Rect2i = Rect2i(x * P, y * P, w * P, h * P).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	if box.size.x <= 0 or box.size.y <= 0:
		return
	if color.a >= 1.0:
		picture.fill_rect(box, color)
		return
	for py: int in range(box.position.y, box.end.y):
		for px: int in range(box.position.x, box.end.x):
			var under: Color = picture.get_pixel(px, py)
			if under.a > 0.0:
				picture.set_pixel(px, py, under.blend(color))

## Fills a box on a small hand-drawn picture.
func _rect_px(picture: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var box: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	if box.size.x > 0 and box.size.y > 0:
		picture.fill_rect(box, color)

func _px_row(picture: Image, from_x: int, to_x: int, y: int, color: Color) -> void:
	_rect_px(picture, from_x, y, to_x - from_x, 1, color)

## Light and dark flecks so new walls match the home's rough plaster.
func _speckle(picture: Image, area: Rect2i, chance: float) -> void:
	_noise.seed = 7
	for y: int in range(area.position.y, area.end.y, P):
		for x: int in range(area.position.x, area.end.x, P):
			var roll: float = _noise.randf()
			if roll < chance:
				picture.fill_rect(Rect2i(x, y, P, P), CREAM_SHADE)
			elif roll < chance * 2.0:
				picture.fill_rect(Rect2i(x, y, P, P), CREAM_LIGHT)
