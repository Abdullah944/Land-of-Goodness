# tools/store_shots.gd
# Purpose: Takes the App Store pictures (farm, village, merchant, harbor, book, map, Quran) in English and Arabic.
# Run on the Mac from the project root, with a save path that is not the real one:
#   KHAIR_SAVE=<scratch>/store_save.json Godot --path . --resolution 2868x1320 -s tools/store_shots.gd --quit-after 12000
# The pictures land in build/store_screenshots/ at the size Apple asks for (6.9 inch, landscape).

extends SceneTree

var OUT: String = ProjectSettings.globalize_path("res://build/store_screenshots/")
var n: int = 0

func _init() -> void:
	_run()

func _wait(frames: int = 4) -> void:
	for i: int in frames:
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	var image: Image = root.get_texture().get_image()
	image.save_png(OUT + "%02d_%s.png" % [n, name])
	print("SHOT ", name, " ", image.get_size())

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://src/scenes/world/main/MainGame.tscn")
	await _wait(6)
	await create_timer(0.5).timeout
	var title: Node = null
	for c: Node in current_scene.get_node("UI").get_children():
		if c is TitleMenu:
			title = c
	title.call("_start_new")
	await create_timer(1.0).timeout
	var dialogue: DialogueBox = current_scene.get_node("UI/Dialogue") as DialogueBox
	for i: int in 8:
		if dialogue.visible:
			dialogue.call("_advance")
		await create_timer(0.3).timeout
	dialogue.visible = false
	var systems: Node = current_scene.get_node("Systems")
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var stead: Stead = systems.get_node("Stead") as Stead
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var friends: Friendship = systems.get_node("Friendship") as Friendship
	var activities: Activities = systems.get_node("Activities") as Activities
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	var hud: Node = current_scene.get_node("UI/HUD")
	clock.set_process(false)
	systems.get_node("Letters").set_process(false)
	stead.flags["met_jassim"] = true
	activities.quest_done = true
	for person: String in Friendship.PEOPLE:
		friends.talk(person)
	Locale.language = "en"
	stead.language = "en"
	bag.dinars = 1420
	for item: String in ["turnips", "tomatoes", "wheat", "watermelons", "onions", "fish", "maid", "safi", "wood", "stone", "dates", "forage", "eggs", "milk", "copper", "feed", "pearl"]:
		bag.add_item(item, 3)
	var crops: Array[String] = ["turnip", "tomato", "wheat", "watermelon", "onion"]
	for x: int in farm.farm_size.x:
		for y: int in farm.farm_size.y:
			var crop: String = crops[y % crops.size()]
			var top: int = int(CropCatalog.get_crop(crop)["mature_stage"])
			farm.plots[farm._key(farm.farm_origin + Vector2i(x, y))] = {"tilled": true, "stage": clampi(int(float(x) * float(top + 1) / float(farm.farm_size.x)), 0, top), "watered": x % 3 != 0, "crop": crop, "sprinkler": false}
	farm.apply()
	var player: Node2D = current_scene.find_child("Player", true, false) as Node2D
	var dirt: TileMapLayer = farm.call("_dirt") as TileMapLayer
	print("FARM size=", farm.farm_size, " origin=", farm.farm_origin, " player=", player.global_position)
	if dirt != null:
		player.global_position = dirt.to_global(dirt.map_to_local(farm.farm_origin + Vector2i(int(farm.farm_size.x / 2.0), -1)))
	for lang: String in ["en", "ar"]:
		Locale.language = lang
		stead.language = lang
		hud.call("refresh")
		if lang == "ar":
			loader.go_to(load("res://src/scenes/world/home/Home.tscn") as PackedScene, "PlayerSpawn")
			await create_timer(1.0).timeout
			player = current_scene.find_child("Player", true, false) as Node2D
			dirt = farm.call("_dirt") as TileMapLayer
			if dirt != null:
				player.global_position = dirt.to_global(dirt.map_to_local(farm.farm_origin + Vector2i(int(farm.farm_size.x / 2.0), -1)))
		await create_timer(6.0).timeout
		await _shot("farm_" + lang)
		loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "PlayerSpawn")
		await create_timer(1.0).timeout
		player = current_scene.find_child("Player", true, false) as Node2D
		player.global_position = Vector2(10, -120)
		hud.call("refresh")
		await create_timer(1.0).timeout
		await _shot("village_" + lang)
		player.global_position = Vector2(10, 22)
		await create_timer(0.6).timeout
		activities.talk_role("merchant")
		await create_timer(1.5).timeout
		await _shot("merchant_" + lang)
		dialogue.call("_close_offer")
		dialogue.visible = false
		activities.set("_shop", "")
		loader.go_to(load("res://src/scenes/world/harbor/Harbor.tscn") as PackedScene, "PlayerSpawn")
		await create_timer(1.5).timeout
		player = current_scene.find_child("Player", true, false) as Node2D
		player.global_position = Vector2(120, 150)
		hud.call("refresh")
		await create_timer(1.2).timeout
		await _shot("harbor_" + lang)
		hud.call("_toggle_menu")
		hud.call("_show_tab", "book")
		await create_timer(0.8).timeout
		await _shot("book_" + lang)
		hud.call("_show_tab", "map")
		await create_timer(0.8).timeout
		await _shot("map_" + lang)
		hud.call("_toggle_menu")
		await create_timer(0.3).timeout
		# The mosque, listening to the Quran (Al-Fatiha, already on this Mac; nothing is downloaded).
		loader.go_to(load("res://src/scenes/world/mosque/Mosque_inside.tscn") as PackedScene, "PlayerSpawn")
		await create_timer(1.2).timeout
		var reader: QuranReader = current_scene.get_node("UI/QuranReader") as QuranReader
		QuranReader.allow_network = false
		reader.open()
		reader.listen(1)
		await create_timer(2.5).timeout
		await _shot("quran_" + lang)
		reader.stop_listening()
		reader.close()
		await create_timer(0.3).timeout
	quit()
