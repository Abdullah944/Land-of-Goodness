# scripts/player/player.gd
# Purpose: The boy. Walking and animations live in the states.

class_name Player
extends CharacterBody2D

@export var move_speed: float = 60.0
var facing: String = "Down"
const REACH: int = 2
## The boy's painted HD animations: prefix, sheet, frames per row, frames per second, loops.
## A stride is eight frames, so walking keeps the old pace of one stride a second.
const HD_SHEETS: Array = [
	["walk_", "res://assets/characters/boy/hd/walk.png", 8, 8.0, true],
	["idle_", "res://assets/characters/boy/hd/idle.png", 4, 3.0, true],
	["hold_", "res://assets/characters/boy/hd/idle.png", 4, 3.0, true],
	["hoe_", "res://assets/characters/boy/hd/hoe.png", 4, 4.0, false],
	["water_", "res://assets/characters/boy/hd/water.png", 4, 4.0, false],
	["axe_", "res://assets/characters/boy/hd/axe.png", 4, 8.0, false],
	["pick_", "res://assets/characters/boy/hd/pickaxe.png", 4, 8.0, false],
]

var tapped_cell: Vector2i = Vector2i.ZERO
var has_tapped_cell: bool = false
var wants_hoe: bool = false
var wants_water: bool = false
var wants_axe: bool = false
var wants_pick: bool = false
var busy: bool = false
var tool: String = ""
var tool_locked: bool = false
var holding_touch: bool = false
var tapped_point: Vector2 = Vector2.ZERO
var walking_indoors: bool = false
## How far a big target such as the pond can be used from. Zero means the normal reach.
var reach_pixels: float = 0.0
## The zoom the player chose. A small place may show closer, but this comes back outside it.
var wanted_zoom: float = 1.0

func get_move_direction() -> Vector2:
	return Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

func get_front_cell(dirt: TileMapLayer) -> Vector2i:
	var feet: Vector2 = global_position + Vector2(0, 20)
	var cell: Vector2i = dirt.local_to_map(dirt.to_local(feet))
	match facing:
		"Left":
			cell += Vector2i(-2, 0)
		"Right":
			cell += Vector2i(2, 0)
		"Up":
			cell += Vector2i(0, -4)
		"Down":
			cell += Vector2i(0, 2)
	return cell

func get_action_cell(dirt: TileMapLayer) -> Vector2i:
	if has_tapped_cell:
		return tapped_cell
	return get_front_cell(dirt)

func set_walk_target(world_position: Vector2) -> void:
	if busy:
		return
	var dirt: TileMapLayer = find_dirt()
	if dirt != null:
		set_tapped_cell(dirt.local_to_map(dirt.to_local(world_position)))
		return
	tapped_point = _snap_indoor(world_position)
	walking_indoors = true
	has_tapped_cell = true
	wants_hoe = false
	wants_water = false
	wants_axe = false
	wants_pick = false
	tool = ""

func set_tapped_cell(cell: Vector2i) -> void:
	if busy:
		return
	walking_indoors = false
	var dirt: TileMapLayer = find_dirt()
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	if dirt != null:
		cell = activities.snap_cell(dirt, cell)
	var farm: FarmField = get_tree().current_scene.get_node_or_null("Systems/FarmField") as FarmField
	if farm != null and farm.ignores_tap(cell):
		has_tapped_cell = false
		wants_hoe = false
		wants_water = false
		return
	tapped_cell = cell
	has_tapped_cell = true
	wants_hoe = false
	wants_water = false
	if dirt == null:
		return
	reach_pixels = activities.reach_for(dirt, cell)
	var needed: String = activities.tool_for_cell(dirt, cell)
	if needed != "":
		tool = needed
		tool_locked = false
	elif not (tool_locked and tool == "hoe"):
		tool = ""

func cancel_tap() -> void:
	has_tapped_cell = false
	walking_indoors = false
	wants_hoe = false
	wants_water = false
	wants_axe = false
	wants_pick = false

func ask_for_tool() -> void:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	var activities: Activities = systems.get_node("Activities") as Activities
	var dirt: TileMapLayer = find_dirt()
	if tool == "use":
		if dirt != null:
			activities.try_use(dirt, tapped_cell)
		cancel_tap()
		return
	if tool == "axe":
		wants_axe = true
		return
	if tool == "pick":
		wants_pick = true
		return
	if tool == "water":
		wants_water = true
		return
	wants_hoe = true

func arrive_indoors() -> void:
	var place: Node = _current_place()
	if place == null:
		return
	var feet: Vector2 = global_position + Vector2(0, 20)
	var chest: Node = place.get_node_or_null("Chest")
	if chest != null and chest.has_method("foot_point") and tapped_point.distance_to(chest.call("foot_point")) <= 4.0:
		if feet.distance_to(chest.call("foot_point")) <= 12.0 and chest.has_method("open_storage"):
			chest.call("open_storage")
		return
	var bed: Node = place.get_node_or_null("Bed")
	if bed != null and bed.has_method("foot_point"):
		if feet.distance_to(bed.call("foot_point")) <= 8.0 and bed.has_method("_ask"):
			bed.call("_ask")
		return
	_arrive_role(place, feet)

func _arrive_role(place: Node, feet: Vector2) -> void:
	var activities: Activities = get_tree().current_scene.get_node_or_null("Systems/Activities") as Activities
	if activities == null:
		return
	for child: Node in place.get_children():
		if not child is Node2D:
			continue
		var spot: Node2D = child as Node2D
		if feet.distance_to(spot.global_position) > 22.0 and feet.distance_to(spot.global_position + _talk_from(spot)) > 6.0:
			continue
		if tapped_point.distance_to(spot.global_position) > 30.0 and tapped_point.distance_to(spot.global_position + _talk_from(spot)) > 4.0:
			continue
		var role: String = Activities.role_of(spot)
		if role != "":
			activities.talk_role(role)
			return
		var kind: String = str(spot.get("group_name"))
		if kind == "date" or kind == "forage" or kind == "ore" or kind == "tree" or kind == "rock" or kind == "shore":
			activities.gather_node(spot)
			return
		if spot.name == "FishingSpot":
			activities.cast(place.name)
			return

## Where the boy stands to talk to someone or use something, from its feet.
func _talk_from(spot: Node2D) -> Vector2:
	var offset: Variant = spot.get("talk_from")
	return offset if offset is Vector2 else Vector2(0, 18)

func reached_indoor_point() -> bool:
	var feet: Vector2 = global_position + Vector2(0, 20)
	return feet.distance_to(tapped_point) <= 2.0

func reached_walk_spot(dirt: TileMapLayer) -> bool:
	return get_stand_cell(dirt) == tapped_cell

func change_zoom(multiplier: float) -> void:
	var cam: Camera2D = get_node("Camera2D") as Camera2D
	wanted_zoom = clampf(cam.zoom.x * multiplier, 1.0, 3.0)
	fit_camera()

## Keeps the view on the map, so the empty space past its edge never shows.
func fit_camera() -> void:
	var cam: Camera2D = get_node("Camera2D") as Camera2D
	var area: Rect2 = _camera_area()
	var shown: float = maxf(wanted_zoom, _lowest_zoom())
	cam.zoom = Vector2(shown, shown)
	if area.size == Vector2.ZERO:
		cam.limit_left = -10000000
		cam.limit_top = -10000000
		cam.limit_right = 10000000
		cam.limit_bottom = 10000000
		return
	cam.limit_left = int(area.position.x)
	cam.limit_top = int(area.position.y)
	cam.limit_right = int(area.end.x)
	cam.limit_bottom = int(area.end.y)

func _lowest_zoom() -> float:
	var area: Rect2 = _camera_area()
	if area.size == Vector2.ZERO:
		return 1.0
	var view: Vector2 = get_viewport().get_visible_rect().size
	return maxf(1.0, maxf(view.x / area.size.x, view.y / area.size.y))

func _camera_area() -> Rect2:
	var place: Node = _current_place()
	if place == null or str(place.name).ends_with("Inside"):
		return Rect2()
	var bounds: Node = place.get_node_or_null("Bounds")
	if bounds != null:
		return (bounds.get("area") as Rect2).grow(16.0)
	return Rect2()

func _ready() -> void:
	var cam: Camera2D = get_node("Camera2D") as Camera2D
	cam.zoom = Vector2(wanted_zoom, wanted_zoom)
	get_viewport().size_changed.connect(fit_camera)
	add_child(UiStyle.shadow_node(Vector2(0, 21), 20.0))
	var sprite: AnimatedSprite2D = get_node("CharacterSprite") as AnimatedSprite2D
	# Three quarters of the drawn size, moved down so the feet stay on the same spot.
	sprite.scale = Vector2(0.75, 0.75)
	sprite.position.y += 5.0
	sprite.sprite_frames = sprite.sprite_frames.duplicate(true)
	for row: Array in HD_SHEETS:
		_add_sheet(sprite, str(row[1]), str(row[0]), int(row[2]), float(row[3]), bool(row[4]))

func _process(_delta: float) -> void:
	z_index = 2000 + int(global_position.y + 20.0)

## Builds one animation per facing from a painted HD sheet whose rows are Down, Left, Right, Up.
func _add_sheet(sprite: AnimatedSprite2D, path: String, prefix: String, columns: int, speed: float, loops: bool) -> void:
	var picture: Texture2D = load(path) as Texture2D
	if picture == null:
		return
	var cell: Vector2 = picture.get_size() / Vector2(columns, 4)
	var frames: SpriteFrames = sprite.sprite_frames
	var faces: Array[String] = ["Down", "Left", "Right", "Up"]
	for row: int in 4:
		var anim: StringName = prefix + faces[row]
		if frames.has_animation(anim):
			frames.remove_animation(anim)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, speed)
		frames.set_animation_loop(anim, loops)
		for column: int in columns:
			frames.add_frame(anim, UiStyle.region_picture(picture, Rect2(Vector2(column, row) * cell, cell), cell))

func _snap_indoor(world_position: Vector2) -> Vector2:
	var place: Node = _current_place()
	if place == null:
		return _grid_point(world_position)
	var bed: Node = place.get_node_or_null("Bed")
	if bed != null and bed.has_method("covers_point") and bool(bed.call("covers_point", world_position)):
		return bed.call("foot_point")
	var chest: Node = place.get_node_or_null("Chest")
	if chest != null and chest.has_method("covers_point") and bool(chest.call("covers_point", world_position)):
		return chest.call("foot_point")
	for child: Node in place.get_children():
		if not child is Node2D:
			continue
		var spot: Node2D = child as Node2D
		var kind: String = str(spot.get("group_name"))
		var interesting: bool = Activities.role_of(spot) != "" or spot.name == "FishingSpot" or kind == "date" or kind == "forage" or kind == "ore" or kind == "tree" or kind == "rock" or kind == "shore"
		if interesting and world_position.distance_to(spot.global_position) <= 28.0:
			return spot.global_position + _talk_from(spot)
	for child: Node in place.get_children():
		if not str(child.name).begins_with("Exit") and child.name != "Rock":
			continue
		if not child is Area2D:
			continue
		var spot: Variant = _area_point(child as Area2D, world_position)
		if spot is Vector2:
			return spot
	return _grid_point(world_position)

func _area_point(area: Area2D, world_position: Vector2) -> Variant:
	var shape_node: CollisionShape2D = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is RectangleShape2D:
		return null
	var box: RectangleShape2D = shape_node.shape as RectangleShape2D
	var center: Vector2 = shape_node.global_position
	var rect: Rect2 = Rect2(center - box.size * 0.5, box.size)
	if rect.grow(16.0).has_point(world_position):
		return center
	return null

func _grid_point(world_position: Vector2) -> Vector2:
	var floor_layer: TileMapLayer = _floor_layer()
	if floor_layer != null:
		var cell: Vector2i = floor_layer.local_to_map(floor_layer.to_local(world_position))
		return floor_layer.to_global(floor_layer.map_to_local(cell))
	return Vector2(
		floor(world_position.x / 16.0) * 16.0 + 8.0,
		floor(world_position.y / 16.0) * 16.0 + 8.0
	)

func _floor_layer() -> TileMapLayer:
	var place: Node = _current_place()
	if place == null:
		return null
	var found: Node = place.find_child("Floor", true, false)
	if found is TileMapLayer:
		return found
	return null

func _current_place() -> Node:
	var main: Node = get_tree().current_scene
	if main == null:
		return null
	var world: Node = main.get_node_or_null("World")
	if world == null:
		return null
	for child: Node in world.get_children():
		if child.name == "Player":
			continue
		return child
	return null

func find_dirt() -> TileMapLayer:
	var main: Node = get_tree().current_scene
	if main == null:
		return null
	var found: Node = main.find_child("Tilled_Dirt", true, false)
	if found is TileMapLayer:
		return found
	return null

func get_stand_cell(dirt: TileMapLayer) -> Vector2i:
	var feet: Vector2 = global_position + Vector2(0, 20)
	return dirt.local_to_map(dirt.to_local(feet))

func is_within_reach(dirt: TileMapLayer) -> bool:
	if reach_pixels > 0.0 and distance_to_cell(dirt, tapped_cell) <= reach_pixels:
		return true
	var gap: Vector2i = (tapped_cell - get_stand_cell(dirt)).abs()
	if maxi(gap.x, gap.y) <= REACH:
		return true
	if tool == "axe" or tool == "pick":
		return distance_to_cell(dirt, tapped_cell) <= 48.0
	return false

func direction_to_cell(dirt: TileMapLayer, cell: Vector2i) -> Vector2:
	var target: Vector2 = dirt.to_global(dirt.map_to_local(cell))
	var feet: Vector2 = global_position + Vector2(0, 20)
	return feet.direction_to(target)

func distance_to_cell(dirt: TileMapLayer, cell: Vector2i) -> float:
	var target: Vector2 = dirt.to_global(dirt.map_to_local(cell))
	var feet: Vector2 = global_position + Vector2(0, 20)
	return feet.distance_to(target)

func face_cell(dirt: TileMapLayer, cell: Vector2i) -> void:
	var delta: Vector2i = cell - get_stand_cell(dirt)
	if absi(delta.x) > absi(delta.y):
		facing = "Right" if delta.x > 0 else "Left"
	elif delta.y > 0:
		facing = "Down"
	elif delta.y < 0:
		facing = "Up"
