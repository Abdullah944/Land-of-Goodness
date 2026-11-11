# tests/playthrough.gd
# Purpose: Plays a brand-new farm day by day with an ordinary routine and checks the goal is reachable in fair time.
# Run: KHAIR_SAVE=user://land_of_khair_play.json Godot --headless --path . -s tests/playthrough.gd

extends SceneTree

const MAX_DAYS: int = 200
## Building goods the routine never sells, and how much it keeps of the goods that make feed.
const KEEP: Array[String] = ["wood", "stone", "copper", "feed"]
const KEEP_SOME: Dictionary = {"forage": 12, "wheat": 12}
## A day is about fourteen real minutes, and the boy also walks, talks and fishes: this many tool swings fit.
## KHAIR_SWINGS and KHAIR_MEALS try another player, such as one who never eats.
var swings_a_day: int = 150
## An ordinary player stops to eat a few times a day, not after every row.
var meals_a_day: int = 3
## Dinars the routine keeps back when it shops, so the next morning is never empty-handed.
const POCKET: int = 40

var passed: int = 0
var failed: int = 0
var _swings: int = 0
var _meals: int = 0
var _income: Dictionary = {}
var _today: Dictionary = {}

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
	activities.quick_fish = true
	systems.get_node("Letters").set_process(false)
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	var home_marks: Array[String] = _daily_marks(main)
	var milestones: Dictionary = {}
	var lowest_dinars: int = inventory.dinars
	var start_dinars: int = inventory.dinars
	var works: VillageWorks = systems.get_node("VillageWorks") as VillageWorks
	var kindness: Kindness = systems.get_node("Kindness") as Kindness
	var established_day: int = 0
	var project_days: Dictionary = {}
	## Nights in the first six weeks when bedtime had only the weather to tell, and caravan days seen.
	var plain_nights: int = 0
	var caravans: int = 0
	var log_days: bool = OS.get_environment("KHAIR_LOG") != ""
	var steady: bool = OS.get_environment("KHAIR_SWINGS") == "" and OS.get_environment("KHAIR_MEALS") == ""
	if not steady:
		swings_a_day = int(OS.get_environment("KHAIR_SWINGS")) if OS.get_environment("KHAIR_SWINGS") != "" else swings_a_day
		meals_a_day = int(OS.get_environment("KHAIR_MEALS")) if OS.get_environment("KHAIR_MEALS") != "" else meals_a_day
	for day: int in MAX_DAYS:
		_swings = 0
		_meals = 0
		_today = {}
		var morning: int = inventory.dinars
		_tend(main, farm, inventory, clock)
		for mark: String in home_marks:
			if _swing(inventory):
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
			if _swing(inventory):
				activities.take_daily("Cave/Copper", "copper")
		_plant_more(main, farm, inventory, clock, stead)
		var before_sale: int = inventory.dinars
		if inventory.turnips > 0:
			activities._sell_to_jassim()
			_note_income("turnips", inventory.dinars - before_sale)
		for item_id: String in Inventory.all_stored_ids():
			var spare: int = _spare(item_id, inventory, works)
			if spare < 1 or GoodsCatalog.sell_price(item_id) < 1 or item_id == "turnips":
				continue
			var held: int = inventory.count_of(item_id) - spare
			_note_income(item_id, inventory.sell_stack(item_id) * spare / (spare + held))
			inventory.dinars -= GoodsCatalog.sell_price(item_id) * held
			inventory.add_item(item_id, held)
		var sold: int = inventory.dinars - before_sale
		_spend(stead, inventory)
		_feed_all(stead, inventory)
		_be_kind(kindness, works, inventory, stead)
		if stead.is_established():
			_buy_upgrades(stead, inventory, works)
			while works.fund_next():
				project_days[str(works.done.keys()[works.done.size() - 1])] = clock.day
		lowest_dinars = mini(lowest_dinars, inventory.dinars)
		if log_days and (clock.day % 7 == 0 or clock.day <= 16):
			print("DAY %d %s sold=%d dinars=%d khair=%d swings=%d meals=%d wood=%d stone=%d animals=%d tools=%d next=%s net=%d %s" % [clock.day, clock.season, sold, inventory.dinars, kindness.points, _swings, _meals, inventory.count_of("wood"), inventory.count_of("stone"), stead.animals.size(), stead.tool_level, str(works.next_project().get("id", "-")), inventory.dinars - morning, str(_today)])
		for step: Dictionary in stead.steps():
			if bool(step["done"]) and not milestones.has(step["key"]):
				milestones[step["key"]] = clock.day
		if stead.is_established() and established_day == 0:
			established_day = clock.day
		if clock.day <= 42:
			if clock.next_weather == "Clear" and Tomorrow.line(systems) == clock.forecast_text():
				plain_nights += 1
			if (systems.get_node("Festivals") as Festivals).caravan_open():
				caravans += 1
		if works.festival_ready():
			break
		clock.sleep_now()
		clock.set_process(false)
	var days: int = established_day
	print("PLAYTHROUGH days=%d dinars=%d lowest=%d steps=%s" % [days, inventory.dinars, lowest_dinars, str(milestones)])
	print("PLAYTHROUGH festival_day=%d khair=%d projects=%s upgrades=%s" % [clock.day, kindness.points, str(project_days), str(stead.flags.keys())])
	print("PLAYTHROUGH income=%s" % str(_income))
	print("PLAYTHROUGH plain_nights=%d caravans=%d" % [plain_nights, caravans])
	check(plain_nights <= 4, "in the first six weeks bedtime nearly always names something to come back for (%d plain nights)" % plain_nights)
	check(caravans >= 5 or not steady, "the caravan comes every week (%d seen)" % caravans)
	check(stead.is_established(), "an ordinary routine reaches the farm goal")
	check(days >= 9, "the farm goal takes longer than the first week (%d days)" % days)
	check(days <= 56, "the goal fits in two seasons of play (%d days)" % days)
	check(lowest_dinars >= 0, "dinars never go below zero")
	check(inventory.dinars >= start_dinars, "the farm ends richer than it began")
	check(milestones.get("quest_turnip", 99) <= 6, "the first sale happens in the first week")
	check(works.festival_ready(), "an ordinary routine reaches the festival")
	check(clock.day >= 35, "the story is not over too soon (%d days)" % clock.day)
	check(clock.day <= 112, "the story ends within four in-game years (%d days)" % clock.day)
	if steady:
		check(clock.day <= 49, "a steady player sees the festival in about six weeks (%d days)" % clock.day)
	var all_income: int = 0
	var top: String = ""
	for item_id: String in _income:
		all_income += int(_income[item_id])
		if top == "" or int(_income[item_id]) > int(_income[top]):
			top = item_id
	var share: int = int(_income.get(top, 0)) * 100 / maxi(1, all_income)
	check(share <= 60, "no single good brings most of the dinars (%s %d%%)" % [top, share])
	var last_cost: int = int(VillageWorks.PROJECTS[VillageWorks.PROJECTS.size() - 1]["costs"]["dinars"])
	check(inventory.dinars <= last_cost or not steady, "dinars still matter at the end: the purse is under the last project's price (%d)" % inventory.dinars)
	clock.sleep_now()
	clock.set_process(false)
	for i: int in 4:
		await process_frame
	var ending: EndingScreen = main.get_node("UI/Ending") as EndingScreen
	check(ending.is_playing() and main.get_node("World").get_node_or_null("Village") != null, "sleeping starts the festival in the village")
	var pages: int = ending.page_count()
	var friends_at_end: Friendship = main.get_node("Systems/Friendship") as Friendship
	var told_line: bool = false
	for person: String in Friendship.STORIES.keys():
		var key: String = "end_%s_story" % person if friends_at_end.story_done(person) else "end_%s" % person
		told_line = ending._pages.has(Locale.t(key))
		if not told_line:
			break
	check(pages == 11 and told_line, "the festival gives each neighbor a moment, and a finished story changes what they say")
	for page: int in pages + 1:
		ending.advance()
	check(not ending.is_playing() and works.finished, "the festival closes and the story is marked finished")
	check(stead.goal_text() == stead.after_text() and stead.goal_text() != "", "the farm stays open after the ending, and the line names what is still open")
	check(save.load_game() and works.finished, "the finished story survives a reload")
	clock.sleep_now()
	clock.set_process(false)
	await process_frame
	check(not ending.is_playing(), "the festival plays only once")
	_remove_side_files(save)
	print("PLAYTHROUGH passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

## One tool swing. It tires the boy like in the game; when he is worn out he eats, a few times a day at most.
func _swing(inventory: Inventory) -> bool:
	if _swings >= swings_a_day:
		return false
	if not inventory.tire():
		if _meals >= meals_a_day or not _eat(inventory):
			return false
		_meals += 1
		if not inventory.tire():
			return false
	_swings += 1
	return true

## The boy eats the cheapest food he can spare. What a village project still needs stays in the chest.
func _eat(inventory: Inventory) -> bool:
	var works: VillageWorks = inventory.get_parent().get_node("VillageWorks") as VillageWorks
	var choice: String = ""
	for item_id: String in Kindness.FOODS:
		if _spare(item_id, inventory, works) < 1:
			continue
		if choice == "" or GoodsCatalog.sell_price(item_id) < GoodsCatalog.sell_price(choice):
			choice = item_id
	if choice == "" or not inventory.take_item(choice, 1):
		return false
	inventory.hearts = minf(inventory.max_hearts, inventory.hearts + 1.0)
	return true

## How many of an item the routine can sell, eat or give away without touching what it is saving.
func _spare(item_id: String, inventory: Inventory, works: VillageWorks) -> int:
	if KEEP.has(item_id):
		return 0
	var saved: int = int(KEEP_SOME.get(item_id, 0))
	for project: Dictionary in VillageWorks.PROJECTS:
		if not works.is_done(str(project["id"])):
			saved = maxi(saved, int(project["costs"].get(item_id, 0)))
	return maxi(0, inventory.count_of(item_id) - saved)

func _note_income(item_id: String, dinars: int) -> void:
	_income[item_id] = int(_income.get(item_id, 0)) + dinars
	_today[item_id] = int(_today.get(item_id, 0)) + dinars

func _cells(farm: FarmField) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in farm.farm_size.y:
		for x: int in farm.farm_size.x:
			cells.append(farm.farm_origin + Vector2i(x, y))
	return cells

## Morning chores: pick what is ripe, then water what is growing.
func _tend(main: Node, farm: FarmField, inventory: Inventory, clock: GameClock) -> void:
	var dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
	if dirt == null:
		return
	for cell: Vector2i in _cells(farm):
		if farm.state_of(cell) == "ready" and _swing(inventory):
			farm.work(dirt, cell, false)
	for cell: Vector2i in _cells(farm):
		var state: String = farm.state_of(cell)
		if (state == "planted" or state == "growing") and _in_season(farm, cell, clock) and _swing(inventory):
			farm.work(dirt, cell, true)

## A plant out of its season does not grow, so the boy leaves it alone.
func _in_season(farm: FarmField, cell: Vector2i, clock: GameClock) -> bool:
	var plot: Dictionary = farm.plots.get(farm._key(cell), {})
	return CropCatalog.get_crop(str(plot.get("crop", ""))).get("seasons", []).has(clock.season)

## The crop an ordinary player grows: turnips in the first week, as the story teaches, then what suits the season.
func _crop_for(clock: GameClock) -> String:
	if clock.day <= 7 and clock.season != "Winter":
		return CropCatalog.TURNIP
	if clock.season == "Spring" or clock.season == "Summer":
		return CropCatalog.TOMATO
	return CropCatalog.WHEAT

## With the swings that are left, plant new squares, but never more than the boy can water tomorrow.
func _plant_more(main: Node, farm: FarmField, inventory: Inventory, clock: GameClock, stead: Stead) -> void:
	var dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
	if dirt == null:
		return
	inventory.selected_seed = _crop_for(clock)
	var crop: Dictionary = CropCatalog.get_crop(inventory.selected_seed)
	var seed_item: String = str(crop.get("seed_item", "seeds"))
	var reach: int = [1, 3, 5][clampi(stead.tool_level, 0, 2)]
	var most: int = int(inventory.max_hearts * 10.0 * 0.7) * reach
	var growing: int = 0
	for cell: Vector2i in _cells(farm):
		if farm.state_of(cell) in ["planted", "growing", "watered", "ready"] and _in_season(farm, cell, clock):
			growing += 1
	for cell: Vector2i in _cells(farm):
		if growing >= most:
			break
		var state: String = farm.state_of(cell)
		if state != "empty" and state != "tilled":
			continue
		if inventory.count_of(seed_item) == 0 and (inventory.dinars < int(crop.get("seed_price", 10)) + POCKET or not inventory.try_buy_seed(inventory.selected_seed)):
			break
		if state == "empty":
			if not _swing(inventory):
				break
			farm.work(dirt, cell, false)
		if not _swing(inventory):
			break
		farm.work(dirt, cell, false)
		growing += 1
		if farm.state_of(cell) == "planted" and _swing(inventory):
			farm.work(dirt, cell, true)

func _spend(stead: Stead, inventory: Inventory) -> void:
	if not stead.coop:
		stead.build("coop")
	if stead.coop and stead.count_kind("chicken") == 0:
		stead.buy_animal("chicken")
	if stead.count_kind("chicken") > 0 and not stead.is_built("tools"):
		stead.build("tools")
	if stead.count_kind("chicken") > 0 and not stead.barn:
		_buy_missing(stead, inventory, "barn")
		stead.build("barn")
	if stead.barn and stead.count_kind("goat") == 0:
		stead.buy_animal("goat")
	if stead.barn and stead.count_kind("goat") > 0 and not stead.expanded:
		stead.build("expand")

## The carpenter sells wood and stone, and a player with spare dinars buys what a building still lacks.
func _buy_missing(stead: Stead, inventory: Inventory, building_id: String) -> void:
	var costs: Dictionary = RecipeCatalog.building(building_id).get("costs", {})
	for item_id: String in ["wood", "stone"]:
		while inventory.count_of(item_id) < int(costs.get(item_id, 0)) and inventory.dinars >= RecipeCatalog.BUNDLE_PRICE + POCKET + 100:
			stead.buy_bundle(item_id)

## The player walks past three neighbors most days, and answers a request when the bag allows.
func _be_kind(kindness: Kindness, works: VillageWorks, inventory: Inventory, stead: Stead) -> void:
	for person: String in ["jassim", "elder", "merchant"]:
		for item_id: String in Kindness.FOODS:
			if _spare(item_id, inventory, works) > 0 and kindness.give_food(person, item_id):
				break
	if inventory.dinars >= 60:
		kindness.give_fund()
	var wish: Dictionary = works.request_today()
	if _spare(str(wish["item"]), inventory, works) >= int(wish["amount"]):
		works.fulfil_request()

func _buy_upgrades(stead: Stead, inventory: Inventory, works: VillageWorks) -> void:
	var project: Dictionary = works.next_project()
	if project.is_empty():
		return
	var costs: Dictionary = project["costs"]
	for item_id: String in ["wood", "stone"]:
		while inventory.count_of(item_id) < int(costs.get(item_id, 0)) and inventory.dinars >= int(costs.get("dinars", 0)) + RecipeCatalog.BUNDLE_PRICE:
			stead.buy_bundle(item_id)
	var spare: int = inventory.dinars - int(costs.get("dinars", 0))
	if spare > 400:
		for building_id: String in ["house", "expand2", "tools", "coop2", "barn2", "tools2"]:
			if stead.can_offer(building_id) and stead.build(building_id):
				break
	if spare > 700 and stead.count_kind("sheep") == 0:
		stead.buy_animal("sheep")

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
