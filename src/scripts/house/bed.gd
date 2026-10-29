# src/scripts/house/bed.gd
# Purpose: Draws the bed and lets the boy sleep until morning.

extends Node2D

const BED_PATH: String = "res://assets/building/house/Cozy 16-bit Bed Base.png"
const QUILT_PATH: String = "res://assets/building/house/Cream pixel quilt blanket overlay.png"

var _bed: Texture2D
var _quilt: Texture2D
var _asleep: bool = false

func _ready() -> void:
	_bed = _fit(load(BED_PATH) as Texture2D, 64)
	_quilt = _fit(load(QUILT_PATH) as Texture2D, 36)
	_add_body()
	queue_redraw()

func _process(_delta: float) -> void:
	z_index = 2000 + int(global_position.y)

func _draw() -> void:
	if _bed == null:
		return
	var bed_size: Vector2 = _bed.get_size()
	draw_texture_rect(_bed, Rect2(Vector2(-bed_size.x * 0.5, -bed_size.y), bed_size), false)
	if _quilt == null:
		return
	var quilt_size: Vector2 = _quilt.get_size()
	var quilt_at: Vector2 = Vector2(-quilt_size.x * 0.5, -bed_size.y * 0.62)
	draw_texture_rect(_quilt, Rect2(quilt_at, quilt_size), false)

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
	area.body_entered.connect(_sleep)
	add_child(area)

func _sleep(body: Node2D) -> void:
	if _asleep or not body is Player:
		return
	_asleep = true
	var clock: GameClock = get_tree().current_scene.get_node("Systems/Clock") as GameClock
	clock.sleep_now()
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	activities.note = "You slept until morning."

func _fit(texture: Texture2D, pixels: int) -> Texture2D:
	var image: Image = texture.get_image()
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	var longest: int = maxi(image.get_width(), image.get_height())
	var width: int = maxi(1, int(round(float(image.get_width()) * pixels / float(longest))))
	var height: int = maxi(1, int(round(float(image.get_height()) * pixels / float(longest))))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
