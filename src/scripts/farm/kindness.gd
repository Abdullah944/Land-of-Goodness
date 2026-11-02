# src/scripts/farm/kindness.gd
# Purpose: The village Khair meter. It counts in-game kindness only, never worship, and never falls.

class_name Kindness
extends Node

const MAX_POINTS: int = 100
const GIFT_POINTS: int = 2
const FUND_POINTS: int = 3
const FEED_POINTS: int = 1
const FUND_PRICE: int = 10
const FOODS: Array[String] = ["turnips", "tomatoes", "wheat", "watermelons", "fish", "dates", "eggs", "milk"]
const LEVELS: Array[Dictionary] = [
	{"at": 10, "item": "seeds", "amount": 3},
	{"at": 30, "item": "tomato_seeds", "amount": 3},
	{"at": 60, "item": "wheat_seeds", "amount": 3},
	{"at": 100, "item": "watermelon_seeds", "amount": 3},
]

var points: int = 0
var levels_paid: int = 0
var gifted: Dictionary = {}
var fund_done: bool = false
var fed_done: bool = false
var _rose: bool = false

func gifted_today(person: String) -> bool:
	return gifted.has(person)

func give_food(person: String, item_id: String) -> bool:
	var bag: Inventory = _bag()
	if bag == null or person == "" or gifted_today(person) or not item_id in FOODS:
		return false
	if not bag.take_item(item_id, 1):
		return false
	gifted[person] = true
	_earn(GIFT_POINTS)
	return true

func give_fund() -> bool:
	var bag: Inventory = _bag()
	if bag == null or fund_done or bag.dinars < FUND_PRICE:
		return false
	bag.dinars -= FUND_PRICE
	fund_done = true
	_earn(FUND_POINTS)
	return true

## Khair for a finished project or a request. It follows the same rules as any other kindness.
func reward(amount: int) -> void:
	_earn(amount)

func note_feeding() -> void:
	if fed_done:
		return
	fed_done = true
	_earn(FEED_POINTS)

func on_new_day() -> void:
	gifted.clear()
	fund_done = false
	fed_done = false

## True once after the meter reaches a new level.
func take_level_up() -> bool:
	var rose: bool = _rose
	_rose = false
	return rose

func to_data() -> Dictionary:
	return {
		"points": points,
		"levels_paid": levels_paid,
		"gifted": gifted.duplicate(),
		"fund_done": fund_done,
		"fed_done": fed_done,
	}

func from_data(data: Dictionary) -> void:
	points = clampi(int(data.get("points", 0)), 0, MAX_POINTS)
	levels_paid = clampi(int(data.get("levels_paid", 0)), 0, LEVELS.size())
	fund_done = bool(data.get("fund_done", false))
	fed_done = bool(data.get("fed_done", false))
	_rose = false
	gifted.clear()
	var stored: Variant = data.get("gifted", {})
	if stored is Dictionary:
		for key: Variant in stored:
			gifted[str(key)] = true

func _earn(amount: int) -> void:
	points = mini(points + amount, MAX_POINTS)
	var bag: Inventory = _bag()
	while levels_paid < LEVELS.size() and points >= int(LEVELS[levels_paid]["at"]):
		if bag != null:
			bag.add_item(str(LEVELS[levels_paid]["item"]), int(LEVELS[levels_paid]["amount"]))
		levels_paid += 1
		_rose = true

func _bag() -> Inventory:
	return get_parent().get_node_or_null("Inventory") as Inventory
