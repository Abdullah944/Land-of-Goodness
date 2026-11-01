# src/scripts/World/activities.gd
# Purpose: Neighbor, the seed shop, daily gathering, the cave, and the one quest.

class_name Activities
extends Node

var quest_done: bool = false
var fished_today: bool = false
var fish_day: int = -1
var rock_mined: bool = false
var gathered: Dictionary = {}
var note: String = ""
var _shop: String = ""
var _flash: String = ""
var _flash_token: int = 0

func try_use(dirt: TileMapLayer, cell: Vector2i) -> bool:
	var place: Node = _place()
	if place == null:
		return false
	if _take_mark("date", dirt, cell, "dates"):
		return true
	if _take_mark("forage", dirt, cell, "forage"):
		return true
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
		if not mark.is_in_group("tree") and not mark.is_in_group("rock") and not mark.is_in_group("date") and not mark.is_in_group("forage") and mark.name != "Neighbor" and mark.name != "FishingSpot" and mark.name != "CaveEntrance":
			continue
		var spot: Node2D = mark as Node2D
		var mark_cell: Vector2i = dirt.local_to_map(dirt.to_local(spot.global_position))
		var gap: Vector2i = cell - mark_cell
		var distance: int = maxi(absi(gap.x), absi(gap.y))
		var close: bool = distance <= 1
		if spot.is_in_group("tree") or spot.is_in_group("date"):
			close = absi(gap.x) <= 2 and gap.y <= 0 and gap.y >= -5
			distance = absi(gap.x) + absi(gap.y)
		elif spot.get("person") != null:
			close = absi(gap.x) <= 1 and gap.y <= 0 and gap.y >= -3
			distance = absi(gap.x) + absi(gap.y)
		if close and distance < best_distance:
			best = mark_cell
			best_distance = distance
	return best

func tool_for_cell(dirt: TileMapLayer, cell: Vector2i) -> String:
	var place: Node = _place()
	if place == null:
		return ""
	if _group_has("date", dirt, cell) or _group_has("forage", dirt, cell):
		return "use"
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
	fish_day = -1
	rock_mined = false
	gathered.clear()
	apply_gathered()

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
		"fish_day": fish_day,
		"rock_mined": rock_mined,
		"gathered": gathered.duplicate(),
	}

func from_data(data: Dictionary) -> void:
	quest_done = bool(data.get("quest_done", false))
	rock_mined = bool(data.get("rock_mined", false))
	if data.has("fish_day"):
		fish_day = int(data.get("fish_day", -1))
		fished_today = fish_day == _day()
	else:
		fish_day = -1
		fished_today = bool(data.get("fished_today", false))
	gathered.clear()
	var stored: Variant = data.get("gathered", {})
	if typeof(stored) == TYPE_DICTIONARY:
		for key: Variant in stored:
			if int(stored[key]) == _day():
				gathered[str(key)] = _day()
	apply_gathered()

func apply_gathered() -> void:
	var place: Node = _place()
	if place == null:
		return
	var today: int = _day()
	for mark: Node in place.get_children():
		if not mark is Node2D:
			continue
		var kind: String = str(mark.get("group_name"))
		if kind != "tree" and kind != "rock" and kind != "date" and kind != "forage":
			continue
		var taken: bool = gathered.has(_mark_key(place, mark)) and int(gathered[_mark_key(place, mark)]) == today
		_set_mark(mark as Node2D, not taken)

func _talk() -> void:
	var dialogue: DialogueBox = _dialogue()
	if dialogue.visible:
		return
	if not dialogue.picked.is_connected(_on_shop_choice):
		dialogue.picked.connect(_on_shop_choice)
	_shop = "menu"
	var greeting: String = "Peace be upon you. I am Jassim."
	if not quest_done:
		greeting = "Peace be upon you. I am Jassim. Plant a turnip, water it each day, then sell it to me."
	dialogue.offer(greeting, PackedStringArray(["Sell Turnips", "Buy Seeds", "Cancel"]))

func _on_shop_choice(choice: String) -> void:
	if _shop == "menu":
		if choice == "Sell Turnips":
			_sell_to_jassim()
		elif choice == "Buy Seeds":
			_shop = "seeds"
			_dialogue().offer("Which seed?", _seed_choices())
		return
	if _shop != "seeds" or choice == "Cancel":
		_shop = ""
		return
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		if choice != _seed_label(crop):
			continue
		_buy_seed(crop_id, crop)
		return

func _sell_to_jassim() -> void:
	var inventory: Inventory = _inventory()
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if inventory.turnips <= 0:
		note = "You have no turnips to sell."
		if hud != null and hud.has_method("dismiss_sale"):
			hud.call("dismiss_sale")
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	var sold: int = inventory.turnips
	var earned: int = inventory.sell_turnips()
	quest_done = true
	note = ""
	_save()
	_refresh()
	if hud != null and hud.has_method("show_sale"):
		var crop_name: String = str(CropCatalog.get_crop(CropCatalog.TURNIP).get("name", "Turnip"))
		hud.call("show_sale", crop_name, sold, earned, inventory.turnips, inventory.dinars)

func _buy_seed(crop_id: String, crop: Dictionary) -> void:
	var inventory: Inventory = _inventory()
	var price: int = int(crop.get("seed_price", 0))
	var seed_name: String = str(crop.get("seed_name", "Seed"))
	if not inventory.try_buy_seed(crop_id):
		note = "You need %d dinars." % price
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	note = "You bought %s." % seed_name
	_dialogue().open_lines(PackedStringArray([note]))
	_save()
	_refresh()

func _seed_choices() -> PackedStringArray:
	var choices: PackedStringArray = []
	for crop_id: String in CropCatalog.ids():
		choices.append(_seed_label(CropCatalog.get_crop(crop_id)))
	choices.append("Cancel")
	return choices

func _seed_label(crop: Dictionary) -> String:
	return "%s  %d dinars" % [str(crop.get("seed_name", "Seed")), int(crop.get("seed_price", 0))]

func _dialogue() -> DialogueBox:
	return get_tree().current_scene.get_node("UI/Dialogue") as DialogueBox

func display_note() -> String:
	if _flash != "":
		return _flash
	return note

func flash(text: String) -> void:
	_flash_token += 1
	var token: int = _flash_token
	_flash = text
	_refresh()
	await get_tree().create_timer(2.0).timeout
	if token != _flash_token:
		return
	_flash = ""
	_refresh()

func _refresh() -> void:
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud != null and hud.has_method("refresh"):
		hud.refresh()

func _fish() -> void:
	if fished_today:
		note = "The water is quiet until tomorrow."
		return
	fished_today = true
	fish_day = _day()
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
		var key: String = _mark_key(place, spot)
		if gathered.has(key) and int(gathered[key]) == _day():
			return false
		var inventory: Inventory = _inventory()
		inventory.add_item(item, 1)
		note = _gather_note(item)
		gathered[key] = _day()
		_set_mark(spot, false)
		_save()
		_refresh()
		return true
	return false

func _gather_note(item: String) -> String:
	match item:
		"wood":
			return "You cut the tree."
		"stone":
			return "You broke the rock."
		"dates":
			return "You picked a date."
		"forage":
			return "You picked an herb."
		_:
			return "You gathered."

func _mark_key(place: Node, spot: Node) -> String:
	return "%s/%s" % [place.name, spot.name]

func _day() -> int:
	var clock: GameClock = get_parent().get_node("Clock") as GameClock
	return clock.day

func _set_mark(spot: Node2D, available: bool) -> void:
	spot.visible = available
	spot.set_process(available)
	var kind: String = str(spot.get("group_name"))
	if available:
		if kind != "" and not spot.is_in_group(kind):
			spot.add_to_group(kind)
	elif kind != "" and spot.is_in_group(kind):
		spot.remove_from_group(kind)
	var block: StaticBody2D = spot.get_node_or_null("Block") as StaticBody2D
	if block != null:
		block.set_collision_layer_value(1, available)

func _matches(place: Node, node_name: String, dirt: TileMapLayer, cell: Vector2i) -> bool:
	var mark: Node2D = place.get_node_or_null(node_name) as Node2D
	if mark == null:
		return false
	return dirt.local_to_map(dirt.to_local(mark.global_position)) == cell

func _place() -> Node:
	var world: Node = get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return null
	for child: Node in world.get_children():
		if child.name == "Player":
			continue
		return child
	return null

func _inventory() -> Inventory:
	return get_parent().get_node("Inventory") as Inventory

func _save() -> void:
	var save: SaveGame = get_parent().get_node("SaveGame") as SaveGame
	save.write_now()
