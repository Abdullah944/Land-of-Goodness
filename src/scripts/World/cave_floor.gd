# src/scripts/World/cave_floor.gd
# Purpose: The cave goes ten levels down. Each level has its own color, its own layout of rocks, ore and crystals,
# a ladder down at the back, and the way out at the front leads one level up.

class_name CaveFloor
extends Node2D

const DEEPEST: int = 10
const SCENE: String = "res://src/scenes/world/cave/Cave.tscn"
const LADDER_PICTURE: String = "res://assets/props/mine_door.png"
const CRYSTAL_PICTURE: String = "res://assets/props/ore_rock.png"
## Floor and wall tint, then crystal glow, for levels 1 to 10.
const COLORS: Array = [
	[Color("ffffff"), Color("ffc46b")],
	[Color("ffb39a"), Color("ff5a3c")],
	[Color("ffe08a"), Color("ffd23c")],
	[Color("b5e6a0"), Color("5fe36b")],
	[Color("9fe3dc"), Color("3ce0d0")],
	[Color("9fbcff"), Color("4f86ff")],
	[Color("c9a6ff"), Color("a35cff")],
	[Color("ffb3dd"), Color("ff5cb8")],
	[Color("9a9a9a"), Color("ff8a3c")],
	[Color("ffe066"), Color("ffc21a")],
]
## The floor the boy can stand on, inside the walls.
const ROOM: Rect2 = Rect2(-215, -80, 430, 255)
## The front of the cave, where he arrives from above and leaves upward.
const FRONT: Vector2 = Vector2(0, 150)
## Things the boy cannot clear keep this far from the walk between the front and the ladder.
const WALK_ROOM: float = 36.0
## Level 1 keeps its hand-made props; deeper levels make their own.
const LEVEL_ONE_ONLY: Array[String] = ["Rock", "Copper", "Prop2", "Prop3", "Prop4", "Prop5", "Prop6"]
const PROPS: Array[String] = ["res://assets/props/mine_cart.png", "res://assets/props/barrel.png", "res://assets/props/crate.png", "res://assets/props/pot_big.png"]

var level: int = 1
var ladder_at: Vector2 = Vector2.ZERO
var _taken: Array[Vector2] = []

## How many of each gathering spot a level has.
static func stone_count(depth: int) -> int:
	return 2 + depth / 3

static func copper_count(depth: int) -> int:
	return 1 + depth / 3

static func iron_count(depth: int) -> int:
	return 0 if depth < 3 else (depth - 1) / 2

static func floor_color(depth: int) -> Color:
	return COLORS[clampi(depth, 1, DEEPEST) - 1][0]

static func crystal_color(depth: int) -> Color:
	return COLORS[clampi(depth, 1, DEEPEST) - 1][1]

## The level the boy is on, kept in the save.
static func current_level(stead: Stead) -> int:
	return clampi(int(stead.flags.get("cave_level", 1)), 1, DEEPEST) if stead != null else 1

func _ready() -> void:
	var stead: Stead = _stead()
	level = current_level(stead)
	if stead != null:
		stead.flags["cave_deepest"] = maxi(int(stead.flags.get("cave_deepest", 1)), level)
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = 7919 * level
	ladder_at = Vector2(0, -62) if level == 1 else Vector2(roll.randf_range(-160.0, 160.0), -62)
	_paint()
	if level > 1:
		for node_name: String in LEVEL_ONE_ONLY:
			var old: Node = get_node_or_null(node_name)
			if old != null:
				remove_child(old)
				old.free()
		_fill(roll)
	_add_ladder_spawn()
	if level < DEEPEST:
		_add_ladder()
	else:
		_add_spot("Cave10/Treasure", "pearl", ladder_at, crystal_color(level), 1.4)
	_set_exit()
	var activities: Node = _activities()
	if activities != null and activities.has_method("flash"):
		activities.call("flash", Locale.t("cave_level") % level)

## Floor and walls take the level's color. Their brown pictures are turned gray first, so each color shows clearly.
## The floor lies under everything, whatever its height on screen.
func _paint() -> void:
	var tint: Color = floor_color(level)
	var floor_node: Polygon2D = get_node_or_null("Floor") as Polygon2D
	if floor_node != null:
		floor_node.z_index = -10
		if level > 1:
			floor_node.texture = gray_picture(floor_node.texture, 1.15)
			floor_node.modulate = tint
	if level == 1:
		return
	for child: Node in get_children():
		if str(child.name).begins_with("Wall") and child is CanvasItem:
			var wall_picture: Texture2D = child.get("person") as Texture2D
			if wall_picture != null:
				child.set("_picture", gray_picture(wall_picture, 1.1))
			(child as CanvasItem).modulate = tint.darkened(0.2)
			(child as CanvasItem).queue_redraw()

static var _grays: Dictionary = {}

## A gray copy of a picture, a little brighter, so a tint gives a clean color.
static func gray_picture(picture: Texture2D, bright: float) -> Texture2D:
	if picture == null:
		return null
	if _grays.has(picture.resource_path):
		return _grays[picture.resource_path]
	var image: Image = picture.get_image().duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var v: float = clampf(c.get_luminance() * bright, 0.0, 1.0)
			image.set_pixel(x, y, Color(v, v, v, c.a))
	# Keep the picture's game size: HD art holds more pixels than it shows.
	var gray: Texture2D = UiStyle.hd_texture(image, picture.get_size()) if UiStyle.is_hd(picture) else ImageTexture.create_from_image(image)
	_grays[picture.resource_path] = gray
	return gray

## Rocks for stone, copper and iron veins, glowing crystals and a few mining props, never on the walk to the ladder.
func _fill(roll: RandomNumberGenerator) -> void:
	for i: int in stone_count(level):
		_add_spot("Cave%d/Rock%d" % [level, i], "stone", _free_spot(roll, 30.0), Color.WHITE, 1.0, "res://assets/props/ore_rock.png")
	for i: int in copper_count(level):
		_add_spot("Cave%d/Copper%d" % [level, i], "copper", _free_spot(roll, 30.0), Color.WHITE, 1.0, "res://assets/props/ore_copper.png")
	for i: int in iron_count(level):
		_add_spot("Cave%d/Iron%d" % [level, i], "iron", _free_spot(roll, 30.0), Color.WHITE, 1.0, "res://assets/props/ore_iron.png")
	for i: int in 1 + level % 3:
		var prop: Node2D = PropPiece.MARK.new() as Node2D
		prop.name = "Mining%d" % i
		prop.position = _free_spot(roll, 34.0)
		prop.set("person", load(PROPS[roll.randi_range(0, PROPS.size() - 1)]) as Texture2D)
		prop.set("stand_on_feet", true)
		prop.set("block_size", Vector2(12, 6))
		add_child(prop)
	var crystal: Texture2D = load(CRYSTAL_PICTURE) as Texture2D
	for i: int in 4 + level:
		var glow: Sprite2D = Sprite2D.new()
		glow.name = "Crystal%d" % i
		glow.texture = gray_picture(crystal, 1.5)
		glow.scale = Vector2.ONE * roll.randf_range(0.6, 1.0)
		glow.modulate = crystal_color(level)
		glow.position = _free_spot(roll, 16.0)
		add_child(glow)

## A spot inside the room, away from the walk and from everything already placed.
func _free_spot(roll: RandomNumberGenerator, apart: float) -> Vector2:
	var spot: Vector2 = Vector2.ZERO
	for attempt: int in 60:
		spot = Vector2(roll.randf_range(ROOM.position.x, ROOM.end.x), roll.randf_range(ROOM.position.y + 20.0, ROOM.end.y - 10.0))
		if on_walk(spot):
			continue
		var crowded: bool = false
		for other: Vector2 in _taken:
			if other.distance_to(spot) < apart:
				crowded = true
				break
		if not crowded:
			break
	_taken.append(spot)
	return spot

## True on the walk from the front of the cave to the ladder, which always stays clear.
func on_walk(spot: Vector2) -> bool:
	var to_ladder: float = WorldShapes.to_segment(spot, FRONT + Vector2(0, 40), ladder_at)
	return to_ladder < WALK_ROOM

## A rock or vein the boy gathers from once a day by walking into it.
func _add_spot(key: String, item: String, at: Vector2, tint: Color, size: float = 1.0, picture: String = CRYSTAL_PICTURE) -> void:
	var spot: Area2D = Area2D.new()
	spot.set_script(load("res://src/scripts/World/copper_vein.gd"))
	spot.name = key.get_file()
	spot.position = at
	spot.set("mark", key)
	spot.set("item", item)
	spot.set("picture_path", picture)
	spot.set("tint", tint)
	spot.scale = Vector2.ONE * size
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(24, 24)
	shape.shape = box
	spot.add_child(shape)
	add_child(spot)
	var shown: Sprite2D = spot.get_node_or_null("Picture") as Sprite2D
	if shown != null and tint != Color.WHITE:
		shown.texture = gray_picture(shown.texture, 1.5)

## The ladder down sits at the back, with the next level's number beside it.
func _add_ladder() -> void:
	var ladder: Area2D = Area2D.new()
	ladder.name = "LadderDown"
	ladder.position = ladder_at
	var picture: Sprite2D = Sprite2D.new()
	picture.texture = load(LADDER_PICTURE) as Texture2D
	ladder.add_child(picture)
	var number: Label = Label.new()
	number.text = "%d ▼" % (level + 1)
	number.position = Vector2(-20, -40)
	number.size = Vector2(40, 14)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 10)
	number.add_theme_color_override("font_color", UiStyle.GOLD)
	number.add_theme_color_override("font_outline_color", UiStyle.DARK)
	number.add_theme_constant_override("outline_size", 3)
	ladder.add_child(number)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(28, 18)
	shape.shape = box
	ladder.add_child(shape)
	ladder.body_entered.connect(_on_ladder)
	add_child(ladder)

func _add_ladder_spawn() -> void:
	var spawn: Marker2D = Marker2D.new()
	spawn.name = "LadderSpawn"
	spawn.position = ladder_at + Vector2(0, 40)
	add_child(spawn)

## Below level 1, the way out at the front climbs one level up instead of leaving the cave.
func _set_exit() -> void:
	var way_out: Area2D = get_node_or_null("Exit") as Area2D
	if way_out == null or level == 1:
		return
	for link: Dictionary in way_out.body_entered.get_connections():
		way_out.body_entered.disconnect(link["callable"])
	way_out.body_entered.connect(_on_exit)

func _on_ladder(body: Node2D) -> void:
	if body is Player:
		go_down()

func _on_exit(body: Node2D) -> void:
	if body is Player:
		go_up()

func go_down() -> void:
	_move_to(mini(level + 1, DEEPEST), "PlayerSpawn")

func go_up() -> void:
	_move_to(level - 1, "LadderSpawn")

func _move_to(depth: int, spawn: String) -> void:
	var loader: LevelLoader = get_tree().current_scene.get_node_or_null("Systems/LevelLoader") as LevelLoader
	var stead: Stead = _stead()
	if loader == null or stead == null or loader.settling():
		return
	stead.flags["cave_level"] = depth
	loader.go_to(load(SCENE) as PackedScene, spawn)

func _stead() -> Stead:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	return scene.get_node_or_null("Systems/Stead") as Stead if scene != null else null

func _activities() -> Node:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	return scene.get_node_or_null("Systems/Activities") if scene != null else null
