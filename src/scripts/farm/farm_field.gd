# src/scripts/farm/farm_field.gd
# Purpose: Remembers every tilled square and the plant growing on it.

class_name FarmField
extends Node

const PLANTS: Texture2D = preload("res://assets/Basic pack/Objects/Basic_Plants.png")
const DIRT_TILE: Vector2i = Vector2i(2, 4)
const STAGE_TILES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(32, 0),
	Vector2i(64, 0),
	Vector2i(80, 16),
]
const LAST_STAGE: int = 3

var plots: Dictionary = {}

func work(dirt: TileMapLayer, cell: Vector2i, watering_only: bool) -> void:
	var activities: Activities = _activities()
	if activities != null and activities.try_use(dirt, cell):
		_save()
		return
	var plot: Dictionary = _plot(cell)
	if watering_only:
		_water(plot)
	elif not bool(plot["tilled"]):
		plot["tilled"] = true
	elif int(plot["stage"]) < 0:
		_plant(plot)
	elif int(plot["stage"]) >= LAST_STAGE:
		_harvest(plot)
	elif not bool(plot["watered"]):
		_water(plot)
	_store(cell, plot)
	apply()
	_save()

func advance_day(season: String, raining: bool) -> void:
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		var stage: int = int(plot["stage"])
		if season != "Winter" and stage >= 0 and stage < LAST_STAGE and bool(plot["watered"]):
			plot["stage"] = stage + 1
		plot["watered"] = false
		plots[key] = plot
	if raining:
		for key: String in plots.keys():
			var plot: Dictionary = plots[key]
			if int(plot["stage"]) >= 0 and int(plot["stage"]) < LAST_STAGE:
				plot["watered"] = true
				plots[key] = plot
	apply()

func apply() -> void:
	var dirt: TileMapLayer = _dirt()
	if dirt == null:
		return
	var old: Node = dirt.get_node_or_null("Crops")
	if old != null:
		old.queue_free()
	var crops: Node2D = Node2D.new()
	crops.name = "Crops"
	dirt.add_child(crops)
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		var cell: Vector2i = _cell_from_key(key)
		if bool(plot["tilled"]):
			dirt.set_cell(cell, 0, DIRT_TILE)
		var stage: int = int(plot["stage"])
		if stage >= 0:
			crops.add_child(_sprout(dirt, cell, stage, bool(plot["watered"])))

func export_plots() -> Array:
	var rows: Array = []
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		var cell: Vector2i = _cell_from_key(key)
		rows.append({
			"x": cell.x,
			"y": cell.y,
			"stage": int(plot["stage"]),
			"watered": bool(plot["watered"]),
		})
	return rows

func import_plots(rows: Array) -> void:
	plots.clear()
	for row: Variant in rows:
		if row is Dictionary:
			var cell: Vector2i = Vector2i(int(row["x"]), int(row["y"]))
			plots[_key(cell)] = {
				"tilled": true,
				"stage": int(row["stage"]),
				"watered": bool(row["watered"]),
			}

func _plant(plot: Dictionary) -> void:
	var inventory: Inventory = _inventory()
	if inventory == null or inventory.seeds <= 0:
		var activities: Activities = _activities()
		if activities != null:
			activities.note = "You need a seed."
		return
	inventory.seeds -= 1
	plot["stage"] = 0
	plot["watered"] = false

func _water(plot: Dictionary) -> void:
	var stage: int = int(plot["stage"])
	if stage >= 0 and stage < LAST_STAGE:
		plot["watered"] = true

func _harvest(plot: Dictionary) -> void:
	var inventory: Inventory = _inventory()
	if inventory != null:
		inventory.turnips += 1
	plot["stage"] = -1
	plot["watered"] = false

func tool_for_plot(cell: Vector2i) -> String:
	var plot: Dictionary = _plot(cell)
	if not bool(plot["tilled"]):
		return ""
	var stage: int = int(plot["stage"])
	if stage >= 0 and stage < LAST_STAGE and not bool(plot["watered"]):
		return "water"
	if stage < 0 or stage >= LAST_STAGE:
		return "hoe"
	return ""

func _plot(cell: Vector2i) -> Dictionary:
	var key: String = _key(cell)
	if plots.has(key):
		return plots[key]
	return {"tilled": false, "stage": -1, "watered": false}

func _store(cell: Vector2i, plot: Dictionary) -> void:
	if not bool(plot["tilled"]):
		plots.erase(_key(cell))
		return
	plots[_key(cell)] = plot

func _sprout(dirt: TileMapLayer, cell: Vector2i, stage: int, watered: bool) -> Sprite2D:
	var sprout: Sprite2D = Sprite2D.new()
	sprout.texture = PLANTS
	sprout.region_enabled = true
	var tile: Vector2i = STAGE_TILES[clampi(stage, 0, LAST_STAGE)]
	sprout.region_rect = Rect2(tile.x, tile.y, 16, 16)
	sprout.centered = true
	sprout.position = dirt.map_to_local(cell)
	if watered:
		sprout.modulate = Color("c5e4ea")
	return sprout

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
