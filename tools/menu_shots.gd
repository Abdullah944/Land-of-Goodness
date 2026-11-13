# tools/menu_shots.gd
# Purpose: Takes a picture of every menu tab (bag, settings, quests, book, map) in English and Arabic,
# once at the start of a new game and once with a full bag, to check how the menu looks.
# Run from the project root, with a save path that is not the real one:
#   KHAIR_SAVE=<scratch>/menu_save.json Godot --path . --resolution 1688x780 -s tools/menu_shots.gd --quit-after 12000
# Set KHAIR_SHOTS to the folder for the pictures (default: user://menu_shots/).

extends SceneTree

var out: String = ""

func _init() -> void:
	_run()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(out.path_join(name + ".png"))
	print("SHOT ", name, " ", image.get_size())

func _tabs(hud: Node, prefix: String) -> void:
	hud.call("_toggle_menu")
	for tab: String in ["bag", "settings", "quests", "book", "map"]:
		hud.call("_show_tab", tab)
		await create_timer(0.5).timeout
		await _shot("%s_%s" % [prefix, tab])
		if tab == "book":
			hud.call("_turn_book", 3)
			await create_timer(0.4).timeout
			await _shot("%s_book_cave" % prefix)
			hud.call("_turn_book", -3)
	hud.call("_toggle_menu")
	await create_timer(0.2).timeout

func _run() -> void:
	out = OS.get_environment("KHAIR_SHOTS")
	if out == "":
		out = ProjectSettings.globalize_path("user://menu_shots/")
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
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	var stead: Stead = systems.get_node("Stead") as Stead
	var hud: Node = current_scene.get_node("UI/HUD")
	(systems.get_node("Clock") as GameClock).set_process(false)
	systems.get_node("Letters").set_process(false)
	for lang: String in ["en", "ar"]:
		Locale.language = lang
		stead.language = lang
		hud.call("refresh")
		await _tabs(hud, "new_" + lang)
	stead.flags["met_jassim"] = true
	bag.dinars = 1420
	for item: String in ["turnip_seeds", "tomato_seeds", "turnips", "tomatoes", "wheat", "watermelons", "onions", "fish", "maid", "safi", "wood", "stone", "dates", "forage", "eggs", "milk", "copper", "feed", "pearl"]:
		bag.add_item(item, 3)
	for lang: String in ["en", "ar"]:
		Locale.language = lang
		stead.language = lang
		hud.call("refresh")
		await _tabs(hud, "full_" + lang)
	quit()
