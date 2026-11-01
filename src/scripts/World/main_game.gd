# src/scripts/World/main_game.gd
# Purpose: Puts the boy on the current place's spawn point.

extends Node

@onready var player: Player = $World/Player

func _ready() -> void:
	var save: SaveGame = get_node("Systems/SaveGame") as SaveGame
	var loaded: bool = save.load_game()
	var farm: FarmField = get_node("Systems/FarmField") as FarmField
	var stead: Stead = get_node_or_null("Systems/Stead") as Stead
	if stead != null:
		Locale.language = stead.language
		stead.apply_buildings()
	farm.apply()
	if loaded and stead != null and stead.place_name != "Home" and stead.scene_for(stead.place_name) != "":
		var loader: LevelLoader = get_node("Systems/LevelLoader") as LevelLoader
		var destination: PackedScene = load(stead.scene_for(stead.place_name)) as PackedScene
		if destination != null:
			loader.go_to(destination, "PlayerSpawn")
			return
	if loaded and save.has_position:
		player.global_position = save.saved_position
	else:
		var spawn: Marker2D = _find_spawn()
		if spawn:
			player.global_position = spawn.global_position

func _find_spawn() -> Marker2D:
	var world: Node = get_node("World")
	for place: Node in world.get_children():
		var found: Node = place.get_node_or_null("PlayerSpawn")
		if found is Marker2D:
			return found
	return null
