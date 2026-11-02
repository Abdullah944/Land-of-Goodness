# src/scripts/farm/village_works.gd
# Purpose: The village projects, the neighbors' daily requests, and the festival that ends the story.

class_name VillageWorks
extends Node

const REQUEST_POINTS: int = 3
const PEOPLE: Array[String] = ["jassim", "elder", "fisherman", "merchant", "carpenter"]
const PROJECTS: Array[Dictionary] = [
	{"id": "well", "khair": 8, "costs": {"stone": 16, "wood": 8, "dinars": 600}},
	{"id": "grove", "khair": 8, "costs": {"dates": 8, "wood": 12, "dinars": 900}},
	{"id": "market", "khair": 8, "costs": {"wood": 16, "stone": 10, "dinars": 1200}},
	{"id": "dock", "khair": 8, "costs": {"wood": 24, "copper": 5, "fish": 5, "dinars": 1600}},
	{"id": "diwaniya", "khair": 8, "costs": {"wood": 30, "stone": 24, "milk": 4, "eggs": 4, "dinars": 2500}},
]
## Pictures each finished project adds to a place. "flat" pieces lie on the ground.
const PIECES: Dictionary = {
	"well": [
		{"place": "Village", "name": "WorkWell", "path": "res://assets/props/well.png", "at": Vector2(-150, 200), "fit": 58, "block": Vector2(38, 14)},
	],
	"grove": [
		{"place": "Orchard", "name": "GrovePalm1", "path": "res://assets/nature/Date palm.png", "at": Vector2(-260, 60), "group": "date"},
		{"place": "Orchard", "name": "GrovePalm2", "path": "res://assets/nature/Date palm.png", "at": Vector2(-60, 200), "group": "date"},
		{"place": "Orchard", "name": "GrovePalm3", "path": "res://assets/nature/Date palm.png", "at": Vector2(200, 180), "group": "date"},
	],
	"market": [
		{"place": "Village", "name": "WorkStallA", "path": "res://assets/props/stall_produce.png", "at": Vector2(-20, 130), "fit": 64, "block": Vector2(56, 16)},
		{"place": "Village", "name": "WorkStallB", "path": "res://assets/props/stall_pots.png", "at": Vector2(60, 130), "fit": 64, "block": Vector2(56, 16)},
		{"place": "Village", "name": "WorkLampA", "path": "res://assets/props/lantern.png", "at": Vector2(-70, 130)},
		{"place": "Village", "name": "WorkLampB", "path": "res://assets/props/lantern.png", "at": Vector2(110, 130)},
	],
	"dock": [
		{"place": "Harbor", "name": "WorkDhow", "path": "res://assets/building/harbor/Dhow.png", "at": Vector2(-470, 240), "fit": 130},
		{"place": "Harbor", "name": "WorkLampA", "path": "res://assets/props/lantern.png", "at": Vector2(6, 120)},
		{"place": "Harbor", "name": "WorkLampB", "path": "res://assets/props/lantern.png", "at": Vector2(114, 120)},
	],
	"diwaniya": [
		{"place": "Village", "name": "WorkDiwaniya", "path": "res://assets/building/house/Desert Adobe Rooftop House Sprite.png", "at": Vector2(-120, 300), "fit": 170, "block": Vector2(144, 48)},
		{"place": "Village", "name": "WorkRug", "path": "res://assets/props/rug_sadu.png", "at": Vector2(30, 280), "flat": true},
		{"place": "Village", "name": "WorkLampA", "path": "res://assets/props/lantern.png", "at": Vector2(-20, 250)},
		{"place": "Village", "name": "WorkLampB", "path": "res://assets/props/lantern.png", "at": Vector2(80, 250)},
	],
}

var done: Dictionary = {}
var finished: bool = false
var request: Dictionary = {}

func is_done(project_id: String) -> bool:
	return bool(done.get(project_id, false))

func all_done() -> bool:
	for project: Dictionary in PROJECTS:
		if not is_done(str(project["id"])):
			return false
	return true

## The next project, in order. Empty when every project is finished.
func next_project() -> Dictionary:
	for project: Dictionary in PROJECTS:
		if not is_done(str(project["id"])):
			return project
	return {}

## Pays for the next project and returns true when it was built.
func fund_next() -> bool:
	var project: Dictionary = next_project()
	var stead: Stead = _stead()
	if project.is_empty() or stead == null or not stead.pay_costs(project["costs"]):
		return false
	done[str(project["id"])] = true
	var kindness: Kindness = _kindness()
	if kindness != null:
		kindness.reward(int(project["khair"]))
	apply_place()
	return true

func festival_ready() -> bool:
	var kindness: Kindness = _kindness()
	return not finished and all_done() and kindness != null and kindness.points >= Kindness.MAX_POINTS

func finish_story() -> void:
	finished = true

## Today's request, made fresh each morning from what the farm can provide.
func request_today() -> Dictionary:
	var day: int = _day()
	if int(request.get("day", -1)) != day:
		request = _make_request(day)
	return request

func can_help(person: String) -> bool:
	var wish: Dictionary = request_today()
	return str(wish.get("person", "")) == person and not bool(wish.get("done", false))

## Hands over the wanted goods. Pays dinars and Khair once.
func fulfil_request() -> bool:
	var wish: Dictionary = request_today()
	var bag: Inventory = _bag()
	if bool(wish.get("done", false)) or wish.is_empty() or bag == null:
		return false
	if not bag.take_item(str(wish["item"]), int(wish["amount"])):
		return false
	bag.dinars += int(wish["pay"])
	wish["done"] = true
	request = wish
	var kindness: Kindness = _kindness()
	if kindness != null:
		kindness.reward(REQUEST_POINTS)
	return true

## Draws the finished projects in the place the boy is standing in.
func apply_place() -> void:
	var place: Node = _place()
	if place == null:
		return
	var added: bool = false
	for project: Dictionary in PROJECTS:
		var project_id: String = str(project["id"])
		if not is_done(project_id):
			continue
		for piece: Dictionary in PIECES.get(project_id, []):
			if str(piece["place"]) == str(place.name) and place.get_node_or_null(str(piece["name"])) == null:
				PropPiece.add_to(place, piece)
				added = true
	if added:
		var activities: Activities = get_parent().get_node_or_null("Activities") as Activities
		if activities != null:
			activities.apply_gathered()

func to_data() -> Dictionary:
	return {"done": done.duplicate(), "finished": finished, "request": request.duplicate()}

func from_data(data: Dictionary) -> void:
	done.clear()
	var stored: Variant = data.get("done", {})
	if stored is Dictionary:
		for project: Dictionary in PROJECTS:
			if bool(stored.get(str(project["id"]), false)):
				done[str(project["id"])] = true
	finished = bool(data.get("finished", false))
	request = {}
	var wish: Variant = data.get("request", {})
	if wish is Dictionary and int(wish.get("day", -1)) == _day() and int(wish.get("amount", 0)) > 0 \
			and str(wish.get("person", "")) in PEOPLE and str(wish.get("item", "")) in Inventory.all_stored_ids():
		request = {
			"day": int(wish["day"]),
			"person": str(wish["person"]),
			"item": str(wish["item"]),
			"amount": int(wish["amount"]),
			"pay": maxi(0, int(wish.get("pay", 0))),
			"done": bool(wish.get("done", false)),
		}
	apply_place()

func _make_request(day: int) -> Dictionary:
	var pool: Array[String] = ["wood", "stone", "fish", "forage"]
	var clock: GameClock = get_parent().get_node_or_null("Clock") as GameClock
	var season: String = clock.season if clock != null else "Spring"
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		if crop.get("seasons", []).has(season):
			pool.append(str(crop.get("harvest_item", "")))
	var stead: Stead = _stead()
	if stead != null:
		if bool(stead.visited.get("Orchard", false)):
			pool.append("dates")
		if stead.count_kind("chicken") > 0:
			pool.append("eggs")
		if stead.count_kind("goat") + stead.count_kind("cow") > 0:
			pool.append("milk")
		if stead.count_kind("sheep") > 0:
			pool.append("wool")
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = day * 7919 + 13
	var item: String = pool[roll.randi_range(0, pool.size() - 1)]
	var price: int = maxi(GoodsCatalog.sell_price(item), 1)
	var amount: int = roll.randi_range(3, 5) if price < 20 else roll.randi_range(1, 3)
	return {
		"day": day,
		"person": PEOPLE[roll.randi_range(0, PEOPLE.size() - 1)],
		"item": item,
		"amount": amount,
		"pay": int(ceil(price * amount * 1.5)) + 10,
		"done": false,
	}

func _day() -> int:
	var clock: GameClock = get_parent().get_node_or_null("Clock") as GameClock
	return clock.day if clock != null else 1

func _stead() -> Stead:
	return get_parent().get_node_or_null("Stead") as Stead

func _kindness() -> Kindness:
	return get_parent().get_node_or_null("Kindness") as Kindness

func _bag() -> Inventory:
	return get_parent().get_node_or_null("Inventory") as Inventory

func _place() -> Node:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	var world: Node = scene.get_node_or_null("World") if scene != null else null
	if world == null:
		return null
	for child: Node in world.get_children():
		if child.name != "Player":
			return child
	return null
