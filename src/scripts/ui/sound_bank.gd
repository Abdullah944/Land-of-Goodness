# src/scripts/ui/sound_bank.gd
# Purpose: Plays short original sounds. Volumes stay with the farm progress.

class_name SoundBank
extends Node

var _players: Dictionary = {}

func _ready() -> void:
	for kind: String in ["coin", "gather", "ui"]:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/%s.wav" % kind) as AudioStream
		player.bus = "Master"
		add_child(player)
		_players[kind] = player

func play(kind: String) -> void:
	var stead: Node = get_parent().get_node_or_null("Stead")
	if stead != null and not bool(stead.get("sfx")):
		return
	var player: AudioStreamPlayer = _players.get(kind) as AudioStreamPlayer
	if player != null and player.stream != null:
		player.play()
