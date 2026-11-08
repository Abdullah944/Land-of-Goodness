# src/scripts/World/copper_vein.gd
# Purpose: Gives one copper (or stone, iron, or a pearl deep down) when the boy reaches the vein, then waits until morning.

extends Area2D

@export var mark: String = "Cave/Copper"
@export var item: String = "copper"
@export var picture_path: String = "res://assets/props/ore_copper.png"
@export var tint: Color = Color.WHITE

func _ready() -> void:
	_add_picture()
	add_to_group("daily_spot")
	body_entered.connect(_on_body_entered)
	_apply()

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	if activities.take_daily(mark, item):
		_apply()

func apply_day(gathered: Dictionary, day: int) -> void:
	var taken: bool = int(gathered.get(mark, -1)) == day
	visible = not taken
	var shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = taken

func _apply() -> void:
	var activities: Activities = get_tree().current_scene.get_node_or_null("Systems/Activities") as Activities
	if activities == null:
		return
	apply_day(activities.gathered, activities._day())

func _add_picture() -> void:
	var ore: Texture2D = load(picture_path) as Texture2D
	if ore == null:
		return
	var picture: Sprite2D = Sprite2D.new()
	picture.name = "Picture"
	picture.texture = ore
	picture.modulate = tint
	add_child(picture)
