# scripts/player/state_machine/tool_state.gd
# Purpose: Plays one tool animation, then returns to Idle.

extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D
@export var animation_prefix: String = "hoe_"

var _used: bool = false

func _on_enter() -> void:
	_used = false
	animated_sprite_2d.play(animation_prefix + player.facing)

func _on_next_transitions() -> void:
	if animated_sprite_2d.is_playing():
		return
	if not _used:
		_used = true
		if animation_prefix == "water_":
			_use_cell(true)
		elif animation_prefix == "hoe_":
			_use_cell(false)
	transition.emit("Idle")

func _on_exit() -> void:
	animated_sprite_2d.stop()

func _use_cell(watering_only: bool) -> void:
	var dirt: TileMapLayer = player.find_dirt()
	if dirt == null:
		player.has_tapped_cell = false
		return
	var cell: Vector2i = player.get_action_cell(dirt)
	player.has_tapped_cell = false
	var farm: FarmField = get_tree().current_scene.get_node("Systems/FarmField") as FarmField
	farm.work(dirt, cell, watering_only)