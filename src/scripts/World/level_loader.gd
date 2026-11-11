# src/scripts/World/level_loader.gd
# Purpose: Swaps the place inside World and keeps the same boy.

class_name LevelLoader
extends Node

## A door does nothing this long after the boy arrives, so he can't bounce straight back out.
const SETTLE_MS: int = 700

var _busy: bool = false
var _arrived_at: int = -SETTLE_MS

func go_to(next_scene: PackedScene, spawn_name: String = "PlayerSpawn") -> void:
	if _busy or next_scene == null:
		return
	_busy = true
	call_deferred("_swap_place", next_scene, spawn_name)

func _swap_place(next_scene: PackedScene, spawn_name: String) -> void:
	var main: Node = get_tree().current_scene
	var chest_panel: Node = main.get_node_or_null("UI/ChestPanel")
	if chest_panel != null and chest_panel.has_method("close_panel"):
		chest_panel.call("close_panel")
	var world: Node = main.get_node("World")
	var player: Player = main.find_child("Player", true, false) as Player
	for place: Node in world.get_children():
		if place == player:
			continue
		world.remove_child(place)
		place.queue_free()
	var next_place: Node = next_scene.instantiate()
	world.add_child(next_place)
	var gulf: CanvasItem = next_place.get_node_or_null("Gulf") as CanvasItem
	if gulf != null:
		var sea: ShaderMaterial = ShaderMaterial.new()
		sea.shader = load("res://src/shaders/water_scroll.gdshader") as Shader
		gulf.material = sea
	var spawn: Node = next_place.get_node_or_null(spawn_name)
	if spawn is Marker2D:
		player.global_position = spawn.global_position
	# A walk the boy started in the last place ends at the door; it must not carry on in the new one.
	player.cancel_tap()
	player.velocity = Vector2.ZERO
	_arrived_at = Time.get_ticks_msec()
	player.fit_camera()
	var farm: FarmField = main.get_node_or_null("Systems/FarmField") as FarmField
	if farm != null:
		farm.apply()
	var activities: Activities = main.get_node_or_null("Systems/Activities") as Activities
	if activities != null:
		activities.apply_gathered()
	var stead: Stead = main.get_node_or_null("Systems/Stead") as Stead
	if stead != null:
		# A door is heard when the boy steps into a room or back out of one.
		var bank: SoundBank = main.get_node_or_null("Systems/SoundBank") as SoundBank
		if bank != null and (stead.place_name in SoundBank.ROOMS or str(next_place.name) in SoundBank.ROOMS):
			bank.play("door")
		stead.note_place(str(next_place.name))
		stead.apply_buildings()
	var save: SaveGame = main.get_node_or_null("Systems/SaveGame") as SaveGame
	if save != null:
		save.write_now()
	_busy = false
	_warm_rooms(next_place)

## True for a moment after each arrival, while doors wait.
func settling() -> bool:
	return Time.get_ticks_msec() - _arrived_at < SETTLE_MS

func settle_left() -> float:
	return maxf(0.0, float(SETTLE_MS - (Time.get_ticks_msec() - _arrived_at)) / 1000.0)

## Rooms behind this place's doors load in the background, so stepping inside doesn't stall.
func _warm_rooms(place: Node) -> void:
	for child: Node in place.get_children():
		var path: Variant = child.get("next_scene_path")
		if path != null and str(path).contains("_inside") and not ResourceLoader.has_cached(str(path)):
			ResourceLoader.load_threaded_request(str(path))
