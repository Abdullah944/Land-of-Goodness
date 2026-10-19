# scripts/player/state_machine/node_state.gd
# Purpose: One state. Idle and Walk will extend this.

class_name NodeState
extends Node

@warning_ignore("unused_signal")
signal transition(next_state: String)

func _on_process(_delta: float) -> void:
	pass

func _on_physics_process(_delta: float) -> void:
	pass

func _on_next_transitions() -> void:
	pass

func _on_enter() -> void:
	pass

func _on_exit() -> void:
	pass
