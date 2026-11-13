# tools/quran_shots.gd
# Purpose: Takes pictures of the Quran reader (the sura list in English and Arabic, and a few suras) to check the text.
# Run from the project root, with a save path that is not the real one:
#   KHAIR_SAVE=<scratch>/q_save.json KHAIR_SHOTS=<scratch>/q Godot --path . --resolution 1688x780 -s tools/quran_shots.gd --quit-after 12000

extends SceneTree

var out: String = ""

func _init() -> void:
	_run()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)

func _run() -> void:
	out = OS.get_environment("KHAIR_SHOTS")
	if out == "":
		out = ProjectSettings.globalize_path("user://quran_shots/")
	DirAccess.make_dir_recursive_absolute(out)
	print("SURAS ", QuranText.suras().size(), " VERSES ", QuranText.total_verses())
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
	var stead: Stead = current_scene.get_node("Systems/Stead") as Stead
	(current_scene.get_node("Systems/Clock") as GameClock).set_process(false)
	var loader: LevelLoader = current_scene.get_node("Systems/LevelLoader") as LevelLoader
	loader.go_to(load("res://src/scenes/world/mosque/Mosque_inside.tscn") as PackedScene, "PlayerSpawn")
	await create_timer(1.2).timeout
	await _shot("mosque_room")
	var reader: QuranReader = current_scene.get_node("UI/QuranReader") as QuranReader
	for lang: String in ["en", "ar"]:
		Locale.language = lang
		stead.language = lang
		reader.open()
		await create_timer(0.5).timeout
		await _shot("list_" + lang)
		reader.close()
	reader.open()
	for sura: int in [1, 2, 9, 95, 112]:
		reader.read(sura)
		await create_timer(0.6).timeout
		await _shot("sura_%d" % sura)
	reader.read(2)
	await create_timer(0.3).timeout
	(reader.get("_read_scroll") as ScrollContainer).scroll_vertical = 3000
	await create_timer(0.4).timeout
	await _shot("sura_2_middle")
	reader.close()
	reader.open()
	await create_timer(0.4).timeout
	await _shot("list_continue")
	quit()
