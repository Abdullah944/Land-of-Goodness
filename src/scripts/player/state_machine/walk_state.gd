# scripts/player/state_machine/walk_state.gd
# Purpose: Moves the boy, plays the walk animation, and returns to Idle when he stops.

extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

func _on_physics_process(_delta: float) -> void:
	var keys: Vector2 = player.get_move_direction()
	var direction: Vector2 = _move_direction()
	if direction.length() > 1.0:
		direction = direction.normalized()
	_set_facing(direction, keys != Vector2.ZERO)
	if direction != Vector2.ZERO:
		var anim: String = "walk_" + player.facing
		if animated_sprite_2d.animation != anim or not animated_sprite_2d.is_playing():
			animated_sprite_2d.play(anim)
	player.velocity = direction * player.move_speed
	player.move_and_slide()

func _set_facing(direction: Vector2, from_keys: bool) -> void:
	if direction == Vector2.ZERO:
		return
	var sideways: bool = from_keys or absf(direction.x) > absf(direction.y)
	if sideways and direction.x < 0.0:
		player.facing = "Left"
	elif sideways and direction.x > 0.0:
		player.facing = "Right"
	elif direction.y < 0.0:
		player.facing = "Up"
	elif direction.y > 0.0:
		player.facing = "Down"

func _move_direction() -> Vector2:
	var keys: Vector2 = player.get_move_direction()
	if keys != Vector2.ZERO:
		player.cancel_tap()
		return keys
	if player.busy or not player.has_tapped_cell:
		return Vector2.ZERO
	var dirt: TileMapLayer = player.find_dirt()
	if dirt == null:
		player.cancel_tap()
		return Vector2.ZERO
	if player.tool == "":
		if player.reached_walk_spot(dirt) or player.distance_to_cell(dirt, player.tapped_cell) <= 8.0:
			player.cancel_tap()
			return Vector2.ZERO
		return player.direction_to_cell(dirt, player.tapped_cell)
	if player.is_within_reach(dirt):
		player.face_cell(dirt, player.tapped_cell)
		player.ask_for_tool()
		return Vector2.ZERO
	return player.direction_to_cell(dirt, player.tapped_cell)

func _on_next_transitions() -> void:
	if player.wants_water:
		player.wants_water = false
		transition.emit("Water")
		return
	if player.wants_hoe:
		player.wants_hoe = false
		transition.emit("Hoe")
		return
	if player.wants_axe:
		player.wants_axe = false
		transition.emit("Axe")
		return
	if player.wants_pick:
		player.wants_pick = false
		transition.emit("Pick")
		return
	if player.has_tapped_cell:
		return
	if player.get_move_direction() == Vector2.ZERO:
		transition.emit("Idle")
