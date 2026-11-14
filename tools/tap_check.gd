# tools/tap_check.gd
# Purpose: Plays the tools the way a player does, by tapping the world, and checks each one works:
# hoe, seeds, watering can, axe on a tree's leaves, pickaxe, hand on a weed, axe on twigs, and in the forest
# trees and stones (one far across the lake, to check the boy finds his way). Also times the first answer to a tap.
# Run from the project root, headless, with a save path that is not the real one:
#   KHAIR_SAVE=<scratch>/tap_save.json Godot --headless --path . -s tools/tap_check.gd

extends SceneTree

var player: Player
var bag: Inventory
var passed: int = 0
var failed: int = 0

func _init() -> void:
	_run()

func _tap(point: Vector2, seconds: float = 8.0) -> void:
	player.set_walk_target(point)
	var waited: float = 0.0
	while waited < seconds:
		await create_timer(0.25).timeout
		waited += 0.25
		if not player.has_tapped_cell and waited > 1.0:
			break
	await create_timer(0.6).timeout

func _say(ok: bool, what: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print(("PASS " if ok else "FAIL ") + what)

func _leaves(node: Node2D) -> Vector2:
	var rect: Rect2 = node.call("_sprite_rect")
	return rect.position + rect.size * Vector2(0.5, 0.3)

func _run() -> void:
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
	(systems.get_node("Clock") as GameClock).set_process(false)
	systems.get_node("Letters").set_process(false)
	var activities: Activities = systems.get_node("Activities") as Activities
	activities.quest_done = true
	(systems.get_node("Stead") as Stead).flags["met_jassim"] = true
	bag = systems.get_node("Inventory") as Inventory
	var farm: FarmField = systems.get_node("FarmField") as FarmField
	player = current_scene.find_child("Player", true, false) as Player
	var place: Node = activities.place_node()
	var dirt: TileMapLayer = player.find_dirt()
	# Field: hoe, plant, water. The hoe's work should land well before a second has passed.
	var cell: Vector2i = farm.farm_origin + Vector2i(5, 4)
	var spot: Vector2 = dirt.to_global(dirt.map_to_local(cell))
	player.global_position = spot + Vector2(0, -36)
	await create_timer(0.3).timeout
	var rings_before: int = _rings(place)
	player.set_walk_target(spot)
	await process_frame
	_say(_rings(place) > rings_before, "a tap shows a ring at once")
	var started: int = Time.get_ticks_msec()
	while farm.state_of(cell) != "tilled" and Time.get_ticks_msec() - started < 4000:
		await process_frame
	print("HOE tilled after %d ms (walk included)" % (Time.get_ticks_msec() - started))
	_say(farm.state_of(cell) == "tilled", "tap grass in the field: the hoe tills it")
	await create_timer(0.8).timeout
	bag.selected_seed = "turnip"
	await _tap(spot)
	_say(farm.state_of(cell) in ["planted", "growing", "watered"], "tap the tilled square: a seed is planted (%s)" % farm.state_of(cell))
	await _tap(spot)
	_say(farm.state_of(cell) == "watered", "tap the planted square: the can waters it (%s)" % farm.state_of(cell))
	for name: String in ["Tree", "Tree2"]:
		var tree: Node2D = place.get_node_or_null(name) as Node2D
		var wood: int = bag.count_of("wood")
		await _tap(_leaves(tree))
		_say(bag.count_of("wood") > wood, "tap the leaves of the farm %s: the axe cuts it" % name)
	var rock: Node2D = place.get_node_or_null("ZoneRock0") as Node2D
	if rock != null:
		var stone: int = bag.count_of("stone")
		var rect: Rect2 = rock.call("_sprite_rect")
		# Just off the small rock's picture: the bigger tap area still catches it.
		await _tap(rect.get_center() + Vector2(rect.size.x * 0.5 + 4.0, 0))
		_say(bag.count_of("stone") > stone, "tap just beside a small rock: the pickaxe still breaks it")
	for mark: Node in place.get_children():
		if mark.is_in_group("debris_weed") and (mark as Node2D).global_position.distance_to(player.global_position) < 400.0:
			await _tap((mark as Node2D).global_position)
			_say(not is_instance_valid(mark) or not mark.is_in_group("debris_weed"), "tap a weed: the hand pulls it")
			break
	for mark: Node in place.get_children():
		if mark.is_in_group("debris_wood") and (mark as Node2D).global_position.distance_to(player.global_position) < 400.0:
			var twigs_wood: int = bag.count_of("wood")
			await _tap((mark as Node2D).global_position)
			_say(bag.count_of("wood") > twigs_wood, "tap twigs: the axe clears them")
			break
	var loader: LevelLoader = systems.get_node("LevelLoader") as LevelLoader
	loader.go_to(load("res://src/scenes/world/forest/Forest.tscn") as PackedScene, "PlayerSpawn")
	await create_timer(1.5).timeout
	player = current_scene.find_child("Player", true, false) as Player
	place = activities.place_node()
	for name: String in ["Wood0", "Wood3", "Stone0", "Stone1", "Stone2"]:
		var thing: Node2D = place.get_node_or_null(name) as Node2D
		if thing == null:
			_say(false, "the forest has %s" % name)
			continue
		var item: String = "stone" if name.begins_with("Stone") else "wood"
		var before: int = bag.count_of(item)
		await _tap(_leaves(thing), 30.0)
		_say(bag.count_of(item) > before, "forest: tap %s's picture: %s %d -> %d" % [name, item, before, bag.count_of(item)])
	print("TAP_CHECK passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _rings(place: Node) -> int:
	var count: int = 0
	for child: Node in place.get_children():
		if child is Juice.TapRing:
			count += 1
	return count
