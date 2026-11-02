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
		"count": 52,
		"area": Rect2(-240, -128, 496, 272),
		"picks": [TUFT, TUFT, TUFT, TUFT, YELLOW, PINK, WEEDS, WEEDS, STONES, TWIGS, ROCKS, SHRUB],
		"avoid": [
			Rect2(-182, -72, 100, 92), Rect2(-184, -140, 96, 80), Rect2(-84, 60, 72, 60), Rect2(90, 42, 76, 76),
			Rect2(148, 56, 96, 96), Rect2(36, 80, 72, 70), Rect2(148, 16, 44, 44), Rect2(50, -10, 46, 56),
			Rect2(-34, 24, 40, 30), Rect2(20, -60, 40, 40), Rect2(100, -90, 40, 40), Rect2(-136, 30, 34, 40),
		],
		"fixed": [
			[FENCE, Vector2(-168, 34)], [FENCE, Vector2(-144, 34)], [FENCE, Vector2(-120, 34)], [FENCE, Vector2(-96, 34)],
			[STUMP, Vector2(-70, -110)], [HAY, Vector2(118, 138)], [POT, Vector2(-84, -70)], [SHRUB, Vector2(226, -100)],
		],
	},
	"Orchard": {
		"seed": 17,
		"count": 44,
		"area": Rect2(-236, -146, 472, 292),
		"picks": [TUFT, TUFT, TUFT, YELLOW, PINK, WEEDS, STONES, SHRUB],
		"avoid": [Rect2(-204, -124, 110, 60), Rect2(-240, -14, 480, 44), Rect2(114, 20, 44, 130)],
		"fixed": [[STUMP, Vector2(150, -40)], [HAY, Vector2(70, -14)]],
	},
	"Village": {
		"seed": 23,
		"count": 16,
		"area": Rect2(-236, -146, 472, 292),
		"picks": [STONES, ROCKS, TWIGS, TUFT, WEEDS],
		"avoid": [
			Rect2(-240, -14, 480, 50), Rect2(-26, 30, 52, 120), Rect2(-130, -130, 370, 124), Rect2(60, 44, 180, 60),
			Rect2(-240, 84, 170, 66), Rect2(-70, 50, 50, 50), Rect2(-160, 30, 110, 54),
		],
		"fixed": [],
	},
	"Harbor": {
		"seed": 31,
		"count": 12,
		"area": Rect2(-236, -30, 472, 176),
		"picks": [STONES, ROCKS, TWIGS, TUFT],
		"avoid": [Rect2(-200, -30, 90, 70), Rect2(-70, -30, 200, 80)],
		"fixed": [],
	},
}

## Things to clear from the farm once. [picture, group, spot]
const DEBRIS: Array = [
	[TWIGS, "debris_wood", Vector2(-30, -30)], [TWIGS, "debris_wood", Vector2(10, -96)], [TWIGS, "debris_wood", Vector2(72, -104)],
	[TWIGS, "debris_wood", Vector2(-212, -6)], [TWIGS, "debris_wood", Vector2(-222, 72)], [TWIGS, "debris_wood", Vector2(172, -60)],
	[TWIGS, "debris_wood", Vector2(214, -18)],
	[STONES, "debris_stone", Vector2(-62, -102)], [STONES, "debris_stone", Vector2(-204, -112)], [STONES, "debris_stone", Vector2(34, -18)],
	[STONES, "debris_stone", Vector2(-104, 92)], [STONES, "debris_stone", Vector2(-190, 112)], [STONES, "debris_stone", Vector2(232, 22)],
	[WEEDS, "debris_weed", Vector2(-40, -72)], [WEEDS, "debris_weed", Vector2(-212, 32)], [WEEDS, "debris_weed", Vector2(142, -102)],
	[WEEDS, "debris_weed", Vector2(0, 104)], [WEEDS, "debris_weed", Vector2(-150, 122)],
]
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
		PropPiece.add_to(place, {"name": "HouseLamp", "path": ROOM % "lantern", "at": Vector2(-88, -62)})

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
