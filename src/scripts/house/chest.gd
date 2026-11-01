# src/scripts/house/chest.gd
# Purpose: Draws the chest and opens storage when the boy reaches it.

extends Node2D

const CHEST_PATH: String = "res://assets/building/house/Wooden storage chest.png"

var _picture: Texture2D
var _show_mark: bool = false

func _ready() -> void:
	_picture = load(CHEST_PATH) as Texture2D
	_add_body()
	queue_redraw()

func _process(_delta: float) -> void:
	z_index = 2000 + int(global_position.y)
	var player: Player = _player()
	var show_mark: bool = false
	if player != null and not player.busy:
		var feet: Vector2 = player.global_position + Vector2(0, 20)
		show_mark = feet.distance_to(foot_point()) <= 20.0
	if show_mark != _show_mark:
		_show_mark = show_mark
		queue_redraw()
	elif show_mark:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _show_mark:
		return
	var panel: Node = get_tree().current_scene.get_node_or_null("UI/ChestPanel")
	if panel != null and panel.has_method("is_open") and bool(panel.call("is_open")):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		open_storage()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if _picture == null:
		return
	var size: Vector2 = _picture.get_size()
	draw_texture(_picture, Vector2(-size.x * 0.5, -size.y))
	if not _show_mark:
		return
	var player: Player = _player()
	if player == null:
		return
	var at: Vector2 = to_local(player.global_position + Vector2(0, -20))
	draw_set_transform(at)
	var font: Font = ThemeDB.fallback_font
	draw_circle(Vector2.ZERO, 8, Color("fff3dc"))
	draw_arc(Vector2.ZERO, 8, 0, TAU, 16, Color("d9a441"), 1.0)
	var letter: Vector2 = font.get_string_size("E", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2(-letter.x * 0.5, letter.y * 0.35), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3f2d27"))
	draw_set_transform(Vector2.ZERO)

func _add_body() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(26, 16)
	shape_node.shape = shape
	shape_node.position = Vector2(2, -16)
	body.add_child(shape_node)
	add_child(body)

func covers_point(world_position: Vector2) -> bool:
	if _picture == null:
		return false
	var size: Vector2 = _picture.get_size()
	var rect: Rect2 = Rect2(global_position + Vector2(-size.x * 0.5, -size.y), size)
	return rect.grow(10.0).has_point(world_position)

func foot_point() -> Vector2:
	return global_position + Vector2(0, 12)

func open_storage() -> void:
	var dialogue: Node = get_tree().current_scene.get_node_or_null("UI/Dialogue")
	if dialogue != null and bool(dialogue.get("visible")):
		return
	var panel: Node = get_tree().current_scene.get_node_or_null("UI/ChestPanel")
	if panel != null and panel.has_method("open_panel"):
		panel.call("open_panel")

func _player() -> Player:
	return get_tree().current_scene.find_child("Player", true, false) as Player
