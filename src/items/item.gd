# File: src/items/item.gd
# Purpose: the id, pictures, and growth stages for one item.

class_name GameItem
extends Resource

@export var id: StringName
@export var icon: Texture2D
@export var sprout: Texture2D
@export var stages: Array[Texture2D] = []
