# scripts/player/state_machine/walk_state.gd
# Purpose: Moves the boy, plays the walk animation, and returns to Idle when he stops.

extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

func _on_physics_process(_delta: float) -> void:
	var direction: Vector2 = player.get_move_direction()
	if direction.length() > 1.0:
		direction = direction.normalized()

	if direction.x < 0.0:
		player.facing = "Left"
	elif direction.x > 0.0:
		player.facing = "Right"
	elif direction.y < 0.0:
		player.facing = "Up"
	elif direction.y > 0.0:
		player.facing = "Down"

	if direction != Vector2.ZERO:
		animated_sprite_2d.play("walk_" + player.facing)

	player.velocity = direction * player.move_speed
	player.move_and_slide()

func _on_next_transitions() -> void:
	var direction: Vector2 = player.get_move_direction()
	if direction == Vector2.ZERO:
		transition.emit("Idle")
