# File: Scenes/action_tile.gd
# Purpose: show a small square on one quarter of the sand tile in front of the boy.

extends Polygon2D

@onready var _player: CharacterBody2D = $"../../Player"
@onready var _ground: TileMapLayer = $".."

func _physics_process(_delta: float) -> void:
	# One dig spot is half a tile wide and half a tile tall.
	var spot_size := Vector2(_ground.tile_set.tile_size) / 2.0
	var ahead := _ground.to_local(_player.global_position) + Vector2(_player.get_facing_cell()) * spot_size
	var spot := Vector2(floor(ahead.x / spot_size.x), floor(ahead.y / spot_size.y))
	var spot_center := spot * spot_size + spot_size * 0.5
	# The sand label lives on the big tile under that spot.
	var cell := _ground.local_to_map(spot_center)
	var tile_data := _ground.get_cell_tile_data(cell)
	var can_dig := tile_data != null and str(tile_data.get_custom_data("ground")) == "sand"
	visible = can_dig
	if can_dig:
		global_position = _ground.to_global(spot_center)
