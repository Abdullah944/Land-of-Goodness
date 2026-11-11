# tests/core_loop.gd
# Purpose: Checks the economy, animals, crafting, travel, and old-save rules.

extends SceneTree

var passed: int = 0
var failed: int = 0

func _init() -> void:
	_run()

func _run() -> void:
	if OS.get_environment("KHAIR_SAVE") == "" or OS.get_environment("KHAIR_SAVE").get_file() == "land_of_khair.json":
		print("CORE_TEST refused: set KHAIR_SAVE to a side save so the player's farm is never touched")
		quit(2)
		return
	TitleMenu.dismissed = true
	change_scene_to_file("res://src/scenes/world/main/MainGame.tscn")
	await process_frame
	await process_frame
	var main: Node = current_scene
	var systems: Node = main.get_node("Systems")
	var clock: GameClock = systems.get_node("Clock") as GameClock
	clock.set_process(false)
	var save: SaveGame = systems.get_node("SaveGame") as SaveGame
	var inventory: Inventory = systems.get_node("Inventory") as Inventory
	var stead: Stead = systems.get_node("Stead") as Stead
	var activities: Activities = systems.get_node("Activities") as Activities
	activities.quick_fish = true
	systems.get_node("Letters").set_process(false)
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var chest: ChestStore = systems.get_node("ChestStore") as ChestStore
	var old_file: FileAccess = FileAccess.open(save.path, FileAccess.WRITE)
	old_file.store_string(JSON.stringify({
		"plots": [],
		"bag": {"seeds": 3, "dinars": 40, "turnips": 2},
		"clock": {"day": 4, "minute": 400, "season": "Spring", "weather": "Clear"},
		"activities": {"quest_done": true, "fish_day": 4, "gathered": {}},
	}))
	old_file.close()
	check(save.load_game(), "old save loads")
	check(inventory.seeds == 3 and inventory.turnips == 2 and inventory.dinars == 40, "old bag stays")
	check(inventory.tomato_seeds == 4, "missing crop keys still get starters")
	check(stead.animals.is_empty() and not stead.coop, "old save has no animals")
	check(activities.quest_done, "old quest stays done")
	check(not activities.fish_at("Home"), "old fish day still blocks the farm spot")
	check(activities.fish_at("Harbor"), "harbor fish is a separate daily spot")
	var harbor_catch: int = inventory.count_of("fish")
	for kind: String in FishCatalog.kinds():
		harbor_catch += inventory.count_of(kind)
		inventory.take_item(kind, inventory.count_of(kind))
	check(harbor_catch == 1, "one gulf fish was added")
	inventory.add_item("fish", 2 - inventory.count_of("fish"))
	var before: int = inventory.dinars
	var earned: int = inventory.sell_stack("fish")
	check(earned == 60 and inventory.dinars == before + 60 and inventory.count_of("fish") == 0, "fish sells once")
	check(inventory.sell_stack("fish") == 0 and inventory.dinars == before + 60, "empty stack does not pay")
	inventory.wheat = 1
	inventory.forage = 1
	check(stead.craft("feed") and inventory.count_of("feed") == 3, "feed crafts from wheat and herb")
	check(inventory.wheat == 0 and inventory.forage == 0, "craft spends both ingredients")
	check(not stead.craft("feed"), "craft fails when ingredients are missing")
	check(not stead.build("coop"), "coop needs wood and stone")
	inventory.wood = 12
	inventory.stone = 6
	check(stead.build("coop") and stead.coop and inventory.wood == 0 and inventory.stone == 0, "coop spends its cost once")
	check(not stead.build("coop"), "coop cannot be built twice")
	check(not stead.buy_animal("chicken"), "chicken needs dinars")
	inventory.dinars = 180
	check(stead.buy_animal("chicken") and stead.count_kind("chicken") == 1 and inventory.dinars == 0, "one chicken is bought")
	inventory.take_item("feed", inventory.count_of("feed"))
	check(stead.feed_kind("chicken") == 0, "feeding needs feed")
	inventory.add_item("feed", 1)
	check(stead.feed_kind("chicken") == 1 and inventory.count_of("feed") == 0, "one feed fills one chicken")
	clock.sleep_now()
	clock.set_process(false)
	check(inventory.count_of("eggs") == 1 and not bool(stead.animals[0]["fed"]), "a fed chicken lays one egg")
	var eggs: int = inventory.count_of("eggs")
	clock.sleep_now()
	clock.set_process(false)
	check(inventory.count_of("eggs") == eggs, "a hungry chicken does not lay")
	check(chest.store_one(inventory, "eggs") and chest.count_of("eggs") == 1 and inventory.count_of("eggs") == eggs - 1, "an egg stores in the chest")
	check(chest.take_one(inventory, "eggs") and inventory.count_of("eggs") == eggs, "the egg comes back")
	inventory.wood = 20
	inventory.stone = 12
	check(stead.build("barn") and stead.barn, "barn follows the coop")
	inventory.dinars = 420
	check(stead.buy_animal("goat"), "a goat needs the barn")
	inventory.add_item("feed", 1)
	check(stead.feed_kind("goat") == 1, "the goat eats")
	clock.sleep_now()
	clock.set_process(false)
	check(inventory.count_of("milk") == 1, "the goat gives milk")
	inventory.wood = 8
	inventory.stone = 8
	inventory.dinars = 100
	var old_size: Vector2i = farm.farm_size
	check(stead.build("expand") and farm.farm_size == FarmField.LARGER_SIZE and old_size == Vector2i(24, 14), "the field grows larger")
	inventory.add_item("copper", 3)
	inventory.dinars = 120
	check(stead.build("tools") and stead.tool_level == 1, "copper upgrades the watering can")
	farm.plots["-11,-4"] = {"tilled": true, "stage": 0, "watered": false, "crop": "turnip"}
	farm.plots["-10,-4"] = {"tilled": true, "stage": 0, "watered": false, "crop": "turnip"}
	var dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
	farm.work(dirt, Vector2i(-11, -4), true)
	check(bool(farm.plots["-11,-4"]["watered"]) and bool(farm.plots["-10,-4"]["watered"]), "the upgrade waters a neighbor")
	var far: Vector2i = farm.farm_origin + farm.farm_size - Vector2i.ONE
	check(farm.tool_for_plot(far) == "hoe" and farm.tool_for_plot(farm.farm_origin - Vector2i.ONE) == "", "any square of the farm land can be hoed, and none outside it")
	farm.work(dirt, far, false)
	check(farm.state_of(far) == "tilled" and farm.clear_soil(dirt, far) and farm.state_of(far) == "empty", "the pickaxe turns an empty bed back to grass")
	_check_sprinkler(farm, dirt, inventory, stead)
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "PlayerSpawn")
	await process_frame
	await process_frame
	await process_frame
	check(_place_name(main) == "Village" and stead.place_name == "Village", "the village opens")
	check(_buildings_open(main) and _pictures_fit(main, "Village"), "every village building has a way inside")
	var well: Vector2 = Vector2(10, -40)
	var ring: Array[float] = []
	for stall: String in ["Stall", "StallProduce", "StallPots", "StallFar", "StallFar2", "Counter", "ShelfSeeds"]:
		ring.append((_place(main).get_node(stall) as Node2D).position.distance_to(well))
	check(ring.max() - ring.min() < 2.0 and WorldShapes.on_cobble("Village", well + Vector2(0, 140)), "the market stalls stand in a ring around the well, on a round stone square")
	var shop_box: DialogueBox = main.get_node("UI/Dialogue") as DialogueBox
	activities.talk_role("merchant")
	activities._on_shop_choice("buy_seeds")
	var pictured: bool = not shop_box._offer_buttons.is_empty()
	for button: Button in shop_box._offer_buttons:
		pictured = pictured and button.icon != null
	check(shop_box._panel.size.x <= 330.0 and shop_box._panel.size.y < 150.0 and pictured and shop_box._close.visible, "the seller's window is small, each seed has a picture, and X closes it")
	shop_box._pick("cancel")
	var mosque: Node2D = _place(main).get_node("Mosque") as Node2D
	var walls: CollisionShape2D = mosque.get_node("Block").get_child(0) as CollisionShape2D
	check((walls.shape as RectangleShape2D).size.y > 60.0, "a building is solid across its walls, not just its base")
	check(str(mosque.get("sign_key")) == "sign_mosque" and str(_place(main).get_node("Stall").get("sign_key")) == "sign_market", "the mosque and the market carry name boards")
	_check_friends(main)
	_check_stories(main.get_node("Systems"))
	_check_first_steps(main)
	await _check_feel(main)
	_check_ending_pages(main)
	_check_hooks(main)
	await _check_cave(main)
	await _check_book(main)
	loader.go_to(load("res://src/scenes/world/harbor/Harbor.tscn") as PackedScene, "PlayerSpawn")
	await process_frame
	await process_frame
	await process_frame
	check(_place_name(main) == "Harbor" and bool(stead.visited.get("Harbor", false)), "the harbor opens")
	check(_pictures_fit(main, "Harbor") and _place(main).find_children("Hut*", "", false).is_empty(), "the harbor keeps no empty houses, only boats and the fish stall")
	loader.go_to(load("res://src/scenes/world/orchard/Orchard.tscn") as PackedScene, "PlayerSpawn")
	await process_frame
	await process_frame
	await process_frame
	var palm: Node2D = _place(main).get_node("DatePalm") as Node2D
	var dates_before: int = inventory.count_of("dates")
	check(activities.gather_node(palm), "the orchard palm gives a date")
	check(not activities.gather_node(palm) and inventory.count_of("dates") == dates_before + 1, "the same palm waits until morning")
	check(stead.is_established(), "the main farm goal can be reached")
	var saved_dinars: int = inventory.dinars
	save.write_now()
	inventory.dinars += 25
	check(save.load_game() and inventory.dinars == saved_dinars, "reload restores dinars")
	check(stead.coop and stead.barn and stead.count_kind("chicken") == 1, "reload keeps buildings and animals")
	check(bool(stead.flags.get("celebrated", false)), "the farm milestone was celebrated")
	var after_party: int = inventory.dinars
	check(not stead.check_milestone() and inventory.dinars == after_party, "the milestone pays only once")
	inventory.take_item("feed", inventory.count_of("feed"))
	inventory.forage = 2
	check(stead.craft("feed_herbs") and inventory.count_of("feed") == 2 and inventory.forage == 0, "herbs alone make feed")
	inventory.dinars = RecipeCatalog.FEED_PRICE
	check(stead.buy_feed() and inventory.count_of("feed") == 3 and inventory.dinars == 0, "the merchant sells one feed")
	check(not stead.buy_feed() and inventory.count_of("feed") == 3, "feed cannot be bought without dinars")
	await _check_places(main, loader, clock)
	_check_kindness(main, systems, inventory, clock, save, activities)
	await _check_finish(main, systems, inventory, stead, clock, save, activities, farm, loader)
	_check_save_safety(save, inventory)
	if OS.get_environment("KHAIR_SHOT") == "1":
		loader.go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "VillageReturn")
		await process_frame
		await process_frame
		await process_frame
		await _shot("/tmp/khair-farm.png")
		loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "PlayerSpawn")
		await process_frame
		await process_frame
		await process_frame
		await _shot("/tmp/khair-village.png")
		for place: String in ["harbor", "orchard"]:
			loader.go_to(load("res://src/scenes/world/%s/%s.tscn" % [place, place.capitalize()]) as PackedScene, "PlayerSpawn")
			for i: int in 4:
				await process_frame
			await _shot("/tmp/khair-%s.png" % place)
		loader.go_to(load("res://src/scenes/world/cave/Cave.tscn") as PackedScene, "PlayerSpawn")
		for i: int in 4:
			await process_frame
		await _shot("/tmp/khair-cave.png")
	_remove_side_files(save)
	print("CORE_TEST passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

## A crafted sprinkler is set on a hoed square, waters the eight around it each morning, and comes back with the pickaxe.
## Tomatoes fruit again after a harvest.
func _check_sprinkler(farm: FarmField, dirt: TileMapLayer, inventory: Inventory, stead: Stead) -> void:
	inventory.add_item("copper", 2)
	inventory.add_item("stone", 4)
	check(stead.craft("sprinkler") and inventory.count_of("sprinkler") == 1, "copper and stone make a sprinkler")
	var middle: Vector2i = farm.farm_origin + Vector2i(4, 4)
	var keep_seed: String = inventory.selected_seed
	farm.plots[farm._key(middle)] = {"tilled": true, "stage": -1, "watered": false, "crop": "", "sprinkler": false}
	inventory.selected_seed = FarmField.SPRINKLER
	farm.work(dirt, middle, false)
	check(farm.state_of(middle) == FarmField.SPRINKLER and inventory.count_of("sprinkler") == 0, "the sprinkler is set on a hoed square")
	var corner: Vector2i = middle + Vector2i(1, 1)
	var outside: Vector2i = middle + Vector2i(2, 0)
	farm.plots[farm._key(corner)] = {"tilled": true, "stage": 0, "watered": false, "crop": "turnip", "sprinkler": false}
	farm.plots[farm._key(outside)] = {"tilled": true, "stage": 0, "watered": false, "crop": "turnip", "sprinkler": false}
	farm.advance_day("Spring", false)
	check(bool(farm.plots[farm._key(corner)]["watered"]) and not bool(farm.plots[farm._key(outside)]["watered"]), "each morning the sprinkler waters the eight squares around it only")
	var rows: Array = farm.export_plots()
	farm.import_plots(rows)
	check(farm.state_of(middle) == FarmField.SPRINKLER, "a sprinkler stays after save and load")
	check(farm.tool_for_plot(middle) == "pick" and farm.clear_soil(dirt, middle) and inventory.count_of("sprinkler") == 1 and farm.state_of(middle) == "tilled", "the pickaxe lifts the sprinkler back into the bag")
	inventory.selected_seed = keep_seed
	var tomato: Dictionary = {"tilled": true, "stage": 3, "watered": false, "crop": "tomato", "sprinkler": false}
	farm.plots[farm._key(corner)] = tomato
	var before: int = inventory.count_of("tomatoes")
	farm.work(dirt, corner, false)
	check(inventory.count_of("tomatoes") == before + 1 and farm.state_of(corner) != "tilled" and str(farm.plots[farm._key(corner)]["crop"]) == "tomato", "a tomato plant stays after its harvest and fruits again")
	farm.plots[farm._key(outside)] = {"tilled": true, "stage": 2, "watered": true, "crop": "turnip", "sprinkler": false}
	check(int(farm.ripe_tomorrow("Spring", false).get("turnips", 0)) == 1 and farm.ripe_tomorrow("Winter", false).is_empty(), "bedtime knows which crops ripen tomorrow")
	var line: String = Tomorrow.line(farm.get_parent())
	check(line != "", "bedtime always has a line about tomorrow")
	farm.plots[farm._key(outside)] = {"tilled": true, "stage": 3, "watered": false, "crop": "turnip", "sprinkler": false}
	check(farm.has_ripe(), "the farm knows when something is ready to pick")
	_check_notices(farm.get_parent())
	for key: Vector2i in [middle, corner, outside]:
		farm.plots.erase(farm._key(key))
	farm.apply()
	var systems: Node = farm.get_parent()
	var count: int = Journal.found(systems)
	var read: PackedStringArray = Journal.read_lines(systems)
	check(read.size() == count + (1 if count < Journal.PAGE_COUNT else 0), "the journal lists each found page and who has the next")
	check(Journal.chapter_lines("well").size() == 3 and Journal.chapter_lines("diwaniya").size() == 2 and Journal.chapter_lines("well")[1] == Locale.t("page_2"), "each finished project gives a page and starts the next chapter")
	check(_locale_is_whole(), "every page and chapter line has English and Arabic")

## The phone note: only when something is true, never sooner than the overnight wait, only from 8 AM to 9 PM, and one a day.
func _check_notices(systems: Node) -> void:
	var now: float = Time.get_unix_time_from_system()
	var plan: Dictionary = PhoneNotices.plan_for(systems, now, 0.0)
	check(not plan.is_empty() and str(plan["text"]) == Locale.t("notice_ripe") % Locale.item("turnips"), "a ripe crop makes the phone note")
	var due: float = now + float(plan.get("delay", 0))
	var hour: int = int(Time.get_datetime_dict_from_unix_time(int(due + PhoneNotices._zone_seconds()))["hour"])
	check(float(plan.get("delay", 0)) >= SaveGame.AWAY_NIGHT - 1.0 and hour >= 8 and hour < 21, "the phone note waits for the night away and comes only in the day")
	var again: Dictionary = PhoneNotices.plan_for(systems, now, due)
	check(PhoneNotices._day_of(now + float(again["delay"])) != PhoneNotices._day_of(due), "never two phone notes on the same day")
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var keep: Dictionary = farm.plots.duplicate(true)
	farm.plots.clear()
	var fairs: Festivals = systems.get_node("Festivals") as Festivals
	var friends: Friendship = systems.get_node("Friendship") as Friendship
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var quiet: bool = fairs.tomorrow().is_empty() and friends.birthday_on(clock.day + 1, GameClock.SEASONS[int(float(clock.day + 1) / 7.0) % 4]) == ""
	check(not quiet or PhoneNotices.plan_for(systems, now, 0.0).is_empty(), "no phone note when there is nothing true to say")
	farm.plots = keep
	check(systems.get_node_or_null("PhoneNotices") != null and systems.get_node("PhoneNotices")._scheduler == null, "on a computer the phone notes stay quiet")

func _check_places(main: Node, loader: LevelLoader, clock: GameClock) -> void:
	var places: Dictionary = {
		"Village": ["Elder", "Merchant"],
		"Harbor": ["Fisherman"],
		"Orchard": [],
		"Cave": [],
		"Road": [],
		"Forest": [],
	}
	for place_name: String in places:
		var path: String = "res://src/scenes/world/%s/%s.tscn" % [place_name.to_lower(), place_name]
		clock.minute = 6.5 * 60.0
		loader.go_to(load(path) as PackedScene, "PlayerSpawn")
		for i: int in 3:
			await process_frame
		var place: Node = _place(main)
		check(place != null and place.name == place_name and place.get_node_or_null("Bounds/Walls") != null, "%s has walls at its edges" % place_name)
		var exits: int = 0
		for child: Node in place.get_children():
			if str(child.name).begins_with("Exit"):
				exits += 1
		check(exits > 0, "%s has a way out" % place_name)
		var starts: Dictionary = {}
		for person_name: String in places[place_name]:
			var person: Node2D = place.get_node(person_name) as Node2D
			var morning: Vector2 = person.get_node("Route").get("spots")[0]
			check(person.position.distance_to(morning) < 1.0, "%s starts the day at the first spot" % person_name)
			starts[person_name] = person.position
		clock.minute = 12.5 * 60.0
		for i: int in 10:
			await process_frame
		for person_name: String in starts:
			check((place.get_node(person_name) as Node2D).position != starts[person_name], "%s walks when the hour changes" % person_name)
		clock.minute = 6.5 * 60.0

func _check_kindness(main: Node, systems: Node, inventory: Inventory, clock: GameClock, save: SaveGame, activities: Activities) -> void:
	var kindness: Kindness = systems.get_node("Kindness") as Kindness
	kindness.from_data({})
	check(kindness.points == 0 and kindness.levels_paid == 0, "a save without a meter starts at zero")
	inventory.dates = 2
	check(kindness.give_food("elder", "dates") and inventory.dates == 1 and kindness.points == 2, "a gift spends one food and earns Khair")
	check(not kindness.give_food("elder", "dates") and inventory.dates == 1 and kindness.points == 2, "one gift per person each day")
	check(kindness.give_food("fisherman", "dates") and kindness.points == 4, "another neighbor can receive a gift")
	inventory.stone = 3
	check(not kindness.give_food("merchant", "stone") and inventory.stone == 3, "only food and real gifts can be given")
	check(not kindness.give_food("merchant", "dates") and kindness.points == 4, "a gift needs food in the bag")
	inventory.dinars = Kindness.FUND_PRICE - 1
	check(not kindness.give_fund() and inventory.dinars == Kindness.FUND_PRICE - 1, "giving needs enough dinars")
	inventory.dinars = Kindness.FUND_PRICE
	check(kindness.give_fund() and inventory.dinars == 0 and kindness.points == 7, "giving spends dinars and earns Khair")
	inventory.dinars = Kindness.FUND_PRICE
	check(not kindness.give_fund() and inventory.dinars == Kindness.FUND_PRICE, "one village gift each day")
	kindness.note_feeding()
	kindness.note_feeding()
	check(kindness.points == 8, "feeding counts once each day")
	save.write_now()
	kindness.points = 0
	check(save.load_game() and kindness.points == 8 and kindness.gifted_today("elder") and kindness.fund_done, "the meter survives a reload")
	var before_sleep: int = kindness.points
	clock.sleep_now()
	clock.set_process(false)
	check(kindness.points == before_sleep, "the meter never falls overnight")
	check(not kindness.gifted_today("elder") and not kindness.fund_done and not kindness.fed_done, "gifts open again in the morning")
	var seeds_before: int = inventory.seeds
	kindness.points = 9
	kindness.note_feeding()
	check(kindness.levels_paid == 1 and inventory.seeds == seeds_before + 3, "a new level brings a gift of seeds")
	check(kindness.take_level_up() and not kindness.take_level_up(), "the level note shows once")
	kindness.on_new_day()
	kindness.note_feeding()
	check(inventory.seeds == seeds_before + 3, "a level pays only once")
	kindness.points = 99
	kindness.levels_paid = 3
	inventory.dinars = Kindness.FUND_PRICE
	check(kindness.give_fund() and kindness.points == Kindness.MAX_POINTS and kindness.levels_paid == 4, "the meter stops at its full mark")
	kindness.from_data({"points": -9, "levels_paid": 99, "gifted": "x"})
	check(kindness.points == 0 and kindness.levels_paid == Kindness.LEVELS.size() and kindness.gifted.is_empty(), "broken meter values load safely")
	kindness.from_data({})
	var dialogue: DialogueBox = main.get_node("UI/Dialogue") as DialogueBox
	var ids: PackedStringArray = PackedStringArray()
	for i: int in 17:
		ids.append("%d|Row %d" % [i, i])
	ids.append("cancel|Cancel")
	dialogue.offer("Long list", ids)
	var seen: Dictionary = {}
	var fits: bool = true
	var cancel_always: bool = true
	for page: int in 6:
		fits = fits and dialogue._panel.position.y >= 0.0 and dialogue._offer_buttons.size() <= DialogueBox.MAX_ROWS
		for button: Button in dialogue._offer_buttons:
			seen[button.text] = true
		cancel_always = cancel_always and dialogue._close.visible
		dialogue._next_offer_page()
	check(fits, "a long menu page fits on the screen")
	check(cancel_always, "Cancel stays on every page")
	var every_row: bool = true
	for i: int in 17:
		every_row = every_row and seen.has("Row %d" % i)
	check(every_row, "every row of a long menu can be reached")
	dialogue._pick("cancel")
	inventory.dates = 1
	activities.talk_role("elder")
	activities._on_shop_choice("give_food")
	activities._on_shop_choice("dates")
	check(kindness.points == Kindness.GIFT_POINTS and inventory.dates == 0, "the elder's menu passes a gift to the meter")
	dialogue._advance()

func _check_finish(main: Node, systems: Node, inventory: Inventory, stead: Stead, clock: GameClock, save: SaveGame, activities: Activities, farm: FarmField, loader: LevelLoader) -> void:
	var works: VillageWorks = systems.get_node("VillageWorks") as VillageWorks
	var kindness: Kindness = systems.get_node("Kindness") as Kindness
	var dialogue: DialogueBox = main.get_node("UI/Dialogue") as DialogueBox
	check(_locale_is_whole(), "every line exists in both languages with the same blanks")
	check(_icons_are_whole(), "every good has a new bag icon")
	check(WorldShapes.seasonal_picture("res://x/plants/ghaf.png", "Winter").ends_with("ghaf_winter.png"), "the ghaf tree is bare in winter")
	check(WorldShapes.seasonal_picture("res://x/plants/sidr.png", "Autumn").ends_with("sidr_autumn.png"), "the sidr tree turns in autumn")
	check(WorldShapes.seasonal_picture("res://x/plants/ghaf.png", "Spring").ends_with("plants/ghaf.png"), "the ghaf tree is green in spring")
	dialogue.open_lines(PackedStringArray(["x"]))
	check(clock.held_by_ui(), "the clock waits while a talk box is open")
	dialogue._advance()
	check(not clock.held_by_ui(), "the clock runs again after the talk box")
	inventory.hearts = 0.25
	check(inventory.tire() and inventory.tire() and inventory.tire() and not inventory.tire(), "tools stop when the boy is out of hearts")
	inventory.take_item("dates", inventory.dates)
	inventory.dates = 1
	inventory.hearts = 0.0
	check(inventory.eat_something() != "" and inventory.hearts == 1.0, "eating brings one heart back")
	inventory.hearts = inventory.max_hearts
	var before_food: int = inventory.count_of("fish")
	inventory.add_item("fish", 1)
	check(inventory.eat_something() == "" and inventory.count_of("fish") == before_food + 1, "full hearts do not waste food")
	inventory.dinars = int(RecipeCatalog.building("house")["costs"]["dinars"])
	inventory.wood = 30
	inventory.stone = 20
	check(stead.can_offer("house") and stead.build("house") and inventory.max_hearts == 7.0, "the bigger house adds two hearts")
	check(not stead.build("house") and not stead.can_offer("house"), "the house upgrade happens once")
	clock.sleep_now()
	clock.set_process(false)
	check(inventory.hearts == 7.0, "sleep fills all seven hearts")
	check(not stead.can_offer("tools2") or stead.tool_level >= 1, "the best can follows the first can")
	var chicken_cap: int = stead.animal_cap("chicken")
	inventory.dinars = int(RecipeCatalog.building("coop2")["costs"]["dinars"])
	inventory.wood = 15
	inventory.stone = 8
	check(stead.build("coop2") and stead.animal_cap("chicken") == chicken_cap * 2, "the second coop doubles the chickens")
	inventory.dinars = RecipeCatalog.BUNDLE_PRICE
	inventory.wood = 0
	check(stead.buy_bundle("wood") and inventory.wood == RecipeCatalog.BUNDLE_SIZE and inventory.dinars == 0, "the carpenter sells a bundle")
	check(not stead.buy_bundle("wood") and inventory.wood == RecipeCatalog.BUNDLE_SIZE, "a bundle needs dinars")
	inventory.dinars = int(RecipeCatalog.building("decor_plant")["costs"]["dinars"])
	inventory.forage = 2
	stead.build("decor_plant")
	check(stead.is_built("decor_plant"), "a decoration can be bought after the house")
	loader.go_to(load("res://src/scenes/world/house/House_inside.tscn") as PackedScene, "PlayerSpawn")
	for i: int in 3:
		await process_frame
	check(_place(main).get_node_or_null("DecorPlant") != null, "the decoration appears in the house")
	loader.go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "HouseDoor")
	for i: int in 12:
		await physics_frame
	check(_place_name(main) == "Home", "leaving the house does not walk straight back in")
	await _check_walks(main, clock)
	await _check_look(main, loader, dialogue, activities)
	works.from_data({})
	kindness.from_data({})
	check(works.next_project().get("id") == "well" and not works.all_done(), "a save without projects starts at the well")
	inventory.stone = 0
	inventory.wood = 0
	inventory.dinars = 0
	check(not works.fund_next() and not works.is_done("well"), "a project needs its goods")
	check(stead.missing_text(works.next_project()["costs"]).length() > 0, "the refusal says what is missing")
	loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "PlayerSpawn")
	for i: int in 3:
		await process_frame
	for project: Dictionary in VillageWorks.PROJECTS:
		var costs: Dictionary = project["costs"]
		for key: String in costs:
			if key == "dinars":
				inventory.dinars = int(costs[key])
			else:
				inventory.add_item(key, int(costs[key]) - inventory.count_of(key))
		check(works.fund_next() and works.is_done(str(project["id"])), "%s can be finished" % project["id"])
	check(works.all_done() and kindness.points == 40, "every project raises the Khair meter")
	check(_place(main).get_node_or_null("WorkWell") != null and _place(main).get_node_or_null("WorkDiwaniya") != null, "finished projects stand in the village")
	check(_place(main).get_node("WorkWell").get_node_or_null("Block") != null, "the well is solid")
	loader.go_to(load("res://src/scenes/world/orchard/Orchard.tscn") as PackedScene, "PlayerSpawn")
	for i: int in 3:
		await process_frame
	var new_palm: Node2D = _place(main).get_node_or_null("GrovePalm1") as Node2D
	var had_dates: int = inventory.count_of("dates")
	check(new_palm != null and activities.gather_node(new_palm) and inventory.count_of("dates") == had_dates + 1, "the new grove gives dates")
	check(not activities.gather_node(new_palm), "the new palm also waits until morning")
	inventory.take_item("fish", inventory.count_of("fish"))
	inventory.add_item("fish", 1)
	inventory.dinars = 0
	check(inventory.sell_stack("fish") == 33, "the repaired market pays a tenth more")
	inventory.add_item("pearl", 1)
	check(inventory.count_of("pearl") == 1 and GoodsCatalog.sell_price("pearl") > 0, "a pearl can be kept and sold")
	var wish: Dictionary = works.request_today()
	check(wish.has("person") and works.can_help(str(wish["person"])), "a neighbor asks for help today")
	check(works.request_today()["item"] == wish["item"], "the request stays the same all day")
	inventory.take_item(str(wish["item"]), inventory.count_of(str(wish["item"])))
	check(not works.fulfil_request(), "a request needs the goods")
	inventory.add_item(str(wish["item"]), int(wish["amount"]))
	var paid_before: int = inventory.dinars
	var khair_before: int = kindness.points
	check(works.fulfil_request() and inventory.dinars == paid_before + int(wish["pay"]) and kindness.points == khair_before + VillageWorks.REQUEST_POINTS, "a request pays dinars and Khair")
	check(not works.fulfil_request() and not works.can_help(str(wish["person"])), "a request pays once")
	save.write_now()
	works.done.clear()
	check(save.load_game() and works.all_done() and bool(works.request_today().get("done", false)), "projects and requests survive a reload")
	clock.sleep_now()
	clock.set_process(false)
	check(int(works.request_today()["day"]) == clock.day and not bool(works.request_today()["done"]), "a new request comes each morning")
	check(not works.festival_ready(), "the festival waits for a full meter")
	kindness.points = Kindness.MAX_POINTS
	check(works.festival_ready() and stead.goal_text() == Locale.t("quest_festival"), "a full meter and all projects open the festival")
	works.from_data({"done": {"moon": true}, "request": {"day": clock.day, "person": "nobody", "item": "wood", "amount": 1}})
	check(works.done.is_empty() and works.request.is_empty(), "broken project values load safely")
	kindness.from_data({})
	stead.flags.erase("built_house")
	stead.apply_buildings()
	inventory.hearts = 5.0
	loader.go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "VillageReturn")
	for i: int in 3:
		await process_frame

## Walks with the same calls a screen tap makes, because direct calls cannot catch an unreachable door.
func _check_walks(main: Node, clock: GameClock) -> void:
	var player: Player = main.find_child("Player", true, false) as Player
	var dialogue: DialogueBox = main.get_node("UI/Dialogue") as DialogueBox
	player.global_position = Vector2(0, 20)
	player.busy = false
	player.set_walk_target(Vector2(-392, -293))
	for i: int in 900:
		await physics_frame
		if _place_name(main) == "HouseInside":
			break
	check(_place_name(main) == "HouseInside", "a tap on the house walks the boy inside")
	player.busy = false
	var bed: Node2D = _place(main).get_node("Bed") as Node2D
	player.set_walk_target(bed.global_position + Vector2(0, -10))
	for i: int in 900:
		await physics_frame
		if dialogue.visible:
			break
	check(dialogue.visible and dialogue._choosing, "a tap on the bed asks about sleep")
	dialogue._choose(false)
	var door: Node2D = _place(main).get_node("Exit") as Node2D
	player.set_walk_target(door.get_node("CollisionShape2D").global_position)
	for i: int in 900:
		await physics_frame
		if _place_name(main) == "Home":
			break
	check(_place_name(main) == "Home", "a tap on the door walks back to the farm")
	for i: int in 3:
		await process_frame
	player.busy = false
	player.set_walk_target(Vector2(608, 40))
	for i: int in 900:
		await physics_frame
		if _place_name(main) == "Road":
			break
	check(_place_name(main) == "Road", "a tap on the east sign walks to the caravan road")
	for i: int in 3:
		await process_frame
	var road_door: Node2D = _place(main).get_node("ExitVillage") as Node2D
	player.busy = false
	player.set_walk_target(road_door.global_position)
	for i: int in 900:
		await physics_frame
		if _place_name(main) == "Village":
			break
	check(_place_name(main) == "Village", "the caravan road leads to the village")
	for i: int in 3:
		await process_frame
	player.busy = false
	var elder: Node2D = _place(main).get_node("Elder") as Node2D
	player.set_walk_target(elder.global_position)
	for i: int in 900:
		await physics_frame
		if dialogue.visible:
			break
	check(dialogue.visible, "a tap on the elder opens talk")
	dialogue._pick("cancel")
	(main.get_node("Systems/LevelLoader") as LevelLoader).go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "HouseDoor")
	for i: int in 3:
		await process_frame

func _check_look(main: Node, loader: LevelLoader, dialogue: DialogueBox, activities: Activities) -> void:
	loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "PlayerSpawn")
	for i: int in 3:
		await process_frame
	var elder: Node = _place(main).get_node("Elder")
	# Painted HD villagers breathe gently instead of playing an idle sheet.
	check(bool(elder.get("_breathes")) and elder.get("_frames").is_empty(), "the HD elder breathes while standing")
	check(elder.get("person") is HdPicture, "the elder is a painted HD picture")
	check(_place(main).get_node_or_null("Decor") != null and _place(main).get_node("Decor").get_child_count() > 0, "the village has ground details")
	activities.talk_role("elder")
	check(dialogue._portrait_box.visible and dialogue._portrait.texture != null, "a villager talks with a portrait")
	dialogue._pick("cancel")
	dialogue.ask("x")
	check(not dialogue._portrait_box.visible, "a question with no speaker shows no portrait")
	dialogue._choose(false)
	loader.go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "HouseDoor")
	for i: int in 3:
		await process_frame
	await _check_debris(main, loader, activities)
	await _check_world(main, loader, activities)
	await _check_juice(main)
	var pond: Node = _place(main).get_node("FishingSpot")
	check(pond.get_node_or_null("Block") != null, "the pond cannot be walked through")
	check((main.find_child("Player", true, false).get_node("Camera2D") as Camera2D).zoom.x <= 1.0, "the camera shows a wide view of the world")
	var boy: AnimatedSprite2D = main.find_child("Player", true, false).get_node("CharacterSprite") as AnimatedSprite2D
	check(boy.scale.x < 1.0 and boy.sprite_frames.has_animation("axe_Down") and boy.sprite_frames.has_animation("pick_Down"), "the boy is small and has his tool swings")
	var player: Player = main.find_child("Player", true, false) as Player
	var dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
	player.busy = false
	var fished: bool = bool(activities.fish_spots.has("Home/FishingSpot"))
	player.global_position = Vector2(230, -170)
	player.set_walk_target(Vector2(380, -150))
	for i: int in 400:
		await physics_frame
		if activities.fish_spots.has("Home/FishingSpot"):
			break
	check(fished or activities.fish_spots.has("Home/FishingSpot"), "a tap on the pond reaches it and fishes")
	player.cancel_tap()

func _check_debris(main: Node, loader: LevelLoader, activities: Activities) -> void:
	var systems: Node = main.get_node("Systems")
	var inventory: Inventory = systems.get_node("Inventory") as Inventory
	var stead: Stead = systems.get_node("Stead") as Stead
	var save: SaveGame = systems.get_node("SaveGame") as SaveGame
	var dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
	var place: Node = _place(main)
	var twigs: Node2D = place.get_node_or_null("Debris0") as Node2D
	check(twigs != null, "the farm starts with twigs to clear")
	var cell: Vector2i = dirt.local_to_map(dirt.to_local(twigs.global_position))
	check(activities.tool_for_cell(dirt, cell) == "axe", "twigs ask for the axe")
	var wood: int = inventory.wood
	check(activities.chop_at(dirt, cell) and inventory.wood == wood + 1, "clearing twigs gives wood")
	check(not activities.chop_at(dirt, cell) and inventory.wood == wood + 1, "cleared twigs pay once")
	var stones: Node2D = place.get_node("Debris7") as Node2D
	var stone_cell: Vector2i = dirt.local_to_map(dirt.to_local(stones.global_position))
	check(activities.tool_for_cell(dirt, stone_cell) == "pick", "stones ask for the pickaxe")
	var weeds: Node2D = place.get_node("Debris13") as Node2D
	var weed_cell: Vector2i = dirt.local_to_map(dirt.to_local(weeds.global_position))
	var herbs: int = inventory.forage
	check(activities.try_use(dirt, weed_cell) and inventory.forage == herbs + 1, "pulling weeds gives an herb")
	save.write_now()
	loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "PlayerSpawn")
	for i: int in 3:
		await process_frame
	loader.go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "HouseDoor")
	for i: int in 3:
		await process_frame
	check(_place(main).get_node_or_null("Debris0") == null and _place(main).get_node_or_null("Debris7") != null, "cleared debris stays gone, and the rest waits")
	check(bool(stead.flags.get("cleared_Debris0", false)), "the cleared list is saved")
	loader.go_to(load("res://src/scenes/world/house/House_inside.tscn") as PackedScene, "PlayerSpawn")
	for i: int in 3:
		await process_frame
	check(_place(main).get_node_or_null("Room_table") != null and _place(main).get_node_or_null("Bounds/Walls") != null, "the house has furniture and walls")
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var lamp: PointLight2D = _place(main).get_node("Room_lantern").get_child(-1) as PointLight2D
	clock.minute = 22.0 * 60.0
	clock._paint_sky()
	check(lamp != null and lamp.enabled and (main.get_node("NightTint") as CanvasModulate).color != Color.WHITE, "lamps glow at night")
	clock.minute = 10.0 * 60.0
	clock._paint_sky()
	check(not lamp.enabled and (main.get_node("NightTint") as CanvasModulate).color.r > 0.9, "lamps rest in daylight")
	loader.go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "HouseDoor")
	for i: int in 3:
		await process_frame

## A picture with no size set draws at full size and can hide the whole screen.
func _pictures_fit(main: Node, place: String) -> bool:
	var fits: bool = true
	for mark: Node in _place(main).get_children():
		var picture: Variant = mark.get("_picture")
		if picture is Texture2D:
			var drawn: Vector2 = (picture as Texture2D).get_size()
			if int(mark.get("fit_pixels")) == 0 and _frames_empty(mark):
				drawn *= float(mark.get("person_scale"))
			if maxf(drawn.x, drawn.y) > 240.0:
				print("TOO BIG in %s: %s %s" % [place, mark.name, drawn])
				fits = false
	return fits

func _check_friends(main: Node) -> void:
	var systems: Node = main.get_node("Systems")
	var friends: Friendship = systems.get_node("Friendship") as Friendship
	var fairs: Festivals = systems.get_node("Festivals") as Festivals
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var old_day: int = clock.day
	var old_season: String = clock.season
	friends.from_data({})
	friends.talk("elder")
	friends.talk("elder")
	check(int(friends.points.get("elder", 0)) == Friendship.TALK_POINTS, "a neighbor grows closer from one talk a day")
	check(friends.gift("elder", "dates") == "love" and friends.gift("fisherman", "fish") == "dislike", "neighbors love and dislike different gifts")
	check(int(friends.points.get("fisherman", 0)) == 0 and friends.hearts("elder") == 0, "hearts never drop below zero")
	friends.points["merchant"] = Friendship.HEART * 2
	check(friends.talk("merchant") == Locale.t("heart_merchant_2") and friends.talk("merchant") != Locale.t("heart_merchant_2"), "a heart talk plays once at two hearts")
	clock.season = "Summer"
	clock.day = 12
	check(friends.is_birthday("elder") and friends.birthday_today() == "elder", "the elder has a summer birthday")
	var before: int = int(friends.points.get("elder", 0))
	friends.gift("elder", "milk")
	check(int(friends.points.get("elder", 0)) == before + 80 * Friendship.BIRTHDAY_TIMES, "a birthday gift counts three times")
	var saved: Dictionary = friends.to_data()
	friends.from_data(saved)
	check(int(friends.points.get("elder", 0)) == before + 240 and friends.heart_talks_seen.has("merchant_2"), "hearts survive a save")
	clock.season = "Spring"
	clock.day = 4
	fairs.joined_day = -1
	check(str(fairs.today().get("id", "")) == "truffle" and fairs.morning_note() != "", "spring has the truffle fair")
	var herbs: int = bag.count_of("forage")
	check(fairs.join() and bag.count_of("forage") == herbs + 4 and not fairs.join(), "the fair gift comes once")
	fairs.apply_place()
	check(_place(main).get_node_or_null("FairRug") != null and _place(main).get_node_or_null("FairFlags-150") != null, "the square is dressed for the fair")
	clock.day = 5
	fairs.apply_place()
	check(fairs.today().is_empty() and str(fairs.tomorrow().get("id", "")) == "", "no fair the next day")
	clock.day = old_day
	clock.season = old_season
	friends.from_data({})
	fairs.apply_place()

func _check_stories(systems: Node) -> void:
	var friends: Friendship = systems.get_node("Friendship") as Friendship
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var old: Dictionary = {"day": clock.day, "minute": clock.minute, "wood": bag.wood, "copper": bag.count_of("copper"), "eggs": bag.count_of("eggs"), "fish": bag.fish, "pearl": bag.count_of("pearl"), "tomatoes": bag.tomatoes, "dinars": bag.dinars}
	friends.from_data({})
	friends.points["jassim"] = Friendship.HEART * 2
	friends.heart_talks_seen["jassim_2"] = true
	check(friends.talk("jassim") == "" and friends.story_row("jassim") == "", "no story before three hearts")
	friends.points["jassim"] = Friendship.HEART * Friendship.STORY_START
	check(friends.talk("jassim") == Locale.t("story_jassim_ask") and friends.story_row("jassim").begins_with("story|"), "at three hearts Jassim asks for help and the menu shows it")
	bag.wood = 2
	check(friends.finish_story("jassim", systems).is_empty() and friends.story_hint("jassim", systems).contains("4"), "the story waits until the wood is there")
	bag.wood = 8
	var lines: PackedStringArray = friends.finish_story("jassim", systems)
	check(lines.size() == 2 and bag.wood == 2 and bag.count_of("eggs") == int(old["eggs"]) + 3 and friends.story_state("jassim") == Friendship.HELPED, "helping Jassim takes the wood and gives eggs")
	check(friends.take_weekly_eggs() == 0, "no second batch of eggs the same week")
	clock.day += 7
	check(friends.take_weekly_eggs() == Friendship.WEEKLY_EGGS and friends.take_weekly_eggs() == 0, "Jassim shares eggs again the next week, once")
	friends.points["jassim"] = Friendship.HEART * Friendship.STORY_END
	friends.heart_talks_seen["jassim_4"] = true
	check(friends.talk("jassim") == Locale.t("story_jassim_thanks") and friends.story_state("jassim") == Friendship.THANKED and friends.talk("jassim") != Locale.t("story_jassim_thanks"), "at five hearts Jassim says thank you, once")
	friends.stories["fisherman"] = Friendship.ASKED
	clock.minute = 10.0 * 60.0
	check(not friends.story_ready("fisherman", systems), "the dawn trip waits for the early morning")
	clock.minute = 6.5 * 60.0
	var fish: int = bag.fish
	check(friends.finish_story("fisherman", systems).size() == 2 and bag.fish == fish + 3, "a dawn trip with the fisherman shares his catch")
	friends.stories["carpenter"] = Friendship.ASKED
	bag.add_item("copper", 3)
	friends.finish_story("carpenter", systems)
	check(bag.count_of("toy_dhow") == 1 and GoodsCatalog.icon_path("toy_dhow") != "", "the carpenter carves a toy dhow for the bag")
	friends.stories["elder"] = Friendship.ASKED
	check(friends.story_hint("elder", systems).contains("3"), "the elder waits for three pages")
	friends.stories["merchant"] = Friendship.ASKED
	bag.tomatoes = 5
	var dinars: int = bag.dinars
	friends.finish_story("merchant", systems)
	check(bag.tomatoes == 0 and bag.dinars == dinars + 120, "the merchant pays for tomatoes from our own land")
	var saved: Dictionary = friends.to_data()
	friends.from_data(saved)
	check(friends.story_state("jassim") == Friendship.THANKED and friends.story_state("merchant") == Friendship.HELPED and friends.eggs_week == int(saved["eggs_week"]), "stories survive a save")
	var language: String = Locale.language
	for key: String in ["story_jassim_ask", "story_fisherman_done", "toy_dhow", "story_elder_wait"]:
		Locale.language = "ar"
		var arabic: String = Locale.t(key)
		Locale.language = "en"
		check(arabic != Locale.t(key) and arabic != key, "story words have Arabic: " + key)
	Locale.language = language
	bag.add_item("toy_dhow", -1)
	clock.day = int(old["day"])
	clock.minute = float(old["minute"])
	bag.wood = int(old["wood"])
	bag.fish = int(old["fish"])
	bag.tomatoes = int(old["tomatoes"])
	bag.dinars = int(old["dinars"])
	for item_id: String in ["copper", "eggs", "pearl"]:
		bag.add_item(item_id, int(old[item_id]) - bag.count_of(item_id))
	friends.from_data({})

## The festival's pages follow the neighbors' stories, and the line after the story names what is still open.
func _check_ending_pages(main: Node) -> void:
	var systems: Node = main.get_node("Systems")
	var friends: Friendship = systems.get_node("Friendship") as Friendship
	var stead: Stead = systems.get_node("Stead") as Stead
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var ending: EndingScreen = main.get_node("UI/Ending") as EndingScreen
	var old_stories: Dictionary = friends.stories.duplicate()
	var old_found: Dictionary = bag.found.duplicate()
	friends.stories = {"jassim": Friendship.THANKED, "elder": Friendship.ASKED}
	var pages: PackedStringArray = ending._write_pages(systems)
	check(pages.size() == 11 and pages.has(Locale.t("end_jassim_story")) and pages.has(Locale.t("end_elder")) and not pages.has(Locale.t("end_jassim")), "at the festival a neighbor whose story was finished speaks about it, and the others get a plain line")
	check(pages[pages.size() - 1].contains("1") and pages[pages.size() - 2] == Locale.t("ending_saad"), "the festival closes with grandfather's last page and the boy's own story in numbers")
	check(stead.after_text() == Locale.t("quest_after") % [1, CollectionBook.found_total(bag.found), CollectionBook.total()], "after the story the line counts the stories and the book")
	for person: String in Friendship.STORIES.keys():
		friends.stories[person] = Friendship.HELPED
	for item_id: String in CollectionBook.all_items():
		bag.found[item_id] = true
	check(stead.after_text() == Locale.t("quest_free"), "with every story and the whole book done, the farm is simply the boy's to enjoy")
	friends.stories = old_stories
	bag.found = old_found

## Reasons to come back: the caravan on the last day of each season, a gift at the door after a night away,
## and a bedtime line that names something close.
func _check_hooks(main: Node) -> void:
	var systems: Node = main.get_node("Systems")
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var fairs: Festivals = systems.get_node("Festivals") as Festivals
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var letters: Letters = systems.get_node("Letters") as Letters
	var friends: Friendship = systems.get_node("Friendship") as Friendship
	var save: SaveGame = systems.get_node("SaveGame") as SaveGame
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var map: Node = main.find_child("WorldMap", true, false)
	var old: Dictionary = {"day": clock.day, "season": clock.season, "dinars": bag.dinars, "found": bag.found.duplicate(), "paid": bag.book_paid.duplicate(), "pending": letters.pending.duplicate(), "doors": letters.door_count, "points": friends.points.duplicate(), "plots": farm.plots.duplicate(true), "next": clock.next_weather, "bag": bag.to_data()}
	var weeks_ok: bool = not Caravan.is_day(0) and not Caravan.is_day(5) and Caravan.is_day(6) and Caravan.is_day(13) and not Caravan.is_day(11)
	check(weeks_ok and Caravan.offers(5).is_empty(), "the caravan comes on the last day of each season and on no other day")
	var seeds_by_season: PackedStringArray = PackedStringArray()
	var fair_price: bool = true
	for day: int in [6, 13, 20, 27]:
		var rows: Array[Dictionary] = Caravan.offers(day)
		seeds_by_season.append(str(rows[0]["id"]))
		fair_price = fair_price and rows.size() == 3 and int(rows[1]["price"]) >= GoodsCatalog.sell_price(str(rows[1]["item"])) * int(rows[1]["amount"])
	check(seeds_by_season == PackedStringArray(["watermelon", "wheat", "wheat", "tomato"]), "the caravan brings seeds for the season that starts tomorrow (%s)" % ", ".join(seeds_by_season))
	check(fair_price, "nothing from the caravan can be sold on for more than it cost")
	var off_paths: bool = true
	for piece: Dictionary in Caravan.PROPS:
		off_paths = off_paths and not WorldShapes.on_path("Village", piece["at"], 14.0) and not piece.has("block")
	check(off_paths, "the caravan's goods stand off the village paths and block nothing")
	farm.plots = {}
	clock.day = 5
	clock.season = "Spring"
	check(Tomorrow.line(systems) == Locale.t("caravan_tomorrow") and PhoneNotices._what_to_say(systems) == Locale.t("notice_caravan"), "the night before, bedtime and the phone note say the caravan is coming")
	clock.day = 6
	bag.dinars = 500
	bag.found = {}
	check(fairs.caravan_open() and fairs.morning_note() == Locale.t("caravan_today") and (map == null or map.task_places().has("Village")), "on caravan day the morning says so and the map marks the village")
	var seeds_before: int = bag.count_of("watermelon_seeds")
	var got: Dictionary = fairs.buy_caravan("watermelon")
	check(bool(got.get("ok", false)) and bag.count_of("watermelon_seeds") == seeds_before + 6 and bag.dinars == 500 - 160, "six seeds for the price of four")
	check(fairs.buy_caravan("watermelon").is_empty() and fairs.caravan_today().size() == 2, "each thing is sold once a visit")
	var sack: Dictionary = fairs.buy_caravan(Caravan.SACK)
	check(bool(sack.get("ok", false)) and str(sack["item"]) == "dates" and int(sack["amount"]) == 4 and bag.found.has("dates"), "the mystery sack holds something new for the book")
	var sack_fair: bool = true
	var all_found: Dictionary = {}
	for item_id: String in Caravan.SACK_FINDS:
		var find: Dictionary = Caravan.sack_find(all_found, 6)
		sack_fair = sack_fair and str(find["item"]) == item_id and GoodsCatalog.sell_price(item_id) * int(find["amount"]) < Caravan.SACK_PRICE
		all_found[item_id] = true
	check(sack_fair and int(Caravan.sack_find(all_found, 6)["amount"]) >= 1, "whatever is in the sack is worth less than the sack cost")
	bag.dinars = 10
	check(not bool(fairs.buy_caravan("copper").get("ok", true)) and bag.dinars == 10 and fairs.caravan_open(), "too few dinars buys nothing and takes nothing")
	var kept: Dictionary = fairs.to_data()
	fairs.from_data(JSON.parse_string(JSON.stringify(kept)))
	check(fairs.caravan_today().size() == 1, "what was bought stays bought after a reload")
	clock.day = 7
	clock.season = "Summer"
	check(not fairs.caravan_open() and fairs.buy_caravan("copper").is_empty(), "the next morning the caravan has gone")
	# A gift at the door after a real night away.
	letters.pending = {}
	letters.door_count = 0
	clock.day = 9
	save.away_seconds = 9.0 * 3600.0
	var eggs: int = bag.count_of("eggs")
	check(save.catch_up() and bool(letters.pending.get("door", false)) and str(letters.pending["person"]) == "jassim", "after a night away a neighbor has left something at the door")
	letters.read()
	main.get_node("UI/Dialogue").call("_close_offer")
	main.get_node("UI/Dialogue").set("visible", false)
	check(bag.count_of("eggs") == eggs + 2 and letters.pending.is_empty(), "opening it puts the gift in the bag")
	letters.leave_at_door()
	check(str(letters.pending["person"]) == "elder", "the neighbors take turns")
	save.away_seconds = 1.0 * 3600.0
	letters.pending = {}
	check(not save.catch_up() and letters.pending.is_empty(), "a short break leaves nothing at the door")
	# Bedtime names something close when there is no bigger news.
	farm.plots = {}
	clock.day = 15
	clock.season = "Autumn"
	clock.next_weather = "Clear"
	friends.points = {}
	bag.found = {"wood": true, "dates": true}
	check(Tomorrow.line(systems) == Locale.t("tomorrow_book") % [1, Locale.t("book_land")], "bedtime names a book page that is nearly full")
	bag.found = {}
	friends.points = {"merchant": 195}
	check(Tomorrow.line(systems) == Locale.t("tomorrow_friend") % Locale.t("name_merchant"), "or a neighbor who is one hello from a new heart")
	friends.points = {}
	check(Tomorrow.line(systems) == clock.forecast_text(), "and with nothing close, the weather")
	bag.from_data(old["bag"])
	bag.dinars = int(old["dinars"])
	bag.found = old["found"]
	bag.book_paid = old["paid"]
	letters.pending = old["pending"]
	letters.door_count = int(old["doors"])
	friends.points = old["points"]
	farm.plots = old["plots"]
	clock.day = int(old["day"])
	clock.season = str(old["season"])
	clock.next_weather = str(old["next"])
	fairs.caravan_day = -1
	fairs.caravan_bought = PackedStringArray()

## The top bar plays a change out: dinars count to the new sum, Khair fills, and a finished step is marked.
func _check_feel(main: Node) -> void:
	var systems: Node = main.get_node("Systems")
	var stead: Stead = systems.get_node("Stead") as Stead
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var activities: Activities = systems.get_node("Activities") as Activities
	var hud: Node = main.get_node("UI/HUD")
	var old_dinars: int = bag.dinars
	var old_done: bool = activities.quest_done
	var old_plots: Dictionary = farm.plots.duplicate(true)
	hud._live_after = 0
	hud.refresh()
	bag.dinars = old_dinars + 40
	hud.refresh()
	var mid: String = hud._gold.text
	await create_timer(0.7).timeout
	hud.refresh()
	check(hud._gold.text == Locale.t("dinars") % (old_dinars + 40) and hud._dinars_seen == old_dinars + 40, "dinars count up to the new sum (%s then %s)" % [mid, hud._gold.text])
	activities.quest_done = false
	var before: int = stead.progress()
	activities.quest_done = true
	check(stead.progress() == before + 1, "a finished quest step raises the progress count")
	activities.quest_done = old_done
	farm.plots["90,90"] = {"tilled": true, "stage": 3, "watered": false, "crop": "turnip", "sprinkler": false}
	farm.apply()
	var dirt: TileMapLayer = farm._dirt()
	var crops: Node = dirt.get_node_or_null("Crops") if dirt != null else null
	var blinked: bool = false
	for i: int in 150:
		await process_frame
		if crops != null:
			for child: Node in crops.get_children():
				if child is Polygon2D:
					blinked = true
		if blinked:
			break
	check(blinked or crops == null, "a ripe plant blinks")
	farm.plots = old_plots
	farm.apply()
	bag.dinars = old_dinars
	hud.refresh()

func _check_first_steps(main: Node) -> void:
	var systems: Node = main.get_node("Systems")
	var stead: Stead = systems.get_node("Stead") as Stead
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var activities: Activities = systems.get_node("Activities") as Activities
	var works: VillageWorks = systems.get_node("VillageWorks") as VillageWorks
	var old_plots: Dictionary = farm.plots.duplicate(true)
	var old_flags: Dictionary = stead.flags.duplicate()
	var old_done: bool = activities.quest_done
	var old_turnips: int = bag.turnips
	activities.quest_done = false
	stead.flags.erase("met_jassim")
	farm.plots.clear()
	bag.turnips = 0
	check(stead.goal_text() == Locale.t("step_hello") and not works.requests_open() and not works.can_help(str(works.request_today().get("person", ""))), "a new player is first sent to say hello, and nobody asks for goods yet")
	stead.flags["met_jassim"] = true
	check(stead.goal_text() == Locale.t("step_dig"), "then to dig a square")
	farm.plots["0,0"] = {"tilled": true, "stage": -1, "watered": false, "crop": "", "sprinkler": false}
	check(stead.goal_text() == Locale.t("step_plant"), "then to plant")
	farm.plots["0,0"] = {"tilled": true, "stage": 0, "watered": false, "crop": "turnip", "sprinkler": false}
	check(stead.goal_text() == Locale.t("step_water"), "then to water")
	farm.plots["0,0"]["watered"] = true
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var friends: Friendship = systems.get_node("Friendship") as Friendship
	var kindness: Kindness = systems.get_node("Kindness") as Kindness
	var old_day: int = clock.day
	var old_friends: Dictionary = friends.to_data()
	var old_khair: Dictionary = kindness.to_data()
	var old_seeds: int = bag.seeds
	var old_dinars: int = bag.dinars
	clock.day = 1
	friends.from_data({})
	stead.flags.erase("welcomed")
	check(stead.goal_text() == Locale.t("step_sleep"), "then to sleep")
	clock.day = 2
	check(stead.goal_text() == Locale.t("step_meet") % [0, 5], "on the second day, the wait for the turnips sends him to meet the neighbors")
	for person: String in ["jassim", "elder", "merchant", "carpenter"]:
		friends.talk(person)
	check(stead.goal_text() == Locale.t("step_meet") % [4, 5] and activities.take_welcome() == "", "the line counts who he has met, and the gift waits for all five")
	friends.talk("fisherman")
	var welcome: String = activities.take_welcome()
	# The gift's Khair can also reach a Khair level, which adds seeds of its own.
	check(welcome != "" and bag.dinars == old_dinars + Activities.WELCOME_DINARS and bag.seeds >= old_seeds + Activities.WELCOME_SEEDS, "meeting all five brings the village's welcome gift")
	check(activities.take_welcome() == "" and bag.dinars == old_dinars + Activities.WELCOME_DINARS, "the welcome gift comes only once")
	var seen_woods: bool = bool(stead.visited.get("Forest", false))
	stead.visited.erase("Forest")
	check(stead.goal_text() == Locale.t("step_woods"), "after meeting everyone, the line sends him to the woods")
	stead.visited["Forest"] = true
	check(stead.goal_text() == Locale.t("step_sleep"), "after the woods, the line says to sleep again")
	if not seen_woods:
		stead.visited.erase("Forest")
	var kept: Dictionary = friends.to_data()
	friends.from_data(kept)
	check(friends.met_count() == 5, "the neighbors he has met survive a reload")
	bag.dinars = old_dinars
	bag.seeds = old_seeds
	clock.day = old_day
	friends.from_data(old_friends)
	kindness.from_data(old_khair)
	farm.plots["0,0"]["stage"] = 99
	check(stead.goal_text() == Locale.t("step_harvest"), "then to pick the ripe turnip")
	bag.turnips = 1
	check(stead.goal_text() == Locale.t("quest_turnip"), "then to sell it to Jassim")
	activities.quest_done = true
	check(works.requests_open(), "after the first sale, neighbors start asking for goods")
	var held: Dictionary = {"wood": bag.wood, "stone": bag.stone, "forage": bag.forage}
	var held_flags: Dictionary = stead.flags.duplicate()
	var held_coop: bool = stead.coop
	stead.flags["crafted_feed"] = true
	stead.coop = false
	bag.wood = 12
	bag.stone = 2
	check(stead.goal_text() == "%s. %s" % [Locale.t("quest_coop"), Locale.t("need_items") % ("4 " + Locale.item("stone"))], "the coop quest says what is still missing")
	check(stead.where_hint() == Locale.t("where_stone"), "and where to find it")
	bag.stone = 6
	check(stead.goal_text() == Locale.t("quest_coop") and stead.where_hint() == "", "with everything in the bag, the quest line is short again")
	stead.flags.erase("crafted_feed")
	bag.forage = 0
	check(stead.where_hint() == Locale.t("where_forage"), "the feed quest points to where herbs grow")
	bag.wood = int(held["wood"])
	bag.stone = int(held["stone"])
	bag.forage = int(held["forage"])
	stead.flags = held_flags
	stead.coop = held_coop
	var found_before: Dictionary = bag.found.duplicate()
	bag.found.clear()
	var asks_crop: bool = false
	for day: int in range(1, 60):
		var wish: Dictionary = works._make_request(day)
		if str(wish["item"]) in ["turnips", "tomatoes", "wheat", "watermelons"]:
			asks_crop = true
	check(not asks_crop, "nobody asks for a crop the boy has never grown")
	bag.found = found_before
	var language: String = Locale.language
	Locale.language = "ar"
	var arabic: String = Locale.t("step_dig")
	Locale.language = "en"
	check(arabic != Locale.t("step_dig"), "the first steps have Arabic words")
	Locale.language = language
	var place: Node = _place(main)
	var decor: Node = place.get_node_or_null("Decor") if place != null else null
	check(decor == null or PlaceDecor.stuck_on_paths(decor, str(place.name)).is_empty(), "no hay, pot, log or stump stands on a road or dirt path in " + (str(place.name) if place != null else "?"))
	var road_scene: Node = (load("res://src/scenes/world/road/Road.tscn") as PackedScene).instantiate()
	var junk: int = 0
	for child: Node in road_scene.get_children():
		var picture: Texture2D = child.get("person") as Texture2D
		var file: String = picture.resource_path.get_file() if picture != null else ""
		if file in ["crate.png", "sack.png", "basket.png", "table.png", "barrel.png"] and (child as Node2D).position.y > 0.0:
			junk += 1
	road_scene.free()
	check(junk == 0, "nothing the boy cannot clear stands on the walking side of the caravan road")
	farm.plots = old_plots
	stead.flags = old_flags
	activities.quest_done = old_done
	bag.turnips = old_turnips
	farm.apply()

## Ten cave levels, each its own color and layout, joined by a ladder down at the back and the way up at the front.
func _check_cave(main: Node) -> void:
	var systems: Node = main.get_node("Systems")
	var stead: Stead = systems.get_node("Stead") as Stead
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	var activities: Activities = systems.get_node("Activities") as Activities
	var colors: Dictionary = {}
	for depth: int in range(1, CaveFloor.DEEPEST + 1):
		colors[CaveFloor.floor_color(depth).to_html()] = true
	check(colors.size() == CaveFloor.DEEPEST, "each of the ten cave levels has its own color")
	activities._enter_cave()
	for i: int in 4:
		await process_frame
	var cave: CaveFloor = main.get_node("World/Cave") as CaveFloor
	check(cave != null and cave.level == 1 and cave.get_node_or_null("LadderDown") != null and cave.get_node_or_null("Rock") != null, "the farm's cave opens on level 1, with its rock and a ladder down")
	await create_timer(loader.settle_left() + 0.05).timeout
	cave.go_down()
	for i: int in 6:
		await process_frame
	cave = main.get_node("World/Cave") as CaveFloor
	check(cave.level == 2 and int(stead.flags.get("cave_deepest", 0)) >= 2 and cave.get_node_or_null("Rock") == null, "the ladder leads down to level 2, which has its own layout")
	var veins: int = 0
	var walk_clear: bool = true
	for child: Node in cave.get_children():
		if child.get_script() == load("res://src/scripts/World/copper_vein.gd"):
			veins += 1
		if (child.name.begins_with("Mining") or child.get_script() == load("res://src/scripts/World/copper_vein.gd")) and cave.on_walk((child as Node2D).position):
			walk_clear = false
	check(veins == CaveFloor.stone_count(2) + CaveFloor.copper_count(2) + CaveFloor.iron_count(2), "level 2 has its rocks and veins")
	check(walk_clear, "nothing stands on the walk from the way in to the ladder")
	var stone: int = (systems.get_node("Inventory") as Inventory).stone
	var first_rock: Node = cave.get_node("Rock0")
	first_rock.call("_on_body_entered", main.find_child("Player", true, false))
	check((systems.get_node("Inventory") as Inventory).stone == stone + 1 and not (first_rock as Node2D).visible, "a cave rock gives stone once a day")
	await create_timer(loader.settle_left() + 0.05).timeout
	cave.go_up()
	for i: int in 6:
		await process_frame
	cave = main.get_node("World/Cave") as CaveFloor
	check(cave.level == 1, "the way out of level 2 climbs back to level 1")
	stead.flags["cave_level"] = CaveFloor.DEEPEST
	loader.go_to(load(CaveFloor.SCENE) as PackedScene, "PlayerSpawn")
	for i: int in 6:
		await process_frame
	cave = main.get_node("World/Cave") as CaveFloor
	check(cave.level == 10 and cave.get_node_or_null("LadderDown") == null and cave.get_node_or_null("Treasure") != null and CaveFloor.iron_count(10) > 0, "level 10 is the bottom, with iron and a glowing treasure")
	var language: String = Locale.language
	Locale.language = "ar"
	var arabic: String = Locale.t("cave_level")
	Locale.language = "en"
	check(arabic != Locale.t("cave_level") and Locale.t("iron") != "iron", "cave words have English and Arabic")
	Locale.language = language
	stead.flags["cave_level"] = 1

func _check_book(main: Node) -> void:
	var systems: Node = main.get_node("Systems")
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var kindness: Kindness = systems.get_node("Kindness") as Kindness
	var save: SaveGame = systems.get_node("SaveGame") as SaveGame
	check(CollectionBook.total() == 23 and CollectionBook.PAGES.size() == 5, "the book has five pages and 23 things")
	var all_have_words: bool = true
	for item_id: String in CollectionBook.all_items():
		if Locale.t("about_" + item_id) == "about_" + item_id or GoodsCatalog.icon_path(item_id) == "":
			all_have_words = false
	check(all_have_words, "every thing in the book has a picture and a line about it")
	bag.found.clear()
	bag.book_paid.clear()
	for item_id: String in CollectionBook.all_items():
		bag.take_item(item_id, bag.count_of(item_id))
	bag.add_item("copper", 2)
	bag.take_item("copper", 2)
	check(bag.found.has("copper") and bag.count_of("copper") == 0, "a thing stays found after it leaves the bag")
	var points: int = kindness.points
	bag.add_item("stone", 1)
	check(not bag.book_paid.has("book_cave"), "a page that is not full gives nothing")
	bag.add_item("iron", 1)
	check(bag.book_paid.has("book_cave") and kindness.points == mini(points + CollectionBook.PAGE_REWARD, Kindness.MAX_POINTS), "a full page gives a little Khair")
	points = kindness.points
	bag.add_item("iron", 1)
	bag.pay_book_pages()
	check(kindness.points == points, "each page pays only once")
	var data: Dictionary = bag.to_data()
	bag.from_data(data)
	check(bag.found.has("copper") and bag.book_paid.has("book_cave"), "found things and paid pages are kept in the save")
	data.erase("found")
	data.erase("book_paid")
	data["extra"] = {"wool": 1}
	bag.from_data(data)
	check(bag.found.has("wool") and bag.found.has("stone") and not bag.found.has("copper"), "an older save fills the book from what the bag holds")
	var hud: Node = main.get_node("UI/HUD")
	hud.call("_toggle_menu")
	hud.call("_open_book")
	await process_frame
	var book: Control = hud.get("_book") as Control
	var title: Label = hud.get("_book_title") as Label
	check(book.visible and title.text.contains("/7"), "the book opens on the farm page from the journal")
	hud.call("_turn_book", 3)
	check(title.text.contains(Locale.t("book_cave")), "the arrows turn to the cave page")
	hud.call("_turn_book", -3)
	check(FishCatalog.pick("Home", "Spring", 0.9) == "fish", "the home pond always gives the plain fish")
	var harbor_spring: Dictionary = FishCatalog.table("Harbor", "Spring")
	var harbor_winter: Dictionary = FishCatalog.table("Harbor", "Winter")
	check(harbor_spring.has("zubaidi") and not harbor_spring.has("hamour") and harbor_winter.has("hamour") and not harbor_winter.has("zubaidi"), "zubaidi and hamour bite only in their seasons")
	var seen: Dictionary = {}
	for i: int in 200:
		for season: String in ["Spring", "Winter"]:
			seen[FishCatalog.pick("Harbor", season, i / 200.0)] = true
			seen[FishCatalog.pick("Forest", season, i / 200.0)] = true
	var every_kind: bool = true
	for kind: String in FishCatalog.kinds():
		if not seen.has(kind) or GoodsCatalog.sell_price(kind) <= GoodsCatalog.sell_price("fish") or not bag.can_store(kind):
			every_kind = false
	check(every_kind, "all five Gulf fish can be caught, stored and sell for more than the plain fish")
	hud.call("_toggle_menu")
	save.write_now()

func _check_fish_game(main: Node, activities: Activities) -> void:
	var bag: Inventory = main.get_node("Systems/Inventory") as Inventory
	var game: FishGame = main.get_node("UI/FishGame") as FishGame
	activities.quick_fish = false
	var fish: int = bag.count_of("fish")
	activities.cast("Home", "TestPondA")
	check(game.is_open() and bag.count_of("fish") == fish, "a cast opens the fishing game")
	var net: ColorRect = game.get("_net") as ColorRect
	game.set("_x", 0.0 if net.position.x > 100.0 else FishGame.BAR_SIZE.x - 16.0)
	game.set("_playing", true)
	game.pull()
	await create_timer(FishGame.RESULT_SECONDS + 0.2).timeout
	check(not game.is_open() and bag.count_of("fish") == fish and not activities.fish_spots.has("Home/TestPondA"), "a pull outside the net loses the fish but not the day")
	activities.cast("Home", "TestPondA")
	game.land()
	await create_timer(FishGame.RESULT_SECONDS + 0.2).timeout
	check(bag.count_of("fish") == fish + 1 and not game.is_open(), "a pull inside the net catches a fish")
	activities.quick_fish = true

## No one building picture fills more than half of a place's buildings.
## Each building in the place has a door that leads inside it; none stand there only for show.
func _buildings_open(main: Node) -> bool:
	var doors: Array[Vector2] = []
	for node: Node in _place(main).get_children():
		if node is Area2D and str(node.get("next_scene_path")).contains("_inside"):
			doors.append((node.get_child(0) as Node2D).position)
	var total: int = 0
	for mark: Node in _place(main).get_children():
		var picture: Variant = mark.get("person")
		if picture is Texture2D and ((picture as Texture2D).resource_path.contains("/building/town/") or (picture as Texture2D).resource_path.ends_with("mosque.png")):
			total += 1
			if not doors.any(func(door: Vector2) -> bool: return door.distance_to((mark as Node2D).position) < 30.0):
				print("NO WAY IN: %s" % mark.name)
				return false
	return total >= 2

func _frames_empty(mark: Node) -> bool:
	return (mark.get("_frames") as Array).is_empty()

func _check_world(main: Node, loader: LevelLoader, activities: Activities) -> void:
	var home: Node = _place(main)
	check(_pictures_fit(main, "Home"), "no picture on the farm is giant")
	check(home.get_node_or_null("ExitForest") != null and home.get_node_or_null("ExitVillage") != null, "the farm has two ways out")
	check(home.get_node_or_null("Forest0") != null and home.get_node_or_null("Pond_0") != null, "the farm has a forest edge and more ponds")
	var player_check: Player = main.find_child("Player", true, false) as Player
	player_check.global_position = Vector2(-360, 257)
	player_check.busy = false
	player_check.set_walk_target(Vector2(-360, 400))
	for i: int in 200:
		await physics_frame
	check(player_check.global_position.y < 257.0, "the boy cannot walk onto a pond")
	player_check.cancel_tap()
	var zone_dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
	var pond_fish: int = main.get_node("Systems/Inventory").count_of("fish")
	var pond_cell: Vector2i = zone_dirt.local_to_map(zone_dirt.to_local((home.get_node("Pond_0") as Node2D).global_position))
	check(activities.tool_for_cell(zone_dirt, pond_cell) == "use", "a new pond can be fished")
	check(activities.try_use(zone_dirt, pond_cell) and main.get_node("Systems/Inventory").count_of("fish") == pond_fish + 1, "a new pond gives a fish")
	check(activities.try_use(zone_dirt, pond_cell) and main.get_node("Systems/Inventory").count_of("fish") == pond_fish + 1, "the pond rests until morning")
	await _check_fish_game(main, activities)
	var ore_cell: Vector2i = zone_dirt.local_to_map(zone_dirt.to_local((home.get_node("ZoneOre") as Node2D).global_position))
	var copper: int = main.get_node("Systems/Inventory").count_of("copper")
	check(activities.tool_for_cell(zone_dirt, ore_cell) == "pick" and activities.mine_at(zone_dirt, ore_cell) and main.get_node("Systems/Inventory").count_of("copper") == copper + 1, "the farm quarry gives copper")
	var stump_cell: Vector2i = zone_dirt.local_to_map(zone_dirt.to_local((home.get_node("ZoneStump0") as Node2D).global_position))
	var stump_wood: int = main.get_node("Systems/Inventory").wood
	check(activities.tool_for_cell(zone_dirt, stump_cell) == "axe" and activities.chop_at(zone_dirt, stump_cell) and main.get_node("Systems/Inventory").wood == stump_wood + 1, "a stump gives wood")
	check(not activities.chop_at(zone_dirt, stump_cell) and main.get_node("Systems/Inventory").wood == stump_wood + 1, "a stump waits until morning")
	loader.go_to(load("res://src/scenes/world/harbor/Harbor.tscn") as PackedScene, "PlayerSpawn")
	for i: int in 3:
		await process_frame
	var crate: Node2D = _place(main).get_node("ShoreCrate") as Node2D
	var total_before: int = _bag_total(main)
	check(activities.gather_node(crate) and _bag_total(main) == total_before + 1, "the shore crate gives one find")
	check(not activities.gather_node(crate) and _bag_total(main) == total_before + 1, "the shore crate waits until morning")
	loader.go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "HouseDoor")
	for i: int in 3:
		await process_frame
	home = _place(main)
	check(WorldShapes.edge("Home", Vector2(0, 0)) < 1.0 and WorldShapes.edge("Home", Vector2(690, 560)) > 1.0, "the clearing is inside the forest")
	check(WorldShapes.water_depth("Harbor", Vector2(-300, 200)) > 0.0 and WorldShapes.water_depth("Harbor", Vector2(-300, -100)) < 0.0, "the sea lies south of the harbor")
	check(WorldShapes.on_planks("Village", Vector2(540, -40)) and WorldShapes.water_depth("Village", Vector2(540, -40)) > 0.0, "a bridge crosses the village inlet")
	var blocked_exit: bool = false
	for mark: Node in home.get_children():
		if str(mark.name).begins_with("Forest") and mark is Node2D and not mark is Marker2D:
			blocked_exit = blocked_exit or WorldShapes.in_exit("Home", (mark as Node2D).global_position)
	check(not blocked_exit, "no forest tree stands in a way out")
	var player: Player = main.find_child("Player", true, false) as Player
	player.global_position = Vector2(0, 420)
	player.busy = false
	var dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
	player.set_walk_target(Vector2(0, 490))
	for i: int in 500:
		await physics_frame
		if _place_name(main) == "Forest":
			break
	check(_place_name(main) == "Forest", "the south road walks to the woods")
	for i: int in 3:
		await process_frame
	var wood: Node2D = _place(main).get_node("Wood0") as Node2D
	var before: int = main.get_node("Systems/Inventory").wood
	player.busy = false
	player.global_position = wood.global_position + Vector2(0, -6)
	player.set_walk_target(wood.global_position)
	for i: int in 300:
		await physics_frame
		if main.get_node("Systems/Inventory").wood > before:
			break
	check(main.get_node("Systems/Inventory").wood == before + 1, "a tree in the woods gives wood with a tap")
	for row: Array in [["village/Village", "ExitHarbor", "Harbor"], ["village/Village", "ExitOrchard", "Orchard"], ["village/Village", "ExitWoods", "Forest"], ["village/Village", "ExitRoad", "Road"]]:
		loader.go_to(load("res://src/scenes/world/%s.tscn" % row[0]) as PackedScene, "PlayerSpawn")
		for i: int in 3:
			await process_frame
		check(_place(main).get_node_or_null("PaintedGround") != null, "%s has painted ground" % _place_name(main))
		check(_pictures_fit(main, _place_name(main)), "no picture in %s is giant" % _place_name(main))
		var way: Node2D = _place(main).get_node(str(row[1])) as Node2D
		player.busy = false
		player.global_position = way.global_position + (Vector2.ZERO - way.global_position).normalized() * 60.0
		player.set_walk_target(way.global_position)
		for i: int in 240:
			await physics_frame
			if _place_name(main) == row[2]:
				break
		check(_place_name(main) == row[2], "the village leads to %s" % row[2])
		for i: int in 3:
			await process_frame
	var hud: Node = main.get_node("UI/HUD")
	hud._toggle_menu()
	hud._show_tab("map")
	check(hud._world_map.visible and hud._world_map.current_spot() != Vector2.ZERO, "the map shows where the boy is")
	var map: WorldMap = hud._world_map
	var stead: Stead = main.get_node("Systems/Stead") as Stead
	var saw_cave: bool = bool(stead.visited.get("Cave", false))
	stead.visited.erase("Cave")
	map.tap_at(map._screen(WorldMap.PLACES["Cave"][0]))
	check(map._note == Locale.t("map_walk_first") and hud._menu.visible and _place_name(main) != "Cave", "the map won't take the boy somewhere he hasn't walked to")
	if saw_cave:
		stead.visited["Cave"] = true
	map.tap_at(map._screen(WorldMap.PLACES["Home"][0]))
	for i: int in 3:
		await process_frame
	check(_place_name(main) == "Home" and not hud._menu.visible, "tapping a visited place on the map takes the boy there")
	hud._show_tab("bag")
	loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "MosqueDoor")
	for i: int in 3:
		await process_frame
	var posts: Array = _place(main).get_children().filter(func(mark: Node) -> bool: return mark.get("person") != null and str((mark.get("person") as Texture2D).resource_path).ends_with("lamp_post.png"))
	check(posts.size() >= 6 and posts[0].get_tree().get_nodes_in_group("night_light").size() > 0, "the village lamps stand on posts and light up at night")
	var walker: Player = main.find_child("Player", true, false) as Player
	walker.set_walk_target(walker.global_position + Vector2(0, 120))
	activities.talk_role("mosque")
	for i: int in 40:
		await physics_frame
	check(_place_name(main) == "MosqueInside" and not walker.has_tapped_cell, "stepping inside stops the old walk, so the boy doesn't bounce back out")
	var mosque: Node = _place(main)
	check(_place_name(main) == "MosqueInside" and mosque.get_node_or_null("Decor") != null and mosque.get_node_or_null("Room_minbar_2") != null and mosque.get_node_or_null("Room_shoe_rack_10") != null and mosque.find_children("*fountain*", "", false).is_empty(), "the mosque has an open prayer hall with a carpet, a minbar, and shoe racks by the door")
	var dialogue: DialogueBox = main.get_node("UI/Dialogue") as DialogueBox
	activities.talk_role("mosque")
	check(dialogue.visible and activities._shop == "mosque", "by the mihrab inside, the boy can sit quietly")
	dialogue._pick("cancel")
	check(map.current_key() == "Village", "the map shows the mosque inside the village")
	loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "MosqueDoor")
	for i: int in 3:
		await process_frame
	check(_place_name(main) == "Village", "the mosque door leads back out to the village")
	check(_place(main).get_node_or_null("Carpenter") == null, "the carpenter works indoors, not out in the village")
	loader.go_to(load("res://src/scenes/world/workshop/Workshop_inside.tscn") as PackedScene, "PlayerSpawn")
	for i: int in 3:
		await process_frame
	var shop: Node = _place(main)
	var carpenter: Node = shop.get_node_or_null("Carpenter")
	check(_place_name(main) == "WorkshopInside" and shop.get_node_or_null("Decor") != null and carpenter != null and str(carpenter.get("role")) == "carpenter" and shop.get_node_or_null("Room_Workbench_0") != null, "the carpenter stands at his bench inside his workshop")
	var buyer: Player = main.find_child("Player", true, false) as Player
	buyer.set_walk_target((carpenter as Node2D).global_position)
	var front: Vector2 = buyer.tapped_point
	check(front.y > (shop.get_node("Room_counter_1") as Node2D).position.y, "tapping the carpenter walks the boy to the front of the counter")
	buyer.global_position = front - Vector2(0, 20)
	buyer.arrive_indoors()
	check(dialogue.visible and activities._shop == "work", "the carpenter still builds and sells wood, across his counter")
	dialogue._pick("cancel")
	buyer.cancel_tap()
	check(shop.get_node("Decor").get_children().any(func(n: Node) -> bool: return n is RoomFrame), "the room has a thick wooden frame")
	check(map.current_key() == "Village", "the map shows the workshop inside the village")
	var works: VillageWorks = main.get_node("Systems/VillageWorks") as VillageWorks
	var wish: Dictionary = works.request_today()
	if not wish.is_empty():
		wish["done"] = false
		check(map.task_places().has(WorldMap.PERSON_PLACES[str(wish["person"])]), "the map marks where a neighbor has a request today")
		wish["done"] = true
		check(not map.task_places().has(WorldMap.PERSON_PLACES[str(wish["person"])]) or str(wish["person"]) == "jassim", "the mark goes once the request is done")
	var field: FarmField = main.get_node("Systems/FarmField") as FarmField
	var quest_was: bool = (main.get_node("Systems/Activities") as Activities).quest_done
	(main.get_node("Systems/Activities") as Activities).quest_done = true
	field.plots["900,900"] = {"tilled": true, "stage": 3, "watered": false, "crop": "turnip", "sprinkler": false}
	check(str(map.task_places().get("Home", "")) == "ripe", "the map shows a leaf on the farm when a crop is ripe")
	field.plots.erase("900,900")
	check(not map.task_places().has("Home") or str(map.task_places()["Home"]) != "ripe", "the leaf goes when nothing is ripe")
	(main.get_node("Systems/Activities") as Activities).quest_done = quest_was
	loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "WorkshopDoor")
	for i: int in 3:
		await process_frame
	check(_place_name(main) == "Village", "the workshop door leads back out to the village")
	loader.go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "HouseDoor")
	for i: int in 3:
		await process_frame

## Letters, the forecast, pickup notes, the seed square, and life outdoors.
func _check_juice(main: Node) -> void:
	var systems: Node = main.get_node("Systems")
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var letters: Letters = systems.get_node("Letters") as Letters
	var dialogue: DialogueBox = main.get_node("UI/Dialogue") as DialogueBox
	var wood: int = bag.count_of("wood")
	letters.pending = {"person": "carpenter", "line": "letter_wood", "item": "wood", "amount": 5}
	letters.read()
	check(bag.count_of("wood") == wood + 5 and dialogue.visible and letters.pending.is_empty(), "a letter is read once and its gift goes in the bag")
	var letter_clock: GameClock = systems.get_node("Clock") as GameClock
	var letter_day: int = letter_clock.day
	letter_clock.day = Letters.FIRST_DAY
	letters.on_new_day()
	check(str(letters.pending.get("person", "")) == "elder" and str(letters.pending.get("item", "")) == "dates", "the third morning always brings the elder's first letter")
	letters.pending = {}
	letter_clock.day = letter_day
	while dialogue.visible:
		dialogue._advance()
	var clock: GameClock = systems.get_node("Clock") as GameClock
	clock.next_weather = "Rain"
	check(clock.forecast_text() == Locale.t("forecast") % Locale.t("weather_rain"), "the morning can tell tomorrow's weather")
	check(clock.to_data()["next_weather"] == "Rain", "tomorrow's weather is saved")
	var hud: Node = main.get_node("UI/HUD")
	hud.show_pickup("pearl", 1)
	hud.show_pickup("pearl", 2)
	var pearl_rows: Array = hud._pickups.filter(func(row: Dictionary) -> bool: return row["item"] == "pearl")
	check(pearl_rows.size() == 1 and int(pearl_rows[0]["amount"]) == 3, "picking the same item again adds to its note")
	bag.add_item("tomato_seeds", 2)
	bag.selected_seed = "turnip"
	hud._next_seed()
	check(bag.selected_seed == "tomato", "the seed square picks the next seed in the bag")
	bag.watermelon_seeds = 0
	bag.add_item("eggs", 1)
	hud.refresh()
	var listed: Array = hud._bag_shown.map(func(row: Dictionary) -> String: return str(row["item"]))
	check(not listed.has("watermelon_seeds") and listed.has("eggs") and listed.has("tomato_seeds"), "the bag lists only what the boy has")
	var map: WorldMap = hud._world_map
	map.zoom_at(2.0)
	var zoomed: float = map.zoom
	map.zoom_at(100.0)
	check(zoomed == 2.0 and map.zoom == WorldMap.MAX_ZOOM and map.offset.x <= 0.0, "the map zooms in, up to a limit")
	map.zoom_at(0.01)
	check(map.zoom == WorldMap.MIN_ZOOM and map.offset == Vector2.ZERO, "the map zooms back out to the whole land")
	for i: int in 3:
		await process_frame
	var place: Node = _place(main)
	check(place.get_node_or_null("Life") != null and place.get_node("Life").get_child_count() > 0, "birds and butterflies live outdoors")
	check(Juice.item_icon("wood") != null and Juice.item_icon("tomatoes") != null and Juice.item_icon("tomato_seeds") != null, "every item has a picture to fly")

func _bag_total(main: Node) -> int:
	var bag: Inventory = main.get_node("Systems/Inventory") as Inventory
	var total: int = 0
	for item_id: String in Inventory.all_stored_ids():
		total += bag.count_of(item_id)
	return total

func _icons_are_whole() -> bool:
	var whole: bool = true
	for item_id: String in GoodsCatalog.sellable_ids():
		if GoodsCatalog.icon_path(item_id) == "" or not ResourceLoader.exists(GoodsCatalog.icon_path(item_id)):
			print("NO ICON %s" % item_id)
			whole = false
	return whole

func _locale_is_whole() -> bool:
	var whole: bool = true
	for key: String in Locale._EN:
		if key == "language":
			continue
		if not Locale._AR.has(key):
			print("MISSING ARABIC %s" % key)
			whole = false
			continue
		for blank: String in ["%d", "%s"]:
			if str(Locale._EN[key]).count(blank) != str(Locale._AR[key]).count(blank):
				print("BLANKS DIFFER %s" % key)
				whole = false
	return whole

func _check_save_safety(save: SaveGame, inventory: Inventory) -> void:
	var clock: GameClock = save.get_parent().get_node("Clock") as GameClock
	var day: int = clock.day
	save.away_seconds = 2.0 * 3600.0
	check(not save.catch_up() and clock.day == day, "a short break changes nothing on the farm")
	save.away_seconds = 30.0 * 3600.0
	check(save.catch_up() and clock.day == day + 1, "after a long time away, exactly one night passes, never more")
	check(save.away_seconds == 0.0 and not save.catch_up() and clock.day == day + 1, "the night away is counted only once")
	inventory.dinars = 77
	save.write_now()
	save.write_now()
	var broken: FileAccess = FileAccess.open(save.path, FileAccess.WRITE)
	broken.store_string("{not json")
	broken.close()
	inventory.dinars = 1
	check(save.load_game() and save.recovered and inventory.dinars == 77, "a damaged save recovers from the backup")
	check(FileAccess.file_exists(save.path.get_basename() + ".damaged.json"), "the damaged save is kept for repair")
	var odd: FileAccess = FileAccess.open(save.path, FileAccess.WRITE)
	odd.store_string(JSON.stringify({"bag": {"seeds": -5, "dinars": -20, "turnips": "x"}, "clock": {"day": -3, "minute": 99999, "season": "Moon"}}))
	odd.close()
	check(save.load_game() and inventory.seeds == 0 and inventory.dinars == 0, "negative counts load as zero")
	save.write_now()
	save.start_new()
	var kept: int = 0
	for file_name: String in DirAccess.get_files_at(save.path.get_base_dir()):
		if file_name.begins_with(save.path.get_file().get_basename() + ".before-new-"):
			kept += 1
	check(kept >= 1, "a new game keeps a copy of the old save")
	check(save._read_dictionary(save.path) is Dictionary, "the new save is a valid empty farm")

func _remove_side_files(save: SaveGame) -> void:
	var folder: String = save.path.get_base_dir()
	var stem: String = save.path.get_file().get_basename()
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.begins_with(stem + "."):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file_name)))

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("SHOT_NULL %s" % path)
		return
	image.save_png(path)
	print("SHOT_OK %s" % path)

func _place(main: Node) -> Node:
	for child: Node in main.get_node("World").get_children():
		if child.name != "Player":
			return child
	return null

func _place_name(main: Node) -> String:
	var place: Node = _place(main)
	return place.name if place != null else ""

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("FAIL %s" % label)
