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
const LOG: int = 14
const SHELLS: int = 15
const TRUFFLE: int = 16
const DRY_GRASS: int = 17
const OBJECTS: String = "res://assets/props/world_objects.png"
## Newer pictures: which object sheet cell replaces a detail, and its longest side in pixels.
const OBJECT_CUTS: Dictionary = {
	YELLOW: [Vector2i(2, 2), 20], PINK: [Vector2i(3, 2), 20], SHRUB: [Vector2i(1, 3), 24], STONES: [Vector2i(0, 1), 12],
	TWIGS: [Vector2i(3, 1), 22], WEEDS: [Vector2i(0, 2), 20], STUMP: [Vector2i(1, 0), 34], ROCKS: [Vector2i(2, 0), 26],
	LOG: [Vector2i(0, 0), 46], SHELLS: [Vector2i(3, 0), 26], TRUFFLE: [Vector2i(2, 3), 18], DRY_GRASS: [Vector2i(3, 3), 20],
}

const LAYOUTS: Dictionary = {
	"Home": {
		"seed": 41,
		"count": 620,
		"picks": [TUFT, TUFT, TUFT, TUFT, TUFT, YELLOW, PINK, WEEDS, WEEDS, STONES, TWIGS, ROCKS, SHRUB],
		"avoid": [
			Rect2(-186, -74, 104, 96), Rect2(-220, -220, 170, 150), Rect2(-430, -300, 100, 90), Rect2(260, -230, 140, 110),
			Rect2(240, 110, 160, 160), Rect2(68, 130, 104, 110), Rect2(50, -10, 46, 56), Rect2(-40, 20, 50, 40),
			Rect2(50, -190, 80, 90), Rect2(170, -140, 80, 90), Rect2(-446, 66, 212, 210), Rect2(84, -296, 132, 132), Rect2(364, 192, 112, 108),
		],
		"fixed": [
			[FENCE, Vector2(-168, 34)], [FENCE, Vector2(-144, 34)], [FENCE, Vector2(-120, 34)], [FENCE, Vector2(-96, 34)],
			[FENCE, Vector2(32, 250)], [FENCE, Vector2(56, 250)], [STUMP, Vector2(-30, -180)], [HAY, Vector2(236, 262)],
			[HAY, Vector2(30, 228)], [POT, Vector2(-54, -90)], [STUMP, Vector2(-300, 120)], [STUMP, Vector2(420, -60)],
			[LOG, Vector2(-220, -300)], [LOG, Vector2(430, 330)], [LOG, Vector2(-480, -60)], [LOG, Vector2(300, -380)], [LOG, Vector2(-120, 380)],
		],
	},
	"Road": {
		"seed": 53,
		"count": 90,
		"picks": [DRY_GRASS, DRY_GRASS, TUFT, ROCKS, ROCKS, STONES, SHRUB, TWIGS, YELLOW],
		"avoid": [],
		"fixed": [[STUMP, Vector2(-180, 110)], [HAY, Vector2(120, -70)], [FENCE, Vector2(-60, -48)], [FENCE, Vector2(-36, -48)], [FENCE, Vector2(-12, -48)]],
	},
	"Forest": {
		"seed": 61,
		"count": 620,
		"picks": [TUFT, TUFT, TUFT, WEEDS, WEEDS, SHRUB, SHRUB, PINK, YELLOW, STUMP, TWIGS, STONES, TRUFFLE],
		"avoid": [],
		"fixed": [[LOG, Vector2(380, -330)], [LOG, Vector2(-420, -300)], [LOG, Vector2(420, 330)], [LOG, Vector2(-380, 420)]],
	},
	"Orchard": {
		"seed": 17,
		"count": 240,
		"picks": [TUFT, TUFT, TUFT, DRY_GRASS, YELLOW, PINK, WEEDS, STONES, SHRUB],
		"avoid": [Rect2(-410, -210, 220, 120)],
		"fixed": [[STUMP, Vector2(300, -80)], [HAY, Vector2(140, -40)]],
	},
	"Village": {
		"seed": 23,
		"count": 460,
		"picks": [TUFT, TUFT, TUFT, TUFT, YELLOW, PINK, WEEDS, SHRUB, STONES, ROCKS],
		"avoid": [],
		"fixed": [],
	},
	"Cave": {
		"seed": 7,
		"count": 34,
		"area": Rect2(-236, -110, 472, 320),
		"picks": [STONES, STONES, ROCKS, ROCKS, TWIGS, TRUFFLE],
		"avoid": [Rect2(-60, 150, 120, 60), Rect2(50, 30, 60, 60), Rect2(-100, 10, 60, 60)],
		"fixed": [],
	},
	"Harbor": {
		"seed": 31,
		"count": 170,
		"picks": [STONES, ROCKS, TWIGS, DRY_GRASS, DRY_GRASS, SHELLS, SHELLS, SHRUB],
		"avoid": [],
		"fixed": [[HAY, Vector2(-40, -130)]],
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
const PLANT: String = "res://assets/nature/plants/%s.png"
## Which trees grow where, and how the bushes and rocks are mixed.
const TREES_BY_PLACE: Dictionary = {
	"Home": ["ghaf", "sidr", "leafy", "ghaf", "acacia", "sidr", "tamarisk"],
	"Forest": ["ghaf", "ghaf", "sidr", "ghaf", "acacia"],
	"Village": ["sidr", "ghaf", "leafy", "tamarisk", "sidr"],
	"Orchard": ["sidr", "ghaf", "acacia"],
}
const BUSH_COUNTS: Dictionary = {"Home": 46, "Forest": 60, "Village": 34, "Orchard": 20, "Road": 18, "Harbor": 14}
const BUSHES_GREEN: Array[String] = ["bush", "bush_pink", "bush_white", "bush", "sapling", "rocks_moss", "outcrop"]
const BUSHES_DRY: Array[String] = ["bush_dry", "dune_grass", "outcrop", "bush_dry", "dune_grass"]
## Sandstone walls that give the quarry and the shores some height. [place, spots]
const CLIFFS: Dictionary = {
	"Home": [Vector2(-560, -330), Vector2(-500, -390), Vector2(-430, -420), Vector2(-360, -440), Vector2(-290, -440), Vector2(-220, -450), Vector2(-540, -250)],
	"Forest": [Vector2(-620, 480), Vector2(-560, 530), Vector2(-490, 570), Vector2(-420, 590), Vector2(600, 460), Vector2(540, 520)],
	"Village": [Vector2(-700, -430), Vector2(-640, -480), Vector2(-570, -500), Vector2(-500, -520), Vector2(690, 470), Vector2(640, 520)],
	"Harbor": [Vector2(-700, -330), Vector2(-640, -350), Vector2(650, -340), Vector2(700, -300)],
}
const PALM_PICTURE: String = "res://assets/nature/Date palm.png"
## Tree groups inside the farm clearing. They are scenery and cannot be chopped.
const FARM_TREES: Array[Vector2] = [
	Vector2(-420, -120), Vector2(-440, 60), Vector2(-280, -280), Vector2(-120, 270), Vector2(-70, 300), Vector2(70, 300),
	Vector2(200, 300), Vector2(420, 130), Vector2(430, -120), Vector2(300, 60), Vector2(380, -40), Vector2(-300, -60),
	Vector2(-120, 130), Vector2(20, -230), Vector2(-20, -280), Vector2(60, -280), Vector2(250, -280), Vector2(-250, -130),
	Vector2(-210, 110), Vector2(120, 110),
]
const FARM_PALMS: Array[Vector2] = [Vector2(-310, 40), Vector2(-360, -30), Vector2(-260, 130), Vector2(170, 120), Vector2(400, 180)]
## Extra ponds, as in a real clearing. [spot, width, solid footprint]
const FARM_PONDS: Array = [
	[Vector2(-340, 170), 190, Vector2(160, 134)], [Vector2(150, -230), 110, Vector2(92, 78)], [Vector2(420, 246), 90, Vector2(74, 62)],
]
const MORE_GROVES: int = 44
const ROCK_PICTURE: String = "res://assets/nature/Chunky desert rock sprite.png"
const COPPER_PICTURE: String = "res://assets/props/ore_copper.png"
const HERB_PICTURE: String = "res://assets/nature/Wild herb.png"
## Each corner of the farm has its own daily job. These come back every morning.
const QUARRY: Array[Vector2] = [Vector2(-320, -170), Vector2(-280, -240), Vector2(-430, -190)]
const QUARRY_ORE: Vector2 = Vector2(-340, -290)
const WOODLOT: Array[Vector2] = [Vector2(-210, 245), Vector2(-120, 215), Vector2(-60, 255)]
const HERB_PATCH: Array[Vector2] = [Vector2(250, -30), Vector2(340, -60), Vector2(280, 100)]

const MORE_DEBRIS: int = 70
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
	var place_name: String = str(place.name)
	var shaped: bool = WorldShapes.has_place(place_name)
	if shaped:
		_lay_ground(place, place_name)
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = int(layout["seed"])
	var picks: Array = layout["picks"]
	var area: Rect2 = layout["area"] if layout.has("area") else _clearing(place_name)
	for i: int in int(layout["count"]):
		var at: Vector2 = area.position + Vector2(roll.randf() * area.size.x, roll.randf() * area.size.y)
		var pick: int = int(picks[roll.randi_range(0, picks.size() - 1)])
		if _blocked(at, layout["avoid"]):
			continue
		if shaped and (WorldShapes.keep_clear(place_name, at) or WorldShapes.edge(place_name, at) > 0.98):
			continue
		decor.add_child(_sprite(pick, at))
	for row: Array in layout["fixed"]:
		decor.add_child(_sprite(int(row[0]), row[1]))
	place.add_child(decor)
	if shaped and bool(WorldShapes.PLACES[place_name]["wooded"]):
		_add_forest(place, place_name)
	if shaped:
		_add_bushes(place, place_name, layout)
		_add_cliffs(place, place_name)
	if place.name == "Home":
		_add_debris(place, cleared)
		PropPiece.add_to(place, {"name": "HouseLamp", "path": ROOM % "lantern", "at": Vector2(-50, -66)})
		for i: int in FARM_TREES.size():
			PropPiece.add_to(place, {"name": "Palm_tree%d" % i, "path": _tree("Home", i), "at": FARM_TREES[i], "block": Vector2(14, 8)})
		for i: int in FARM_PALMS.size():
			PropPiece.add_to(place, {"name": "Palm_farm%d" % i, "path": PALM_PICTURE, "at": FARM_PALMS[i], "block": Vector2(10, 6)})
		for i: int in FARM_PONDS.size():
			PropPiece.add_to(place, {"name": "Pond_%d" % i, "path": "res://assets/nature/Oasis pond.png", "at": FARM_PONDS[i][0], "fit": FARM_PONDS[i][1], "block": FARM_PONDS[i][2], "centered": true})
		_add_zones(place)
		_add_groves(place)

static func _add_zones(place: Node) -> void:
	for i: int in QUARRY.size():
		PropPiece.add_to(place, {"name": "ZoneRock%d" % i, "path": ROCK_PICTURE, "at": QUARRY[i], "fit": 28, "group": "rock"})
	PropPiece.add_to(place, {"name": "ZoneOre", "path": COPPER_PICTURE, "at": QUARRY_ORE, "group": "ore"})
	for i: int in WOODLOT.size():
		PropPiece.add_to(place, {"name": "ZoneStump%d" % i, "texture": _cuts[STUMP], "at": WOODLOT[i], "group": "tree"})
	for i: int in HERB_PATCH.size():
		PropPiece.add_to(place, {"name": "ZoneHerb%d" % i, "path": HERB_PICTURE, "at": HERB_PATCH[i], "group": "forage"})

static func _tree(place_name: String, index: int) -> String:
	var kinds: Array = TREES_BY_PLACE.get(place_name, ["sidr"])
	var kind: String = str(kinds[index % kinds.size()])
	return PLANT % kind

static func _add_bushes(place: Node, place_name: String, layout: Dictionary) -> void:
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = int(layout["seed"]) + 5
	var area: Rect2 = _clearing(place_name)
	var kinds: Array[String] = BUSHES_DRY if bool(WorldShapes.PLACES[place_name]["sandy"]) else BUSHES_GREEN
	for i: int in int(BUSH_COUNTS.get(place_name, 0)):
		var at: Vector2 = area.position + Vector2(roll.randf() * area.size.x, roll.randf() * area.size.y)
		var kind: String = kinds[roll.randi_range(0, kinds.size() - 1)]
		if WorldShapes.keep_clear(place_name, at) or WorldShapes.edge(place_name, at) > 0.96 or WorldShapes.in_exit(place_name, at) or _blocked(at, layout["avoid"]):
			continue
		PropPiece.add_to(place, {"name": "Grove_bush%d" % i, "path": PLANT % kind, "at": at, "block": Vector2(18, 8) if kind.begins_with("bush") or kind.ends_with("crop") else Vector2.ZERO})

static func _add_cliffs(place: Node, place_name: String) -> void:
	var spots: Array = CLIFFS.get(place_name, [])
	for i: int in spots.size():
		PropPiece.add_to(place, {"name": "Cliff%d" % i, "path": PLANT % "cliff", "at": spots[i], "block": Vector2(70, 18)})

static func _clearing(place_name: String) -> Rect2:
	var half: Vector2 = WorldShapes.PLACES[place_name]["half"]
	return Rect2(-half, half * 2.0)

## The painted ground lies under everything else in the place.
static func _lay_ground(place: Node, place_name: String) -> void:
	var picture: Texture2D = load(WorldShapes.ground_path(place_name)) as Texture2D
	if picture == null:
		return
	var ground: Sprite2D = Sprite2D.new()
	ground.name = "PaintedGround"
	ground.texture = picture
	ground.z_index = -1
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shimmer: ShaderMaterial = ShaderMaterial.new()
	shimmer.shader = load("res://src/shaders/water_shimmer.gdshader") as Shader
	var clock: Node = place.get_tree().current_scene.get_node_or_null("Systems/Clock") if place.is_inside_tree() else null
	var tint: Color = WorldShapes.season_grass(str(clock.get("season"))) if clock != null else Color.WHITE
	shimmer.set_shader_parameter("grass_tint", Vector3(tint.r, tint.g, tint.b))
	ground.material = shimmer
	place.add_child(ground)
	place.move_child(ground, 0)
	WorldShapes.add_water_walls(place)

## A thick ring of still trees around the clearing, with gaps at the exits.
static func _add_forest(place: Node, place_name: String) -> void:
	var half: Vector2 = WorldShapes.PLACES[place_name]["half"]
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = 77
	var made: int = 0
	var y: float = -half.y - 110.0
	while y < half.y + 130.0:
		var x: float = -half.x - 110.0
		while x < half.x + 110.0:
			var at: Vector2 = Vector2(x + roll.randf() * 24.0, y + roll.randf() * 20.0)
			var edge: float = WorldShapes.edge(place_name, at)
			if edge > 1.0 and edge < 1.22 and not WorldShapes.in_exit(place_name, at) and not WorldShapes.keep_clear(place_name, at):
				PropPiece.add_to(place, {"name": "Forest%d" % made, "path": _tree(place_name, made), "at": at, "block": Vector2(18, 10)})
				made += 1
			x += 46.0
		y += 42.0

## Groups of trees on the farm, away from the roads and buildings.
static func _add_groves(place: Node) -> void:
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = 91
	var avoid: Array = LAYOUTS["Home"]["avoid"]
	var made: int = 0
	for i: int in MORE_GROVES:
		var at: Vector2 = Vector2(roll.randf_range(-570.0, 570.0), roll.randf_range(-460.0, 460.0))
		if WorldShapes.edge("Home", at) > 0.95 or _blocked(at, avoid) or WorldShapes.on_road("Home", at, 30.0) or WorldShapes.in_exit("Home", at):
			continue
		if at.distance_to(Vector2.ZERO) < 240.0:
			continue
		var is_palm: bool = i % 4 == 0
		PropPiece.add_to(place, {"name": "Palm_grove%d" % made, "path": PALM_PICTURE if is_palm else _tree("Home", i), "at": at, "block": Vector2(14, 8)})
		made += 1

static func _add_debris(place: Node, cleared: Dictionary) -> void:
	for i: int in DEBRIS.size():
		var row: Array = DEBRIS[i]
		var mark_name: String = "Debris%d" % i
		if bool(cleared.get("cleared_" + mark_name, false)):
			continue
		PropPiece.add_to(place, {"name": mark_name, "texture": _cuts[int(row[0])], "at": row[2], "group": str(row[1])})
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = 58
	var kinds: Array = [[TWIGS, "debris_wood"], [STONES, "debris_stone"], [WEEDS, "debris_weed"]]
	var avoid: Array = LAYOUTS["Home"]["avoid"]
	for i: int in MORE_DEBRIS:
		var spot: Vector2 = Vector2(roll.randf_range(-580.0, 580.0), roll.randf_range(-470.0, 470.0))
		var kind: Array = kinds[i % kinds.size()]
		var extra_name: String = "Debris%d" % (DEBRIS.size() + i)
		if WorldShapes.edge("Home", spot) > 0.94 or _blocked(spot, avoid) or WorldShapes.keep_clear("Home", spot) or bool(cleared.get("cleared_" + extra_name, false)):
			continue
		PropPiece.add_to(place, {"name": extra_name, "texture": _cuts[int(kind[0])], "at": spot, "group": str(kind[1])})

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

static func _cut_objects() -> void:
	var sheet: Texture2D = load(OBJECTS) as Texture2D
	if sheet == null:
		return
	var image: Image = sheet.get_image()
	var cell: int = int(float(image.get_width()) / float(GRID))
	_cuts.resize(maxi(_cuts.size(), DRY_GRASS + 1))
	for key: int in OBJECT_CUTS:
		var at: Vector2i = OBJECT_CUTS[key][0]
		var part: Image = image.get_region(Rect2i(at * cell, Vector2i(cell, cell)))
		var used: Rect2i = part.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		part = part.get_region(used)
		var factor: float = float(OBJECT_CUTS[key][1]) / float(maxi(part.get_width(), part.get_height()))
		part.resize(maxi(1, int(part.get_width() * factor)), maxi(1, int(part.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
		_cuts[key] = ImageTexture.create_from_image(part)

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
	_cut_objects()
