# src/scripts/World/activities.gd
# Purpose: Neighbor, fishing, the cave, and the one quest.

class_name Activities
extends Node

var quest_done: bool = false
var fished_today: bool = false
var rock_mined: bool = false
var note: String = ""

func try_use(dirt: TileMapLayer, cell: Vector2i) -> bool:
	var place: Node = _place()
	if place == null:
		return false
	if _matches(place, "Neighbor", dirt, cell):
		_talk()
		return true
	if _matches(place, "FishingSpot", dirt, cell):
		_fish()
		return true
	if _matches(place, "CaveEntrance", dirt, cell):
		_enter_cave()
		return true
	return false

func snap_cell(dirt: TileMapLayer, cell: Vector2i) -> Vector2i:
	var place: Node = _place()
	if place == null:
		return cell
	var best: Vector2i = cell
	var best_distance: int = 99
	for mark: Node in place.get_children():
		if not mark is Node2D:
			continue
		if not mark.is_in_group("tree") and not mark.is_in_group("rock") and mark.name != "Neighbor" and mark.name != "FishingSpot" and mark.name != "CaveEntrance":
			continue
		var spot: Node2D = mark as Node2D
		var mark_cell: Vector2i = dirt.local_to_map(dirt.to_local(spot.global_position))
		var gap: Vector2i = cell - mark_cell
		var distance: int = maxi(absi(gap.x), absi(gap.y))
		var close: bool = distance <= 1
		if spot.get("person") != null:
			var reach_x: int = 2 if spot.is_in_group("tree") else 1
			var reach_up: int = 4 if spot.is_in_group("tree") else 3
			close = absi(gap.x) <= reach_x and gap.y <= 0 and gap.y >= -reach_up
			distance = absi(gap.x) + absi(gap.y)
		if close and distance < best_distance:
			best = mark_cell
			best_distance = distance
	return best

func tool_for_cell(dirt: TileMapLayer, cell: Vector2i) -> String:
	var place: Node = _place()
	if place == null:
		return ""
	if _group_has("tree", dirt, cell):
		return "axe"
	if _group_has("rock", dirt, cell):
		return "pick"
	if _matches(place, "Neighbor", dirt, cell) or _matches(place, "FishingSpot", dirt, cell) or _matches(place, "CaveEntrance", dirt, cell):
		return "use"
	var farm: FarmField = get_parent().get_node("FarmField") as FarmField
	return farm.tool_for_plot(cell)

func chop_at(dirt: TileMapLayer, cell: Vector2i) -> bool:
	return _take_mark("tree", dirt, cell, "wood")

func mine_at(dirt: TileMapLayer, cell: Vector2i) -> bool:
	return _take_mark("rock", dirt, cell, "stone")

func on_new_day() -> void:
	fished_today = false
	rock_mined = false

func give_stone() -> void:
	if rock_mined:
		return
	rock_mined = true
	var inventory: Inventory = _inventory()
	inventory.stone += 1
	note = "You broke a stone."
	_save()

func to_data() -> Dictionary:
	return {
		"quest_done": quest_done,
		"fished_today": fished_today,
		"rock_mined": rock_mined,
	}

func from_data(data: Dictionary) -> void:
	quest_done = bool(data.get("quest_done", false))
	fished_today = bool(data.get("fished_today", false))
	rock_mined = bool(data.get("rock_mined", false))

func _talk() -> void:
	var inventory: Inventory = _inventory()
	var dialogue: DialogueBox = get_tree().current_scene.get_node("UI/Dialogue") as DialogueBox
	var lines: PackedStringArray = ["Peace be upon you. I am Jassim."]
	if inventory.turnips > 0:
		var earned: int = inventory.sell_turnips()
		quest_done = true
		lines.append("I bought your turnips for %d dinars." % earned)
	elif quest_done:
		lines.append("The field is doing well. Sell me more when you have them.")
	else:
		lines.append("Plant a turnip, water it each day, then sell it to me.")
	dialogue.open_lines(lines)
	_save()

func _fish() -> void:
	if fished_today:
		note = "The water is quiet until tomorrow."
		return
	fished_today = true
	_inventory().fish += 1
	note = "You caught a fish."
	_save()

func _enter_cave() -> void:
	var loader: LevelLoader = get_parent().get_node("LevelLoader") as LevelLoader
	var cave: PackedScene = load("res://src/scenes/world/cave/Cave.tscn") as PackedScene
	loader.go_to(cave, "PlayerSpawn")

func _group_has(group_name: String, dirt: TileMapLayer, cell: Vector2i) -> bool:
	var place: Node = _place()
	if place == null:
		return false
	for mark: Node in place.get_children():
		if not mark.is_in_group(group_name) or not mark is Node2D:
			continue
		var spot: Node2D = mark as Node2D
		if dirt.local_to_map(dirt.to_local(spot.global_position)) == cell:
			return true
	return false

func _take_mark(group_name: String, dirt: TileMapLayer, cell: Vector2i, item: String) -> bool:
	var place: Node = _place()
	if place == null:
		return false
	for mark: Node in place.get_children():
		if not mark.is_in_group(group_name) or not mark is Node2D:
			continue
		var spot: Node2D = mark as Node2D
		if dirt.local_to_map(dirt.to_local(spot.global_position)) != cell:
			continue
		var inventory: Inventory = _inventory()
		if item == "wood":
			inventory.wood += 1
			note = "You cut the tree."
		else:
			inventory.stone += 1
			note = "You broke the rock."
		spot.queue_free()
		_save()
		return true
	return false

func _matches(place: Node, node_name: String, dirt: TileMapLayer, cell: Vector2i) -> bool:
	var mark: Node2D = place.get_node_or_null(node_name) as Node2D
	if mark == null:
		return false
	return dirt.local_to_map(dirt.to_local(mark.global_position)) == cell

func _place() -> Node:
	var world: Node = get_tree().current_scene.get_node_or_null("World")
	if world == null or world.get_child_count() == 0:
		return null
	return world.get_child(0)

func _inventory() -> Inventory:
	return get_parent().get_node("Inventory") as Inventory

func _save() -> void:
	var save: SaveGame = get_parent().get_node("SaveGame") as SaveGame
	save.write_now()
