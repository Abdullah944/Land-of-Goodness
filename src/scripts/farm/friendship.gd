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
## Each neighbor's small story: at STORY_START hearts they ask for help once, and after the help, at STORY_END hearts, they thank the boy.
const STORY_START: int = 3
const STORY_END: int = 5
const STORIES: Dictionary = {
	"jassim": {"need": {"wood": 6}, "gift": {"eggs": 3}},
	"elder": {"pages": 3, "khair": 5},
	"merchant": {"need": {"tomatoes": 5}, "gift": {"dinars": 120, "watermelon_seeds": 3}},
	"carpenter": {"need": {"copper": 3}, "gift": {"toy_dhow": 1}},
	"fisherman": {"before_hour": 8, "gift": {"fish": 3, "pearl": 1}},
}
## After the fence, Jassim shares this many eggs once a week.
const WEEKLY_EGGS: int = 3
const ASKED: String = "asked"
const HELPED: String = "helped"
const THANKED: String = "thanked"
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
## Where each neighbor's story stands: "", ASKED, HELPED or THANKED.
var stories: Dictionary = {}
var eggs_week: int = -1

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
	var story: String = _story_step(person)
	if story != "":
		return story
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

## Whose birthday falls on the given day and season, or "".
func birthday_on(day: int, season: String) -> String:
	for person: String in PEOPLE:
		if BIRTHDAYS.has(person) and str(BIRTHDAYS[person][0]) == season and day_of_season(day) == int(BIRTHDAYS[person][1]):
			return person
	return ""

static func day_of_season(day: int) -> int:
	return day % 7

func story_state(person: String) -> String:
	return str(stories.get(person, ""))

## The story's opening or thank-you talk, when the hearts are there for it.
func _story_step(person: String) -> String:
	if not STORIES.has(person):
		return ""
	var state: String = story_state(person)
	if state == "" and hearts(person) >= STORY_START:
		stories[person] = ASKED
		return Locale.t("story_%s_ask" % person)
	if state == HELPED and hearts(person) >= STORY_END:
		stories[person] = THANKED
		return Locale.t("story_%s_thanks" % person)
	return ""

## True when the boy has what the neighbor asked for.
func story_ready(person: String, systems: Node) -> bool:
	if story_state(person) != ASKED:
		return false
	var story: Dictionary = STORIES[person]
	if story.has("pages") and Journal.found(systems) < int(story["pages"]):
		return false
	if story.has("before_hour"):
		var clock: GameClock = systems.get_node_or_null("Clock") as GameClock
		if clock == null or clock.minute >= float(story["before_hour"]) * 60.0:
			return false
	var bag: Inventory = systems.get_node_or_null("Inventory") as Inventory
	var need: Dictionary = story.get("need", {})
	for item_id: Variant in need:
		if bag == null or bag.count_of(str(item_id)) < int(need[item_id]):
			return false
	return true

## Takes what was asked for, gives the neighbor's thank-you gift, and returns the story's middle talk.
func finish_story(person: String, systems: Node) -> PackedStringArray:
	if not story_ready(person, systems):
		return PackedStringArray()
	var story: Dictionary = STORIES[person]
	var bag: Inventory = systems.get_node_or_null("Inventory") as Inventory
	var need: Dictionary = story.get("need", {})
	for item_id: Variant in need:
		bag.take_item(str(item_id), int(need[item_id]))
	var gift: Dictionary = story.get("gift", {})
	for item_id: Variant in gift:
		if str(item_id) == "dinars":
			bag.dinars += int(gift[item_id])
		else:
			bag.add_item(str(item_id), int(gift[item_id]))
	if story.has("khair"):
		var kindness: Kindness = systems.get_node_or_null("Kindness") as Kindness
		if kindness != null:
			kindness.reward(int(story["khair"]))
	stories[person] = HELPED
	if person == "jassim":
		eggs_week = _week()
	var lines: PackedStringArray = PackedStringArray([Locale.t("story_%s_done" % person)])
	if not gift.is_empty():
		lines.append(Locale.t("story_gift") % Stead.cost_text(gift))
	return lines

## What the neighbor still waits for, as a short line.
func story_hint(person: String, systems: Node) -> String:
	var story: Dictionary = STORIES.get(person, {})
	if story.has("pages"):
		return Locale.t("story_elder_wait") % int(story["pages"])
	if story.has("before_hour"):
		return Locale.t("story_fisherman_wait")
	var stead: Stead = systems.get_node_or_null("Stead") as Stead
	var need: Dictionary = story.get("need", {})
	return Locale.t("story_wait") % (stead.missing_text(need) if stead != null else Stead.cost_text(need))

## The story's row in the talk menu while the neighbor waits for help, or "".
func story_row(person: String) -> String:
	if story_state(person) != ASKED:
		return ""
	return "story|%s" % Locale.t("story_%s_row" % person)

## After the fence, Jassim's eggs: the number to hand over now, once a week.
func take_weekly_eggs() -> int:
	if story_state("jassim") != HELPED and story_state("jassim") != THANKED:
		return 0
	var week: int = _week()
	if week == eggs_week:
		return 0
	eggs_week = week
	return WEEKLY_EGGS

func _week() -> int:
	var clock: GameClock = _clock()
	return 0 if clock == null else int(clock.day / 7)

func on_new_day() -> void:
	talked.clear()

func to_data() -> Dictionary:
	return {"points": points.duplicate(), "talked": talked.duplicate(), "seen": heart_talks_seen.duplicate(), "stories": stories.duplicate(), "eggs_week": eggs_week}

func from_data(data: Dictionary) -> void:
	points.clear()
	talked.clear()
	heart_talks_seen.clear()
	stories.clear()
	var told: Variant = data.get("stories", {})
	if told is Dictionary:
		for person: Variant in told:
			if STORIES.has(str(person)) and str(told[person]) in [ASKED, HELPED, THANKED]:
				stories[str(person)] = str(told[person])
	eggs_week = int(data.get("eggs_week", -1))
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
