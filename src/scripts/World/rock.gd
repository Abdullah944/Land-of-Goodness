# src/scripts/World/rock.gd
# Purpose: Gives one stone when the boy walks into the rock.

extends Area2D

func _ready() -> void:
	_add_picture()
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

func _add_picture() -> void:
	var ore: Texture2D = load("res://assets/props/ore_rock.png") as Texture2D
	if ore == null:
		return
	var picture: Sprite2D = Sprite2D.new()
	picture.name = "Picture"
	picture.texture = ore
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(picture)
