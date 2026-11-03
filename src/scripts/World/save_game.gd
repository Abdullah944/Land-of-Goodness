# src/scripts/World/save_game.gd
# Purpose: Writes the field, the bag, the chest, the day, and the farm progress, then reads them back.

class_name SaveGame
extends Node

const PATH: String = "user://land_of_khair.json"
const VERSION: int = 3

var path: String = PATH
var saved_position: Vector2 = Vector2.ZERO
var has_position: bool = false
## Set when the main file could not be read and the backup was used instead.
var recovered: bool = false

func _ready() -> void:
	var override_path: String = OS.get_environment("KHAIR_SAVE")
	if override_path != "":
		path = override_path

## A phone can close the game at any moment, so save when it goes to the background.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED and what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	var title: Node = scene.get_node_or_null("UI/TitleMenu") if scene != null else null
	if title == null or bool(title.call("is_open")):
		return
	write_now()

func backup_path() -> String:
	return path.get_basename() + ".backup.json"

func write_now() -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var player: Player = main.find_child("Player", true, false) as Player
	if player != null and player.find_dirt() != null:
		saved_position = player.global_position
		has_position = true
	var farm: Variant = get_parent().get_node("FarmField")
	var inventory: Variant = get_parent().get_node("Inventory")
	var clock: Variant = get_parent().get_node("Clock")
	var activities: Variant = get_parent().get_node("Activities")
	var chest: Variant = get_parent().get_node("ChestStore")
	var stead: Variant = get_parent().get_node_or_null("Stead")
	var data: Dictionary = {
		"version": VERSION,
		"plots": farm.export_plots(),
		"bag": inventory.to_data(),
		"chest": chest.to_data(),
		"clock": clock.to_data(),
		"activities": activities.to_data(),
		"x": saved_position.x,
		"y": saved_position.y,
		"has_position": has_position,
	}
	if stead != null:
		data["stead"] = stead.to_data()
	var kindness: Variant = get_parent().get_node_or_null("Kindness")
	if kindness != null:
		data["kindness"] = kindness.to_data()
	var works: Variant = get_parent().get_node_or_null("VillageWorks")
	if works != null:
		data["works"] = works.to_data()
	for system: String in ["Friendship", "Festivals"]:
		var part: Node = get_parent().get_node_or_null(system)
		if part != null:
			data[system.to_lower()] = part.call("to_data")
	_write_safely(JSON.stringify(data))

## Writes a temporary file, keeps the last good save as a backup, then swaps the new file in.
func _write_safely(text: String) -> void:
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
	var global_path: String = ProjectSettings.globalize_path(path)
	var global_temp: String = ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(path) and _read_dictionary(path) != null:
		DirAccess.copy_absolute(global_path, ProjectSettings.globalize_path(backup_path()))
	DirAccess.rename_absolute(global_temp, global_path)

func load_game() -> bool:
	recovered = false
	var data: Variant = _read_dictionary(path)
	if data == null and FileAccess.file_exists(path):
		_keep_damaged_copy()
		data = _read_dictionary(backup_path())
		recovered = data != null
	if data == null:
		return false
	_apply(data)
	return true

## Starts a new farm. The old save is copied aside first and never deleted.
func start_new(seed: Dictionary = {}) -> void:
	if FileAccess.file_exists(path):
		var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
		var keep: String = path.get_basename() + ".before-new-" + stamp + ".json"
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(keep))
	_write_safely(JSON.stringify(seed))

func _apply(data: Dictionary) -> void:
	var farm: Variant = get_parent().get_node("FarmField")
	var inventory: Variant = get_parent().get_node("Inventory")
	var clock: Variant = get_parent().get_node("Clock")
	var activities: Variant = get_parent().get_node("Activities")
	var chest: Variant = get_parent().get_node("ChestStore")
	var stead: Variant = get_parent().get_node_or_null("Stead")
	var plots: Variant = data.get("plots", [])
	farm.import_plots(plots if plots is Array else [])
	inventory.from_data(_section(data, "bag"))
	chest.from_data(_section(data, "chest"))
	clock.from_data(_section(data, "clock"))
	activities.from_data(_section(data, "activities"))
	if stead != null:
		stead.from_data(_section(data, "stead"))
	var kindness: Variant = get_parent().get_node_or_null("Kindness")
	if kindness != null:
		kindness.from_data(_section(data, "kindness"))
	var works: Variant = get_parent().get_node_or_null("VillageWorks")
	if works != null:
		works.from_data(_section(data, "works"))
	for system: String in ["Friendship", "Festivals"]:
		var part: Node = get_parent().get_node_or_null(system)
		if part != null:
			part.call("from_data", _section(data, system.to_lower()))
	has_position = bool(data.get("has_position", false))
	saved_position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))

func _section(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	return value if value is Dictionary else {}

func _read_dictionary(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

func _keep_damaged_copy() -> void:
	var keep: String = path.get_basename() + ".damaged.json"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(keep))
