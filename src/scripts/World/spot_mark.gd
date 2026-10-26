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

func _ready() -> void:
	if group_name != "":
		add_to_group(group_name)
	if person == null:
		return
	if fit_pixels > 0:
		_picture = _fit(person, fit_pixels)
	else:
		_picture = person
	queue_redraw()

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
