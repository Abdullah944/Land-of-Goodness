# File: src/levels/dig_spot.gd
# Purpose: show a small square on sand, and turn only that quarter into soil.

extends Polygon2D

@onready var _player: CharacterBody2D = $"../../Player"
@onready var _ground: TileMapLayer = $".."

# Quarters that have already been dug.
var _dug := {}

func _physics_process(_delta: float) -> void:
	var spot := _spot_in_front()
	var can_dig := _is_sand(_cell_for_spot(spot)) and not _dug.has(spot)
	visible = can_dig
	if can_dig:
		global_position = _ground.to_global(_spot_center(spot))

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
