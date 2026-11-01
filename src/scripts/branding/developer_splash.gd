# src/scripts/branding/developer_splash.gd
# Purpose: Fades a branding image in and out, then opens the next scene.

extends Control

@export var branding: Texture2D
@export var next_scene: PackedScene
@export var fade_in_seconds: float = 0.4
@export var hold_seconds: float = 1.5
@export var fade_out_seconds: float = 0.4

const BRANDING_PATH: String = "res://assets/branding/Abdullah Dev logo with gold divider (1).png"

@onready var _branding: TextureRect = $Branding

func _ready() -> void:
	if branding == null and ResourceLoader.exists(BRANDING_PATH):
		branding = load(BRANDING_PATH) as Texture2D
	if branding == null:
		_open_next()
		return
	_branding.texture = branding
	_branding.modulate.a = 0.0
	var fade: Tween = create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.set_ease(Tween.EASE_IN_OUT)
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(_branding, "modulate:a", 1.0, fade_in_seconds)
	fade.tween_interval(hold_seconds)
	fade.tween_property(_branding, "modulate:a", 0.0, fade_out_seconds)
	fade.finished.connect(_open_next)

func _open_next() -> void:
	if next_scene == null:
		push_error("Developer splash has no next scene.")
		return
	get_tree().change_scene_to_packed.call_deferred(next_scene)
