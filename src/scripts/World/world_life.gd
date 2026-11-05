# src/scripts/World/world_life.gd
# Purpose: Small life outdoors: birds on the ground that fly off when the boy comes near, butterflies by day,
# falling leaves in autumn and petals in spring, fireflies at night, and rain you can see.

class_name WorldLife
extends Node

const BIRDS: int = 4
const BUTTERFLIES: int = 4
const FIREFLIES: int = 16
const LEAVES: int = 14
const PETALS: int = 9
const RAIN_DROPS: int = 70
## Birds lift off when the boy is this close, and come back somewhere else after a while.
const SCARE_PIXELS: float = 48.0
const BIRD_RETURN: Vector2 = Vector2(12, 30)
const BUTTERFLY_COLORS: Array[Color] = [Color("fff3dc"), Color("f6d36b"), Color("f2a65a"), Color("e9e6f5")]
const LEAF_COLORS: Array[Color] = [Color("d08a3a"), Color("b8612c"), Color("e2b04a"), Color("9c6b2f")]
const PETAL_COLORS: Array[Color] = [Color("f7c6d0"), Color("fff3f3"), Color("f3a9bb")]

var _place: Node
var _ground: Node2D
var _sky: Node2D
var _layer: CanvasLayer
var _roll: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_roll.randomize()
	# Fireflies, leaves and rain sit on their own layer that follows the camera, so the night tint does not dim the glow.
	_layer = CanvasLayer.new()
	_layer.follow_viewport_enabled = true
	_layer.layer = 1
	add_child(_layer)
	_sky = SkyLife.new()
	_sky.set("life", self)
	_layer.add_child(_sky)

func _process(_delta: float) -> void:
	var activities: Activities = get_parent().get_node_or_null("Activities") as Activities
	var place: Node = activities.place_node() if activities != null else null
	if place != _place:
		_place = place
		_ground = null
		if place != null and is_outdoors():
			_fill_ground(place)
	_sky.visible = is_outdoors()

func is_outdoors() -> bool:
	return _place != null and is_instance_valid(_place) and WorldShapes.has_place(str(_place.name))

func place_name() -> String:
	return str(_place.name) if is_outdoors() else ""

func clock() -> GameClock:
	return get_parent().get_node_or_null("Clock") as GameClock

func player() -> Node2D:
	var scene: Node = get_tree().current_scene
	return scene.find_child("Player", true, false) as Node2D if scene != null else null

## The part of the world the camera shows, in world pixels.
func view_rect() -> Rect2:
	var view: Rect2 = get_viewport().get_visible_rect()
	var to_world: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	return Rect2(to_world * view.position, to_world.basis_xform(view.size))

func hour() -> float:
	var time: GameClock = clock()
	return fmod(time.minute / 60.0, 24.0) if time != null else 12.0

func raining() -> bool:
	var time: GameClock = clock()
	return time != null and time.weather == "Rain"

func season() -> String:
	var time: GameClock = clock()
	return time.season if time != null else "Spring"

## A dry spot away from water, roads and the edge, near the given point.
func ground_spot(near: Vector2, reach: float) -> Vector2:
	var place: String = place_name()
	for attempt: int in 20:
		var spot: Vector2 = near + Vector2(_roll.randf_range(-reach, reach), _roll.randf_range(-reach, reach) * 0.7)
		if place == "" or (WorldShapes.edge(place, spot) < 0.88 and WorldShapes.water_depth(place, spot) < -14.0 and not WorldShapes.on_planks(place, spot)):
			return spot
	return near

func _fill_ground(place: Node) -> void:
	var life: Node2D = Node2D.new()
	life.name = "Life"
	place.add_child(life)
	_ground = life
	var hero: Node2D = player()
	var center: Vector2 = hero.global_position if hero != null else Vector2.ZERO
	for i: int in BIRDS:
		var bird: GroundBird = GroundBird.new()
		bird.life = self
		bird.position = ground_spot(center, 220.0)
		life.add_child(bird)
	for i: int in BUTTERFLIES:
		var fly: Butterfly = Butterfly.new()
		fly.life = self
		fly.home = ground_spot(center, 200.0)
		fly.position = fly.home
		fly.color = BUTTERFLY_COLORS[_roll.randi_range(0, BUTTERFLY_COLORS.size() - 1)]
		life.add_child(fly)

## A small brown bird that hops and pecks, and flies away when the boy comes close.
class GroundBird extends Node2D:
	var life: WorldLife
	var _hop_left: float = 0.0
	var _peck: float = 0.0
	var _flying: bool = false
	var _speed: Vector2 = Vector2.ZERO
	var _away: float = 0.0
	var _clock: float = 0.0
	var _facing: float = 1.0
	var _rest: float = 0.0

	func _ready() -> void:
		_hop_left = randf() * 2.0
		_facing = -1.0 if randf() < 0.5 else 1.0

	func _process(delta: float) -> void:
		_clock += delta
		var awake: bool = life.hour() >= 6.0 and life.hour() < 19.0 and not life.raining()
		if _flying:
			position += _speed * delta
			_speed.y -= 20.0 * delta
			_away -= delta
			modulate.a = clampf(_away / 0.8, 0.0, 1.0)
			if _away <= -_rest:
				_land()
		else:
			visible = awake
			var hero: Node2D = life.player()
			if hero != null and visible and (hero.global_position + Vector2(0, 18)).distance_to(global_position) < WorldLife.SCARE_PIXELS:
				_take_off(hero.global_position)
			_hop_left -= delta
			if _hop_left <= 0.0:
				_hop_left = 0.6 + randf() * 2.2
				if randf() < 0.55:
					_facing = -_facing if randf() < 0.4 else _facing
					var hop: Tween = create_tween()
					hop.tween_property(self, "position", position + Vector2(_facing * randf_range(3.0, 7.0), randf_range(-2.0, 2.0)), 0.16)
				else:
					_peck = 0.3
			_peck = maxf(0.0, _peck - delta)
		z_index = 3300 if _flying else 2000 + int(global_position.y)
		queue_redraw()

	func _take_off(from: Vector2) -> void:
		_flying = true
		var away: Vector2 = (global_position - from).normalized()
		_facing = 1.0 if away.x >= 0.0 else -1.0
		_speed = Vector2(away.x * 70.0 + _facing * 20.0, -55.0 - randf() * 20.0)
		_away = 2.0
		_rest = randf_range(WorldLife.BIRD_RETURN.x, WorldLife.BIRD_RETURN.y)

	func _land() -> void:
		_flying = false
		modulate.a = 1.0
		var hero: Node2D = life.player()
		var near: Vector2 = hero.global_position if hero != null else Vector2.ZERO
		# Somewhere out of sight of the boy, so it is simply there next time he passes.
		var side: Vector2 = Vector2(1, 0).rotated(randf() * TAU) * 260.0
		position = life.ground_spot(near + side, 60.0)

	func _draw() -> void:
		var body: Color = Color("8b6a4a")
		var belly: Color = Color("d8c3a0")
		var dark: Color = Color("3f2d27")
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1.0))
		if _flying:
			var flap: float = sin(_clock * 28.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-1, -4), Vector2(2, -4), Vector2(-2, -4 - 4.0 * flap)]), body)
			draw_set_transform(Vector2(0, -4), 0.0, Vector2(_facing * 2.4, 1.4))
			draw_circle(Vector2.ZERO, 1.0, body)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1.0))
			draw_circle(Vector2(2.6, -4.6), 1.1, body)
			return
		UiStyle.draw_shadow(self, Vector2(0, 0), 5.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1.0))
		var dip: float = 1.4 if _peck > 0.0 and fmod(_peck, 0.15) < 0.08 else 0.0
		draw_colored_polygon(PackedVector2Array([Vector2(-2.2, -2.6), Vector2(-4.6, -3.6), Vector2(-4.2, -2.2)]), body)
		draw_set_transform(Vector2(0, -2.6), 0.0, Vector2(_facing * 2.4, 1.6))
		draw_circle(Vector2.ZERO, 1.0, body)
		draw_set_transform(Vector2(0.4 * _facing, -2.0), 0.0, Vector2(_facing * 1.6, 0.8))
		draw_circle(Vector2.ZERO, 1.0, belly)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1.0))
		var head: Vector2 = Vector2(2.4, -4.2 + dip)
		draw_circle(head, 1.4, body)
		draw_circle(head + Vector2(0.5, -0.3), 0.35, dark)
		draw_colored_polygon(PackedVector2Array([head + Vector2(1.2, -0.3), head + Vector2(2.6, 0.2), head + Vector2(1.2, 0.5)]), Color("e0a44a"))
		draw_line(Vector2(-0.5, -1.0), Vector2(-0.5, 0.0), dark, 0.5)
		draw_line(Vector2(0.6, -1.0), Vector2(0.6, 0.0), dark, 0.5)

## A butterfly that wanders around a patch of grass on spring and summer days.
class Butterfly extends Node2D:
	var life: WorldLife
	var home: Vector2
	var color: Color = Color.WHITE
	var _clock: float = 0.0
	var _seed: float = 0.0

	func _ready() -> void:
		_seed = randf() * 100.0
		z_index = 3300

	func _process(delta: float) -> void:
		_clock += delta
		var season: String = life.season()
		visible = (season == "Spring" or season == "Summer") and life.hour() >= 7.0 and life.hour() < 18.0 and not life.raining()
		if not visible:
			return
		var t: float = _clock * 0.5 + _seed
		position = home + Vector2(sin(t * 1.3) * 40.0 + sin(t * 3.1) * 10.0, cos(t * 0.9) * 22.0 + sin(t * 4.3) * 5.0 - 14.0)
		queue_redraw()

	func _draw() -> void:
		var flap: float = absf(sin(_clock * 16.0 + _seed))
		var wing: Vector2 = Vector2(2.6 * (0.25 + flap * 0.75), 2.2)
		for side: float in [-1.0, 1.0]:
			draw_set_transform(Vector2(side * wing.x * 0.6, -0.6), 0.0, Vector2(wing.x * 0.45, wing.y * 0.5))
			draw_circle(Vector2.ZERO, 1.0, color)
			draw_set_transform(Vector2(side * wing.x * 0.45, 0.9), 0.0, Vector2(wing.x * 0.32, wing.y * 0.35))
			draw_circle(Vector2.ZERO, 1.0, color.darkened(0.12))
		draw_set_transform(Vector2.ZERO)
		draw_line(Vector2(0, -1.4), Vector2(0, 1.6), Color("3f2d27"), 0.7)
		draw_set_transform(Vector2(0, 14.0), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 1.6, Color(0.1, 0.08, 0.05, 0.12))
		draw_set_transform(Vector2.ZERO)

## Everything that floats over the whole view: fireflies, leaves, petals, and rain.
class SkyLife extends Node2D:
	var life: WorldLife
	var _bits: Array[Dictionary] = []
	var _kind: String = ""
	var _clock: float = 0.0

	func _process(delta: float) -> void:
		_clock += delta
		var view: Rect2 = life.view_rect()
		var wanted: String = _wanted()
		if wanted != _kind:
			_kind = wanted
			_bits.clear()
			for i: int in _count(wanted):
				_bits.append(_new_bit(view, true))
		for bit: Dictionary in _bits:
			_move(bit, delta, view)
		queue_redraw()

	func _wanted() -> String:
		if not life.is_outdoors():
			return ""
		var hour: float = life.hour()
		if life.raining():
			return "rain"
		var night: bool = hour >= 19.5 or hour < 5.0
		if night and life.season() != "Winter":
			return "fireflies"
		if night:
			return ""
		if life.season() == "Autumn":
			return "leaves"
		if life.season() == "Spring":
			return "petals"
		return ""

	func _count(kind: String) -> int:
		return {"rain": WorldLife.RAIN_DROPS, "fireflies": WorldLife.FIREFLIES, "leaves": WorldLife.LEAVES, "petals": WorldLife.PETALS}.get(kind, 0)

	func _new_bit(view: Rect2, anywhere: bool) -> Dictionary:
		var at: Vector2 = Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
		if not anywhere:
			at.y = view.position.y - 10.0
			if _kind == "leaves" or _kind == "petals":
				at.x = randf_range(view.position.x - view.size.x * 0.3, view.end.x)
		var bit: Dictionary = {"at": at, "seed": randf() * 100.0, "spin": randf() * TAU}
		match _kind:
			"rain":
				bit["speed"] = randf_range(260.0, 340.0)
				bit["length"] = randf_range(5.0, 9.0)
			"leaves":
				bit["color"] = WorldLife.LEAF_COLORS[randi() % WorldLife.LEAF_COLORS.size()]
				bit["speed"] = randf_range(14.0, 24.0)
			"petals":
				bit["color"] = WorldLife.PETAL_COLORS[randi() % WorldLife.PETAL_COLORS.size()]
				bit["speed"] = randf_range(10.0, 18.0)
			"fireflies":
				bit["home"] = at
		return bit

	func _move(bit: Dictionary, delta: float, view: Rect2) -> void:
		var at: Vector2 = bit["at"]
		var t: float = _clock + float(bit["seed"])
		match _kind:
			"rain":
				at += Vector2(-0.25, 1.0) * float(bit["speed"]) * delta
			"leaves", "petals":
				at += Vector2(10.0 + sin(t * 1.7) * 14.0, float(bit["speed"])) * delta
				bit["spin"] = float(bit["spin"]) + delta * 2.4
			"fireflies":
				at = Vector2(bit["home"]) + Vector2(sin(t * 0.7) * 26.0, cos(t * 0.53) * 16.0)
		bit["at"] = at
		var out: bool = at.y > view.end.y + 12.0 or at.x > view.end.x + 30.0 or at.x < view.position.x - view.size.x * 0.4
		if _kind == "fireflies":
			out = not view.grow(40.0).has_point(at)
		if out:
			var fresh: Dictionary = _new_bit(view, _kind == "fireflies")
			for key: Variant in fresh:
				bit[key] = fresh[key]

	func _draw() -> void:
		var tint: Color = _tint()
		for bit: Dictionary in _bits:
			var at: Vector2 = bit["at"]
			match _kind:
				"rain":
					draw_line(at, at + Vector2(-0.25, 1.0) * float(bit["length"]), Color(0.78, 0.88, 0.95, 0.45), 0.8)
				"leaves", "petals":
					var spin: float = float(bit["spin"])
					var color: Color = Color(bit["color"]) * tint
					var wide: float = 3.4 if _kind == "leaves" else 2.2
					draw_set_transform(at, spin, Vector2(wide * (0.35 + absf(cos(spin)) * 0.65), wide * 0.6))
					draw_circle(Vector2.ZERO, 1.15, color.darkened(0.35))
					draw_circle(Vector2.ZERO, 1.0, color)
					draw_set_transform(Vector2.ZERO)
				"fireflies":
					var glow: float = 0.5 + 0.5 * sin(_clock * 2.3 + float(bit["seed"]) * 3.0)
					draw_circle(at, 5.0, Color(1.0, 0.92, 0.45, 0.10 * glow))
					draw_circle(at, 2.6, Color(1.0, 0.93, 0.5, 0.25 * glow))
					draw_circle(at, 1.2, Color(1.0, 1.0, 0.75, 0.95 * glow))

	func _tint() -> Color:
		var scene: Node = get_tree().current_scene
		var night: CanvasModulate = scene.get_node_or_null("NightTint") as CanvasModulate if scene != null else null
		return night.color if night != null else Color.WHITE
