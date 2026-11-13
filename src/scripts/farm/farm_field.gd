# src/scripts/farm/farm_field.gd
# Purpose: Remembers every farm square and the plant growing on it.

class_name FarmField
extends Node

const DIRT_TILE: Vector2i = Vector2i(2, 4)
const SOIL_TILLED: Texture2D = preload("res://assets/farming/soil_tilled.png")
const SOIL_WET: Texture2D = preload("res://assets/farming/soil_wet.png")

## The fenced farm land below the house. The boy hoes any square inside it, so he lays out his own beds and paths.
## It starts here and grows right and down with each larger-field project.
@export var farm_origin: Vector2i = Vector2i(-31, -9)
@export var farm_size: Vector2i = START_SIZE
const START_SIZE: Vector2i = Vector2i(28, 16)
const LARGER_SIZE: Vector2i = Vector2i(36, 20)
const LARGEST_SIZE: Vector2i = Vector2i(44, 24)
## The gate in the top fence, counted in fence rails from the left. It faces the house door.
const GATE_RAIL: int = 3
const FIELD_SOIL: Script = preload("res://src/scripts/farm/field_soil.gd")
const FENCE_RAIL: String = "res://assets/props/fence/rail.png"
const FENCE_POST: String = "res://assets/props/fence/post.png"
const FENCE_SIDE: String = "res://assets/props/fence/side.png"
const FENCE_GATE: String = "res://assets/props/fence/gate.png"
## A sprinkler stands on a tilled square and waters the eight squares around it every morning.
const SPRINKLER: String = "sprinkler"
const SPRINKLER_PICTURE: String = "res://assets/farming/sprinkler.png"
const AROUND: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var plots: Dictionary = {}
## The plant picture on each planted square, by square key, so one swing redraws only its own squares.
var _sprouts: Dictionary = {}

func work(dirt: TileMapLayer, cell: Vector2i, watering_only: bool) -> void:
	var activities: Activities = _activities()
	if activities != null and activities.try_use(dirt, cell):
		_save()
		return
	if not _can_work(cell):
		if activities != null:
			activities.note = Locale.t("outside")
		return
	if activities != null and activities.note == Locale.t("outside"):
		activities.note = ""
	var plot: Dictionary = _plot(cell)
	var watered_now: bool = false
	if watering_only:
		_water(plot)
		watered_now = true
	elif not bool(plot["tilled"]):
		plot["tilled"] = true
		_maybe_find(dirt, cell)
	elif bool(plot.get("sprinkler", false)):
		pass
	elif int(plot["stage"]) < 0:
		if _inventory() != null and _inventory().selected_seed == SPRINKLER:
			_place_sprinkler(plot)
		else:
			_plant(plot)
	elif _is_ready(plot):
		_harvest(plot, dirt.to_global(dirt.map_to_local(cell)))
	elif not bool(plot["watered"]):
		_water(plot)
		watered_now = true
	_store(cell, plot)
	var changed: Array[Vector2i] = [cell]
	if watered_now:
		changed.append_array(_spread_water(cell))
	_refresh_cells(changed)
	_bounce(dirt, cell)
	_save()

## A ripe plant blinks now and then, so the boy sees from afar what is ready to pick.
const GLINT_EVERY: Vector2 = Vector2(0.5, 1.1)
var _glint_left: float = 2.0

func _process(delta: float) -> void:
	_glint_left -= delta
	if _glint_left > 0.0:
		return
	_glint_left = randf_range(GLINT_EVERY.x, GLINT_EVERY.y)
	var ripe: Array[Sprite2D] = []
	for key: String in _sprouts.keys():
		var sprout: Variant = _sprouts[key]
		if sprout == null or not is_instance_valid(sprout) or not plots.has(key):
			continue
		if int(plots[key]["stage"]) >= 0 and _is_ready(plots[key]):
			ripe.append(sprout as Sprite2D)
	if ripe.is_empty():
		return
	var pick: Sprite2D = ripe.pick_random()
	Juice.glint(pick.get_parent(), pick.position + Vector2(randf_range(-4.0, 4.0), randf_range(-6.0, 1.0)))

## The pickaxe turns a tilled square with nothing planted back into grass, so a bed can be moved.
func clear_soil(dirt: TileMapLayer, cell: Vector2i) -> bool:
	if not _is_tilled(cell) or int(plots[_key(cell)]["stage"]) >= 0:
		return false
	if bool(plots[_key(cell)].get("sprinkler", false)):
		return _take_sprinkler(dirt, cell)
	plots.erase(_key(cell))
	_refresh_cells([cell])
	Juice.burst(dirt, dirt.map_to_local(cell), Juice.DUST_BROWN, 10, 34.0, 0.4, 2.2)
	if _activities() != null:
		_activities().note = Locale.t("soil_cleared")
	_save()
	return true

## Fresh soil sometimes hides a few seeds that grow this season.
const FIND_CHANCE: float = 0.05

func _maybe_find(dirt: TileMapLayer, cell: Vector2i) -> void:
	if randf() >= FIND_CHANCE or _inventory() == null or _activities() == null:
		return
	var seed_item: String = "seeds"
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		if (crop.get("seasons", []) as Array).has(_season()):
			seed_item = str(crop.get("seed_item", "seeds"))
			break
	_inventory().add_item(seed_item, 2)
	_activities().pop_item(seed_item, 2, dirt.to_global(dirt.map_to_local(cell)))
	_activities().flash(Locale.t("found_seeds"))

## The plant on a square that was just worked gives a little bounce.
func _bounce(dirt: TileMapLayer, cell: Vector2i) -> void:
	var crops: Node = dirt.get_node_or_null("Crops")
	if crops == null:
		return
	var middle: Vector2 = dirt.map_to_local(cell)
	for child: Node in crops.get_children():
		if child is Sprite2D and absf((child as Sprite2D).position.x - middle.x) < 1.0 and absf((child as Sprite2D).position.y - middle.y) < 12.0:
			Juice.boing(child as Sprite2D)

func advance_day(season: String, raining: bool) -> void:
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		var stage: int = int(plot["stage"])
		var mature: int = _mature_stage(plot)
		var seasons: Array = _crop_of(plot).get("seasons", [])
		if stage >= 0 and stage < mature and bool(plot["watered"]) and seasons.has(season):
			plot["stage"] = stage + 1
		plot["watered"] = false
		plots[key] = plot
	if raining:
		for key: String in plots.keys():
			var plot: Dictionary = plots[key]
			var stage: int = int(plot["stage"])
			if stage >= 0 and stage < _mature_stage(plot):
				plot["watered"] = true
				plots[key] = plot
	_run_sprinklers()
	apply()

func apply() -> void:
	var dirt: TileMapLayer = _dirt()
	if dirt == null:
		return
	var old: Node = dirt.get_node_or_null("Crops")
	if old != null:
		# Free it now. queue_free would keep the name until the end of the frame,
		# and the new sprout layer would be renamed away from Crops.
		dirt.remove_child(old)
		old.free()
	var used: Array[Vector2i] = dirt.get_used_cells()
	for cell: Vector2i in used:
		if not _keeps_cell(cell):
			dirt.erase_cell(cell)
	var crops: Node2D = Node2D.new()
	crops.name = "Crops"
	dirt.add_child(crops)
	_add_fence(dirt)
	var soil: Node2D = FIELD_SOIL.new() as Node2D
	soil.name = "Soil"
	crops.add_child(soil)
	_lay_soil(soil, dirt)
	_sprouts.clear()
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		var cell: Vector2i = _cell_from_key(key)
		if bool(plot["tilled"]):
			dirt.set_cell(cell, 0, DIRT_TILE)
		var stage: int = int(plot["stage"])
		if stage >= 0 or bool(plot.get("sprinkler", false)):
			var sprout: Sprite2D = _sprout(dirt, cell, plot)
			crops.add_child(sprout)
			_sprouts[key] = sprout

## Redraws only the given squares: their soil, their tile, and their plant. The whole field is built by apply.
func _refresh_cells(cells: Array[Vector2i]) -> void:
	var dirt: TileMapLayer = _dirt()
	var crops: Node = dirt.get_node_or_null("Crops") if dirt != null else null
	if crops == null or crops.get_node_or_null("Soil") == null:
		apply()
		return
	for cell: Vector2i in cells:
		var key: String = _key(cell)
		var old: Variant = _sprouts.get(key)
		if old != null and is_instance_valid(old):
			(old as Node).free()
		_sprouts.erase(key)
		if _is_tilled(cell):
			dirt.set_cell(cell, 0, DIRT_TILE)
		else:
			dirt.erase_cell(cell)
		if plots.has(key) and (int(plots[key]["stage"]) >= 0 or bool(plots[key].get("sprinkler", false))):
			var sprout: Sprite2D = _sprout(dirt, cell, plots[key])
			crops.add_child(sprout)
			_sprouts[key] = sprout
	_lay_soil(crops.get_node("Soil") as Node2D, dirt)

## The soil layer draws every tilled square in one pass, wet or dry.
func _lay_soil(soil: Node2D, dirt: TileMapLayer) -> void:
	var squares: Array = []
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		if bool(plot["tilled"]):
			squares.append([dirt.map_to_local(_cell_from_key(key)), SOIL_WET if bool(plot["watered"]) else SOIL_TILLED])
	soil.set("squares", squares)
	soil.queue_redraw()

func export_plots() -> Array:
	var rows: Array = []
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		var cell: Vector2i = _cell_from_key(key)
		var row: Dictionary = {
			"x": cell.x,
			"y": cell.y,
			"stage": int(plot["stage"]),
			"watered": bool(plot["watered"]),
		}
		if int(plot["stage"]) >= 0:
			row["crop"] = str(plot.get("crop", CropCatalog.TURNIP))
		if bool(plot.get("sprinkler", false)):
			row["sprinkler"] = true
		rows.append(row)
	return rows

func import_plots(rows: Array) -> void:
	plots.clear()
	for row: Variant in rows:
		if row is Dictionary and row.has("x") and row.has("y"):
			var cell: Vector2i = Vector2i(int(row["x"]), int(row["y"]))
			var stage: int = maxi(-1, int(row.get("stage", -1)))
			var crop_id: String = str(row.get("crop", ""))
			if stage >= 0 and not CropCatalog.has_crop(crop_id):
				crop_id = CropCatalog.TURNIP
			if stage >= 0:
				stage = mini(stage, int(CropCatalog.get_crop(crop_id).get("mature_stage", 3)))
			plots[_key(cell)] = {
				"tilled": true,
				"stage": stage,
				"watered": bool(row.get("watered", false)),
				"crop": crop_id,
				"sprinkler": stage < 0 and bool(row.get("sprinkler", false)),
			}

func tool_for_plot(cell: Vector2i) -> String:
	if not _can_work(cell):
		return ""
	var state: String = state_of(cell)
	if state == "empty" or state == "tilled" or state == "ready":
		return "hoe"
	if state == "planted" or state == "growing":
		return "water"
	if state == SPRINKLER:
		return "pick"
	return ""

func state_of(cell: Vector2i) -> String:
	var plot: Dictionary = _plot(cell)
	if not bool(plot["tilled"]):
		return "empty"
	if bool(plot.get("sprinkler", false)):
		return SPRINKLER
	var stage: int = int(plot["stage"])
	if stage < 0:
		return "tilled"
	if _is_ready(plot):
		return "ready"
	if bool(plot["watered"]):
		return "watered"
	if stage == 0:
		return "planted"
	return "growing"

func ignores_tap(cell: Vector2i) -> bool:
	return state_of(cell) == "watered"

func _plant(plot: Dictionary) -> void:
	var inventory: Inventory = _inventory()
	var activities: Activities = _activities()
	var crop_id: String = CropCatalog.TURNIP
	if inventory != null and CropCatalog.has_crop(inventory.selected_seed):
		crop_id = inventory.selected_seed
	var crop: Dictionary = CropCatalog.get_crop(crop_id)
	if inventory == null or not _take_seed(inventory, crop):
		if activities != null:
			activities.note = Locale.t("need_seed")
			_no()
		return
	plot["stage"] = 0
	plot["watered"] = false
	plot["crop"] = crop_id
	var seasons: Array = crop.get("seasons", [])
	if activities != null and not seasons.has(_season()):
		activities.note = Locale.t("waits_season") % Locale.item(str(crop.get("harvest_item", "")))

## Puts a sprinkler from the bag on an empty tilled square.
func _place_sprinkler(plot: Dictionary) -> void:
	var inventory: Inventory = _inventory()
	if inventory == null or not inventory.take_item(SPRINKLER, 1):
		if _activities() != null:
			_activities().note = Locale.t("need_sprinkler")
			_no()
		return
	plot["sprinkler"] = true
	plot["watered"] = false
	if _activities() != null:
		_activities().flash(Locale.t("sprinkler_placed"))

## The pickaxe lifts a sprinkler back into the bag and leaves the soil tilled.
func _take_sprinkler(dirt: TileMapLayer, cell: Vector2i) -> bool:
	var plot: Dictionary = plots[_key(cell)]
	plot["sprinkler"] = false
	plots[_key(cell)] = plot
	if _inventory() != null:
		_inventory().add_item(SPRINKLER, 1)
	if _activities() != null:
		_activities().pop_item(SPRINKLER, 1, dirt.to_global(dirt.map_to_local(cell)))
	_refresh_cells([cell])
	_save()
	return true

## Every sprinkler waters the planted squares around it, so the morning starts with them wet.
func _run_sprinklers() -> void:
	for key: String in plots.keys():
		if not bool(plots[key].get("sprinkler", false)):
			continue
		var cell: Vector2i = _cell_from_key(key)
		for offset: Vector2i in AROUND:
			var next: String = _key(cell + offset)
			if plots.has(next):
				var plot: Dictionary = plots[next]
				_water(plot)
				plots[next] = plot

## How many of each harvest will be ripe tomorrow morning that are not ripe now.
func ripe_tomorrow(season: String, raining: bool) -> Dictionary:
	var wet: Dictionary = {}
	for key: String in plots.keys():
		if bool(plots[key].get("sprinkler", false)):
			var cell: Vector2i = _cell_from_key(key)
			for offset: Vector2i in AROUND:
				wet[_key(cell + offset)] = true
	var ripe: Dictionary = {}
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		var crop: Dictionary = _crop_of(plot)
		if int(plot["stage"]) != _mature_stage(plot) - 1 or not (crop.get("seasons", []) as Array).has(season):
			continue
		if bool(plot["watered"]) or raining or wet.has(key):
			var item: String = str(crop.get("harvest_item", ""))
			ripe[item] = int(ripe.get(item, 0)) + 1
	return ripe

## How many of each harvest are ready to pick right now.
func ripe_now() -> Dictionary:
	var ripe: Dictionary = {}
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		if int(plot["stage"]) >= 0 and _is_ready(plot):
			var item: String = str(_crop_of(plot).get("harvest_item", ""))
			ripe[item] = int(ripe.get(item, 0)) + 1
	return ripe

## True when at least one square is ready to pick.
func has_ripe() -> bool:
	for key: String in plots.keys():
		if int(plots[key]["stage"]) >= 0 and _is_ready(plots[key]):
			return true
	return false

func sprinkler_count() -> int:
	var count: int = 0
	for key: String in plots.keys():
		if bool(plots[key].get("sprinkler", false)):
			count += 1
	return count

## Waters the squares around one with the better cans, and returns the squares it watered.
func _spread_water(cell: Vector2i) -> Array[Vector2i]:
	var watered: Array[Vector2i] = []
	var stead: Node = get_parent().get_node_or_null("Stead")
	if stead == null or int(stead.get("tool_level")) < 1:
		return watered
	var around: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	if int(stead.get("tool_level")) >= 2:
		around.append_array([Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)])
	for offset: Vector2i in around:
		var next: Vector2i = cell + offset
		if not plots.has(_key(next)):
			continue
		var plot: Dictionary = plots[_key(next)]
		_water(plot)
		plots[_key(next)] = plot
		watered.append(next)
	return watered

func _water(plot: Dictionary) -> void:
	var stage: int = int(plot["stage"])
	if stage >= 0 and stage < _mature_stage(plot):
		plot["watered"] = true

func _harvest(plot: Dictionary, at: Vector2 = Vector2.INF) -> void:
	var crop: Dictionary = _crop_of(plot)
	var inventory: Inventory = _inventory()
	if inventory != null:
		_give_harvest(inventory, crop)
	if _activities() != null:
		_activities().pop_item(str(crop.get("harvest_item", "")), int(crop.get("harvest_amount", 1)), at)
		if at != Vector2.INF:
			Juice.burst(_activities().place_node(), at, Juice.LEAF_GREEN, 10, 40.0, 0.5)
	var activities: Activities = _activities()
	if activities != null:
		activities.flash(_picked_line(crop))
	var bank: Node = get_parent().get_node_or_null("SoundBank")
	if bank != null:
		bank.call("play", "harvest")
	plot["watered"] = false
	# Some plants, like tomatoes, keep their roots and fruit again a few days later.
	if crop.has("regrow_to"):
		plot["stage"] = int(crop["regrow_to"])
		return
	plot["stage"] = -1
	plot["crop"] = ""

func _picked_line(crop: Dictionary) -> String:
	return Locale.t("picked") % Locale.item(str(crop.get("harvest_item", "")))

func _take_seed(inventory: Inventory, crop: Dictionary) -> bool:
	return inventory.take_item(str(crop.get("seed_item", "")), 1)

func _give_harvest(inventory: Inventory, crop: Dictionary) -> void:
	inventory.add_item(str(crop.get("harvest_item", "")), int(crop.get("harvest_amount", 1)))

func _plot(cell: Vector2i) -> Dictionary:
	var key: String = _key(cell)
	if plots.has(key):
		return plots[key]
	return {"tilled": false, "stage": -1, "watered": false, "crop": "", "sprinkler": false}

func _store(cell: Vector2i, plot: Dictionary) -> void:
	if not bool(plot["tilled"]):
		plots.erase(_key(cell))
		return
	plots[_key(cell)] = plot

func _can_work(cell: Vector2i) -> bool:
	if _in_farm(cell):
		return true
	return plots.has(_key(cell))

func _in_farm(cell: Vector2i) -> bool:
	return cell.x >= farm_origin.x \
		and cell.y >= farm_origin.y \
		and cell.x < farm_origin.x + farm_size.x \
		and cell.y < farm_origin.y + farm_size.y

func _keeps_cell(cell: Vector2i) -> bool:
	return _is_tilled(cell)

func _is_tilled(cell: Vector2i) -> bool:
	return plots.has(_key(cell)) and bool(plots[_key(cell)]["tilled"])

func _is_ready(plot: Dictionary) -> bool:
	return int(plot["stage"]) >= _mature_stage(plot)

func _mature_stage(plot: Dictionary) -> int:
	return int(_crop_of(plot).get("mature_stage", 3))

func _crop_of(plot: Dictionary) -> Dictionary:
	var crop_id: String = str(plot.get("crop", ""))
	if not CropCatalog.has_crop(crop_id):
		crop_id = CropCatalog.TURNIP
	return CropCatalog.get_crop(crop_id)

## A wooden fence around the farm land with a gate on the side that faces the house, so it is clear where hoeing works.
## It is built again only when the field changes size.
func _add_fence(dirt: TileMapLayer) -> void:
	if not ResourceLoader.exists(FENCE_RAIL):
		return
	var size_key: String = "Fence_%d_%d" % [farm_size.x, farm_size.y]
	var old: Node = dirt.get_node_or_null("Fence")
	if old != null and old.get_meta("size_key", "") == size_key:
		return
	if old != null:
		dirt.remove_child(old)
		old.free()
	var crops: Node2D = Node2D.new()
	crops.name = "Fence"
	crops.set_meta("size_key", size_key)
	dirt.add_child(crops)
	var top_left: Vector2 = dirt.map_to_local(farm_origin) - Vector2(8, 8)
	var box: Rect2 = Rect2(top_left, Vector2(farm_size) * 16.0)
	var rails: int = int(box.size.x / 32.0)
	for row: float in [box.position.y - 1.0, box.end.y + 5.0]:
		for i: int in rails:
			var gate: bool = row < box.position.y and i == GATE_RAIL
			var at: Vector2 = Vector2(box.position.x + i * 32.0, row)
			if gate:
				crops.add_child(_fence_piece(FENCE_POST, at + Vector2(2, 0)))
				crops.add_child(_fence_piece(FENCE_GATE, at + Vector2(16, 0)))
				crops.add_child(_fence_piece(FENCE_POST, at + Vector2(30, 0)))
			else:
				crops.add_child(_fence_piece(FENCE_RAIL, at + Vector2(16, 0)))
	for x: float in [box.position.x - 2.0, box.end.x + 2.0]:
		var y: float = box.position.y + 10.0
		while y < box.end.y + 4.0:
			crops.add_child(_fence_piece(FENCE_SIDE, Vector2(x, y)))
			y += 11.0

## One fence picture, standing on its feet and drawn in the same order as everything else by its feet.
func _fence_piece(path: String, feet: Vector2) -> Sprite2D:
	var piece: Sprite2D = Sprite2D.new()
	piece.texture = load(path) as Texture2D
	piece.centered = false
	piece.offset = Vector2(-piece.texture.get_width() * 0.5, -piece.texture.get_height())
	piece.position = feet
	piece.z_as_relative = false
	piece.z_index = 2000 + int(feet.y)
	return piece

func _sprout(dirt: TileMapLayer, cell: Vector2i, plot: Dictionary) -> Sprite2D:
	if bool(plot.get("sprinkler", false)):
		var stand: Sprite2D = Sprite2D.new()
		stand.texture = load(SPRINKLER_PICTURE) as Texture2D
		stand.centered = true
		stand.position = dirt.map_to_local(cell) + Vector2(0, -5)
		return stand
	var crop: Dictionary = _crop_of(plot)
	var sprout: Sprite2D = Sprite2D.new()
	sprout.texture = crop.get("texture", CropCatalog.PLANTS)
	sprout.region_enabled = true
	var sprites: Array = crop.get("sprites", [])
	var stage: int = clampi(int(plot["stage"]), 0, maxi(sprites.size() - 1, 0))
	if stage < sprites.size():
		sprout.region_rect = sprites[stage]
	sprout.centered = true
	var height: float = sprout.region_rect.size.y
	sprout.position = dirt.map_to_local(cell) + Vector2(0, (16.0 - height) * 0.5)
	if bool(plot["watered"]):
		sprout.modulate = Color("c5e4ea")
	return sprout

func _season() -> String:
	var clock: Node = get_parent().get_node_or_null("Clock")
	if clock == null:
		return ""
	return str(clock.get("season"))

func _dirt() -> TileMapLayer:
	var main: Node = get_tree().current_scene
	if main == null:
		return null
	var found: Node = main.find_child("Tilled_Dirt", true, false)
	if found is TileMapLayer:
		return found
	return null

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _cell_from_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func _inventory() -> Inventory:
	return get_parent().get_node_or_null("Inventory") as Inventory

func _activities() -> Activities:
	return get_parent().get_node_or_null("Activities") as Activities

func _save() -> void:
	var save: SaveGame = get_parent().get_node_or_null("SaveGame") as SaveGame
	if save != null:
		save.write_now()

## The soft "not now" sound, for when the bag lacks what the square needs.
func _no() -> void:
	var bank: Node = get_parent().get_node_or_null("SoundBank")
	if bank != null:
		bank.call("play", "no")
