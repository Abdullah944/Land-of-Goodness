# scripts/player/state_machine/tool_state.gd
# Purpose: Plays one tool animation, then returns to Idle.

extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D
@export var animation_prefix: String = "hoe_"

func _on_enter() -> void:
	animated_sprite_2d.play(animation_prefix + player.facing)

func _on_next_transitions() -> void:
	if not animated_sprite_2d.is_playing():
		transition.emit("Idle")

func _on_exit() -> void:
	animated_sprite_2d.stop()
