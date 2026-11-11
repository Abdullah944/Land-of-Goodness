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
		if not _rested():
			transition.emit("Idle")
			return
		_chime()
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

func _rested() -> bool:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	if (systems.get_node("Inventory") as Inventory).tire():
		return true
	player.cancel_tap()
	(systems.get_node("Activities") as Activities).note = Locale.t("tired")
	(systems.get_node("SoundBank") as SoundBank).play("no")
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud != null and hud.has_method("nudge_hearts"):
		hud.call("nudge_hearts")
	return false

func _chime() -> void:
	var bank: Node = get_tree().current_scene.get_node_or_null("Systems/SoundBank")
	if bank != null:
		bank.call("play", {"water_": "water", "hoe_": "hoe", "axe_": "chop", "pick_": "mine"}.get(animation_prefix, "hoe"))
	var dirt: TileMapLayer = player.find_dirt()
	if dirt == null:
		return
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	var place: Node = activities.place_node()
	var cell: Vector2i = player.get_action_cell(dirt) if animation_prefix == "water_" or animation_prefix == "hoe_" else player.tapped_cell
	var at: Vector2 = dirt.to_global(dirt.map_to_local(cell))
	match animation_prefix:
		"water_":
			Juice.splash(place, at)
		"hoe_":
			Juice.burst(place, at, Juice.DUST_BROWN, 12, 38.0, 0.45, 2.4)
		"axe_":
			Juice.burst(place, at + Vector2(0, -10), Juice.WOOD_CHIP, 8, 45.0, 0.45)
		"pick_":
			Juice.burst(place, at + Vector2(0, -4), Juice.STONE_GREY, 8, 45.0, 0.4)
	Juice.tap(get_tree())

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
	if kind == "stone" and (get_tree().current_scene.get_node("Systems/FarmField") as FarmField).clear_soil(dirt, cell):
		return
	activities.note = Locale.t("nothing_cut") if kind == "wood" else Locale.t("nothing_mine")