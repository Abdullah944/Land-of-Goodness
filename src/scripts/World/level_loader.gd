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
	var world: Node = main.get_node("World")
	var player: Player = main.find_child("Player", true, false) as Player
	for place: Node in world.get_children():
		if place == player:
			continue
		world.remove_child(place)
		place.queue_free()
	var next_place: Node = next_scene.instantiate()
	world.add_child(next_place)
	var spawn: Node = next_place.get_node_or_null(spawn_name)
	if spawn is Marker2D:
		player.global_position = spawn.global_position
	var farm: FarmField = main.get_node_or_null("Systems/FarmField") as FarmField
	if farm != null:
		farm.apply()
	_busy = false
