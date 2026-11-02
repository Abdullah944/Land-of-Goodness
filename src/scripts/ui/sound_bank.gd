# src/scripts/ui/sound_bank.gd
# Purpose: Plays the original music and short sounds. Their volumes stay with the farm progress.

class_name SoundBank
extends Node

const KINDS: Array[String] = ["coin", "gather", "ui", "hoe", "water", "harvest", "chop", "mine", "level"]
## Volume in decibels for levels 1 and 2. Level 0 is silent.
const LEVEL_DB: Array[float] = [-80.0, -12.0, 0.0]
const MUSIC_TRIM_DB: float = -6.0

var _players: Dictionary = {}
var _music: AudioStreamPlayer

func _ready() -> void:
	for kind: String in KINDS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/%s.wav" % kind) as AudioStream
		player.bus = "Master"
		add_child(player)
		_players[kind] = player
	_music = AudioStreamPlayer.new()
	var song: AudioStreamMP3 = load("res://assets/audio/music_village.mp3") as AudioStreamMP3
	if song != null:
		song.loop = true
	_music.stream = song
	_music.bus = "Master"
	add_child(_music)

func play(kind: String) -> void:
	var level: int = _level("sfx_level")
	if level < 1:
		return
	var player: AudioStreamPlayer = _players.get(kind) as AudioStreamPlayer
	if player != null and player.stream != null:
		player.volume_db = LEVEL_DB[level]
		player.play()

## Called after a load and after a change in Settings.
func apply_levels() -> void:
	var level: int = _level("music_level")
	if _music == null or _music.stream == null:
		return
	if level < 1:
		_music.stop()
		return
	_music.volume_db = LEVEL_DB[level] + MUSIC_TRIM_DB
	if not _music.playing:
		_music.play()

func _level(key: String) -> int:
	var stead: Node = get_parent().get_node_or_null("Stead")
	return clampi(int(stead.get(key)), 0, 2) if stead != null else 2
