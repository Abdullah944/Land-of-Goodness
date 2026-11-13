# src/scripts/World/fish_spot.gd
# Purpose: Starts the fishing game when the boy reaches this water. It gives one fish a day.

extends Area2D

## A tap this close to the spot counts as a tap on this water.
const GOAL_REACH: float = 64.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	# Walking past on the way to somewhere else does not start fishing; only a tap on this water does.
	var player: Player = body as Player
	if player.has_tapped_cell and _goal_of(player).distance_to(global_position) > GOAL_REACH:
		return
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	activities.cast(get_parent().name)

func _goal_of(player: Player) -> Vector2:
	if player.walking_indoors:
		return player.tapped_point
	var dirt: TileMapLayer = player.find_dirt()
	return dirt.to_global(dirt.map_to_local(player.tapped_cell)) if dirt != null else player.global_position
