# src/scripts/farm/field_soil.gd
# Purpose: Draws every soil square of the field in one pass, so a big field costs one drawing instead of hundreds of sprites.

extends Node2D

## [middle of the square, picture] for each square.
var squares: Array = []

func _draw() -> void:
	for square: Array in squares:
		var picture: Texture2D = square[1]
		draw_texture(picture, Vector2(square[0]) - picture.get_size() * 0.5)
