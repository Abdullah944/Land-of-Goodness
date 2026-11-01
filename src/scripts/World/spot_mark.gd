# src/scripts/World/spot_mark.gd
# Purpose: Draws a picture, or a small colored mark, on one farm spot.

extends Node2D

@export var mark_color: Color = Color("fff3dc")
@export var title: String = ""
@export var group_name: String = ""
@export var person: Texture2D
@export var person_scale: float = 1.0
@export var stand_on_feet: bool = false
@export var fit_pixels: int = 0
@export var role: String = ""
## Solid footprint at the feet. Zero means the boy walks through.
@export var block_size: Vector2 = Vector2.ZERO

var bob: float = 0.0
var _picture: Texture2D
var _player: Player
var _show_talk: bool = false

func _ready() -> void:
	if group_name != "":
		add_to_group(group_name)
	if person == null:
		return
	if fit_pixels > 0:
		_picture = _fit(person, fit_pixels)
	else:
		_picture = person
	_block_tree()
	_block_footprint()
	queue_redraw()

func _block_footprint() -> void:
	if block_size == Vector2.ZERO:
		return
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Block"
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = block_size
	shape_node.shape = shape
	shape_node.position = Vector2(0, -block_size.y * 0.5) if stand_on_feet else Vector2.ZERO
	body.add_child(shape_node)
	add_child(body)

func _block_tree() -> void:
	if group_name != "tree" or _picture == null:
		return
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Block"
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	var trunk: Vector2 = Vector2(10, 6)
	shape.size = trunk
	shape_node.shape = shape
	shape_node.position = Vector2(0, -13)
	body.add_child(shape_node)
	add_child(body)

func _process(_delta: float) -> void:
	if _picture == null:
		return
	z_index = 2000 + int(global_position.y)
	if name == "Neighbor" or role != "":
		var show_talk: bool = _near_player()
		if show_talk != _show_talk or show_talk:
			_show_talk = show_talk
			queue_redraw()
	if group_name != "tree":
		return
	if _player == null or not is_instance_valid(_player):
		var scene: Node = get_tree().current_scene
		_player = scene.find_child("Player", true, false) as Player if scene != null else null
	if _player == null:
		return
	var feet_y: float = _player.global_position.y + 20.0
	var behind: bool = feet_y < global_position.y + 4.0
	var covered: bool = _sprite_rect().intersects(_player_rect())
	modulate.a = 0.45 if behind and covered else 1.0

func _unhandled_input(event: InputEvent) -> void:
	if not _show_talk:
		return
	if name != "Neighbor" and role == "":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
		if role != "":
			activities.talk_role(role)
		else:
			activities.call("_talk")
		get_viewport().set_input_as_handled()

func _near_player() -> bool:
	var player: Player = _hero()
	if player == null or player.busy:
		return false
	var feet: Vector2 = player.global_position + Vector2(0, 20)
	return feet.distance_to(global_position) <= 40.0

func _hero() -> Player:
	if _player != null and is_instance_valid(_player):
		return _player
	var scene: Node = get_tree().current_scene
	_player = scene.find_child("Player", true, false) as Player if scene != null else null
	return _player

func _draw_talk_mark() -> void:
	if not _show_talk:
		return
	var player: Player = _hero()
	if player == null:
		return
	var at: Vector2 = to_local(player.global_position + Vector2(0, -20))
	draw_set_transform(at)
	var font: Font = ThemeDB.fallback_font
	draw_circle(Vector2.ZERO, 8, Color("fff3dc"))
	draw_arc(Vector2.ZERO, 8, 0, TAU, 16, Color("d9a441"), 1.0)
	var size: Vector2 = font.get_string_size("E", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2(-size.x * 0.5, size.y * 0.35), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3f2d27"))
	draw_set_transform(Vector2.ZERO)

func _sprite_rect() -> Rect2:
	var size: Vector2 = _picture.get_size()
	if fit_pixels == 0:
		size *= person_scale
	var origin: Vector2 = Vector2(-size.x * 0.5, -size.y) if stand_on_feet else -size * 0.5
	return Rect2(to_global(origin), size)

func _player_rect() -> Rect2:
	return Rect2(_player.global_position - Vector2(10, 22), Vector2(20, 40))

func _draw() -> void:
	if _picture != null:
		var size: Vector2 = _picture.get_size()
		if fit_pixels == 0:
			size *= person_scale
		var origin: Vector2 = Vector2(-size.x * 0.5, -size.y) if stand_on_feet else -size * 0.5
		draw_texture_rect(_picture, Rect2(origin + Vector2(0, -bob), size), false)
		_draw_talk_mark()
		return
	draw_rect(Rect2(-8, -8, 16, 16), mark_color)
	if title != "":
		draw_string(ThemeDB.fallback_font, Vector2(-16, -12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("3f2d27"))

func _fit(texture: Texture2D, pixels: int) -> Texture2D:
	var image: Image = texture.get_image()
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	var longest: int = maxi(image.get_width(), image.get_height())
	var width: int = maxi(1, int(round(float(image.get_width()) * pixels / float(longest))))
	var height: int = maxi(1, int(round(float(image.get_height()) * pixels / float(longest))))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
