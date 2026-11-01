# tests/core_loop.gd
# Purpose: Checks the economy, animals, crafting, travel, and old-save rules.

extends SceneTree

var passed: int = 0
var failed: int = 0

func _init() -> void:
	_run()

func _run() -> void:
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
	check(inventory.count_of("fish") == 1, "one gulf fish was added")
	inventory.add_item("fish", 1)
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
	check(stead.build("expand") and farm.farm_size == Vector2i(4, 4) and old_size == Vector2i(3, 3), "the field grows to four by four")
	inventory.add_item("copper", 3)
	inventory.dinars = 120
	check(stead.build("tools") and stead.tool_level == 1, "copper upgrades the watering can")
	farm.plots["-11,-4"] = {"tilled": true, "stage": 0, "watered": false, "crop": "turnip"}
	farm.plots["-10,-4"] = {"tilled": true, "stage": 0, "watered": false, "crop": "turnip"}
	var dirt: TileMapLayer = main.find_child("Tilled_Dirt", true, false) as TileMapLayer
	farm.work(dirt, Vector2i(-11, -4), true)
	check(bool(farm.plots["-11,-4"]["watered"]) and bool(farm.plots["-10,-4"]["watered"]), "the upgrade waters a neighbor")
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "PlayerSpawn")
	await process_frame
	await process_frame
	await process_frame
	check(_place_name(main) == "Village" and stead.place_name == "Village", "the village opens")
	loader.go_to(load("res://src/scenes/world/harbor/Harbor.tscn") as PackedScene, "PlayerSpawn")
	await process_frame
	await process_frame
	await process_frame
	check(_place_name(main) == "Harbor" and bool(stead.visited.get("Harbor", false)), "the harbor opens")
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	print("CORE_TEST passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

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
