# scripts/player/state_machine/tool_state.gd
# Purpose: Plays one tool animation, then returns to Idle.

extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D
@export var animation_prefix: String = "hoe_"

var _used: bool = false

func _on_enter() -> void:
	_used = false
	var swing: String = animation_prefix + player.facing
	if animated_sprite_2d.sprite_frames.has_animation(swing):
		animated_sprite_2d.play(swing)

func _on_next_transitions() -> void:
	var swing: String = animation_prefix + player.facing
	if animated_sprite_2d.animation == swing and animated_sprite_2d.is_playing():
		return
	_finish()

func _finish() -> void:
	if not _used:
		_used = true
		if animation_prefix == "water_":
			_use_cell(true)
		elif animation_prefix == "hoe_":
			_use_cell(false)
		elif animation_prefix == "axe_":
			_swing("wood")
		elif animation_prefix == "pick_":
			_swing("stone")
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

func _swing(kind: String) -> void:
	var dirt: TileMapLayer = player.find_dirt()
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	var cell: Vector2i = player.tapped_cell
	player.has_tapped_cell = false
	if dirt == null:
		return
	var cut: bool = activities.chop_at(dirt, cell) if kind == "wood" else activities.mine_at(dirt, cell)
	if cut:
		return
	activities.note = "Nothing to cut." if kind == "wood" else "Nothing to mine."