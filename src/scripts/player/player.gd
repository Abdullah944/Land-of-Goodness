# scripts/player/player.gd
# Purpose: The boy. Walking and animations live in the states.


class_name Player
extends CharacterBody2D

@export var move_speed: float = 60.0
var facing: String = "Down"

func get_move_direction() -> Vector2:
	return Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
