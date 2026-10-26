# src/scripts/player/dig_target.gd
# Purpose: Sends a finger press to the boy, and keeps him walking while the finger stays down.

extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var player: Player = get_parent() as Player
	if player == null or player.busy:
		return
	if event is InputEventMagnifyGesture:
		player.change_zoom(event.factor)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if _hits_menu(event.position):
			return
		if event.pressed:
			player.holding_touch = true
			_choose_cell(event.position)
		else:
			player.holding_touch = false
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and player.holding_touch and player.tool == "":
		if _hits_menu(event.position):
			return
		_choose_cell(event.position)
		get_viewport().set_input_as_handled()

func _choose_cell(screen_position: Vector2) -> void:
	var dirt: TileMapLayer = _find_dirt()
	var player: Player = get_parent() as Player
	if dirt == null or player == null:
		return
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var cell: Vector2i = dirt.local_to_map(dirt.to_local(world_position))
	player.set_tapped_cell(cell)

func _hits_menu(screen_position: Vector2) -> bool:
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud != null and hud.has_method("blocks_point"):
		return bool(hud.call("blocks_point", screen_position))
	return false

func _find_dirt() -> TileMapLayer:
	var main: Node = get_tree().current_scene
	if main == null:
		return null
	var found: Node = main.find_child("Tilled_Dirt", true, false)
	if found is TileMapLayer:
		return found
	return null

func _draw() -> void:
	var dirt: TileMapLayer = _find_dirt()
	var player: Player = get_parent() as Player
	if dirt == null or player == null or not player.has_tapped_cell:
		return
	var cell: Vector2i = player.tapped_cell
	var center: Vector2 = to_local(dirt.to_global(dirt.map_to_local(cell)))
	var square: Rect2 = Rect2(center - Vector2(8, 8), Vector2(16, 16))
	draw_rect(square, Color("55afc4"), false, 1.0)
