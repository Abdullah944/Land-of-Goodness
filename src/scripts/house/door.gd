# src/scripts/house/door.gd
# Purpose: Asks the loader to open the next place.

extends Area2D

@export var next_scene: PackedScene
@export_file("*.tscn") var next_scene_path: String = ""
@export var spawn_name: String = "PlayerSpawn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var destination: PackedScene = next_scene
	if destination == null and next_scene_path != "":
		destination = load(next_scene_path) as PackedScene
	if destination == null:
		return
	var loader: LevelLoader = get_tree().current_scene.get_node("Systems/LevelLoader") as LevelLoader
	loader.go_to(destination, spawn_name)
