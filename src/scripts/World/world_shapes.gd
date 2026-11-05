# src/scripts/World/world_shapes.gd
# Purpose: The land shape of each place: its edge, roads, water, and bridges. The ground painter and the game read the same data.

class_name WorldShapes
extends RefCounted

const FOREST_FLOOR: int = 0
const GRASS: int = 1
const DIRT: int = 2
const ROAD: int = 3
const COBBLE: int = 4
const WATER: int = 5
const SHORE: int = 6
const SAND: int = 7
const PLANKS: int = 8

## bare: how much noise it takes for a patch of bare dirt to show through the grass (higher is fewer patches).
## half: the middle-to-edge size of the clearing. wooded: dark forest around it. sandy: sand in place of grass.
## roads: [from, to, half width]. water: [from, to, half width]. lakes: [middle, radius]. planks: bridges and docks.
## lawn: boxes kept as grass with no bare patches. exits: gaps cut through the forest. sea_from: below this height everything is sea.
const PLACES: Dictionary = {
	"Home": {
		"half": Vector2(620, 500), "wooded": true, "sandy": false, "seed": 12, "bare": 0.42,
		"roads": [
			[Vector2(-392, -262), Vector2(-392, -150), 11.0], [Vector2(-392, -170), Vector2(220, -170), 11.0],
			[Vector2(220, -170), Vector2(260, 40), 11.0], [Vector2(260, 40), Vector2(720, 40), 11.0],
			[Vector2(220, -170), Vector2(400, -268), 9.0], [Vector2(260, 40), Vector2(240, 240), 10.0],
			[Vector2(240, 240), Vector2(0, 330), 11.0], [Vector2(0, 330), Vector2(0, 620), 11.0],
		],
		"water": [], "lakes": [], "planks": [],
		"dirt": [],
		# The farm land is plain grass, so only the squares the boy hoes look like soil.
		"lawn": [Rect2(-470, -150, 652, 366)],
		"exits": [Rect2(380, 6, 400, 68), Rect2(-34, 320, 68, 320)],
	},
	"Road": {
		"half": Vector2(330, 200), "wooded": false, "sandy": true, "seed": 3,
		"roads": [[Vector2(-420, 6), Vector2(420, 6), 22.0]],
		"water": [], "lakes": [], "planks": [], "dirt": [], "exits": [],
	},
	"Village": {
		"half": Vector2(800, 620), "wooded": true, "sandy": false, "seed": 27, "bare": 0.42,
		"roads": [
			[Vector2(-900, -120), Vector2(-220, -60), 18.0], [Vector2(-180, -760), Vector2(-140, -160), 18.0], [Vector2(180, 760), Vector2(120, 100), 18.0],
			[Vector2(-600, 760), Vector2(-400, 300), 16.0], [Vector2(-400, 300), Vector2(-160, 100), 16.0], [Vector2(240, -40), Vector2(900, -40), 16.0],
			[Vector2(140, 60), Vector2(420, 300), 12.0], [Vector2(420, 300), Vector2(720, 300), 12.0], [Vector2(-340, -170), Vector2(-200, -100), 12.0],
			[Vector2(-300, 330), Vector2(-60, 450), 12.0], [Vector2(-40, -280), Vector2(-40, -160), 12.0], [Vector2(230, -280), Vector2(190, -160), 12.0],
		],
		"water": [
			[Vector2(590, -760), Vector2(500, -320), 42.0], [Vector2(500, -320), Vector2(540, 40), 42.0], [Vector2(540, 40), Vector2(470, 330), 42.0],
			[Vector2(470, 330), Vector2(530, 760), 42.0],
		],
		"lakes": [],
		"planks": [Rect2(462, -62, 150, 44), Rect2(432, 280, 120, 40)],
		"cobble": [Rect2(-230, -180, 480, 290)],
		"dirt": [],
		"exits": [Rect2(-900, -170, 300, 100), Rect2(-230, -760, 110, 260), Rect2(120, 400, 120, 360), Rect2(-660, 420, 120, 340)],
	},
	"Forest": {
		"half": Vector2(750, 650), "wooded": true, "sandy": false, "seed": 61,
		"roads": [
			[Vector2(0, -780), Vector2(40, -300), 12.0], [Vector2(40, -300), Vector2(320, -120), 12.0], [Vector2(320, -120), Vector2(860, 0), 12.0],
		],
		"water": [
			[Vector2(-140, 180), Vector2(60, 340), 34.0], [Vector2(60, 340), Vector2(-30, 520), 40.0], [Vector2(-30, 520), Vector2(60, 780), 48.0],
		],
		"lakes": [[Vector2(-270, 40), 190.0]],
		"planks": [], "dirt": [],
		"exits": [Rect2(-44, -780, 88, 300), Rect2(420, -44, 440, 88)],
	},
	"Harbor": {
		"half": Vector2(750, 400), "wooded": false, "sandy": true, "seed": 44, "sea_from": 92.0,
		"roads": [[Vector2(180, -500), Vector2(150, -120), 16.0], [Vector2(150, -120), Vector2(60, 70), 14.0]],
		"water": [], "lakes": [],
		"planks": [Rect2(10, 70, 100, 270)],
		"dirt": [], "exits": [],
	},
	"Orchard": {
		"half": Vector2(520, 340), "wooded": true, "sandy": false, "seed": 17,
		"roads": [[Vector2(0, 460), Vector2(10, 40), 14.0], [Vector2(10, 40), Vector2(-160, -40), 10.0], [Vector2(10, 40), Vector2(240, 10), 10.0]],
		"water": [], "lakes": [], "planks": [], "dirt": [],
		"exits": [Rect2(-44, 200, 88, 260)],
	},
}

## A tree's picture for this season. Gulf winters bring bare branches, not snow.
static func seasonal_picture(path: String, season: String) -> String:
	if season == "Autumn" and (path.ends_with("plants/ghaf.png") or path.ends_with("plants/sidr.png")):
		return path.replace(".png", "_autumn.png")
	if season == "Winter" and path.ends_with("plants/ghaf.png"):
		return path.replace(".png", "_winter.png")
	return path

## How green ground shifts with the season.
static func season_grass(season: String) -> Color:
	match season:
		"Summer":
			return Color(1.08, 1.0, 0.78)
		"Autumn":
			return Color(1.22, 0.94, 0.62)
		"Winter":
			return Color(1.0, 0.96, 0.78)
	return Color.WHITE

static func has_place(place: String) -> bool:
	return PLACES.has(place)

static func ground_path(place: String) -> String:
	return "res://assets/world/ground_%s.png" % place.to_lower()

## One of the three mask maps the ground shader reads. Each mask pixel covers MASK_BLOCK world pixels.
static func mask_path(place: String, index: int) -> String:
	return "res://assets/world/mask_%s_%d.png" % [place.to_lower(), index]

const MASK_BLOCK: int = 4

## Below 1 is inside the clearing. The edge wobbles, so it never looks like a rectangle.
static func edge(place: String, world: Vector2) -> float:
	var half: Vector2 = PLACES[place]["half"]
	var x: float = absf(world.x) / half.x
	var y: float = absf(world.y) / half.y
	var round_edge: float = pow(pow(x, 4.0) + pow(y, 4.0), 0.25)
	var angle: float = atan2(world.y / half.y, world.x / half.x)
	return round_edge / (1.0 + 0.04 * sin(angle * 3.0 + 1.0) + 0.025 * sin(angle * 7.0 + 2.0) + 0.012 * sin(angle * 13.0))

static func in_exit(place: String, world: Vector2) -> bool:
	for gap: Rect2 in PLACES[place]["exits"]:
		if gap.has_point(world):
			return true
	return false

static func to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to))

static func sea_line(place: String, x: float) -> float:
	return float(PLACES[place].get("sea_from", 1000000.0)) + sin(x * 0.012) * 10.0 + sin(x * 0.031) * 5.0

## How far a point is inside water. Below zero is dry land, and near zero is the shore.
static func water_depth(place: String, world: Vector2) -> float:
	var shape: Dictionary = PLACES[place]
	var depth: float = world.y - sea_line(place, world.x)
	for part: Array in shape["water"]:
		depth = maxf(depth, float(part[2]) - to_segment(world, part[0], part[1]))
	for lake: Array in shape["lakes"]:
		var middle: Vector2 = lake[0]
		var wobble: float = 1.0 + 0.1 * sin((world - middle).angle() * 3.0 + 0.5) + 0.05 * sin((world - middle).angle() * 7.0)
		depth = maxf(depth, float(lake[1]) * wobble - world.distance_to(middle))
	return depth

static func on_planks(place: String, world: Vector2) -> bool:
	for box: Rect2 in PLACES[place]["planks"]:
		if box.has_point(world):
			return true
	return false

static func on_road(place: String, world: Vector2, margin: float = 0.0) -> bool:
	for road: Array in PLACES[place]["roads"]:
		if to_segment(world, road[0], road[1]) < float(road[2]) + margin:
			return true
	for box: Rect2 in PLACES[place].get("cobble", []):
		if box.has_point(world):
			return true
	return false

## True where small details and trees should stay away from.
static func keep_clear(place: String, world: Vector2) -> bool:
	return water_depth(place, world) > -12.0 or on_planks(place, world) or on_road(place, world, 6.0)

## Solid water, with gaps where a bridge crosses. Lakes and rivers stop the boy; the sea is walled by the scene.
static func add_water_walls(place_node: Node) -> void:
	var place: String = str(place_node.name)
	var shape: Dictionary = PLACES[place]
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "WaterWalls"
	for part: Array in shape["water"]:
		var from: Vector2 = part[0]
		var to: Vector2 = part[1]
		var steps: int = maxi(1, int(from.distance_to(to) / 24.0))
		for i: int in steps:
			var a: Vector2 = from.lerp(to, float(i) / float(steps))
			var b: Vector2 = from.lerp(to, float(i + 1) / float(steps))
			if on_planks(place, (a + b) * 0.5):
				continue
			var piece: CollisionShape2D = CollisionShape2D.new()
			var box: RectangleShape2D = RectangleShape2D.new()
			box.size = Vector2(a.distance_to(b) + 2.0, float(part[2]) * 2.0 - 8.0)
			piece.shape = box
			piece.position = (a + b) * 0.5
			piece.rotation = (b - a).angle()
			body.add_child(piece)
	for lake: Array in shape["lakes"]:
		var piece: CollisionShape2D = CollisionShape2D.new()
		var round_shape: CircleShape2D = CircleShape2D.new()
		round_shape.radius = float(lake[1]) * 0.92
		piece.shape = round_shape
		piece.position = lake[0]
		body.add_child(piece)
	if body.get_child_count() > 0:
		place_node.add_child(body)
	else:
		body.free()
