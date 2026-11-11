# tests/phone_check.gd
# Purpose: Runs inside a debug build on the phone and measures speed, memory and save safety on a side save.
# Run: copy a file named phone_check.txt holding "1" into the game's Documents folder, then open the game.
#      The report lands beside it as phone_check_report.txt. The player's own save is never opened.
#      With "2" in the file, close the game by force during the first launch; the second launch checks the save survived.

extends Node

const REPORT: String = "user://phone_check_report.txt"
const DAYS: int = 20
## A frame this long is a stutter the player can see.
const STUTTER_USEC: int = 34000
const STAY_MSEC: int = 1500
const PLACES: Array[String] = [
	"home/Home", "house/House_inside", "road/Road", "village/Village", "mosque/Mosque_inside",
	"workshop/Workshop_inside", "harbor/Harbor", "orchard/Orchard", "forest/Forest", "cave/Cave",
]

var passed: int = 0
var failed: int = 0
var _lines: PackedStringArray = []

func _ready() -> void:
	_run()

func _run() -> void:
	for i: int in 10:
		await get_tree().process_frame
	var main: Node = get_tree().current_scene
	var systems: Node = main.get_node("Systems")
	var save: SaveGame = systems.get_node("SaveGame") as SaveGame
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	clock.set_process(false)
	var resumed: bool = SaveGame.check_resumes and FileAccess.file_exists(REPORT)
	if resumed:
		_lines = FileAccess.get_file_as_string(REPORT).split("\n", false)
	_say("%s %s %s day=%d screen=%s save=%s" % ["RESUMED" if resumed else "START", OS.get_model_name(), Time.get_datetime_string_from_system(), clock.day, str(DisplayServer.screen_get_size()), save.path])
	check(save.path == SaveGame.CHECK_SAVE, "the check runs on its own save")
	if resumed:
		check(clock.day > 1, "after the game was killed the save still opens (day %d, from backup: %s)" % [clock.day, str(save.recovered)])
	# The biggest farm a player can have, with every square planted, is the heaviest the game gets.
	farm.farm_size = FarmField.LARGEST_SIZE
	for x: int in farm.farm_size.x:
		for y: int in farm.farm_size.y:
			farm.plots[farm._key(farm.farm_origin + Vector2i(x, y))] = {"tilled": true, "stage": (x + y) % 4, "watered": x % 2 == 0, "crop": "tomato", "sprinkler": false}
	farm.apply()
	bag.dinars = maxi(bag.dinars, 5000)
	for day: int in DAYS:
		var slowest: float = 999.0
		for place: String in PLACES:
			loader.go_to(load("res://src/scenes/world/%s.tscn" % place) as PackedScene, "PlayerSpawn")
			for i: int in 6:
				await get_tree().process_frame
			var frames: int = 0
			var worst: int = 0
			var stutters: int = 0
			var began: int = Time.get_ticks_msec()
			var last: int = Time.get_ticks_usec()
			while Time.get_ticks_msec() - began < STAY_MSEC:
				await get_tree().process_frame
				var now: int = Time.get_ticks_usec()
				worst = maxi(worst, now - last)
				if now - last > STUTTER_USEC:
					stutters += 1
				last = now
				frames += 1
			var fps: float = frames * 1000.0 / float(maxi(1, Time.get_ticks_msec() - began))
			slowest = minf(slowest, fps)
			if day == 0 or day == DAYS - 1 or stutters > 0 or fps < 57.0:
				_say("PLACE day=%d %s %s fps=%.1f worst_frame_ms=%.1f stutters=%d %s" % [clock.day, clock.weather, place.get_file(), fps, worst / 1000.0, stutters, _memory()])
		var before: int = Time.get_ticks_usec()
		save.write_now()
		var save_ms: float = (Time.get_ticks_usec() - before) / 1000.0
		_say("DAY %d %s slowest_fps=%.1f save_ms=%.1f %s" % [clock.day, clock.weather, slowest, save_ms, _memory()])
		check(slowest >= 50.0, "every place holds 50 frames a second on day %d (slowest %.1f)" % [clock.day, slowest])
		clock.sleep_now()
		clock.set_process(false)
		for i: int in 4:
			await get_tree().process_frame
	await _check_saves(save, bag)
	_say("DONE passed=%d failed=%d" % [passed, failed])
	if not OS.has_feature("mobile"):
		get_tree().quit(0 if failed == 0 else 1)

## The same save dangers as the desktop test, on the phone's own storage.
func _check_saves(save: SaveGame, bag: Inventory) -> void:
	var longest: float = 0.0
	var total: float = 0.0
	for i: int in 20:
		for wait: int in 20:
			await get_tree().process_frame
		var before: int = Time.get_ticks_usec()
		save.write_now()
		var took: float = (Time.get_ticks_usec() - before) / 1000.0
		longest = maxf(longest, took)
		total += took
	var size: int = FileAccess.get_file_as_bytes(save.path).size()
	_say("SAVE size_kb=%.1f average_ms=%.1f longest_ms=%.1f" % [size / 1024.0, total / 20.0, longest])
	check(longest < 50.0, "a save on the biggest farm takes under 50 ms (%.1f)" % longest)
	bag.dinars = 4321
	save.write_now()
	save.write_now()
	_spoil(save.path, "{\"bag\": {\"dinars\": 12")
	bag.dinars = 0
	check(save.load_game() and save.recovered and bag.dinars == 4321, "a save cut off in the middle recovers from the backup")
	save.write_now()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	bag.dinars = 0
	check(save.load_game() and bag.dinars == 4321, "a save that went missing recovers from the backup")
	save.write_now()
	_spoil(save.path + ".tmp", "half a file")
	save.write_now()
	bag.dinars = 0
	check(save.load_game() and not save.recovered and bag.dinars == 4321, "a leftover half-written file does no harm")
	var real: String = SaveGame.PATH
	check(save.path != real, "the player's own save was never the target")

func _spoil(file_path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()

func _memory() -> String:
	return "static_mb=%.1f peak_mb=%.1f video_mb=%.1f nodes=%d orphans=%d objects=%d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	]

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		_say("FAIL %s" % label)

func _say(line: String) -> void:
	print("PHONE_CHECK %s" % line)
	_lines.append(line)
	var file: FileAccess = FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines) + "\n")
		file.close()
