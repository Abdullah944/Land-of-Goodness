# src/scripts/house/door.gd
# Purpose: Asks the loader to open the next place.

extends Area2D

@export var next_scene: PackedScene
@export_file("*.tscn") var next_scene_path: String = ""
@export var spawn_name: String = "PlayerSpawn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if str(name).begins_with("Exit") or str(name) == "Entrance":
		z_index = 1900
		queue_redraw()

## A gold arrow and the place's name, so the way out can be found without a map.
func _draw() -> void:
	if not str(name).begins_with("Exit"):
		return
	var outward: Vector2 = Vector2(signf(position.x), 0.0) if absf(position.x) > absf(position.y) else Vector2(0.0, signf(position.y))
	var side: Vector2 = Vector2(-outward.y, outward.x)
	var tip: Vector2 = outward * 8.0
	draw_colored_polygon(PackedVector2Array([tip, -outward * 2.0 + side * 8.0, -outward * 2.0 - side * 8.0]), UiStyle.GOLD)
	draw_polyline(PackedVector2Array([tip, -outward * 2.0 + side * 8.0, -outward * 2.0 - side * 8.0, tip]), UiStyle.DARK, 1.0)
	var stem: String = next_scene_path.get_file().get_basename().to_lower()
	var title: String = Locale.t("to_home" if stem == "" or next_scene_path.begins_with("uid://") else "to_" + stem)
	var font: Font = ThemeDB.fallback_font
	var at: Vector2 = Vector2(-font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x * 0.5, -14.0)
	draw_string_outline(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, UiStyle.DARK)
	draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiStyle.CREAM)

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
