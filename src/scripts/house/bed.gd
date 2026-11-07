# src/scripts/house/bed.gd
# Purpose: Draws the bed and asks before the boy sleeps until morning.

extends Node2D

const BED_PATH: String = "res://assets/building/house/Cozy 16-bit Bed Base.png"
const QUILT_PATH: String = "res://assets/building/house/Cream pixel quilt blanket overlay.png"

var _bed: Texture2D
var _quilt: Texture2D
var _show_mark: bool = false
var _asking: bool = false

func _ready() -> void:
	var bed: Texture2D = load(BED_PATH) as Texture2D
	_bed = _fit(bed, 64)
	# The painted HD bed already has its quilt; only the old pixel bed needs the overlay.
	if not UiStyle.is_hd(bed):
		_quilt = _fit(load(QUILT_PATH) as Texture2D, 36)
	_add_body()
	var dialogue: DialogueBox = get_tree().current_scene.get_node("UI/Dialogue") as DialogueBox
	dialogue.answered.connect(_on_answer)
	queue_redraw()

func _process(_delta: float) -> void:
	z_index = 2000 + int(global_position.y)
	var player: Player = _player()
	var show_mark: bool = player != null and not player.busy and covers_point(player.global_position + Vector2(0, 20))
	if show_mark != _show_mark:
		_show_mark = show_mark
		queue_redraw()
	elif show_mark:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _show_mark or _asking:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		_ask()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if _bed == null:
		return
	var bed_size: Vector2 = _bed.get_size()
	draw_texture_rect(_bed, Rect2(Vector2(-bed_size.x * 0.5, -bed_size.y), bed_size), false)
	if _quilt == null:
		_draw_mark()
		return
	var quilt_size: Vector2 = _quilt.get_size()
	var quilt_at: Vector2 = Vector2(-quilt_size.x * 0.5, -bed_size.y * 0.62)
	draw_texture_rect(_quilt, Rect2(quilt_at, quilt_size), false)
	_draw_mark()

func _draw_mark() -> void:
	if not _show_mark:
		return
	var player: Player = _player()
	if player == null:
		return
	UiStyle.draw_bubble(self, to_local(player.global_position + Vector2(0, -28)))

func _add_body() -> void:
	var bed_size: Vector2 = _bed.get_size()
	var body: StaticBody2D = StaticBody2D.new()
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(bed_size.x - 8.0, bed_size.y - 10.0)
	shape_node.shape = shape
	shape_node.position = Vector2(0, -bed_size.y * 0.5)
	body.add_child(shape_node)
	add_child(body)
	var area: Area2D = Area2D.new()
	var area_shape_node: CollisionShape2D = CollisionShape2D.new()
	var area_shape: RectangleShape2D = RectangleShape2D.new()
	area_shape.size = Vector2(bed_size.x, 14)
	area_shape_node.shape = area_shape
	area_shape_node.position = Vector2(0, 6)
	area.add_child(area_shape_node)
	add_child(area)

func _ask() -> void:
	if _asking:
		return
	var dialogue: DialogueBox = get_tree().current_scene.get_node("UI/Dialogue") as DialogueBox
	if dialogue.visible:
		return
	_asking = true
	dialogue.ask(Locale.t("sleep_ask"))

func _on_answer(yes: bool) -> void:
	if not _asking:
		return
	_asking = false
	if not yes:
		return
	var player: Player = _player()
	if player != null:
		player.busy = true
		player.cancel_tap()
	var hud: Node = get_tree().current_scene.get_node("UI/HUD")
	hud.call("cover_for_sleep", Tomorrow.line(get_tree().current_scene.get_node("Systems")))
	await get_tree().create_timer(3.0).timeout
	var clock: GameClock = get_tree().current_scene.get_node("Systems/Clock") as GameClock
	clock.sleep_now()
	hud.call("uncover_sleep")
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	activities.note = Locale.t("slept")
	var notices: PhoneNotices = get_tree().current_scene.get_node_or_null("Systems/PhoneNotices") as PhoneNotices
	if notices != null:
		notices.ask_once()
	if player != null:
		player.busy = false

func _player() -> Player:
	return get_tree().current_scene.find_child("Player", true, false) as Player

func covers_point(world_position: Vector2) -> bool:
	if _bed != null:
		var size: Vector2 = _bed.get_size()
		var rect: Rect2 = Rect2(global_position + Vector2(-size.x * 0.5, -size.y), size)
		if rect.grow(8.0).has_point(world_position):
			return true
	for child: Node in get_children():
		if not child is Area2D:
			continue
		var shape_node: CollisionShape2D = child.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null or not shape_node.shape is RectangleShape2D:
			continue
		var box: RectangleShape2D = shape_node.shape as RectangleShape2D
		var center: Vector2 = shape_node.global_position
		var area_rect: Rect2 = Rect2(center - box.size * 0.5, box.size)
		if area_rect.grow(8.0).has_point(world_position):
			return true
	return false

func foot_point() -> Vector2:
	for child: Node in get_children():
		if not child is Area2D:
			continue
		var shape_node: CollisionShape2D = child.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null:
			return shape_node.global_position
	return global_position + Vector2(0, 6)

func _fit(texture: Texture2D, pixels: int) -> Texture2D:
	return UiStyle.fit_picture(texture, pixels)
