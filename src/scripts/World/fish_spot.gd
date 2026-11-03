# src/scripts/World/fish_spot.gd
# Purpose: Starts the fishing game when the boy reaches this water. It gives one fish a day.

extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
	activities.cast(get_parent().name)
