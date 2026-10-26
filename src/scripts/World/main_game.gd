# src/scripts/World/main_game.gd
# Purpose: Puts the boy on the current place's spawn point.

extends Node

@onready var player: Player = $Player

func _ready() -> void:
	var save: SaveGame = get_node("Systems/SaveGame") as SaveGame
	var loaded: bool = save.load_game()
	var farm: FarmField = get_node("Systems/FarmField") as FarmField
	farm.apply()
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
