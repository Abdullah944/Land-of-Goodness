# File: src/gameplay/boy/boy_movement.gd
# Purpose: move the boy and start a dig.

extends CharacterBody2D

@export var speed: float = 200.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _animation := BoyAnimation.new()
# The last way he was facing. Starts looking down.
var _facing := &"D"
# True while a dig animation is playing.
var _digging := false

func _ready() -> void:
	_animation.setup(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta: float) -> void:
	# Stand still until the dig animation ends.
	if _digging:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# Read the stick or the arrow keys.
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	# Walk while moving. Idle in the same direction when he stops.
	if direction != Vector2.ZERO:
		_facing = _facing_name(direction)
		_animation.play_walk(_facing)
	else:
		_animation.play_idle(_facing)

# Play the dig that matches the way he is facing.
func dig() -> void:
	if _digging:
		return
	_digging = true
	velocity = Vector2.ZERO
	_animation.play_dig(_facing)

# Pick right, left, up, or down. The stronger axis wins.
func _facing_name(direction: Vector2) -> StringName:
	if abs(direction.x) > abs(direction.y):
		return &"R" if direction.x > 0.0 else &"L"
	if direction.y < 0.0:
		return &"UP"
	return &"D"

func _on_animation_finished() -> void:
	if not _digging:
		return
	_digging = false
	var action_tile := get_tree().get_first_node_in_group("action_tile")
	if action_tile != null:
		action_tile.dig_here()
	_animation.play_idle(_facing)

# Tell the square which tile is in front of him.
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
