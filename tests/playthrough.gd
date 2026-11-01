# tests/playthrough.gd
# Purpose: Plays a brand-new farm day by day with an ordinary routine and checks the goal is reachable in fair time.
# Run: KHAIR_SAVE=user://land_of_khair_play.json Godot --headless --path . -s tests/playthrough.gd

extends SceneTree

const MAX_DAYS: int = 70
const KEEP: Array[String] = ["wood", "stone", "forage", "wheat", "copper", "feed"]

var passed: int = 0
var failed: int = 0

func _init() -> void:
	_run()

func _run() -> void:
	var side: String = OS.get_environment("KHAIR_SAVE")
	if side == "" or side.get_file() == "land_of_khair.json":
		print("PLAYTHROUGH refused: set KHAIR_SAVE to a side save so the player's farm is never touched")
		quit(2)
		return
	seed(11)
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
	var inventory: Inventory = systems.get_node("Inventory") as Inventory
	var stead: Stead = systems.get_node("Stead") as Stead
	var activities: Activities = systems.get_node("Activities") as Activities
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	var home_marks: Array[String] = _daily_marks(main)
	var milestones: Dictionary = {}
	var lowest_dinars: int = inventory.dinars
	var start_dinars: int = inventory.dinars
	for day: int in MAX_DAYS:
		_farm_day(main, farm, inventory, clock)
		for mark: String in home_marks:
			activities.take_daily(mark.get_slice("=", 0), mark.get_slice("=", 1))
		activities.fish_at("Home")
		if day >= 2:
			if not stead.visited.get("Harbor", false):
				await _visit(loader, "harbor/Harbor")
				await _visit(loader, "orchard/Orchard")
				await _visit(loader, "home/Home", "VillageReturn")
				home_marks = _daily_marks(main)
			activities.fish_at("Harbor")
			for spot: String in ["DatePalm", "DatePalm2", "DatePalm3"]:
				activities.take_daily("Orchard/" + spot, "dates")
			for spot: String in ["Herb", "Herb2", "Herb3"]:
				activities.take_daily("Orchard/" + spot, "forage")
			activities.take_daily("Cave/Copper", "copper")
		if inventory.turnips > 0:
			activities._sell_to_jassim()
		for item_id: String in Inventory.all_stored_ids():
			if not KEEP.has(item_id) and GoodsCatalog.sell_price(item_id) > 0 and item_id != "turnips":
				inventory.sell_stack(item_id)
		_spend(stead, inventory)
		_feed_all(stead, inventory)
		lowest_dinars = mini(lowest_dinars, inventory.dinars)
		for step: Dictionary in stead.steps():
			if bool(step["done"]) and not milestones.has(step["key"]):
				milestones[step["key"]] = clock.day
		if stead.is_established():
			break
		clock.sleep_now()
		clock.set_process(false)
	var days: int = clock.day
	print("PLAYTHROUGH days=%d dinars=%d lowest=%d steps=%s" % [days, inventory.dinars, lowest_dinars, str(milestones)])
	check(stead.is_established(), "an ordinary routine reaches the farm goal")
	check(days >= 12, "the goal is not trivially fast (%d days)" % days)
	check(days <= 56, "the goal fits in two seasons of play (%d days)" % days)
	check(lowest_dinars >= 0, "dinars never go below zero")
	check(inventory.dinars >= start_dinars, "the farm ends richer than it began")
	check(milestones.get("quest_turnip", 99) <= 6, "the first sale happens in the first week")
	_remove_side_files(save)
	print("PLAYTHROUGH passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _farm_day(main: Node, farm: FarmField, inventory: Inventory, clock: GameClock) -> void:
	var dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
	if dirt == null:
		return
	inventory.selected_seed = CropCatalog.WHEAT if clock.season == "Winter" else CropCatalog.TURNIP
	var crop: Dictionary = CropCatalog.get_crop(inventory.selected_seed)
	var seed_item: String = str(crop.get("seed_item", "seeds"))
	var cells: int = farm.farm_size.x * farm.farm_size.y
	while inventory.count_of(seed_item) < cells and inventory.dinars >= int(crop.get("seed_price", 10)) + 40:
		if not inventory.try_buy_seed(inventory.selected_seed):
			break
	for x: int in farm.farm_size.x:
		for y: int in farm.farm_size.y:
			var cell: Vector2i = farm.farm_origin + Vector2i(x, y)
			for attempt: int in 4:
				var state: String = farm.state_of(cell)
				if state == "watered":
					break
				if state == "tilled" and inventory.count_of(seed_item) == 0:
					break
				farm.work(dirt, cell, false)

func _spend(stead: Stead, inventory: Inventory) -> void:
	if not stead.coop:
		stead.build("coop")
	if stead.coop and stead.count_kind("chicken") == 0:
		stead.buy_animal("chicken")
	if stead.count_kind("chicken") > 0 and not stead.barn:
		stead.build("barn")
	if stead.barn and stead.count_kind("goat") == 0:
		stead.buy_animal("goat")
	if stead.barn and stead.count_kind("goat") > 0 and not stead.expanded:
		stead.build("expand")

func _feed_all(stead: Stead, inventory: Inventory) -> void:
	while inventory.forage >= 2 and inventory.count_of("feed") < stead.animals.size():
		if not stead.craft("feed_herbs"):
			break
	if inventory.count_of("feed") < stead.animals.size():
		stead.craft("feed")
	while inventory.count_of("feed") < stead.animals.size() and inventory.dinars >= RecipeCatalog.FEED_PRICE + 30:
		stead.buy_feed()
	for kind: String in ["chicken", "goat", "sheep", "cow"]:
		stead.feed_kind(kind)

func _visit(loader: LevelLoader, place: String, spawn: String = "PlayerSpawn") -> void:
	loader.go_to(load("res://src/scenes/world/%s.tscn" % place) as PackedScene, spawn)
	for i: int in 3:
		await process_frame

func _daily_marks(main: Node) -> Array[String]:
	var marks: Array[String] = []
	var place: Node = null
	for child: Node in main.get_node("World").get_children():
		if child.name != "Player":
			place = child
			break
	if place == null or place.name != "Home":
		return marks
	for child: Node in place.get_children():
		var kind: String = str(child.get("group_name"))
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
