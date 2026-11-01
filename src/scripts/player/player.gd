# scripts/player/player.gd
# Purpose: The boy. Walking and animations live in the states.

class_name Player
extends CharacterBody2D

@export var move_speed: float = 60.0
var facing: String = "Down"
const REACH: int = 2

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
		if feet.distance_to(spot.global_position) > 22.0:
			continue
		if tapped_point.distance_to(spot.global_position) > 30.0:
			continue
		var role: String = str(spot.get("role"))
		if role != "":
			activities.talk_role(role)
			return
		var kind: String = str(spot.get("group_name"))
		if kind == "date" or kind == "forage" or kind == "ore":
			activities.gather_node(spot)
			return
		if spot.name == "FishingSpot":
			activities.fish_at(place.name)
			return

func reached_indoor_point() -> bool:
	var feet: Vector2 = global_position + Vector2(0, 20)
	return feet.distance_to(tapped_point) <= 2.0

func reached_walk_spot(dirt: TileMapLayer) -> bool:
	return get_stand_cell(dirt) == tapped_cell

func change_zoom(multiplier: float) -> void:
	var cam: Camera2D = get_node("Camera2D") as Camera2D
	var next: float = clampf(cam.zoom.x * multiplier, 1.0, 3.0)
	cam.zoom = Vector2(next, next)

func _ready() -> void:
	var cam: Camera2D = get_node("Camera2D") as Camera2D
	cam.zoom = Vector2(1.6, 1.6)
	var sprite: AnimatedSprite2D = get_node("CharacterSprite") as AnimatedSprite2D
	sprite.sprite_frames = sprite.sprite_frames.duplicate(true)
	_add_swing(sprite, "res://assets/characters/boy/animation/axe/Kuwaiti farm boy axe-swing sprite sheet.png", "axe_")
	_add_swing(sprite, "res://assets/characters/boy/animation/pickaxe/Kuwaiti farmer pickaxe strike sprite sheet.png", "pick_")

func _process(_delta: float) -> void:
	z_index = 2000 + int(global_position.y + 20.0)

func _add_swing(sprite: AnimatedSprite2D, path: String, prefix: String) -> void:
	var picture: Texture2D = load(path) as Texture2D
	if picture == null:
		return
	var sheet: Image = picture.get_image()
	var cell_w: int = int(sheet.get_width() / 4.0)
	var cell_h: int = int(sheet.get_height() / 4.0)
	var frames: SpriteFrames = sprite.sprite_frames
	var faces: Array[String] = ["Down", "Left", "Right", "Up"]
	for row: int in 4:
		var anim: StringName = prefix + faces[row]
		if frames.has_animation(anim):
			frames.remove_animation(anim)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 8.0)
		frames.set_animation_loop(anim, false)
		for col: int in 4:
			var cell: Image = sheet.get_region(Rect2i(col * cell_w, row * cell_h, cell_w, cell_h))
			var used: Rect2i = cell.get_used_rect()
			if used.size != Vector2i.ZERO:
				cell = cell.get_region(used)
			var longest: int = maxi(cell.get_width(), cell.get_height())
			var width: int = maxi(1, int(round(float(cell.get_width()) * 64.0 / float(longest))))
			var height: int = maxi(1, int(round(float(cell.get_height()) * 68.0 / float(longest))))
			cell.resize(width, height, Image.INTERPOLATE_LANCZOS)
			frames.add_frame(anim, ImageTexture.create_from_image(cell))

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
		var interesting: bool = str(spot.get("role")) != "" or spot.name == "FishingSpot" or kind == "date" or kind == "forage" or kind == "ore"
		if interesting and world_position.distance_to(spot.global_position) <= 28.0:
			return spot.global_position + Vector2(0, 18)
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
