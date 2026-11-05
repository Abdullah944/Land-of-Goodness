# src/scripts/World/place_decor.gd
# Purpose: Scatters small ground details, so a place looks lived in. They are pictures only and never block.

class_name PlaceDecor
extends RefCounted

const SHEET: String = "res://assets/props/ground_details.png"
## The painted textures the HD ground blends, by shader name.
const GROUND_TEXTURES: Dictionary = {
	"grass": "res://assets/world/hd/grass.png", "dirt": "res://assets/world/hd/dirt.png", "sand": "res://assets/world/hd/sand.png",
	"road": "res://assets/world/hd/road.png", "cobble": "res://assets/world/hd/cobble.png", "water": "res://assets/world/hd/water.png",
	"planks": "res://assets/world/hd/planks.png", "forest": "res://assets/world/hd/forest.png",
}
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
	TUFT: [Vector2i(1, 1), 15], FENCE: [Vector2i(2, 1), 26], HAY: [Vector2i(1, 2), 28], POT: [Vector2i(0, 3), 17],
}

## The fenced farm land below the house at its largest. Nothing else grows or lies inside it.
const FIELD_ROOM: Rect2 = Rect2(-484, -164, 680, 392)

const LAYOUTS: Dictionary = {
	"Home": {
		"seed": 41,
		"count": 300,
		"picks": [TUFT, TUFT, TUFT, TUFT, TUFT, TUFT, YELLOW, PINK, WEEDS, STONES],
		# The farm land, the house corner, the bench and neighbor, the cave and quarry corner, the ponds,
		# the coop and barn, the wood lot, the herb patch, and the trees on the north lawn.
		"avoid": [
			FIELD_ROOM, Rect2(-520, -460, 260, 260), Rect2(-330, -280, 180, 90), Rect2(220, -470, 340, 270), Rect2(300, -210, 170, 120),
			Rect2(-450, 260, 190, 150), Rect2(250, 130, 150, 160), Rect2(370, 190, 190, 210), Rect2(-230, 220, 200, 100),
			Rect2(270, -100, 110, 240), Rect2(-140, -300, 300, 110),
		],
		"fixed": [
			[STUMP, Vector2(-160, -215)], [HAY, Vector2(380, 270)],
			[HAY, Vector2(212, 268)], [POT, Vector2(-318, -262)], [STUMP, Vector2(540, -60)],
			[LOG, Vector2(-220, -300)], [LOG, Vector2(530, 250)], [LOG, Vector2(-540, -120)], [LOG, Vector2(200, -400)], [LOG, Vector2(-120, 380)],
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
	[TWIGS, "debris_wood", Vector2(-150, -240)], [TWIGS, "debris_wood", Vector2(30, -270)], [TWIGS, "debris_wood", Vector2(150, -215)],
	[TWIGS, "debris_wood", Vector2(-530, 250)], [TWIGS, "debris_wood", Vector2(-250, 420)], [TWIGS, "debris_wood", Vector2(540, 180)],
	[TWIGS, "debris_wood", Vector2(420, -60)],
	[STONES, "debris_stone", Vector2(150, -280)], [STONES, "debris_stone", Vector2(470, -200)], [STONES, "debris_stone", Vector2(60, 250)],
	[STONES, "debris_stone", Vector2(-176, 380)], [STONES, "debris_stone", Vector2(300, 420)], [STONES, "debris_stone", Vector2(380, 100)],
	[WEEDS, "debris_weed", Vector2(-240, -290)], [WEEDS, "debris_weed", Vector2(-530, -200)], [WEEDS, "debris_weed", Vector2(520, -190)],
	[WEEDS, "debris_weed", Vector2(150, 420)], [WEEDS, "debris_weed", Vector2(-555, 0)],
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
const BUSH_COUNTS: Dictionary = {"Home": 18, "Forest": 60, "Village": 34, "Orchard": 20, "Road": 18, "Harbor": 14}
const BUSHES_GREEN: Array[String] = ["bush", "bush_pink", "bush_white", "bush", "sapling", "rocks_moss", "outcrop"]
const BUSHES_DRY: Array[String] = ["bush_dry", "dune_grass", "outcrop", "bush_dry", "dune_grass"]
## Sandstone walls that give the quarry and the shores some height. [place, spots]
const CLIFFS: Dictionary = {
	"Home": [Vector2(560, -330), Vector2(500, -390), Vector2(430, -420), Vector2(360, -440), Vector2(290, -440), Vector2(220, -450), Vector2(540, -250)],
	"Forest": [Vector2(-620, 480), Vector2(-560, 530), Vector2(-490, 570), Vector2(-420, 590), Vector2(600, 460), Vector2(540, 520)],
	"Village": [Vector2(-700, -430), Vector2(-640, -480), Vector2(-570, -500), Vector2(-500, -520), Vector2(690, 470), Vector2(640, 520)],
	"Harbor": [Vector2(-700, -330), Vector2(-640, -350), Vector2(650, -340), Vector2(700, -300)],
}
const PALM_PICTURE: String = "res://assets/nature/Date palm.png"
## Tree groups inside the farm clearing. They are scenery and cannot be chopped.
const FARM_TREES: Array[Vector2] = [
	Vector2(-200, -340), Vector2(-70, 320), Vector2(90, 380), Vector2(200, 330), Vector2(430, 130), Vector2(500, -120),
	Vector2(480, -30), Vector2(-40, -330), Vector2(60, -320), Vector2(170, -330),
]
## Palms stand in a row along the farm land's left side, and two on the north lawn.
const FARM_PALMS: Array[Vector2] = [Vector2(-510, -40), Vector2(-510, 70), Vector2(-510, 180), Vector2(560, 120), Vector2(-60, -215)]
## Extra ponds, as in a real clearing. [spot, width, solid footprint]
const FARM_PONDS: Array = [
	[Vector2(-360, 330), 170, Vector2(144, 120)],
]
const MORE_GROVES: int = 16
const ROCK_PICTURE: String = "res://assets/nature/Chunky desert rock sprite.png"
const COPPER_PICTURE: String = "res://assets/props/ore_copper.png"
const HERB_PICTURE: String = "res://assets/nature/Wild herb.png"
## Each corner of the farm has its own daily job. These come back every morning.
## The house has the north-west corner; the quarry is by the cave in the north-east.
const QUARRY: Array[Vector2] = [Vector2(300, -290), Vector2(480, -270), Vector2(260, -235)]
const QUARRY_ORE: Vector2 = Vector2(340, -360)
const WOODLOT: Array[Vector2] = [Vector2(-200, 280), Vector2(-120, 250), Vector2(-60, 290)]
const HERB_PATCH: Array[Vector2] = [Vector2(300, -60), Vector2(350, -10), Vector2(310, 110)]

const MORE_DEBRIS: int = 30
const ROOM: String = "res://assets/building/house/room/%s.png"
const ROOM_AREA: Rect2 = Rect2(-120, 6, 288, 154)
const WALL_ROW: Array[String] = ["wall", "wall_window", "wall", "wall_pattern", "wall", "wall_window", "wall", "wall_shelf", "wall_window"]
## Furniture that is always in the house. [picture, spot, solid footprint]
## The room has corners with one use each: the shelf and pot on the back wall, a sitting rug on the left,
## the bed on the right, and baskets and a bench along the front wall. The walk from the door stays open.
const FURNITURE: Array = [
	["pot", Vector2(-104, 30), Vector2(22, 8)], ["shelf", Vector2(-58, 22), Vector2(52, 8)], ["lantern", Vector2(-14, 14), Vector2.ZERO],
	["lamp_table", Vector2(72, 30), Vector2(24, 8)], ["plant_vase", Vector2(160, 30), Vector2(20, 8)],
	["table", Vector2(-62, 104), Vector2(44, 12)], ["dates_bowl", Vector2(-62, 86), Vector2.ZERO],
	["cushion_red", Vector2(-100, 106), Vector2.ZERO], ["cushion_green", Vector2(-24, 106), Vector2.ZERO],
	["basket", Vector2(-104, 152), Vector2(22, 8)], ["jar", Vector2(-82, 150), Vector2(16, 8)], ["bench", Vector2(128, 152), Vector2(44, 8)],
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
		PropPiece.add_to(place, {"name": "HouseLamp", "path": ROOM % "lantern", "at": Vector2(-306, -274)})
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
	var clock: Node = place.get_tree().current_scene.get_node_or_null("Systems/Clock") if place.is_inside_tree() else null
	var tint: Color = WorldShapes.season_grass(str(clock.get("season"))) if clock != null else Color.WHITE
	var paint: ShaderMaterial = _hd_ground(place_name, picture.get_size())
	if paint != null:
		# The mask map stands in for the colored map, stretched over the same ground.
		ground.texture = load(WorldShapes.mask_path(place_name, 0)) as Texture2D
		ground.scale = picture.get_size() / ground.texture.get_size()
	else:
		paint = ShaderMaterial.new()
		paint.shader = load("res://src/shaders/water_shimmer.gdshader") as Shader
	paint.set_shader_parameter("grass_tint", Vector3(tint.r, tint.g, tint.b))
	ground.material = paint
	place.add_child(ground)
	place.move_child(ground, 0)
	WorldShapes.add_water_walls(place)

## The painted HD ground for a place, or null when its masks are missing.
static func _hd_ground(place_name: String, world_size: Vector2) -> ShaderMaterial:
	for i: int in 3:
		if not ResourceLoader.exists(WorldShapes.mask_path(place_name, i)):
			return null
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = load("res://src/shaders/ground_blend.gdshader") as Shader
	paint.set_shader_parameter("mask_a", load(WorldShapes.mask_path(place_name, 0)))
	paint.set_shader_parameter("mask_b", load(WorldShapes.mask_path(place_name, 1)))
	paint.set_shader_parameter("mask_c", load(WorldShapes.mask_path(place_name, 2)))
	for kind: String in GROUND_TEXTURES:
		paint.set_shader_parameter(kind, load(GROUND_TEXTURES[kind]))
	paint.set_shader_parameter("world_size", world_size)
	return paint

## The edge of a place is a tidy wall of green trees in rows that follow the border, with gaps at the exits,
## so it is always clear where the place ends.
const EDGE_TREES: Array[String] = ["sidr", "leafy", "ghaf", "sidr", "leafy"]
const EDGE_ROWS: Array[float] = [0.99, 1.06, 1.13]
const EDGE_STEP: float = 30.0

static func _add_forest(place: Node, place_name: String) -> void:
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = 77
	var made: int = 0
	for row: int in EDGE_ROWS.size():
		var walked: float = EDGE_STEP * 0.5 * float(row % 2)
		var last: Vector2 = _edge_point(place_name, 0.0, EDGE_ROWS[row])
		var turn: float = 0.0
		while turn < TAU:
			turn += 0.004
			var point: Vector2 = _edge_point(place_name, turn, EDGE_ROWS[row])
			walked += point.distance_to(last)
			last = point
			if walked < EDGE_STEP:
				continue
			walked = roll.randf_range(-3.0, 3.0)
			var at: Vector2 = point + Vector2(roll.randf_range(-3.0, 3.0), roll.randf_range(-2.0, 2.0))
			if WorldShapes.in_exit(place_name, at) or WorldShapes.keep_clear(place_name, at):
				continue
			var kind: String = EDGE_TREES[roll.randi_range(0, EDGE_TREES.size() - 1)]
			PropPiece.add_to(place, {"name": "Forest%d" % made, "path": PLANT % kind, "at": at, "block": Vector2(18, 10)})
			made += 1

## The point in this direction where the place's edge measure equals the given value. The measure grows evenly outward.
static func _edge_point(place_name: String, turn: float, measure: float) -> Vector2:
	var half: Vector2 = WorldShapes.PLACES[place_name]["half"]
	var way: Vector2 = Vector2(cos(turn) * half.x, sin(turn) * half.y)
	return way * measure / WorldShapes.edge(place_name, way)

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
		# Groves only near the edge of the farm, so the middle stays open for paths, the field, and the animals.
		if WorldShapes.edge("Home", at) < 0.72:
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
		if FIELD_ROOM.has_point(row[2]) or WorldShapes.keep_clear("Home", row[2]):
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
	PropPiece.add_to(place, {"name": "RoomRug", "path": ROOM % "rug", "at": Vector2(-62, 98), "flat": true})
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
	var image: Image = UiStyle.pixels_of(sheet)
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
		_cuts[key] = UiStyle.hd_texture(part, Vector2(part.get_size()) * factor)

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
