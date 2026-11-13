# tools/window_shots.gd
# Purpose: Takes a picture of every window outside the menu (title, talk, shop, workbench, chest,
# sale, prayer, sleep, fishing, help, ending) in English and Arabic, to check they look alike.
# Run from the project root, with a save path that is not the real one:
#   KHAIR_SAVE=<scratch>/win_save.json KHAIR_SHOTS=<scratch>/shots Godot --path . --resolution 1688x780 -s tools/window_shots.gd --quit-after 20000

extends SceneTree

var out: String = ""

func _init() -> void:
	_run()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(out.path_join(name + ".png"))
	print("SHOT ", name)

func _close_talk() -> void:
	var dialogue: DialogueBox = current_scene.get_node("UI/Dialogue") as DialogueBox
	dialogue.call("_close_offer")
	dialogue.visible = false
	current_scene.get_node("Systems/Activities").set("_shop", "")
	await create_timer(0.3).timeout

func _run() -> void:
	out = OS.get_environment("KHAIR_SHOTS")
	if out == "":
		out = ProjectSettings.globalize_path("user://window_shots/")
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://src/scenes/world/main/MainGame.tscn")
	for i: int in 6:
		await process_frame
	await create_timer(0.8).timeout
	var title: TitleMenu = null
	for c: Node in current_scene.get_node("UI").get_children():
		if c is TitleMenu:
			title = c
	Locale.language = "en"
	title.call("_redraw_buttons")
	await create_timer(0.4).timeout
	await _shot("title_en")
	title.call("_toggle_language")
	await create_timer(0.4).timeout
	await _shot("title_ar")
	title.call("_toggle_language")
	title.call("_start_new")
	await create_timer(1.0).timeout
	var dialogue: DialogueBox = current_scene.get_node("UI/Dialogue") as DialogueBox
	await _shot("intro_en")
	for i: int in 8:
		if dialogue.visible:
			dialogue.call("_advance")
		await create_timer(0.3).timeout
	dialogue.visible = false
	var systems: Node = current_scene.get_node("Systems")
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var stead: Stead = systems.get_node("Stead") as Stead
	var activities: Activities = systems.get_node("Activities") as Activities
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	var hud: Node = current_scene.get_node("UI/HUD")
	(systems.get_node("Clock") as GameClock).set_process(false)
	systems.get_node("Letters").set_process(false)
	stead.flags["met_jassim"] = true
	activities.quest_done = true
	bag.dinars = 1420
	for item: String in ["turnips", "tomatoes", "fish", "wood", "stone", "dates", "eggs", "copper"]:
		bag.add_item(item, 5)
	for lang: String in ["en", "ar"]:
		Locale.language = lang
		stead.language = lang
		hud.call("refresh")
		loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "PlayerSpawn")
		await create_timer(1.2).timeout
		var player: Node2D = current_scene.find_child("Player", true, false) as Node2D
		player.global_position = Vector2(10, 22)
		await create_timer(0.5).timeout
		activities.talk_role("merchant")
		await create_timer(1.5).timeout
		await _shot("merchant_" + lang)
		activities.call("_on_shop_choice", "buy_seeds")
		await create_timer(1.0).timeout
		await _shot("seeds_" + lang)
		await _close_talk()
		activities.talk_role("elder")
		await create_timer(1.5).timeout
		await _shot("elder_" + lang)
		await _close_talk()
		activities.talk_role("workbench")
		await create_timer(1.0).timeout
		await _shot("workbench_" + lang)
		await _close_talk()
		hud.call("_toggle_menu")
		hud.call("_show_help")
		await create_timer(1.0).timeout
		await _shot("help_" + lang)
		dialogue.visible = false
		await create_timer(0.3).timeout
		hud.call("show_sale", "turnips", 3, 90, 2, 1510)
		await create_timer(1.0).timeout
		await _shot("sale_" + lang)
		hud.call("dismiss_sale")
		hud.call("_show_prayer_banner", Locale.t("prayer_now") % Locale.t("isha"))
		await create_timer(0.8).timeout
		await _shot("prayer_" + lang)
		var chest: Node = current_scene.get_node("UI/ChestPanel")
		chest.call("open_panel")
		await create_timer(0.8).timeout
		await _shot("chest_" + lang)
		chest.call("close_panel")
		await create_timer(0.3).timeout
		var fish: Node = current_scene.get_node("UI/FishGame")
		fish.call("start", "Harbor", "pier")
		await create_timer(0.6).timeout
		await _shot("fish_" + lang)
		fish.call("land")
		await create_timer(2.5).timeout
		hud.call("cover_for_sleep", Locale.t("sleep_tomorrow") if Locale.t("sleep_tomorrow") != "sleep_tomorrow" else "Tomorrow: clear skies.")
		await create_timer(1.0).timeout
		await _shot("sleep_" + lang)
		hud.call("uncover_sleep")
		await create_timer(0.6).timeout
	var ending: Node = current_scene.get_node("UI/Ending")
	ending.call("play")
	await create_timer(1.5).timeout
	await _shot("ending_ar")
	for i: int in 4:
		ending.call("advance")
		await create_timer(0.4).timeout
	await _shot("ending_ar_5")
	quit()
