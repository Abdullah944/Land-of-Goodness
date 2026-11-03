# src/scripts/farm/friendship.gd
# Purpose: How close the boy is to each neighbor: hearts from daily talks and gifts, favorite gifts, birthdays, and small heart talks.

class_name Friendship
extends Node

const PEOPLE: Array[String] = ["jassim", "elder", "merchant", "carpenter", "fisherman"]
const HEART: int = 100
const MAX_HEARTS: int = 5
const TALK_POINTS: int = 10
const GIFT_POINTS: Dictionary = {"love": 80, "like": 45, "neutral": 20, "dislike": -20}
const BIRTHDAY_TIMES: int = 3
## Hearts at which a neighbor shares something personal, once.
const HEART_TALKS: Array[int] = [2, 4]
const TASTES: Dictionary = {
	"jassim": {"love": ["dates", "watermelons"], "like": ["tomatoes", "milk", "turnips"], "dislike": ["wood"]},
	"elder": {"love": ["dates", "milk"], "like": ["eggs", "wheat", "forage"], "dislike": ["copper"]},
	"merchant": {"love": ["pearl", "copper"], "like": ["tomatoes", "watermelons", "wool"], "dislike": ["forage"]},
	"carpenter": {"love": ["copper", "wood"], "like": ["eggs", "fish", "milk"], "dislike": ["watermelons"]},
	"fisherman": {"love": ["dates", "pearl"], "like": ["wheat", "eggs", "turnips"], "dislike": ["fish"]},
}
## Season and day of the season, from 0 to 6, as GameClock counts them.
const BIRTHDAYS: Dictionary = {
	"jassim": ["Spring", 2], "fisherman": ["Summer", 2], "elder": ["Summer", 5], "merchant": ["Autumn", 1], "carpenter": ["Winter", 3],
}

var points: Dictionary = {}
var talked: Dictionary = {}
var heart_talks_seen: Dictionary = {}

func hearts(person: String) -> int:
	return mini(MAX_HEARTS, int(float(points.get(person, 0)) / HEART))

func taste(person: String, item_id: String) -> String:
	var likes: Dictionary = TASTES.get(person, {})
	for kind: String in ["love", "like", "dislike"]:
		if item_id in likes.get(kind, []):
			return kind
	return "neutral"

## The first talk each day brings a neighbor a little closer. Returns a special line for today, or "".
func talk(person: String) -> String:
	if not person in PEOPLE:
		return ""
	if not talked.has(person):
		talked[person] = true
		_add(person, TALK_POINTS)
	for at: int in HEART_TALKS:
		var key: String = "%s_%d" % [person, at]
		if hearts(person) >= at and not heart_talks_seen.has(key):
			heart_talks_seen[key] = true
			return Locale.t("heart_" + key)
	if is_birthday(person):
		return Locale.t("birthday_line")
	return ""

## How the neighbor feels about a gift. Birthdays count three times.
func gift(person: String, item_id: String) -> String:
	var kind: String = taste(person, item_id)
	var amount: int = int(GIFT_POINTS[kind])
	if is_birthday(person) and amount > 0:
		amount *= BIRTHDAY_TIMES
	_add(person, amount)
	return kind

func is_birthday(person: String) -> bool:
	var clock: GameClock = _clock()
	if clock == null or not BIRTHDAYS.has(person):
		return false
	var when: Array = BIRTHDAYS[person]
	return clock.season == str(when[0]) and day_of_season(clock.day) == int(when[1])

## Whose birthday it is today, or "".
func birthday_today() -> String:
	for person: String in PEOPLE:
		if is_birthday(person):
			return person
	return ""

static func day_of_season(day: int) -> int:
	return day % 7

func on_new_day() -> void:
	talked.clear()

func to_data() -> Dictionary:
	return {"points": points.duplicate(), "talked": talked.duplicate(), "seen": heart_talks_seen.duplicate()}

func from_data(data: Dictionary) -> void:
	points.clear()
	talked.clear()
	heart_talks_seen.clear()
	var stored: Variant = data.get("points", {})
	if stored is Dictionary:
		for person: Variant in stored:
			if str(person) in PEOPLE:
				points[str(person)] = clampi(int(stored[person]), 0, HEART * MAX_HEARTS)
	for section: Array in [[talked, data.get("talked", {})], [heart_talks_seen, data.get("seen", {})]]:
		if section[1] is Dictionary:
			for key: Variant in section[1]:
				section[0][str(key)] = true

func _add(person: String, amount: int) -> void:
	points[person] = clampi(int(points.get(person, 0)) + amount, 0, HEART * MAX_HEARTS)

func _clock() -> GameClock:
	return get_parent().get_node_or_null("Clock") as GameClock
