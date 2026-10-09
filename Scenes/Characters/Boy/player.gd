# File: Scenes/Characters/Boy/player.gd
# Purpose: move the boy, and play walk, idle, or one dig.

extends CharacterBody2D

@export var speed: float = 200.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

# The last way he was facing. Starts looking down.
var _facing := &"D"
# True while a dig animation is playing.
var _digging := false

func _ready() -> void:
	_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta: float) -> void:
	# Stand still until the dig animation ends.
	if _digging:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# Read the stick or the arrow keys.
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Move the body.
	velocity = direction * speed
	move_and_slide()
	# Walk while moving. Idle in the same direction when he stops.
	if direction != Vector2.ZERO:
		_facing = _facing_name(direction)
		_play_walk()
	else:
		_play_idle()

# Play the dig that matches the way he is facing.
func dig() -> void:
	if _digging:
		return
	_digging = true
	velocity = Vector2.ZERO
	_sprite.play(_dig_animation())

# Pick right, left, up, or down. The stronger axis wins.
func _facing_name(direction: Vector2) -> StringName:
	if abs(direction.x) > abs(direction.y):
		return &"R" if direction.x > 0.0 else &"L"
	if direction.y < 0.0:
		return &"UP"
	return &"D"

func _dig_animation() -> StringName:
	match _facing:
		&"R":
			return &"dig_r"
		&"L":
			return &"dig_l"
		&"UP":
			return &"dig_up"
		_:
			return &"dig_d"

# Play the walk for the way he is facing.
func _play_walk() -> void:
	_play(StringName("Walk_" + _facing))

# Play the idle for the way he is facing.
func _play_idle() -> void:
	_play(StringName("idle_" + _facing))

# Change the picture only when the animation name changes.
func _play(animation_name: StringName) -> void:
	if _sprite.animation != animation_name:
		_sprite.play(animation_name)

func _on_animation_finished() -> void:
	if not _digging:
		return
	_digging = false
	_play_idle()

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
