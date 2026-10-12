# File: src/gameplay/boy/boy_animation.gd
# Purpose: play the boy's walk, idle, dig, and pickup pictures.

class_name BoyAnimation
extends RefCounted

var _sprite: AnimatedSprite2D

# Keep the picture node this helper will play.
func setup(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite

func play_walk(facing: StringName) -> void:
	_play(StringName("Walk_" + facing))

func play_idle(facing: StringName) -> void:
	_play(StringName("idle_" + facing))

func play_dig(facing: StringName) -> void:
	_sprite.play(_dig_name(facing))

func play_pickup(facing: StringName) -> void:
	_sprite.play(_pickup_name(facing))

func _pickup_name(facing: StringName) -> StringName:
	match facing:
		&"R":
			return &"pickup_r"
		&"L":
			return &"pickup_L"
		&"UP":
			return &"pickup_up"
		_:
			return &"pickup_d"

func _dig_name(facing: StringName) -> StringName:
	match facing:
		&"R":
			return &"dig_r"
		&"L":
			return &"dig_l"
		&"UP":
			return &"dig_up"
		_:
			return &"dig_d"

func _play(animation_name: StringName) -> void:
	if _sprite.animation != animation_name:
		_sprite.play(animation_name)
