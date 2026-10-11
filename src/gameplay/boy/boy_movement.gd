# File: src/gameplay/boy/boy_movement.gd
# Purpose: move the boy and start a dig or a pickup.

extends CharacterBody2D

@export var speed: float = 200.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _animation := BoyAnimation.new()
var _facing := &"D"
var _busy := false
var _pickup_target: Node = null

func _ready() -> void:
	_animation.setup(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta: float) -> void:
	if _busy:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	if direction != Vector2.ZERO:
		_facing = _facing_name(direction)
		_animation.play_walk(_facing)
	else:
		_animation.play_idle(_facing)

func dig() -> void:
	if _busy:
		return
	_busy = true
	_pickup_target = null
	velocity = Vector2.ZERO
	_animation.play_dig(_facing)

func pickup(pack: Node) -> void:
	if _busy:
		return
	_busy = true
	_pickup_target = pack
	velocity = Vector2.ZERO
	_animation.play_pickup(_facing)

func _facing_name(direction: Vector2) -> StringName:
	if abs(direction.x) > abs(direction.y):
		return &"R" if direction.x > 0.0 else &"L"
	if direction.y < 0.0:
		return &"UP"
	return &"D"

func _on_animation_finished() -> void:
	if not _busy:
		return
	var pack := _pickup_target
	_busy = false
	_pickup_target = null
	if pack != null and is_instance_valid(pack):
		pack.take()
	else:
		var action_tile := get_tree().get_first_node_in_group("action_tile")
		if action_tile != null:
			action_tile.dig_here()
	_animation.play_idle(_facing)

func get_facing_cell() -> Vector2i:
	match _facing:
		&"R":
			return Vector2i(1, 0)
		&"L":
			return Vector2i(-1, 0)
		&"UP":
			return Vector2i(0, -1)
		_:
			return Vector2i(0, 1)
