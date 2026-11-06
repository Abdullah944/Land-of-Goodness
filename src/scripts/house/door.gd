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
	set_process(str(name).begins_with("Exit"))

const SIGN_PATH: String = "res://assets/props/signpost.png"
## The sign is drawn larger than its file's game size, so the name on the board can be read on a phone.
const SIGN_GROW: float = 1.75
## The gold arrow on the ground moves back and forth this far, so the way out catches the eye.
const ARROW_SWAY: float = 2.5
const SIGN_FONT: int = 11
## How much wider than its picture a sign may get for a long name.
const SIGN_STRETCH: float = 1.7
## Where the blank board sits on the signpost picture, as parts of its width and height.
const BOARD: Rect2 = Rect2(0.22, 0.21, 0.63, 0.25)

var _sign: Texture2D

## A small gold arrow at the way out, and a wooden signpost beside the path with the place's name painted on it.
func _draw() -> void:
	if not str(name).begins_with("Exit"):
		return
	var outward: Vector2 = _outward()
	var side: Vector2 = Vector2(-outward.y, outward.x)
	var sway: Vector2 = outward * sin(Time.get_ticks_msec() * 0.005) * ARROW_SWAY
	var tip: Vector2 = outward * 8.0 + sway
	var back: Vector2 = -outward * 2.0 + sway
	draw_colored_polygon(PackedVector2Array([tip, back + side * 8.0, back - side * 8.0]), UiStyle.GOLD)
	draw_polyline(PackedVector2Array([tip, back + side * 8.0, back - side * 8.0, tip]), UiStyle.DARK, 1.0)
	if str(name) != "Exit":
		# A path that leads up or down has the board pointing back at the path beside it.
		var points_left: bool = outward.x < -0.5 or (absf(outward.y) > 0.5 and side.x > 0.0)
		_draw_sign(sign_spot(), points_left)

## The sign stands inside the place, to one side of the path that leads out.
func sign_spot() -> Vector2:
	var outward: Vector2 = _outward()
	var side: Vector2 = Vector2(-outward.y, outward.x)
	return -outward * 48.0 + side * 30.0

func _outward() -> Vector2:
	return Vector2(signf(position.x), 0.0) if absf(position.x) > absf(position.y) else Vector2(0.0, signf(position.y))

func _draw_sign(foot: Vector2, points_left: bool) -> void:
	# Kept on the door: a picture loaded only for this draw would be freed before the frame shows it.
	if _sign == null:
		_sign = load(SIGN_PATH) as Texture2D
	var picture: Texture2D = _sign
	if picture == null:
		return
	var title: String = _title()
	var font: Font = Locale.font() if Locale.font() != null else ThemeDB.fallback_font
	# A small arrow on the board shows which way the path goes, even when the board itself points sideways.
	var mark: float = 6.0
	var size: Vector2 = picture.get_size() * SIGN_GROW
	# A long name makes the sign wider instead of the words smaller, up to a point.
	var wanted: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT).x + mark + 8.0
	size.x *= clampf(wanted / (size.x * BOARD.size.x), 1.0, SIGN_STRETCH)
	var box: Rect2 = Rect2(foot - Vector2(size.x * 0.5, size.y), size)
	UiStyle.draw_shadow(self, foot, size.x * 0.4)
	if points_left:
		draw_set_transform(Vector2(foot.x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(picture, box, false)
	draw_set_transform(Vector2.ZERO)
	var board: Rect2 = Rect2(box.position + box.size * BOARD.position, box.size * BOARD.size)
	if points_left:
		board.position.x = box.end.x - (board.position.x - box.position.x) - board.size.x
	var room: float = board.size.x - mark - 4.0
	var font_size: int = SIGN_FONT
	while font_size > 5 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	var width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left: float = board.get_center().x - (width + mark + 2.0) * 0.5
	var at: Vector2 = Vector2(left + mark + 2.0, board.get_center().y + font.get_ascent(font_size) * 0.35)
	draw_string_outline(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color(1.0, 0.93, 0.78, 0.9))
	draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("3a2210"))
	var outward: Vector2 = _outward()
	var side: Vector2 = Vector2(-outward.y, outward.x)
	var middle: Vector2 = Vector2(left + mark * 0.5, board.get_center().y)
	var arrow: PackedVector2Array = PackedVector2Array([middle + outward * 3.5, middle - outward * 2.5 + side * 3.0, middle - outward * 2.5 - side * 3.0])
	draw_colored_polygon(arrow, Color("3a2210"))

func _title() -> String:
	var stem: String = next_scene_path.get_file().get_basename().to_lower()
	return Locale.t("to_home" if stem == "" or next_scene_path.begins_with("uid://") else "to_" + stem)

func _process(_delta: float) -> void:
	queue_redraw()
	# The sign stands among trees and people, so it is drawn in the same order by its feet.
	if str(name) != "Exit":
		z_index = 2000 + int(global_position.y + sign_spot().y)

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var destination: PackedScene = next_scene
	if destination == null and next_scene_path != "":
		destination = load(next_scene_path) as PackedScene
	if destination == null:
		return
	var loader: LevelLoader = get_tree().current_scene.get_node("Systems/LevelLoader") as LevelLoader
	if loader.settling():
		# Just arrived: wait out the moment, then go only if the boy is still standing in the doorway.
		await get_tree().create_timer(loader.settle_left()).timeout
		if not is_instance_valid(self) or not is_inside_tree() or not overlaps_body(body):
			return
	loader.go_to(destination, spawn_name)
