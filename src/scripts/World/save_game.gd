# src/scripts/World/save_game.gd
# Purpose: Writes the field, the bag, and the day, then reads them back.

class_name SaveGame
extends Node

const PATH: String = "user://land_of_khair.json"

var saved_position: Vector2 = Vector2.ZERO
var has_position: bool = false

func write_now() -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var player: Player = main.get_node_or_null("Player") as Player
	if player != null and player.find_dirt() != null:
		saved_position = player.global_position
		has_position = true
	var farm: Variant = get_parent().get_node("FarmField")
	var inventory: Variant = get_parent().get_node("Inventory")
	var clock: Variant = get_parent().get_node("Clock")
	var activities: Variant = get_parent().get_node("Activities")
	var data: Dictionary = {
		"plots": farm.export_plots(),
		"bag": inventory.to_data(),
		"clock": clock.to_data(),
		"activities": activities.to_data(),
		"x": saved_position.x,
		"y": saved_position.y,
		"has_position": has_position,
	}
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))

func load_game() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	var farm: Variant = get_parent().get_node("FarmField")
	var inventory: Variant = get_parent().get_node("Inventory")
	var clock: Variant = get_parent().get_node("Clock")
	var activities: Variant = get_parent().get_node("Activities")
	farm.import_plots(data.get("plots", []))
	inventory.from_data(data.get("bag", {}))
	clock.from_data(data.get("clock", {}))
	activities.from_data(data.get("activities", {}))
	has_position = bool(data.get("has_position", false))
	saved_position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	return true
