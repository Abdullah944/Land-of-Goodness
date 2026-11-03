# addons/khair_hd/hd_picture.gd
# Purpose: A painted HD picture that tells the game its smaller game size.
# The file is kept small (lossless WebP inside "source"); the full detail goes to the screen.

@tool
class_name HdPicture
extends ImageTexture

@export var source: PortableCompressedTexture2D:
	set(value):
		source = value
		_apply()
@export var game_size: Vector2 = Vector2.ZERO:
	set(value):
		game_size = value
		_apply()

## True while the importer writes the file, so the full picture is not stored a second time.
static var saving: bool = false

func _apply() -> void:
	if saving or source == null or game_size == Vector2.ZERO:
		return
	set_image(source.get_image())
	set_size_override(Vector2i(int(round(game_size.x)), int(round(game_size.y))))
