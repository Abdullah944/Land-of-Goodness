# scripts/player/state_machine/idle_state.gd
# Purpose: Plays the standing animation and switches to Walk when he moves.

extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

func _on_physics_process(_delta: float) -> void:
	animated_sprite_2d.play("idle_" + player.facing)

func _on_next_transitions() -> void:
	if player.wants_water:
		player.wants_water = false
		transition.emit("Water")
		return
	if player.wants_hoe:
		player.wants_hoe = false
		transition.emit("Hoe")
		return
	var direction: Vector2 = player.get_move_direction()
	if direction != Vector2.ZERO:
		player.cancel_tap()
		transition.emit("Walk")
		return
	if Input.is_action_just_pressed("use_tool"):
		transition.emit("Hoe")
		return
	if Input.is_action_just_pressed("water"):
		transition.emit("Water")
		return
	if player.has_tapped_cell:
		var dirt: TileMapLayer = player.find_dirt()
		if dirt != null and player.tool == "" and player.reached_walk_spot(dirt):
			player.cancel_tap()
			return
		if dirt != null and player.tool != "" and player.is_within_reach(dirt):
			player.face_cell(dirt, player.tapped_cell)
			player.ask_for_tool()
			return
		transition.emit("Walk")
