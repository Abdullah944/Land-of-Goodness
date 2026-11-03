# src/scripts/farm/festivals.gd
# Purpose: One village fair each season, on the fifth day: truffles in spring, the divers' return in summer,
# the date harvest in autumn, and the winter camp. The square is dressed up and the elder hands out a gift.

class_name Festivals
extends Node

## Day of the season, from 0 to 6, as GameClock counts them.
const FAIR_DAY: int = 4
const FAIRS: Dictionary = {
	"Spring": {"id": "truffle", "gift": "forage", "amount": 4},
	"Summer": {"id": "qafal", "gift": "pearl", "amount": 1},
	"Autumn": {"id": "harvest", "gift": "dates", "amount": 6},
	"Winter": {"id": "kashta", "gift": "wool", "amount": 3},
}
const KHAIR: int = 3
const FRIEND_POINTS: int = 25
const FLAG_COLORS: Array[Color] = [Color("c0483a"), Color("e9c46a"), Color("3f7a4a"), Color("f4e6c8")]
const PROP: String = "res://assets/props/%s.png"
const DECOR: Array[Dictionary] = [
	{"name": "FairRug", "path": "res://assets/props/rug_sadu.png", "at": Vector2(10, -20), "flat": true},
	{"name": "FairLampA", "path": "res://assets/props/lantern.png", "at": Vector2(-150, -40)},
	{"name": "FairLampB", "path": "res://assets/props/lantern.png", "at": Vector2(170, -40)},
	{"name": "FairLampC", "path": "res://assets/props/lantern.png", "at": Vector2(-150, 70)},
	{"name": "FairLampD", "path": "res://assets/props/lantern.png", "at": Vector2(170, 70)},
	{"name": "FairCushions", "path": "res://assets/building/house/room/cushions.png", "at": Vector2(-40, 20)},
	{"name": "FairCushions2", "path": "res://assets/building/house/room/cushions.png", "at": Vector2(60, 20)},
]
const SEASON_DECOR: Dictionary = {
	"Spring": [{"name": "FairBasket", "path": "res://assets/props/basket.png", "at": Vector2(-40, -60)}, {"name": "FairFlowers", "path": "res://assets/nature/plants/bush_pink.png", "at": Vector2(200, 90), "fit": 30}],
	"Summer": [{"name": "FairFish", "path": "res://assets/props/crate_fish.png", "at": Vector2(-40, -60)}, {"name": "FairPots", "path": "res://assets/props/pot_big.png", "at": Vector2(200, 90)}],
	"Autumn": [{"name": "FairDates", "path": "res://assets/building/house/room/dates_bowl.png", "at": Vector2(-40, -60)}, {"name": "FairSacks", "path": "res://assets/props/sack.png", "at": Vector2(200, 90)}],
	"Winter": [{"name": "FairGreenRug", "path": "res://assets/building/house/room/rug_green.png", "at": Vector2(-120, 20), "flat": true}, {"name": "FairJar", "path": "res://assets/building/house/room/jar.png", "at": Vector2(200, 90)}],
}

var joined_day: int = -1

## Today's fair, or an empty dictionary.
func today() -> Dictionary:
	var clock: GameClock = _clock()
	if clock == null or Friendship.day_of_season(clock.day) != FAIR_DAY:
		return {}
	return FAIRS.get(clock.season, {})

func tomorrow() -> Dictionary:
	var clock: GameClock = _clock()
	if clock == null or Friendship.day_of_season(clock.day + 1) != FAIR_DAY:
		return {}
	return FAIRS.get(GameClock.SEASONS[int(float(clock.day + 1) / 7.0) % GameClock.SEASONS.size()], {})

func can_join() -> bool:
	var clock: GameClock = _clock()
	return not today().is_empty() and clock != null and joined_day != clock.day

## Joins today's fair once: a seasonal gift, a little Khair, and every neighbor a bit closer.
func join() -> bool:
	if not can_join():
		return false
	var fair: Dictionary = today()
	joined_day = _clock().day
	var bag: Inventory = get_parent().get_node_or_null("Inventory") as Inventory
	if bag != null:
		bag.add_item(str(fair["gift"]), int(fair["amount"]))
	var kindness: Kindness = get_parent().get_node_or_null("Kindness") as Kindness
	if kindness != null:
		kindness.reward(KHAIR)
	var friends: Friendship = get_parent().get_node_or_null("Friendship") as Friendship
	if friends != null:
		for person: String in Friendship.PEOPLE:
			friends.points[person] = clampi(int(friends.points.get(person, 0)) + FRIEND_POINTS, 0, Friendship.HEART * Friendship.MAX_HEARTS)
	return true

## The morning news: a fair today or tomorrow, or a neighbor's birthday.
func morning_note() -> String:
	if not today().is_empty():
		return Locale.t("fair_today") % Locale.t("fair_" + str(today()["id"]))
	if not tomorrow().is_empty():
		return Locale.t("fair_tomorrow") % Locale.t("fair_" + str(tomorrow()["id"]))
	var friends: Friendship = get_parent().get_node_or_null("Friendship") as Friendship
	if friends != null and friends.birthday_today() != "":
		return Locale.t("birthday_today") % Locale.t("name_" + friends.birthday_today())
	return ""

## Dresses the town square on a fair day, and takes the decorations down on other days.
func apply_place() -> void:
	var place: Node = _place()
	if place == null or str(place.name) != "Village":
		return
	var fair: Dictionary = today()
	for child: Node in place.get_children():
		if str(child.name).begins_with("Fair"):
			child.queue_free()
	if fair.is_empty():
		return
	var pieces: Array = DECOR.duplicate()
	pieces.append_array(SEASON_DECOR.get(_clock().season, []))
	for piece: Dictionary in pieces:
		PropPiece.add_to(place, piece)
	place.add_child(_bunting(Vector2(-230, -150), Vector2(250, -150)))
	place.add_child(_bunting(Vector2(-230, 100), Vector2(250, 100)))

## A string of small cloth flags across the square.
func _bunting(from: Vector2, to: Vector2) -> Node2D:
	var line: Node2D = Node2D.new()
	line.name = "FairFlags%d" % int(from.y)
	# Sorted with the people standing just below the rope, so they pass in front of it.
	line.position = Vector2(0, from.y + 60)
	var rope: Line2D = Line2D.new()
	rope.width = 1.0
	rope.default_color = Color("5a3a22")
	var count: int = 24
	for i: int in count + 1:
		var t: float = float(i) / count
		var at: Vector2 = Vector2(lerpf(from.x, to.x, t), sin(t * PI) * 14.0 - 60.0)
		rope.add_point(at)
		if i < count:
			var flag: Polygon2D = Polygon2D.new()
			flag.polygon = PackedVector2Array([at, at + Vector2(8, 0), at + Vector2(4, 8)])
			flag.color = FLAG_COLORS[i % FLAG_COLORS.size()]
			line.add_child(flag)
	line.add_child(rope)
	line.move_child(rope, 0)
	return line

func to_data() -> Dictionary:
	return {"joined_day": joined_day}

func from_data(data: Dictionary) -> void:
	joined_day = int(data.get("joined_day", -1))

func _clock() -> GameClock:
	return get_parent().get_node_or_null("Clock") as GameClock

func _place() -> Node:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return null
	var world: Node = scene.get_node_or_null("World")
	if world == null:
		return null
	for child: Node in world.get_children():
		if child.name != "Player":
			return child
	return null
