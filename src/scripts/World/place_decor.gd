# src/scripts/World/place_decor.gd
# Purpose: Scatters small ground details, so a place looks lived in. They are pictures only and never block.

class_name PlaceDecor
extends RefCounted

const SHEET: String = "res://assets/props/ground_details.png"
const GRID: int = 4
const SCALE: float = 0.62
const TUFT: int = 0
const YELLOW: int = 1
const PINK: int = 2
const SHRUB: int = 3
const STONES: int = 4
const TWIGS: int = 5
const WEEDS: int = 6
const STUMP: int = 7
const FENCE: int = 8
const HAY: int = 9
const POT: int = 10
const ROCKS: int = 11

const LAYOUTS: Dictionary = {
	"Home": {
		"seed": 41,
		"count": 330,
		"area": Rect2(-510, -330, 1020, 660),
		"picks": [TUFT, TUFT, TUFT, TUFT, TUFT, YELLOW, PINK, WEEDS, WEEDS, STONES, TWIGS, ROCKS, SHRUB],
		"avoid": [
			Rect2(-186, -74, 104, 96), Rect2(-220, -220, 170, 150), Rect2(-430, -300, 100, 90), Rect2(260, -230, 140, 110),
			Rect2(240, 110, 160, 160), Rect2(68, 130, 104, 110), Rect2(470, 20, 50, 50), Rect2(50, -10, 46, 56),
			Rect2(-40, 20, 50, 40), Rect2(50, -190, 80, 90), Rect2(170, -140, 80, 90),
		],
		"fixed": [
			[FENCE, Vector2(-168, 34)], [FENCE, Vector2(-144, 34)], [FENCE, Vector2(-120, 34)], [FENCE, Vector2(-96, 34)],
			[FENCE, Vector2(32, 250)], [FENCE, Vector2(56, 250)], [STUMP, Vector2(-30, -180)], [HAY, Vector2(236, 262)],
			[HAY, Vector2(30, 228)], [POT, Vector2(-54, -90)], [STUMP, Vector2(-300, 120)], [STUMP, Vector2(420, -60)],
		],
	},
	"Orchard": {
		"seed": 17,
		"count": 220,
		"area": Rect2(-470, -292, 940, 584),
		"picks": [TUFT, TUFT, TUFT, TUFT, YELLOW, PINK, WEEDS, STONES, SHRUB],
		"avoid": [Rect2(-410, -250, 220, 120), Rect2(-480, -28, 960, 88), Rect2(228, 40, 88, 260)],
		"fixed": [[STUMP, Vector2(300, -80)], [HAY, Vector2(140, -40)]],
	},
	"Village": {
		"seed": 23,
		"count": 240,
		"area": Rect2(-470, -292, 940, 584),
		"picks": [TUFT, TUFT, TUFT, TUFT, YELLOW, PINK, WEEDS, SHRUB, STONES, ROCKS],
		"avoid": [
			Rect2(-480, -24, 960, 92), Rect2(-48, 60, 96, 240), Rect2(-190, -300, 680, 290), Rect2(120, 88, 360, 120),
		],
		"fixed": [],
	},
	"Cave": {
		"seed": 7,
		"count": 34,
		"area": Rect2(-236, -110, 472, 320),
		"picks": [STONES, STONES, ROCKS, ROCKS, TWIGS],
		"avoid": [Rect2(-60, 150, 120, 60), Rect2(50, 30, 60, 60), Rect2(-100, 10, 60, 60)],
		"fixed": [],
	},
	"Harbor": {
		"seed": 31,
		"count": 60,
		"area": Rect2(-470, -60, 940, 352),
		"picks": [STONES, ROCKS, TWIGS, TUFT],
		"avoid": [Rect2(-400, -60, 180, 140), Rect2(-140, -60, 400, 160), Rect2(260, 60, 160, 130)],
		"fixed": [],
	},
}

## Things to clear from the farm once. [picture, group, spot]
const DEBRIS: Array = [
	[TWIGS, "debris_wood", Vector2(-51, -51)], [TWIGS, "debris_wood", Vector2(17, -163)], [TWIGS, "debris_wood", Vector2(122, -176)],
	[TWIGS, "debris_wood", Vector2(-360, -10)], [TWIGS, "debris_wood", Vector2(-377, 122)], [TWIGS, "debris_wood", Vector2(292, -102)],
	[TWIGS, "debris_wood", Vector2(363, -30)],
	[STONES, "debris_stone", Vector2(-105, -173)], [STONES, "debris_stone", Vector2(-346, -190)], [STONES, "debris_stone", Vector2(57, -30)],
	[STONES, "debris_stone", Vector2(-176, 156)], [STONES, "debris_stone", Vector2(-323, 190)], [STONES, "debris_stone", Vector2(394, 37)],
	[WEEDS, "debris_weed", Vector2(-68, -122)], [WEEDS, "debris_weed", Vector2(-360, 54)], [WEEDS, "debris_weed", Vector2(241, -173)],
	[WEEDS, "debris_weed", Vector2(0, 176)], [WEEDS, "debris_weed", Vector2(-255, 207)],
]
const TREE_PICTURE: String = "res://assets/nature/Leafy 16-Bit Farm Tree Sprite.png"
const PALM_PICTURE: String = "res://assets/nature/Date palm.png"
## Trees that frame the farm. They are scenery and cannot be chopped.
const FARM_TREES: Array[Vector2] = [
	Vector2(-480, -300), Vector2(-420, -120), Vector2(-490, -30), Vector2(-440, 110), Vector2(-490, 220), Vector2(-400, 300),
	Vector2(-280, 310), Vector2(-160, 290), Vector2(-40, 310), Vector2(70, 310), Vector2(200, 320), Vector2(470, 300),
	Vector2(490, 170), Vector2(440, 110), Vector2(490, -120), Vector2(440, -230), Vector2(480, -310), Vector2(360, -310),
	Vector2(220, -300), Vector2(100, -310), Vector2(-40, -300), Vector2(-250, -310), Vector2(-300, -60), Vector2(-340, 200),
	Vector2(-220, 200), Vector2(-120, 130), Vector2(20, -230), Vector2(300, 60), Vector2(380, -40),
]
const FARM_PALMS: Array[Vector2] = [Vector2(-310, 40), Vector2(-360, -30), Vector2(-260, 130), Vector2(170, 120), Vector2(400, 180)]
const ROOM: String = "res://assets/building/house/room/%s.png"
const ROOM_AREA: Rect2 = Rect2(-120, 6, 288, 154)
const WALL_ROW: Array[String] = ["wall", "wall_window", "wall", "wall_pattern", "wall", "wall_window", "wall", "wall_shelf", "wall_window"]
## Furniture that is always in the house. [picture, spot, solid footprint]
const FURNITURE: Array = [
	["shelf", Vector2(-78, 18), Vector2(52, 8)], ["pot", Vector2(-110, 24), Vector2(22, 8)], ["lamp_table", Vector2(112, 26), Vector2(24, 8)],
	["plant_vase", Vector2(152, 22), Vector2(20, 8)], ["table", Vector2(-58, 84), Vector2(44, 12)], ["dates_bowl", Vector2(-58, 66), Vector2.ZERO],
	["cushion_red", Vector2(-92, 94), Vector2.ZERO], ["cushion_green", Vector2(-24, 94), Vector2.ZERO], ["basket", Vector2(-104, 140), Vector2(22, 8)],
	["jar", Vector2(152, 140), Vector2(16, 8)], ["bench", Vector2(116, 148), Vector2(44, 8)], ["lantern", Vector2(-18, 10), Vector2.ZERO],
]

static var _cuts: Array[Texture2D] = []

static func dress(place: Node, cleared: Dictionary = {}) -> void:
	if place.name == "HouseInside":
		_dress_room(place)
		return
	var layout: Dictionary = LAYOUTS.get(str(place.name), {})
	if layout.is_empty() or place.get_node_or_null("Decor") != null:
		return
	_cut_sheet()
	if _cuts.is_empty():
		return
	var decor: Node2D = Node2D.new()
	decor.name = "Decor"
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = int(layout["seed"])
	var picks: Array = layout["picks"]
	var area: Rect2 = layout["area"]
	for i: int in int(layout["count"]):
		var at: Vector2 = area.position + Vector2(roll.randf() * area.size.x, roll.randf() * area.size.y)
		var pick: int = int(picks[roll.randi_range(0, picks.size() - 1)])
		if not _blocked(at, layout["avoid"]):
			decor.add_child(_sprite(pick, at))
	for row: Array in layout["fixed"]:
		decor.add_child(_sprite(int(row[0]), row[1]))
	place.add_child(decor)
	if place.name == "Home":
		_add_debris(place, cleared)
		PropPiece.add_to(place, {"name": "HouseLamp", "path": ROOM % "lantern", "at": Vector2(-50, -66)})
		for i: int in FARM_TREES.size():
			PropPiece.add_to(place, {"name": "Palm_tree%d" % i, "path": TREE_PICTURE, "at": FARM_TREES[i], "fit": 90 + i % 3 * 10, "block": Vector2(14, 8)})
		for i: int in FARM_PALMS.size():
			PropPiece.add_to(place, {"name": "Palm_farm%d" % i, "path": PALM_PICTURE, "at": FARM_PALMS[i], "block": Vector2(10, 6)})

static func _add_debris(place: Node, cleared: Dictionary) -> void:
	for i: int in DEBRIS.size():
		var row: Array = DEBRIS[i]
		var mark_name: String = "Debris%d" % i
		if bool(cleared.get("cleared_" + mark_name, false)):
			continue
		PropPiece.add_to(place, {"name": mark_name, "texture": _cuts[int(row[0])], "at": row[2], "group": str(row[1])})

## Lays the floor and walls, then the furniture. The old tile floor stays hidden for its grid.
static func _dress_room(place: Node) -> void:
	if place.get_node_or_null("Decor") != null:
		return
	var decor: Node2D = Node2D.new()
	decor.name = "Decor"
	var floor_picture: Texture2D = load(ROOM % "floor") as Texture2D
	var step: float = 32.0
	var y: float = ROOM_AREA.position.y - 6.0
	while y < ROOM_AREA.end.y:
		var x: float = ROOM_AREA.position.x
		while x < ROOM_AREA.end.x:
			decor.add_child(_room_tile(floor_picture, Vector2(x, y), Vector2(step, step)))
			x += step
		y += step
	for i: int in WALL_ROW.size():
		var wall: Texture2D = load(ROOM % WALL_ROW[i]) as Texture2D
		decor.add_child(_room_tile(wall, Vector2(ROOM_AREA.position.x + i * step, ROOM_AREA.position.y - 38.0), Vector2(step, 40.0)))
	var edge: Color = Color("6b4426")
	decor.add_child(_room_edge(Rect2(ROOM_AREA.position.x - 6.0, ROOM_AREA.position.y - 38.0, 6.0, ROOM_AREA.size.y + 44.0), edge))
	decor.add_child(_room_edge(Rect2(ROOM_AREA.end.x, ROOM_AREA.position.y - 38.0, 6.0, ROOM_AREA.size.y + 44.0), edge))
	decor.add_child(_room_edge(Rect2(ROOM_AREA.position.x - 6.0, ROOM_AREA.end.y, 110.0, 6.0), edge))
	decor.add_child(_room_edge(Rect2(32.0, ROOM_AREA.end.y, ROOM_AREA.end.x - 26.0, 6.0), edge))
	place.add_child(decor)
	PropPiece.add_to(place, {"name": "RoomRug", "path": ROOM % "rug", "at": Vector2(10, 104), "flat": true})
	PropPiece.add_to(place, {"name": "RoomMat", "path": ROOM % "mat", "at": Vector2(8, 142), "flat": true})
	for row: Array in FURNITURE:
		PropPiece.add_to(place, {"name": "Room_" + str(row[0]), "path": ROOM % str(row[0]), "at": row[1], "block": row[2]})

static func _room_tile(picture: Texture2D, at: Vector2, size: Vector2) -> Sprite2D:
	var tile: Sprite2D = Sprite2D.new()
	tile.texture = picture
	tile.centered = false
	tile.position = at
	tile.scale = size / picture.get_size()
	return tile

static func _room_edge(box: Rect2, color: Color) -> Polygon2D:
	var strip: Polygon2D = Polygon2D.new()
	strip.color = color
	strip.polygon = PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
	return strip

static func _blocked(at: Vector2, avoid: Array) -> bool:
	for box: Rect2 in avoid:
		if box.has_point(at):
			return true
	return false

static func _sprite(pick: int, at: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _cuts[pick]
	sprite.position = at
	sprite.centered = true
	return sprite

## The sheet is a grid. Each cell is trimmed and made smaller once, then shared.
static func _cut_sheet() -> void:
	if not _cuts.is_empty():
		return
	var sheet: Texture2D = load(SHEET) as Texture2D
	if sheet == null:
		return
	var image: Image = sheet.get_image()
	var cell: int = int(float(image.get_width()) / float(GRID))
	for row: int in GRID:
		for column: int in GRID:
			var part: Image = image.get_region(Rect2i(column * cell, row * cell, cell, cell))
			var used: Rect2i = part.get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			part = part.get_region(used)
			part.resize(maxi(1, int(part.get_width() * SCALE)), maxi(1, int(part.get_height() * SCALE)), Image.INTERPOLATE_LANCZOS)
			_cuts.append(ImageTexture.create_from_image(part))
