# File: src/levels/action_tile.gd
# Purpose: show a colored square for dig, plant, or water.

extends Polygon2D

const DIG_COLOR := Color(1, 0.75686276, 0.30588236, 0.43137255)
const PLANT_COLOR := Color(0.369, 0.608, 0.384, 0.45)
const WATER_COLOR := Color(0.333, 0.686, 0.769, 0.45)
const WET_SOIL := Color(0.58, 0.46, 0.34)

@onready var _player: CharacterBody2D = $"../../Player"
@onready var _ground: TileMapLayer = $".."

var _dug := {}
var _planted := {}
var _crops := {}
var _soil := {}
var _watered := {}

func _physics_process(_delta: float) -> void:
	var spot := _spot_in_front()
	var show_dig := _tool_is(&"hoe") and _is_sand(_cell_for_spot(spot)) and not _dug.has(spot)
	var show_plant := _tool_is(&"seed") and can_plant() and _seed_ready()
	var show_water := _tool_is(&"water") and can_water()
	visible = show_dig or show_plant or show_water
	if not visible:
		return
	global_position = _ground.to_global(_spot_center(spot))
	if show_water:
		color = WATER_COLOR
	elif show_plant:
		color = PLANT_COLOR
	else:
		color = DIG_COLOR

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
	_soil[spot] = soil

func can_plant() -> bool:
	var spot := _spot_in_front()
	return _dug.has(spot) and not _planted.has(spot)

func plant_here() -> void:
	if not can_plant():
		return
	var item := _equipped_item()
	if item == null:
		return
	var picture := item.sprout
	if item.stages.size() > 0:
		picture = item.stages[0]
	if picture == null:
		return
	var spot := _spot_in_front()
	_planted[spot] = true
	var sprout := Sprite2D.new()
	sprout.texture = picture
	sprout.position = _spot_center(spot)
	_fit_in_square(sprout)
	_ground.add_child(sprout)
	var crop := Crop.new()
	crop.sprite = sprout
	crop.item = item
	crop.stage = 0
	_crops[spot] = crop

func can_water() -> bool:
	var spot := _spot_in_front()
	if not _dug.has(spot):
		return false
	var crop: Crop = _crops.get(spot)
	if crop == null:
		return not _watered.has(spot)
	if crop.item.stages.size() < 2:
		return false
	return crop.stage < crop.item.stages.size() - 1

func water_here() -> void:
	if not can_water():
		return
	var spot := _spot_in_front()
	_watered[spot] = true
	var soil: Sprite2D = _soil.get(spot)
	if soil != null:
		soil.modulate = WET_SOIL
	var crop: Crop = _crops.get(spot)
	if crop == null:
		return
	crop.stage += 1
	crop.sprite.texture = crop.item.stages[crop.stage]
	_fit_in_square(crop.sprite)

func _seed_ready() -> bool:
	var item := _equipped_item()
	return item != null and item.sprout != null

func _equipped_item() -> GameItem:
	var inventory := get_tree().get_first_node_in_group("inventory")
	if inventory == null or not inventory.has_seed_equipped():
		return null
	return inventory.equipped_item()

func _tool_is(tool_name: StringName) -> bool:
	var tools := get_tree().get_first_node_in_group("tool_bar")
	return tools != null and tools.tool_id() == tool_name

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

func _fit_in_square(sprite: Sprite2D) -> void:
	var spot_size := _spot_size()
	var picture_size := sprite.texture.get_size()
	var fit := minf(spot_size.x / picture_size.x, spot_size.y / picture_size.y)
	sprite.scale = Vector2(fit, fit) * 0.9

class Crop:
	var sprite: Sprite2D
	var item: GameItem
	var stage: int