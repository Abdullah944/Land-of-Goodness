# File: src/levels/action_tile.gd
# Purpose: show a small square on sand, turn that quarter into soil, and plant a sprout.

extends Polygon2D

const DIG_COLOR := Color(1, 0.75686276, 0.30588236, 0.43137255)
const PLANT_COLOR := Color(0.369, 0.608, 0.384, 0.45)

@onready var _player: CharacterBody2D = $"../../Player"
@onready var _ground: TileMapLayer = $".."

# Quarters that have already been dug.
var _dug := {}
# Quarters that already have a sprout.
var _planted := {}

func _physics_process(_delta: float) -> void:
	var spot := _spot_in_front()
	var can_dig := _is_sand(_cell_for_spot(spot)) and not _dug.has(spot)
	var show_plant := can_plant() and _seed_ready()
	visible = can_dig or show_plant
	if not visible:
		return
	global_position = _ground.to_global(_spot_center(spot))
	color = PLANT_COLOR if show_plant else DIG_COLOR

# Put a small soil picture on the quarter in front of him.
func dig_here() -> void:
	var spot := _spot_in_front()
	if not _is_sand(_cell_for_spot(spot)) or _dug.has(spot):
		return
	_dug[spot] = true
	var soil := Sprite2D.new()
	var atlas := _ground.tile_set.get_source(0) as TileSetAtlasSource
	var region_size := Vector2(atlas.texture_region_size)
	soil.texture = atlas.texture
	soil.region_enabled = true
	soil.region_rect = Rect2(Vector2(0, 1) * region_size, region_size)
	soil.scale = Vector2(0.5, 0.5)
	soil.position = _spot_center(spot)
	_ground.add_child(soil)

func can_plant() -> bool:
	var spot := _spot_in_front()
	return _dug.has(spot) and not _planted.has(spot)

func plant_here() -> void:
	if not can_plant():
		return
	var item := _equipped_item()
	if item == null or item.sprout == null:
		return
	var spot := _spot_in_front()
	_planted[spot] = true
	var sprout := Sprite2D.new()
	sprout.texture = item.sprout
	sprout.scale = Vector2(0.35, 0.35)
	sprout.position = _spot_center(spot)
	_ground.add_child(sprout)

func _seed_ready() -> bool:
	var item := _equipped_item()
	return item != null and item.sprout != null

func _equipped_item() -> GameItem:
	var inventory := get_tree().get_first_node_in_group("inventory")
	if inventory == null or not inventory.has_seed_equipped():
		return null
	return inventory.equipped_item()

func _spot_in_front() -> Vector2i:
	var spot_size := _spot_size()
	var ahead := _ground.to_local(_player.global_position) + Vector2(_player.get_facing_cell()) * spot_size
	return Vector2i(floori(ahead.x / spot_size.x), floori(ahead.y / spot_size.y))

func _spot_center(spot: Vector2i) -> Vector2:
	var spot_size := _spot_size()
	return Vector2(spot) * spot_size + spot_size * 0.5

func _spot_size() -> Vector2:
	return Vector2(_ground.tile_set.tile_size) / 2.0

func _cell_for_spot(spot: Vector2i) -> Vector2i:
	return _ground.local_to_map(_spot_center(spot))

func _is_sand(cell: Vector2i) -> bool:
	var tile_data := _ground.get_cell_tile_data(cell)
	return tile_data != null and str(tile_data.get_custom_data("ground")) == "sand"