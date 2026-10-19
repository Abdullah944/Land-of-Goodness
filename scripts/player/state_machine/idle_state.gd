# scripts/player/state_machine/idle_state.gd
# Purpose: Plays the standing animation and switches to Walk when he moves.

extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

func _on_physics_process(_delta: float) -> void:
	animated_sprite_2d.play("idle_" + player.facing)

func _on_next_transitions() -> void:
	var direction: Vector2 = player.get_move_direction()
	if direction == Vector2.ZERO and Input.is_action_just_pressed("use_tool"):
		transition.emit("Hoe")
		return
	if direction == Vector2.ZERO and Input.is_action_just_pressed("water"):
		transition.emit("Water")
		return
	if direction != Vector2.ZERO:
		transition.emit("Walk")
