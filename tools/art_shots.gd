# tools/art_shots.gd
# Purpose: Takes pictures of the views the first art check did not cover: the farm with the coop, barn and
# animals in all four seasons, the four festival days in the village, night, rain, and other places by season.
# Run from the project root, with a save path that is not the real one:
#   KHAIR_SAVE=<scratch>/art_save.json KHAIR_SHOTS=<scratch>/art Godot --path . --resolution 1688x780 -s tools/art_shots.gd --quit-after 30000
# With KHAIR_ART_ANIMALS=1 it only takes the coop, barn and animals (day in spring and winter, and night).

extends SceneTree

var out: String = ""
var clock: GameClock
var loader: LevelLoader

func _init() -> void:
	_run()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)

func _go(scene: String, day: int, hour: float, weather: String = "Clear", spot: Vector2 = Vector2.INF) -> void:
	clock.day = day
	clock.season = GameClock.SEASONS[int(float(day) / 7.0) % GameClock.SEASONS.size()]
	clock.minute = hour * 60.0
	clock.weather = weather
	loader.go_to(load(scene) as PackedScene, "PlayerSpawn")
	await create_timer(1.4).timeout
	if spot != Vector2.INF:
		var player: Node2D = current_scene.find_child("Player", true, false) as Node2D
		player.global_position = spot
	clock.call("_paint_sky")
	await create_timer(0.8).timeout

func _run() -> void:
	out = OS.get_environment("KHAIR_SHOTS")
	if out == "":
		out = ProjectSettings.globalize_path("user://art_shots/")
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://src/scenes/world/main/MainGame.tscn")
	for i: int in 6:
		await process_frame
	await create_timer(0.5).timeout
	for c: Node in current_scene.get_node("UI").get_children():
		if c is TitleMenu:
			c.call("_start_new")
	await create_timer(1.0).timeout
	var dialogue: DialogueBox = current_scene.get_node("UI/Dialogue") as DialogueBox
	for i: int in 8:
		if dialogue.visible:
			dialogue.call("_advance")
		await create_timer(0.3).timeout
	dialogue.visible = false
	var systems: Node = current_scene.get_node("Systems")
	clock = systems.get_node("Clock") as GameClock
	loader = systems.get_node("LevelLoader") as LevelLoader
	clock.set_process(false)
	systems.get_node("Letters").set_process(false)
	var stead: Stead = systems.get_node("Stead") as Stead
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	(systems.get_node("Activities") as Activities).quest_done = true
	stead.flags["met_jassim"] = true
	stead.coop = true
	stead.barn = true
	bag.dinars = 99999
	for kind: String in ["chicken", "chicken", "goat", "sheep", "cow"]:
		stead.buy_animal(kind)
	stead.apply_buildings()
	var farm_scene: String = "res://src/scenes/world/home/Home.tscn"
	var village: String = "res://src/scenes/world/village/Village.tscn"
	if OS.get_environment("KHAIR_ART_ANIMALS") == "1":
		for day: int in [2, 23]:
			await _go(farm_scene, day, 12.0, "Clear", Vector2(390, 290))
			await _shot("animals_%s" % clock.season.to_lower())
		await _go(farm_scene, 2, 21.5, "Clear", Vector2(390, 290))
		await _shot("animals_night")
		quit()
		return
	for day: int in [2, 9, 16, 23]:
		await _go(farm_scene, day, 12.0)
		await _shot("farm_%s" % clock.season.to_lower())
	await _go(farm_scene, 2, 21.5)
	await _shot("farm_night")
	await _go(farm_scene, 2, 10.0, "Rain")
	await _shot("farm_rain")
	for day: int in [4, 11, 18, 25]:
		await _go(village, day, 12.0, "Clear", Vector2(10, -60))
		await _shot("fair_%s" % clock.season.to_lower())
	await _go(village, 3, 21.0, "Clear", Vector2(10, -60))
	await _shot("village_night")
	await _go("res://src/scenes/world/forest/Forest.tscn", 16, 12.0)
	await _shot("forest_autumn")
	await _go("res://src/scenes/world/forest/Forest.tscn", 23, 12.0)
	await _shot("forest_winter")
	await _go("res://src/scenes/world/orchard/Orchard.tscn", 9, 12.0)
	await _shot("orchard_summer")
	await _go("res://src/scenes/world/harbor/Harbor.tscn", 23, 12.0)
	await _shot("harbor_winter")
	await _go("res://src/scenes/world/harbor/Harbor.tscn", 9, 19.5)
	await _shot("harbor_evening")
	await _go("res://src/scenes/world/road/Road.tscn", 16, 12.0)
	await _shot("road_autumn")
	await _go("res://src/scenes/world/house/House_inside.tscn", 2, 22.0)
	await _shot("house_night")
	quit()
