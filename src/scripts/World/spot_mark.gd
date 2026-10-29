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

var _picture: Texture2D
var _player: Player

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
	queue_redraw()

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
		draw_texture_rect(_picture, Rect2(origin, size), false)
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
