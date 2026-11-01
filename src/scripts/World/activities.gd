# src/scripts/World/activities.gd
# Purpose: Neighbor, the seed shop, daily gathering, the cave, and the one quest.

class_name Activities
extends Node

var quest_done: bool = false
var fished_today: bool = false
var fish_day: int = -1
var fish_spots: Dictionary = {}
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
	if _take_mark("ore", dirt, cell, "copper"):
		return true
	if _take_mark("forage", dirt, cell, "forage"):
		return true
	var role: String = _role_at(place, dirt, cell)
	if role != "":
		talk_role(role)
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
		if not mark.is_in_group("tree") and not mark.is_in_group("rock") and not mark.is_in_group("ore") and not mark.is_in_group("date") and not mark.is_in_group("forage") and str(mark.get("role")) == "" and mark.name != "Neighbor" and mark.name != "FishingSpot" and mark.name != "CaveEntrance":
			continue
		var spot: Node2D = mark as Node2D
		var mark_cell: Vector2i = dirt.local_to_map(dirt.to_local(spot.global_position))
		var gap: Vector2i = cell - mark_cell
		var distance: int = maxi(absi(gap.x), absi(gap.y))
		var close: bool = distance <= 1
		if spot.is_in_group("tree") or spot.is_in_group("date"):
			close = absi(gap.x) <= 2 and gap.y <= 0 and gap.y >= -5
			distance = absi(gap.x) + absi(gap.y)
		elif str(spot.get("role")) != "" or spot.get("person") != null:
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
	if _group_has("date", dirt, cell) or _group_has("forage", dirt, cell) or _role_at(place, dirt, cell) != "":
		return "use"
	if _group_has("tree", dirt, cell):
		return "axe"
	if _group_has("rock", dirt, cell) or _group_has("ore", dirt, cell):
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

func fish_at(place_name: String) -> bool:
	var key: String = "%s/FishingSpot" % place_name
	if int(fish_spots.get(key, -1)) == _day():
		note = Locale.t("quiet")
		_refresh()
		return false
	fish_spots[key] = _day()
	fished_today = place_name == "Home"
	if place_name == "Home":
		fish_day = _day()
	_inventory().add_item("fish", 1)
	note = Locale.t("caught")
	_chime("gather")
	_save()
	_refresh()
	return true

func take_daily(mark_key: String, item: String) -> bool:
	if int(gathered.get(mark_key, -1)) == _day():
		return false
	gathered[mark_key] = _day()
	_inventory().add_item(item, 1)
	note = _gather_note(item)
	_chime("gather")
	_save()
	_refresh()
	apply_gathered()
	return true

func gather_node(spot: Node2D) -> bool:
	var kind: String = str(spot.get("group_name"))
	var item: String = ""
	match kind:
		"date":
			item = "dates"
		"forage":
			item = "forage"
		"tree":
			item = "wood"
		"rock":
			item = "stone"
		"ore":
			item = "copper"
		_:
			return false
	var place: Node = spot.get_parent()
	if place == null:
		return false
	return take_daily(_mark_key(place, spot), item)

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
		"fish_spots": fish_spots.duplicate(),
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
	fish_spots.clear()
	if data.has("fish_spots") and data["fish_spots"] is Dictionary:
		var stored_fish: Dictionary = data["fish_spots"]
		for key: Variant in stored_fish:
			if int(stored_fish[key]) == _day():
				fish_spots[str(key)] = _day()
	elif fish_day == _day():
		fish_spots["Home/FishingSpot"] = _day()
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
		if kind != "tree" and kind != "rock" and kind != "ore" and kind != "date" and kind != "forage":
			continue
		var taken: bool = gathered.has(_mark_key(place, mark)) and int(gathered[_mark_key(place, mark)]) == today
		_set_mark(mark as Node2D, not taken)
	for node: Node in get_tree().get_nodes_in_group("daily_spot"):
		if node.has_method("apply_day"):
			node.call("apply_day", gathered, today)

func _talk() -> void:
	var dialogue: DialogueBox = _dialogue()
	if dialogue.visible:
		return
	if not dialogue.picked.is_connected(_on_shop_choice):
		dialogue.picked.connect(_on_shop_choice)
	_shop = "menu"
	var greeting: String = Locale.t("greeting")
	if not quest_done:
		greeting = Locale.t("greeting_quest")
	dialogue.offer(greeting, _menu_choices())

func talk_role(role: String) -> void:
	var dialogue: DialogueBox = _dialogue()
	if dialogue.visible:
		return
	_listen(dialogue)
	match role:
		"workbench", "carpenter":
			_shop = "work"
			dialogue.offer(Locale.t("workbench"), _labeled(["craft", "build", "animals", "quests", "cancel"]))
		"elder":
			_shop = ""
			dialogue.open_lines(PackedStringArray([Locale.t("elder")]))
		"fisherman":
			_shop = ""
			dialogue.open_lines(PackedStringArray([Locale.t("fisherman")]))
		"merchant":
			_shop = "menu"
			dialogue.offer(Locale.t("merchant"), _labeled(["sell_goods", "buy_seeds", "cancel"]))
		_:
			_talk()

func _on_shop_choice(choice: String) -> void:
	if _shop == "menu":
		if choice == "sell_turnips" or choice == "Sell Turnips":
			_sell_to_jassim()
		elif choice == "sell_goods" or choice == "Sell Goods":
			_shop = "sell"
			_offer_sell()
		elif choice == "buy_seeds" or choice == "Buy Seeds":
			_shop = "seeds"
			_dialogue().offer(Locale.t("which_seed"), _seed_choices())
		return
	if _shop == "sell":
		if choice == "cancel" or choice == "Cancel":
			_shop = ""
			return
		_sell_good(choice)
		return
	if _shop == "work":
		_work_choice(choice)
		return
	if _shop == "craft" or _shop == "build" or _shop == "animals":
		_work_action(choice)
		return
	if _shop != "seeds" or choice == "cancel" or choice == "Cancel":
		_shop = ""
		return
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		if choice != crop_id and choice != _seed_label(crop):
			continue
		_buy_seed(crop_id, crop)
		return

func _sell_to_jassim() -> void:
	var inventory: Inventory = _inventory()
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if inventory.turnips <= 0:
		note = Locale.t("no_turnips")
		if hud != null and hud.has_method("dismiss_sale"):
			hud.call("dismiss_sale")
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	var sold: int = inventory.turnips
	var earned: int = inventory.sell_turnips()
	quest_done = true
	note = ""
	_chime("coin")
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
		note = Locale.t("need_dinars") % price
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	note = Locale.t("bought") % seed_name
	_dialogue().open_lines(PackedStringArray([note]))
	_save()
	_refresh()

func _seed_choices() -> PackedStringArray:
	var choices: PackedStringArray = []
	for crop_id: String in CropCatalog.ids():
		choices.append("%s|%s" % [crop_id, _seed_label(CropCatalog.get_crop(crop_id))])
	choices.append("cancel|%s" % Locale.t("cancel"))
	return choices

func _seed_label(crop: Dictionary) -> String:
	return "%s  %d" % [Locale.item(str(crop.get("seed_item", "seeds"))), int(crop.get("seed_price", 0))]

func _menu_choices() -> PackedStringArray:
	return _labeled(["sell_turnips", "sell_goods", "buy_seeds", "cancel"])

func _labeled(keys: Array) -> PackedStringArray:
	var choices: PackedStringArray = []
	for key: Variant in keys:
		choices.append("%s|%s" % [str(key), Locale.t(str(key))])
	return choices

func _listen(dialogue: DialogueBox) -> void:
	if not dialogue.picked.is_connected(_on_shop_choice):
		dialogue.picked.connect(_on_shop_choice)

func _offer_sell() -> void:
	var inventory: Inventory = _inventory()
	var choices: PackedStringArray = []
	for item_id: String in GoodsCatalog.sellable_ids():
		var count: int = inventory.count_of(item_id)
		var price: int = GoodsCatalog.sell_price(item_id)
		if count < 1 or price < 1:
			continue
		choices.append("%s|%s x%d  %d" % [item_id, Locale.item(item_id), count, count * price])
	if choices.is_empty():
		_shop = ""
		note = Locale.t("nothing_to_sell")
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	choices.append("cancel|%s" % Locale.t("cancel"))
	_dialogue().offer(Locale.t("sell_goods"), choices)

func _sell_good(item_id: String) -> void:
	var inventory: Inventory = _inventory()
	var sold: int = inventory.count_of(item_id)
	var earned: int = inventory.sell_stack(item_id)
	if earned < 1:
		note = Locale.t("nothing_to_sell")
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	if item_id == "turnips":
		quest_done = true
	note = Locale.t("sold") % Locale.item(item_id)
	_chime("coin")
	_save()
	_refresh()
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if item_id == "turnips" and hud != null and hud.has_method("show_sale"):
		hud.call("show_sale", Locale.item(item_id), sold, earned, inventory.count_of(item_id), inventory.dinars)
	else:
		_dialogue().open_lines(PackedStringArray([note]))

func _work_choice(choice: String) -> void:
	var stead: Stead = _stead()
	if stead == null or choice == "cancel":
		_shop = ""
		return
	if choice == "quests":
		_shop = ""
		_dialogue().open_lines(PackedStringArray([stead.goal_text(), Locale.t("quests_body")]))
		return
	if choice == "craft":
		_shop = "craft"
		_dialogue().offer(Locale.t("craft"), _labeled(["craft_feed", "cancel"]))
		return
	if choice == "build":
		_shop = "build"
		_dialogue().offer(Locale.t("build"), _labeled(["coop", "barn", "expand", "tools", "cancel"]))
		return
	if choice == "animals":
		_shop = "animals"
		_dialogue().offer(Locale.t("animals"), _labeled([
			"buy_chicken", "feed_chicken", "buy_goat", "feed_goat",
			"buy_sheep", "feed_sheep", "buy_cow", "feed_cow", "cancel",
		]))
		return
	_shop = ""

func _work_action(choice: String) -> void:
	var stead: Stead = _stead()
	var shop: String = _shop
	_shop = ""
	if stead == null or choice == "cancel":
		return
	var ok: bool = false
	var line: String = Locale.t("cannot")
	if shop == "craft" and choice == "craft_feed":
		ok = stead.craft("feed")
		line = Locale.t("made") % Locale.item("feed")
	elif shop == "build":
		ok = stead.build(choice)
		line = Locale.t("built") % Locale.t(choice)
	elif shop == "animals" and choice.begins_with("buy_"):
		var kind: String = choice.trim_prefix("buy_")
		ok = stead.buy_animal(kind)
		line = Locale.t("bought") % Locale.t(kind)
	elif shop == "animals" and choice.begins_with("feed_"):
		var kind: String = choice.trim_prefix("feed_")
		var fed: int = stead.feed_kind(kind)
		ok = fed > 0
		line = Locale.t("fed") % fed
	if not ok:
		note = Locale.t("cannot")
	else:
		note = line
		_chime("ui")
		_save()
	_dialogue().open_lines(PackedStringArray([note]))
	_refresh()

func _stead() -> Stead:
	return get_parent().get_node_or_null("Stead") as Stead

func _chime(kind: String) -> void:
	var bank: Node = get_parent().get_node_or_null("SoundBank")
	if bank != null and bank.has_method("play"):
		bank.call("play", kind)

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
	var place: Node = _place()
	fish_at(place.name if place != null else "Home")

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
			return Locale.t("cut_tree")
		"stone":
			return Locale.t("broke_rock")
		"dates":
			return Locale.t("picked_date")
		"forage":
			return Locale.t("picked_herb")
		"copper":
			return Locale.t("found_copper")
		_:
			return Locale.t("made") % Locale.item(item)

func _role_at(place: Node, dirt: TileMapLayer, cell: Vector2i) -> String:
	for mark: Node in place.get_children():
		if str(mark.get("role")) == "" or not mark is Node2D:
			continue
		var spot: Node2D = mark as Node2D
		if dirt.local_to_map(dirt.to_local(spot.global_position)) == cell:
			return str(mark.get("role"))
	return ""

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
