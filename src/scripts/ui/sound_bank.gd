# src/scripts/ui/sound_bank.gd
# Purpose: Plays real nature recordings in place of music, and short sounds. Their volumes stay with the farm progress.
# Birds play a different stretch each time, fade out, rest in silence, and come back. On rainy days rain fades in
# instead, and a quiet waterfall joins in where there is running water. See tools/loop_nature.py for the recordings.
# Birds sing by day and crickets after dusk. Inside a room the outdoors is heard faintly, and deep in the cave not at all.

class_name SoundBank
extends Node

const KINDS: Array[String] = ["coin", "gather", "ui", "hoe", "water", "harvest", "chop", "mine", "level", "no", "door", "page", "cast", "build"]
## The tool sounds were recorded louder than the rest; these bring every effect to about the same loudness.
const TRIM_DB: Dictionary = {"hoe": -5.0, "chop": -5.0, "mine": -4.0, "ui": -3.0}
## Sounds heard many times in a row get a slightly different pitch each time.
const VARIED: Array[String] = ["hoe", "water", "chop", "mine", "gather"]
const PITCH_SPREAD: float = 0.06
## Volume in decibels for levels 1 and 2. Level 0 is silent.
const LEVEL_DB: Array[float] = [-80.0, -12.0, 0.0]
const QUIET_DB: float = -40.0
const NATURE_PATH: String = "res://assets/audio/nature/%s.wav"
## Which recordings each season's birds come from. A name twice is picked twice as often.
const SEASON_BIRDS: Dictionary = {
	"Spring": ["birds_forest", "birds_forest", "birds_evening"],
	"Summer": ["birds_forest"],
	"Autumn": ["birds_evening", "birds_forest"],
	"Winter": ["birds_evening"],
}
## How long a stretch plays, and how long the silence after it lasts, in seconds.
const BIRD_PLAY: Vector2 = Vector2(45, 110)
const SEASON_REST: Dictionary = {
	"Spring": Vector2(15, 40), "Summer": Vector2(25, 55), "Autumn": Vector2(20, 50), "Winter": Vector2(35, 80),
}
const CRICKET_SEASONS: Array[String] = ["Spring", "Summer", "Autumn"]
## Birds sing until the evening, and crickets start at dusk. Minutes since midnight.
const BIRDS_UNTIL: float = 19.0 * 60.0
const CRICKETS_FROM: float = 18.5 * 60.0
## Rooms, where the outdoors is heard through the walls, and places too deep to hear it at all.
const ROOMS: Array[String] = ["HouseInside", "MosqueInside", "WorkshopInside"]
const DEEP: Array[String] = ["Cave"]
const ROOM_DB: float = -14.0
const CRICKET_PLAY: Vector2 = Vector2(15, 26)
const CRICKET_REST: Vector2 = Vector2(25, 60)
## Places with a river or a lake, where the waterfall plays too.
const WATER_PLACES: Array[String] = ["Forest", "Village"]
const FADE_SECONDS: float = 3.0
const RAIN_FADE_SECONDS: float = 5.0

var _players: Dictionary = {}
var _sounds: Dictionary = {}
var _fades: Dictionary = {}
var _roll: RandomNumberGenerator = RandomNumberGenerator.new()
## Each voice takes turns: it plays a stretch, then rests in silence. {player, playing, left}
var _birds: Dictionary = {}
var _cricket: Dictionary = {}
var _rain: AudioStreamPlayer
var _waterfall: AudioStreamPlayer
var _last_clip: String = ""
## The last effect asked for, even with the sound off. Tests read it.
var last_kind: String = ""

func _ready() -> void:
	_roll.randomize()
	for kind: String in KINDS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/%s.wav" % kind) as AudioStream
		player.bus = "Master"
		add_child(player)
		_players[kind] = player
	_birds = {"player": _new_player(), "playing": false, "left": 1.5}
	_cricket = {"player": _new_player(), "playing": false, "left": _roll.randf_range(8.0, 20.0)}
	_rain = _new_player()
	_rain.stream = _sound("rain", true)
	_waterfall = _new_player()
	_waterfall.stream = _sound("waterfall", true)

func play(kind: String) -> void:
	last_kind = kind
	var level: int = _level("sfx_level")
	if level < 1:
		return
	var player: AudioStreamPlayer = _players.get(kind) as AudioStreamPlayer
	if player != null and player.stream != null:
		player.volume_db = LEVEL_DB[level] + float(TRIM_DB.get(kind, 0.0))
		player.pitch_scale = _roll.randf_range(1.0 - PITCH_SPREAD, 1.0 + PITCH_SPREAD) if kind in VARIED else 1.0
		player.play()

## What is heard in a place: which voices are on, and how much quieter the outdoors is there.
static func mood(place: String, season: String, raining: bool, minute: float) -> Dictionary:
	var outside: bool = not place in DEEP
	return {
		"birds": outside and not raining and minute < BIRDS_UNTIL,
		"crickets": outside and not raining and minute >= CRICKETS_FROM and season in CRICKET_SEASONS,
		"rain": outside and raining,
		"waterfall": place in WATER_PLACES,
		"trim": ROOM_DB if place in ROOMS else 0.0,
	}

## Called after a load and after a change in Settings: sounds already playing move to the new volume.
func apply_levels() -> void:
	var level: int = _level("music_level")
	for player: AudioStreamPlayer in [_birds["player"], _cricket["player"], _rain, _waterfall]:
		if not player.playing:
			continue
		if level < 1:
			_fade(player, QUIET_DB, true, 0.5)
		elif float(player.get_meta("fading_to", 0.0)) > QUIET_DB:
			_fade(player, _loud(level), false, 0.5)

func _process(delta: float) -> void:
	var level: int = _level("music_level")
	var season: String = _clock_value("season", "Spring")
	var now: Dictionary = mood(_place(), season, _clock_value("weather", "Clear") == "Rain", _minute())
	# Nature sounds stay quiet while the Quran is recited.
	var on: bool = level >= 1 and not QuranReader.reciting
	_keep_loop(_rain, on and bool(now["rain"]), RAIN_FADE_SECONDS)
	_keep_loop(_waterfall, on and bool(now["waterfall"]), FADE_SECONDS)
	# Birds and crickets go quiet while it rains, and come back after the rain.
	_take_turns(_birds, delta, on and bool(now["birds"]), BIRD_PLAY, SEASON_REST.get(season, SEASON_REST["Spring"]), _bird_clip.bind(season))
	_take_turns(_cricket, delta, on and bool(now["crickets"]), CRICKET_PLAY, CRICKET_REST, func() -> String: return "cricket")

## One voice's turn: when its stretch ends it fades out and rests; when the rest ends a new stretch starts.
func _take_turns(voice: Dictionary, delta: float, allowed: bool, play_for: Vector2, rest_for: Vector2, pick: Callable) -> void:
	var player: AudioStreamPlayer = voice["player"]
	if not allowed:
		if bool(voice["playing"]):
			voice["playing"] = false
			voice["left"] = _roll.randf_range(rest_for.x, rest_for.y) * 0.5
			_fade(player, QUIET_DB, true, RAIN_FADE_SECONDS)
		return
	voice["left"] = float(voice["left"]) - delta
	if float(voice["left"]) > 0.0:
		# Walking through a door changes how loud the outdoors is.
		if bool(voice["playing"]):
			_fade(player, _loud(_level("music_level")), false, 1.0)
		return
	if bool(voice["playing"]):
		voice["playing"] = false
		voice["left"] = _roll.randf_range(rest_for.x, rest_for.y)
		_fade(player, QUIET_DB, true, FADE_SECONDS)
		return
	var name: String = str(pick.call())
	var sound: AudioStreamWAV = _sound(name, name == "cricket")
	if sound == null:
		voice["left"] = rest_for.x
		return
	var length: float = minf(_roll.randf_range(play_for.x, play_for.y), sound.get_length())
	var start: float = _roll.randf_range(0.0, maxf(0.0, sound.get_length() - length)) if name != "cricket" else 0.0
	player.stream = sound
	player.volume_db = QUIET_DB
	player.play(start)
	_fade(player, _loud(_level("music_level")), false, FADE_SECONDS)
	voice["playing"] = true
	voice["left"] = length

## Birds from a different recording than last time when the season has more than one.
func _bird_clip(season: String) -> String:
	var choices: Array = SEASON_BIRDS.get(season, SEASON_BIRDS["Spring"])
	var name: String = str(choices[_roll.randi_range(0, choices.size() - 1)])
	if name == _last_clip and choices.has(name) and choices.count(name) < choices.size():
		for other: Variant in choices:
			if str(other) != name:
				name = str(other)
				break
	_last_clip = name
	return name

## Keeps a looping sound on or off, fading it either way.
func _keep_loop(player: AudioStreamPlayer, wanted: bool, seconds: float) -> void:
	if wanted:
		if not player.playing:
			player.volume_db = QUIET_DB
			player.play()
		_fade(player, _loud(_level("music_level")), false, seconds)
	elif player.playing:
		_fade(player, QUIET_DB, true, seconds)

## Fades a sound to the given volume, unless it is already on its way there.
func _fade(player: AudioStreamPlayer, target: float, then_stop: bool, seconds: float) -> void:
	if float(player.get_meta("fading_to", 1.0)) == target:
		return
	player.set_meta("fading_to", target)
	# A fade still running would fight this one, or stop the sound after it was wanted again.
	var old: Tween = _fades.get(player) as Tween
	if old != null and old.is_valid():
		old.kill()
	var tween: Tween = create_tween()
	_fades[player] = tween
	tween.tween_property(player, "volume_db", target, seconds)
	if then_stop:
		tween.tween_callback(player.stop)

func _sound(name: String, loops: bool) -> AudioStreamWAV:
	if _sounds.has(name):
		return _sounds[name]
	var sound: AudioStreamWAV = load(NATURE_PATH % name) as AudioStreamWAV
	if sound == null:
		return null
	if loops:
		# The recording's end is blended into its start, so it loops all the way round with no jump.
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_begin = 0
		sound.loop_end = int(sound.get_length() * sound.mix_rate)
	_sounds[name] = sound
	return sound

func _new_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)
	return player

func _clock_value(key: String, fallback: String) -> String:
	var clock: Node = get_parent().get_node_or_null("Clock")
	return str(clock.get(key)) if clock != null else fallback

func _minute() -> float:
	var clock: Node = get_parent().get_node_or_null("Clock")
	return float(clock.get("minute")) if clock != null else 12.0 * 60.0

## The volume for the nature sounds here: the chosen level, and quieter inside a room.
func _loud(level: int) -> float:
	return LEVEL_DB[level] + float(mood(_place(), "", false, 0.0)["trim"])

func _place() -> String:
	var stead: Node = get_parent().get_node_or_null("Stead")
	return str(stead.get("place_name")) if stead != null else ""

func _level(key: String) -> int:
	var stead: Node = get_parent().get_node_or_null("Stead")
	return clampi(int(stead.get(key)), 0, 2) if stead != null else 2
