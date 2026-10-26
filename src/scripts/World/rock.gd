# src/scripts/World/rock.gd
# Purpose: Gives one stone when the boy walks into the rock.

extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	if activities.rock_mined:
		_hide_rock()

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	if activities.rock_mined:
		return
	activities.give_stone()
	_hide_rock()

func _hide_rock() -> void:
	visible = false
	var shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", true)

func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 16), Color("7a4f32"))
