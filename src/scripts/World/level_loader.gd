# src/scripts/World/level_loader.gd
# Purpose: Swaps the place inside World and keeps the same boy.

class_name LevelLoader
extends Node

var _busy: bool = false

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
	player.fit_camera()
	var farm: FarmField = main.get_node_or_null("Systems/FarmField") as FarmField
	if farm != null:
		farm.apply()
	var activities: Activities = main.get_node_or_null("Systems/Activities") as Activities
	if activities != null:
		activities.apply_gathered()
	var stead: Stead = main.get_node_or_null("Systems/Stead") as Stead
	if stead != null:
		stead.note_place(str(next_place.name))
		stead.apply_buildings()
	var save: SaveGame = main.get_node_or_null("Systems/SaveGame") as SaveGame
	if save != null:
		save.write_now()
	_busy = false
