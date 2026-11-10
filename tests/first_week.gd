# tests/first_week.gd
# Purpose: Plays days 1 to 7 the way a new player does (a few seeds, one bag of energy, following the quest line)
# and prints what each day gave, so slow or empty days show up.
# Run: KHAIR_SAVE=user://land_of_khair_week.json Godot --headless --path . -s tests/first_week.gd

extends SceneTree

const DAYS: int = 7
const KEEP: Array[String] = ["wood", "stone", "forage", "wheat", "copper", "feed", "eggs"]
## A new player does not fill the field. This is the most beds he keeps in his first week.
const BEDS: int = 16

var passed: int = 0
var failed: int = 0
var swings: int = 0

func _init() -> void:
	_run()

func _run() -> void:
	var side: String = OS.get_environment("KHAIR_SAVE")
	if side == "" or side.get_file() == "land_of_khair.json":
		print("WEEK refused: set KHAIR_SAVE to a side save so the player's farm is never touched")
		quit(2)
		return
	seed(23)
	TitleMenu.dismissed = true
	change_scene_to_file("res://src/scenes/world/main/MainGame.tscn")
	await process_frame
	await process_frame
	var main: Node = current_scene
	var systems: Node = main.get_node("Systems")
	var clock: GameClock = systems.get_node("Clock") as GameClock
	clock.set_process(false)
	var save: SaveGame = systems.get_node("SaveGame") as SaveGame
	save.start_new()
	check(save.load_game(), "a new farm starts")
	Locale.language = "en"
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var stead: Stead = systems.get_node("Stead") as Stead
	var activities: Activities = systems.get_node("Activities") as Activities
	activities.quick_fish = true
	var letters: Letters = systems.get_node("Letters") as Letters
	letters.set_process(false)
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var works: VillageWorks = systems.get_node("VillageWorks") as VillageWorks
	var friends: Friendship = systems.get_node("Friendship") as Friendship
	var fairs: Festivals = systems.get_node("Festivals") as Festivals
	var kindness: Kindness = systems.get_node("Kindness") as Kindness
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	var marks: Array[String] = _home_marks(main)
	print("WEEK start dinars=%d seeds=%d tomato=%d wheat=%d melon=%d home_marks=%d" % [bag.dinars, bag.seeds, bag.tomato_seeds, bag.wheat_seeds, bag.watermelon_seeds, marks.size()])
	var new_things: Array[int] = []
	var earned_by_day: Array[int] = []
	var before: Dictionary = _snapshot(bag, stead, kindness, friends)
	for index: int in DAYS:
		swings = 0
		var events: PackedStringArray = PackedStringArray()
		print("\nWEEK day %d  %s %s" % [clock.day, clock.season, clock.weather])
		print("  goal: %s" % stead.goal_text())
		if activities.note != "":
			print("  morning note: %s" % activities.note)
		if not letters.pending.is_empty():
			var item: String = str(letters.pending["item"])
			events.append("letter from %s (%s x%d)" % [letters.pending["person"], item, int(letters.pending["amount"])])
			if item != "":
				bag.add_item(item, int(letters.pending["amount"]))
			letters.pending = {}
		if not fairs.today().is_empty():
			events.append("fair: " + str(fairs.today()["id"]))
			fairs.join()
		if friends.birthday_today() != "":
			events.append("birthday: " + friends.birthday_today())
		if not bool(stead.flags.get("met_jassim", false)):
			stead.flags["met_jassim"] = true
			events.append("met Jassim, got the key")
		# Field first: pick, then plant what he has, then water.
		var earned: int = 0
		var dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
		_field(farm, dirt, bag, clock)
		if bag.turnips > 0:
			var had: int = bag.dinars
			activities._sell_to_jassim()
			earned += bag.dinars - had
		# Neighbors: one talk each from the second day, and today's request when the bag allows.
		var away: bool = false
		if clock.day >= 2:
			if stead.goal_text().begins_with(Locale.t("step_meet").get_slice("(", 0)) or bool(stead.visited.get("Village", false)):
				await _visit(loader, "village/Village")
				await _visit(loader, "harbor/Harbor")
				away = true
				for person: String in Friendship.PEOPLE:
					var line: String = friends.talk(person)
					if line != "":
						events.append("%s says something new" % person)
				if activities.take_welcome() != "":
					events.append("welcome gift from the village")
			else:
				friends.talk("jassim")
		if works.requests_open():
			var wish: Dictionary = works.request_today()
			var had_dinars: int = bag.dinars
			if stead._step_costs(_open_step(stead)).has(str(wish["item"])):
				events.append("request kept for later: he needs the %s himself" % wish["item"])
			elif works.fulfil_request():
				events.append("request done: %d %s for %s" % [int(wish["amount"]), wish["item"], wish["person"]])
				earned += bag.dinars - had_dinars
			else:
				events.append("request open: %d %s for %s" % [int(wish["amount"]), wish["item"], wish["person"]])
		if stead.goal_text() == Locale.t("step_woods"):
			await _visit(loader, "forest/Forest")
			away = true
			for spot: Node in _place(main).get_children():
				if swings >= _budget(bag):
					break
				if spot is Node2D and str(spot.get("group_name")) in ["tree", "rock", "forage"] and activities.gather_node(spot as Node2D):
					swings += 1
			activities.fish_at("Forest")
			events.append("explored the woods")
		# The quest line, in order. When it says what is missing, he goes to the woods for it.
		_follow_quest(stead, bag, events)
		for place: String in ["Harbor", "Orchard"]:
			if stead.goal_text() == Locale.t("quest_" + place.to_lower()):
				await _visit(loader, "%s/%s" % [place.to_lower(), place])
				away = true
				for spot: Node in _place(main).get_children():
					if spot is Node2D and str(spot.get("group_name")) in ["date", "forage", "shore"]:
						activities.gather_node(spot as Node2D)
				_follow_quest(stead, bag, events)
		if stead.where_hint() != "" and swings < _budget(bag):
			await _visit(loader, "forest/Forest")
			away = true
			var got: int = 0
			for spot: Node in _place(main).get_children():
				if swings >= _budget(bag):
					break
				if spot is Node2D and str(spot.get("group_name")) in ["tree", "rock", "forage"] and activities.gather_node(spot as Node2D):
					swings += 1
					got += 1
			events.append("went to the woods: %d things" % got)
			if stead.where_hint() == Locale.t("where_stone") and swings < _budget(bag):
				await _visit(loader, "cave/Cave")
				var mined: int = 0
				for spot: Node in _place(main).get_children():
					if swings >= _budget(bag):
						break
					if spot is Node2D and str(spot.get("group_name")) in ["rock", "ore"] and activities.gather_node(spot as Node2D):
						swings += 1
						mined += 1
				events.append("went to the cave: %d things" % mined)
			_follow_quest(stead, bag, events)
		if away:
			await _visit(loader, "home/Home", "VillageReturn")
			dirt = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
		# What is left of his energy goes to trees and rocks at home, then the pond.
		for mark: String in marks:
			if swings >= _budget(bag):
				break
			if activities.take_daily(mark.get_slice("=", 0), mark.get_slice("=", 1)):
				swings += 1
		activities.fish_at("Home")
		if activities.quest_done:
			for item_id: String in Inventory.all_stored_ids():
				if KEEP.has(item_id) or GoodsCatalog.sell_price(item_id) < 1 or item_id == "turnips" or item_id == "tomatoes":
					continue
				earned += bag.sell_stack(item_id)
			while bag.dinars >= 10 and bag.seeds + _planted(farm) < BEDS:
				if not bag.try_buy_seed(CropCatalog.TURNIP):
					break
			_field(farm, dirt, bag, clock)
		var after: Dictionary = _snapshot(bag, stead, kindness, friends)
		var fresh: PackedStringArray = _new_things(before, after)
		for line: String in events:
			print("  event: %s" % line)
		print("  swings %d of %d, beds %d, earned %d, dinars %d" % [swings, _budget(bag), _planted(farm), earned, bag.dinars])
		print("  bag: wood %d stone %d forage %d fish %d turnips %d tomatoes %d eggs %d feed %d" % [bag.wood, bag.stone, bag.forage, bag.fish, bag.turnips, bag.tomatoes, bag.count_of("eggs"), bag.count_of("feed")])
		print("  new today: %s" % (", ".join(fresh) if fresh.size() > 0 else "nothing"))
		print("  bedtime: %s" % Tomorrow.line(systems))
		before = after
		new_things.append(fresh.size() + events.size())
		earned_by_day.append(earned)
		clock.sleep_now()
		clock.set_process(false)
	print("\nWEEK end day=%d dinars=%d goal=%s khair=%d book=%d/%d" % [clock.day, bag.dinars, stead.goal_text(), kindness.points, CollectionBook.found_total(bag.found), CollectionBook.total()])
	var hearts: PackedStringArray = PackedStringArray()
	for person: String in Friendship.PEOPLE:
		hearts.append("%s %d" % [person, int(friends.points.get(person, 0))])
	print("WEEK friendship points: %s" % ", ".join(hearts))
	var quiet: int = 0
	for index: int in DAYS:
		if new_things[index] == 0:
			quiet += 1
	check(quiet == 0, "every day of the first week brings something new (%d quiet days)" % quiet)
	check(activities.quest_done, "the first sale happens in the first week")
	check(stead.coop, "the coop stands by the end of the first week")
	_remove_side_files(save)
	print("WEEK passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _budget(bag: Inventory) -> int:
	return int(bag.max_hearts / Inventory.TOOL_TIRE)

## Picks what is ripe, digs and plants while there are seeds for this season, and waters what is dry.
func _field(farm: FarmField, dirt: TileMapLayer, bag: Inventory, clock: GameClock) -> void:
	for x: int in farm.farm_size.x:
		for y: int in farm.farm_size.y:
			var cell: Vector2i = farm.farm_origin + Vector2i(x, y)
			for attempt: int in 4:
				if swings >= _budget(bag):
					return
				var state: String = farm.state_of(cell)
				if state == "watered":
					break
				if state == "empty" or state == "tilled":
					if not _pick_seed(bag, clock) or _planted(farm) >= BEDS and state == "empty":
						break
				farm.work(dirt, cell, false)
				swings += 1

func _pick_seed(bag: Inventory, clock: GameClock) -> bool:
	for crop_id: String in [CropCatalog.TURNIP, CropCatalog.TOMATO, CropCatalog.WATERMELON, CropCatalog.WHEAT]:
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		if bag.count_of(str(crop["seed_item"])) > 0 and (crop["seasons"] as Array).has(clock.season):
			bag.selected_seed = crop_id
			return true
	return false

func _planted(farm: FarmField) -> int:
	var count: int = 0
	for key: String in farm.plots.keys():
		if int(farm.plots[key].get("stage", -1)) >= 0:
			count += 1
	return count

func _follow_quest(stead: Stead, bag: Inventory, events: PackedStringArray) -> void:
	var activities: Node = stead.get_parent().get_node("Activities")
	if not bool(activities.get("quest_done")):
		return
	if not bool(stead.flags.get("crafted_feed", false)):
		if stead.craft("feed_herbs") or stead.craft("feed"):
			events.append("crafted feed")
		else:
			events.append("stuck: feed needs %s" % stead.missing_text({"forage": 2}))
			return
	if not stead.coop:
		if stead.build("coop"):
			events.append("built the coop")
		else:
			events.append("stuck: coop needs %s" % stead.missing_text(RecipeCatalog.building("coop")["costs"]))
			return
	if stead.count_kind("chicken") < 1:
		if stead.buy_animal("chicken"):
			events.append("bought a chicken")
		else:
			events.append("stuck: chicken needs %d dinars" % (180 - bag.dinars))
			return
	if bag.count_of("feed") < stead.animals.size() and not stead.craft("feed_herbs"):
		stead.buy_feed()
	stead.feed_kind("chicken")
	if not bool(stead.flags.get("got_egg", false)) or not bool(stead.visited.get("Harbor", false)) or not bool(stead.visited.get("Orchard", false)):
		return
	if not stead.barn:
		if stead.build("barn"):
			events.append("built the barn")
		else:
			events.append("stuck: barn needs %s" % stead.missing_text(RecipeCatalog.building("barn")["costs"]))
			return
	if stead.count_kind("sheep") + stead.count_kind("goat") < 1:
		if stead.buy_animal("sheep"):
			events.append("bought a sheep")
		else:
			events.append("stuck: sheep needs %d dinars" % (380 - bag.dinars))
			return
	if bag.count_of("feed") < stead.animals.size() and not stead.craft("feed_herbs"):
		stead.buy_feed()
	stead.feed_kind("sheep")

func _open_step(stead: Stead) -> String:
	for step: Dictionary in stead.steps():
		if not bool(step["done"]):
			return str(step["key"])
	return ""

func _visit(loader: LevelLoader, place: String, spawn: String = "PlayerSpawn") -> void:
	loader.go_to(load("res://src/scenes/world/%s.tscn" % place) as PackedScene, spawn)
	for i: int in 3:
		await process_frame

func _place(main: Node) -> Node:
	for child: Node in main.get_node("World").get_children():
		if child.name != "Player":
			return child
	return null

func _snapshot(bag: Inventory, stead: Stead, kindness: Kindness, friends: Friendship) -> Dictionary:
	var done: Dictionary = {}
	for step: Dictionary in stead.steps():
		if bool(step["done"]):
			done[step["key"]] = true
	var hearts: int = 0
	for person: String in Friendship.PEOPLE:
		hearts += friends.hearts(person)
	return {"steps": done, "found": bag.found.duplicate(), "khair": kindness.points, "hearts": hearts, "journal": Journal.found(stead.get_parent()), "places": stead.visited.duplicate(), "met": friends.met_count()}

func _new_things(before: Dictionary, after: Dictionary) -> PackedStringArray:
	var fresh: PackedStringArray = PackedStringArray()
	for key: String in after["steps"]:
		if not before["steps"].has(key):
			fresh.append("quest step " + key)
	for key: String in after["found"]:
		if not before["found"].has(key):
			fresh.append("first " + key)
	for key: String in after["places"]:
		if not before["places"].has(key):
			fresh.append("first visit to " + key)
	if int(after["met"]) > int(before["met"]):
		fresh.append("met %d neighbors" % (int(after["met"]) - int(before["met"])))
	if int(after["hearts"]) > int(before["hearts"]):
		fresh.append("a friendship heart")
	if int(after["journal"]) > int(before["journal"]):
		fresh.append("a journal page")
	return fresh

func _home_marks(main: Node) -> Array[String]:
	var marks: Array[String] = []
	var place: Node = main.get_node("World").get_node_or_null("Home")
	if place == null:
		return marks
	for child: Node in place.get_children():
		var kind: String = str(child.get("group_name"))
		if str(child.name).begins_with("Zone"):
			continue
		if kind == "tree" or kind == "rock":
			marks.append("Home/%s=%s" % [child.name, "wood" if kind == "tree" else "stone"])
	return marks

func _remove_side_files(save: SaveGame) -> void:
	var folder: String = save.path.get_base_dir()
	var stem: String = save.path.get_file().get_basename()
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.begins_with(stem + "."):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file_name)))

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("FAIL %s" % label)
