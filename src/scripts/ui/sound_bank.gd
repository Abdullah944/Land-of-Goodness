# src/scripts/ui/sound_bank.gd
# Purpose: Plays calm nature sounds in place of music, a different mix each season, and short sounds. Their volumes stay with the farm progress.

class_name SoundBank
extends Node

const KINDS: Array[String] = ["coin", "gather", "ui", "hoe", "water", "harvest", "chop", "mine", "level"]
## Volume in decibels for levels 1 and 2. Level 0 is silent.
const LEVEL_DB: Array[float] = [-80.0, -12.0, 0.0]
const MUSIC_TRIM_DB: float = -1.0
const SEASON_SONGS: Dictionary = {
	"Spring": "res://assets/audio/nature_village.wav",
	"Summer": "res://assets/audio/nature_summer.wav",
	"Autumn": "res://assets/audio/nature_autumn.wav",
	"Winter": "res://assets/audio/nature_winter.wav",
}

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
	_music.bus = "Master"
	add_child(_music)
	_pick_song()

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
	_pick_song()
	var level: int = _level("music_level")
	if _music == null or _music.stream == null:
		return
	if level < 1:
		_music.stop()
		return
	_music.volume_db = LEVEL_DB[level] + MUSIC_TRIM_DB
	if not _music.playing:
		_music.play()

## The current season's nature sounds. Changing it starts them from the top.
func song_path() -> String:
	var clock: Node = get_parent().get_node_or_null("Clock")
	var season: String = str(clock.get("season")) if clock != null else "Spring"
	return str(SEASON_SONGS.get(season, SEASON_SONGS["Spring"]))

func _pick_song() -> void:
	var path: String = song_path()
	if _music.stream != null and _music.stream.resource_path == path:
		return
	var song: AudioStreamWAV = load(path) as AudioStreamWAV
	if song == null:
		return
	# The file's end is blended into its start, so it loops all the way round with no jump.
	song.loop_mode = AudioStreamWAV.LOOP_FORWARD
	song.loop_begin = 0
	song.loop_end = int(song.get_length() * song.mix_rate)
	var was_playing: bool = _music.playing
	_music.stream = song
	if was_playing:
		_music.play()

func _level(key: String) -> int:
	var stead: Node = get_parent().get_node_or_null("Stead")
	return clampi(int(stead.get(key)), 0, 2) if stead != null else 2
