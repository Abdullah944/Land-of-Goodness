# src/scripts/ui/world_map.gd
# Purpose: The Map tab. Draws the whole land, its roads, and a mark where the boy is now.
# Drag to look around; pinch, the mouse wheel, or the + and - buttons zoom in and out.
# Tap a place you have already walked to and the boy travels there at once.

class_name WorldMap
extends Control

## A place the boy has been to was tapped; the HUD closes the menu and takes him there.
signal place_chosen(key: String)

const SEA: Color = Color("4f9fb8")
const SEA_DEEP: Color = Color("3f8aa6")
const FOAM: Color = Color("d8f0f2")
const SAND: Color = Color("edd29a")
const SAND_WET: Color = Color("d9b878")
const GREEN: Color = Color("86ad62")
const GREEN_DARK: Color = Color("6e9450")
const FOREST: Color = Color("3f6d4a")
const TREE_TOP: Color = Color("5b8f5a")
const ROAD: Color = Color("b98c54")
const ROAD_EDGE: Color = Color("8a6238")
const ICON_SIZE: float = 30.0
const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 3.0
const ZOOM_STEP: float = 1.35
## A press that moves less than this is a tap, not a drag.
const TAP_SLOP: float = 6.0
const NOTE_TIME: int = 2200
## Small spots that show their names once the map is zoomed in this far.
const DETAIL_ZOOM: float = 1.6

## key: [spot on the map, picture, name]
const PLACES: Dictionary = {
	"Home": [Vector2(74, 76), "res://assets/building/house/Desert Adobe Rooftop House Sprite.png", "to_home"],
	"Cave": [Vector2(28, 28), "res://assets/building/Cave/Sandstone Cave Entrance.png", "to_cave"],
	"Road": [Vector2(176, 56), "res://assets/props/stall_produce.png", "to_road"],
	"Forest": [Vector2(112, 114), "res://assets/nature/Leafy 16-Bit Farm Tree Sprite.png", "to_forest"],
	"Village": [Vector2(276, 66), "res://assets/building/Mosque/mosque.png", "to_village"],
	"Orchard": [Vector2(250, 18), "res://assets/nature/Date palm.png", "to_orchard"],
	"Harbor": [Vector2(296, 108), "res://assets/building/harbor/Dhow.png", "to_harbor"],
}
const LINKS: Array = [
	["Home", "Road"], ["Road", "Village"], ["Home", "Forest"], ["Forest", "Village"], ["Village", "Orchard"], ["Village", "Harbor"], ["Home", "Cave"],
]
## [spot on the map, name] for the smaller things inside places.
## Only a few, so the zoomed-in map stays tidy.
const DETAILS: Array = [
	[Vector2(256, 82), "sign_mosque"], [Vector2(300, 52), "sign_market"], [Vector2(318, 124), "map_dock"],
]
## Where each neighbor can be found, so a "!" on the map shows where someone needs the boy.
const PERSON_PLACES: Dictionary = {"jassim": "Home", "elder": "Village", "merchant": "Village", "carpenter": "Village", "fisherman": "Harbor"}
const SPOTS: Dictionary = {"HouseInside": "Home", "MosqueInside": "Village", "WorkshopInside": "Village"}
const LAND: PackedVector2Array = [
	Vector2(0, 0), Vector2(429, 0), Vector2(429, 84), Vector2(372, 96), Vector2(330, 106), Vector2(280, 104),
	Vector2(226, 124), Vector2(190, 142), Vector2(0, 142),
]
const FARM_GREEN: PackedVector2Array = [Vector2(0, 40), Vector2(40, 34), Vector2(124, 44), Vector2(136, 96), Vector2(92, 106), Vector2(0, 104)]
const WOODS: PackedVector2Array = [Vector2(60, 104), Vector2(160, 100), Vector2(176, 128), Vector2(164, 142), Vector2(50, 142)]
const TOWN_GREEN: PackedVector2Array = [Vector2(210, 34), Vector2(330, 32), Vector2(346, 88), Vector2(216, 92)]
const GROVE_GREEN: PackedVector2Array = [Vector2(214, 0), Vector2(290, 0), Vector2(294, 32), Vector2(216, 34)]

var zoom: float = 1.0
## Where the map's top-left corner sits on screen, in map pixels.
var offset: Vector2 = Vector2.ZERO

var _icons: Dictionary = {}
var _trees: PackedVector2Array = []
var _dragging: bool = false
var _drag_from: Vector2
var _offset_at_drag: Vector2
var _touches: Dictionary = {}
var _pinch_gap: float = 0.0
var _zoom_in: Button
var _zoom_out: Button
var _center: Button
var _was_visible: bool = false
var _note: String = ""
var _note_until: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_scatter()
	_zoom_in = _map_button("+", _zoom_by.bind(ZOOM_STEP))
	_zoom_out = _map_button("-", _zoom_by.bind(1.0 / ZOOM_STEP))
	_center = _map_button("", center_on_you)
	resized.connect(_place_buttons)
	_place_buttons()

func _process(_delta: float) -> void:
	if visible and not _was_visible:
		# Each time the map opens it starts zoomed out, with the whole land in view.
		zoom = MIN_ZOOM
		offset = Vector2.ZERO
	_was_visible = visible
	if visible:
		_center.text = Locale.t("map_me")
		Locale.apply_control(_center)
		queue_redraw()

## Where the boy's mark goes.
func current_spot() -> Vector2:
	var stead: Node = get_tree().current_scene.get_node_or_null("Systems/Stead")
	var place: String = str(stead.get("place_name")) if stead != null else "Home"
	place = str(SPOTS.get(place, place))
	return PLACES[place][0] if PLACES.has(place) else Vector2(PLACES["Home"][0])

func current_key() -> String:
	var stead: Node = get_tree().current_scene.get_node_or_null("Systems/Stead")
	var place: String = str(stead.get("place_name")) if stead != null else "Home"
	place = str(SPOTS.get(place, place))
	return place if PLACES.has(place) else "Home"

## Zooms by a step, keeping the given screen point still. Without a point it keeps the middle still.
func zoom_at(factor: float, screen_point: Vector2 = Vector2.INF) -> void:
	var still: Vector2 = size * 0.5 if screen_point == Vector2.INF else screen_point
	var map_point: Vector2 = (still - offset) / zoom
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	offset = still - map_point * zoom
	_keep_in_view()

func center_on_you() -> void:
	if zoom < 1.5:
		zoom = 2.0
	offset = size * 0.5 - current_spot() * zoom
	_keep_in_view()

## True when the boy may travel to this place from the map: home always, other places once walked to.
func can_travel(key: String) -> bool:
	if key == "Home":
		return true
	var stead: Node = get_tree().current_scene.get_node_or_null("Systems/Stead")
	return stead != null and bool((stead.get("visited") as Dictionary).get(key, false))

## Places with something waiting today: a neighbor's request, Jassim's first task, or a birthday.
func task_places() -> Dictionary:
	var marks: Dictionary = {}
	var systems: Node = get_tree().current_scene.get_node_or_null("Systems") if is_inside_tree() else null
	if systems == null:
		return marks
	var works: Node = systems.get_node_or_null("VillageWorks")
	if works != null:
		var wish: Dictionary = works.call("request_today")
		if not wish.is_empty() and not bool(wish.get("done", false)):
			marks[PERSON_PLACES.get(str(wish.get("person", "")), "")] = true
	var activities: Node = systems.get_node_or_null("Activities")
	if activities != null and not bool(activities.get("quest_done")):
		marks["Home"] = true
	var friends: Node = systems.get_node_or_null("Friendship")
	if friends != null:
		var person: String = str(friends.call("birthday_today"))
		if person != "":
			marks[PERSON_PLACES.get(person, "")] = true
	var fairs: Node = systems.get_node_or_null("Festivals")
	if fairs != null and bool(fairs.call("caravan_open")):
		marks["Village"] = true
	# A leaf over the farm when something there is ready to pick, unless someone already needs you there.
	var farm: Node = systems.get_node_or_null("FarmField")
	if farm != null and bool(farm.call("has_ripe")) and not marks.has("Home"):
		marks["Home"] = "ripe"
	marks.erase("")
	return marks

## Acts on a tap at a point on the map: travels to the place there, or says why it can't.
func tap_at(screen_point: Vector2) -> void:
	var key: String = place_at(screen_point)
	if key == "":
		return
	if can_travel(key):
		place_chosen.emit(key)
	else:
		_note = Locale.t("map_walk_first")
		_note_until = Time.get_ticks_msec() + NOTE_TIME

## The place whose badge or name tag is under a point on the map, or "" for none.
func place_at(screen_point: Vector2) -> String:
	var radius: float = 13.0 * clampf(1.0 + (zoom - 1.0) * 0.35, 1.0, 1.7)
	for key: String in PLACES:
		var at: Vector2 = _screen(PLACES[key][0])
		if at.distance_to(screen_point) <= radius + 4.0 or Rect2(at + Vector2(-30.0, radius), Vector2(60.0, 16.0)).has_point(screen_point):
			return key
	return ""

func _zoom_by(factor: float) -> void:
	zoom_at(factor)

## The land always fills the window; it never slides away to show empty space.
func _keep_in_view() -> void:
	offset.x = clampf(offset.x, size.x - size.x * zoom, 0.0)
	offset.y = clampf(offset.y, size.y - size.y * zoom, 0.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		_pinch_gap = _touch_gap()
		if _touches.size() >= 2:
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_touches[drag.index] = drag.position
		if _touches.size() >= 2:
			var gap: float = _touch_gap()
			if _pinch_gap > 1.0 and gap > 1.0:
				zoom_at(gap / _pinch_gap, _touch_middle())
			_pinch_gap = gap
		accept_event()
	elif event is InputEventMagnifyGesture:
		var magnify: InputEventMagnifyGesture = event
		zoom_at(magnify.factor, magnify.position)
		accept_event()
	elif event is InputEventPanGesture:
		var pan: InputEventPanGesture = event
		offset -= pan.delta * 4.0
		_keep_in_view()
		accept_event()
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index == MOUSE_BUTTON_WHEEL_UP and click.pressed:
			zoom_at(1.1, click.position)
		elif click.button_index == MOUSE_BUTTON_WHEEL_DOWN and click.pressed:
			zoom_at(1.0 / 1.1, click.position)
		elif click.button_index == MOUSE_BUTTON_LEFT:
			if not click.pressed and _dragging and click.position.distance_to(_drag_from) < TAP_SLOP:
				tap_at(click.position)
			_dragging = click.pressed and _touches.size() < 2
			_drag_from = click.position
			_offset_at_drag = offset
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if _touches.size() >= 2:
			_dragging = false
			return
		var motion: InputEventMouseMotion = event
		offset = _offset_at_drag + motion.position - _drag_from
		_keep_in_view()
		accept_event()

func _touch_gap() -> float:
	if _touches.size() < 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1])

func _touch_middle() -> Vector2:
	var points: Array = _touches.values()
	return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	draw_set_transform(offset, 0.0, Vector2(zoom, zoom))
	_draw_land()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Names, icons, and the boy's mark keep their size on screen, so zooming in shows more room between them.
	for link: Array in LINKS:
		_draw_road(_screen(PLACES[link[0]][0]), _screen(PLACES[link[1]][0]))
	if zoom >= DETAIL_ZOOM:
		for detail: Array in DETAILS:
			if not _near_place(_screen(detail[0])):
				_draw_detail(_screen(detail[0]), Locale.t(str(detail[1])))
	var here: String = current_key()
	var tasks: Dictionary = task_places()
	for key: String in PLACES:
		_draw_place(key, key == here)
		if tasks.has(key):
			_draw_task_mark(key, str(tasks[key]) == "ripe")
	_draw_you()
	_draw_compass(Vector2(size.x - 20.0, 20.0))
	_draw_here_tag(here)
	if Time.get_ticks_msec() < _note_until:
		_draw_note(_note)
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BROWN, false, 2.0)

## True when a spot would sit on top of a place's badge or name tag.
func _near_place(at: Vector2) -> bool:
	var radius: float = 13.0 * clampf(1.0 + (zoom - 1.0) * 0.35, 1.0, 1.7)
	for key: String in PLACES:
		var badge: Vector2 = _screen(PLACES[key][0])
		if Rect2(badge - Vector2(radius + 30.0, radius + 6.0), Vector2(radius * 2.0 + 60.0, radius * 2.0 + 26.0)).has_point(at):
			return true
	return false

func _screen(map_point: Vector2) -> Vector2:
	return offset + map_point * zoom

func _draw_land() -> void:
	_wave_lines()
	draw_polyline(_closed(LAND), FOAM, 4.0)
	draw_colored_polygon(LAND, SAND_WET)
	draw_colored_polygon(_shrunk(LAND, 2.0), SAND)
	for part: PackedVector2Array in [FARM_GREEN, TOWN_GREEN, GROVE_GREEN]:
		draw_colored_polygon(part, GREEN)
		draw_polyline(_closed(part), GREEN_DARK, 1.0)
	draw_colored_polygon(WOODS, FOREST)
	for tree: Vector2 in _trees:
		draw_circle(tree + Vector2(0.6, 0.8), 3.2, Color(0.1, 0.2, 0.12, 0.5))
		draw_circle(tree, 3.0, TREE_TOP)
		draw_circle(tree + Vector2(-0.9, -0.9), 1.2, Color("7fb070"))
	draw_polyline(PackedVector2Array([Vector2(340, 0), Vector2(322, 40), Vector2(332, 72), Vector2(320, 108)]), SEA_DEEP, 6.0)
	draw_polyline(PackedVector2Array([Vector2(340, 0), Vector2(322, 40), Vector2(332, 72), Vector2(320, 108)]), SEA, 4.0)
	for peak: Vector2 in [Vector2(70, 18), Vector2(100, 24), Vector2(128, 14)]:
		draw_colored_polygon(PackedVector2Array([peak + Vector2(-16, 14), peak + Vector2(0, -12), peak + Vector2(16, 14)]), Color("a98a66"))
		draw_colored_polygon(PackedVector2Array([peak + Vector2(0, -12), peak + Vector2(16, 14), peak + Vector2(4, 14)]), Color("8c6f50"))
		draw_colored_polygon(PackedVector2Array([peak + Vector2(-5, -4), peak + Vector2(0, -12), peak + Vector2(5, -4)]), UiStyle.CREAM)

func _draw_road(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, ROAD_EDGE, 4.0)
	draw_line(from, to, ROAD, 2.4)
	var length: float = from.distance_to(to)
	var step: float = 7.0
	var along: float = 2.0
	while along < length - 2.0:
		var a: Vector2 = from.lerp(to, along / length)
		var b: Vector2 = from.lerp(to, minf(along + 3.0, length) / length)
		draw_line(a, b, Color("e2c08a"), 1.0)
		along += step

func _draw_place(key: String, here: bool) -> void:
	var row: Array = PLACES[key]
	var at: Vector2 = _screen(row[0])
	if not Rect2(Vector2(-16, -16), size + Vector2(32, 32)).has_point(at):
		return
	var grow: float = clampf(1.0 + (zoom - 1.0) * 0.35, 1.0, 1.7)
	var radius: float = 13.0 * grow
	draw_circle(at + Vector2(1, 2), radius, Color(0, 0, 0, 0.25))
	draw_circle(at, radius, UiStyle.CREAM)
	draw_arc(at, radius, 0.0, TAU, 32, UiStyle.GOLD if here else UiStyle.BROWN, 2.5 if here else 1.5)
	var icon: Texture2D = _icon(str(row[1]))
	if icon != null:
		var drawn: Vector2 = icon.get_size() * (radius * 1.7 / ICON_SIZE)
		# Places not walked to yet are faded: the map can't take the boy there.
		var shade: Color = Color.WHITE if can_travel(key) else Color(1, 1, 1, 0.4)
		draw_texture_rect(icon, Rect2(at - drawn * 0.5, drawn), false, shade)
	_draw_tag(at + Vector2(0, radius + 8.0), Locale.t(str(row[2])), here)

## A gold "!" on the top corner of a place's badge: someone there needs the boy today.
func _draw_task_mark(key: String, ripe: bool = false) -> void:
	var at: Vector2 = _screen(PLACES[key][0])
	var radius: float = 13.0 * clampf(1.0 + (zoom - 1.0) * 0.35, 1.0, 1.7)
	var mark: Vector2 = at + Vector2(radius * 0.8, -radius * 0.8)
	var beat: float = 1.0 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.006)
	draw_circle(mark + Vector2(0.6, 1.0), 6.5 * beat, Color(0, 0, 0, 0.3))
	draw_circle(mark, 6.5 * beat, Color("5e9b62") if ripe else UiStyle.GOLD)
	draw_arc(mark, 6.5 * beat, 0.0, TAU, 20, UiStyle.WOOD_DARK, 1.2)
	if ripe:
		# A small leaf: two arcs that meet at the tips, and a stem.
		var leaf: PackedVector2Array = PackedVector2Array([mark + Vector2(-3, 3), mark + Vector2(-2.5, -1), mark + Vector2(0, -3.5), mark + Vector2(3, -3.5), mark + Vector2(2.5, 0.5), mark + Vector2(-0.5, 3)])
		draw_colored_polygon(leaf, Color("fff3dc"))
		draw_line(mark + Vector2(-3.5, 3.5), mark + Vector2(1.5, -1.5), Color("3e6b40"), 1.0)
		return
	draw_rect(Rect2(mark + Vector2(-1.0, -4.0), Vector2(2.0, 5.0)), UiStyle.DARK)
	draw_rect(Rect2(mark + Vector2(-1.0, 2.0), Vector2(2.0, 2.0)), UiStyle.DARK)

## A name on a little wooden tag, kept inside the window.
func _draw_tag(middle: Vector2, title: String, gold: bool) -> void:
	var font: Font = _font()
	var text_size: int = 9
	var wide: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var box: Rect2 = Rect2(middle - Vector2(wide * 0.5 + 4.0, 6.0), Vector2(wide + 8.0, 12.0))
	draw_rect(Rect2(box.position + Vector2(1, 1), box.size), Color(0, 0, 0, 0.3))
	draw_rect(box, UiStyle.GOLD if gold else UiStyle.WOOD_LIGHT)
	draw_rect(box, UiStyle.WOOD_DARK, false, 1.0)
	draw_string(font, box.position + Vector2(4.0, 9.5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, UiStyle.DARK)

func _draw_detail(at: Vector2, title: String) -> void:
	if not Rect2(Vector2.ZERO, size).has_point(at):
		return
	draw_circle(at, 3.0, UiStyle.DARK)
	draw_circle(at, 2.0, UiStyle.CREAM)
	var font: Font = _font()
	var wide: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var box: Rect2 = Rect2(at + Vector2(-wide * 0.5 - 3.0, 5.0), Vector2(wide + 6.0, 10.0))
	draw_rect(box, Color(UiStyle.CREAM, 0.9))
	draw_rect(box, UiStyle.BROWN, false, 1.0)
	draw_string(font, box.position + Vector2(3.0, 8.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiStyle.DARK)

## A gold pin over the place the boy is in, with a ring that beats.
func _draw_you() -> void:
	var at: Vector2 = _screen(current_spot())
	var grow: float = clampf(1.0 + (zoom - 1.0) * 0.35, 1.0, 1.7)
	var beat: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 220.0)
	draw_arc(at, 13.0 * grow + 3.0 + beat * 3.0, 0.0, TAU, 32, Color(UiStyle.GOLD, 0.8 - beat * 0.4), 2.0)
	var tip: Vector2 = at - Vector2(0, 13.0 * grow + 1.0)
	var head: Vector2 = tip - Vector2(0, 10.0)
	draw_colored_polygon(PackedVector2Array([tip, head + Vector2(-5, 2), head + Vector2(5, 2)]), UiStyle.WOOD_DARK)
	draw_circle(head, 5.5, UiStyle.WOOD_DARK)
	draw_circle(head, 4.5, UiStyle.GOLD)
	draw_circle(head, 1.8, UiStyle.CREAM)

func _draw_compass(at: Vector2) -> void:
	draw_circle(at, 11.0, Color(UiStyle.CREAM, 0.85))
	draw_arc(at, 11.0, 0.0, TAU, 24, UiStyle.BROWN, 1.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(3, 0), at + Vector2(-3, 0)]), Color("b8432f"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, 9), at + Vector2(3, 0), at + Vector2(-3, 0)]), UiStyle.DARK)
	var font: Font = _font()
	draw_string(font, at + Vector2(-3, -12), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiStyle.DARK)

func _draw_here_tag(here: String) -> void:
	var title: String = Locale.t("map_here") % Locale.t(str(PLACES[here][2]))
	var font: Font = _font()
	var wide: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	# Top right, beside the compass, where no place names sit.
	var box: Rect2 = Rect2(Vector2(size.x - wide - 12.0 - 42.0, 5.0), Vector2(wide + 12.0, 15.0))
	draw_rect(box, Color(UiStyle.CREAM, 0.92))
	draw_rect(box, UiStyle.BROWN, false, 1.0)
	draw_string(font, box.position + Vector2(6, 11.5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.DARK)

## A short message across the bottom of the map.
func _draw_note(title: String) -> void:
	var font: Font = _font()
	var wide: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var box: Rect2 = Rect2(Vector2((size.x - wide) * 0.5 - 8.0, size.y - 42.0), Vector2(wide + 16.0, 17.0))
	draw_rect(box, Color(UiStyle.DARK, 0.85))
	draw_string(font, box.position + Vector2(8, 12.5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.CREAM)

func _wave_lines() -> void:
	var drift: float = fmod(float(Time.get_ticks_msec()) / 90.0, 34.0)
	for row: int in 6:
		for column: int in 14:
			var at: Vector2 = Vector2(column * 34.0 + drift - 30.0 + row % 2 * 16.0, 10.0 + row * 24.0)
			if at.x < size.x - 8.0:
				draw_line(at, at + Vector2(8, 0), SEA_DEEP, 1.0)

## Trees inside the woods, spread the same way every time.
func _scatter() -> void:
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = 5
	var y: float = 104.0
	while y < 144.0:
		var x: float = 50.0 + roll.randf() * 3.0
		while x < 178.0:
			var spot: Vector2 = Vector2(x, y) + Vector2(roll.randf_range(-1.5, 1.5), roll.randf_range(-1.0, 1.0))
			if Geometry2D.is_point_in_polygon(spot, WOODS):
				_trees.append(spot)
			x += 6.0
		y += 5.0

func _shrunk(points: PackedVector2Array, by: float) -> PackedVector2Array:
	var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(points, -by)
	return grown[0] if not grown.is_empty() else points

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var ring: PackedVector2Array = points.duplicate()
	ring.append(points[0])
	return ring

func _map_button(title: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(26, 20)
	button.size = Vector2(26, 20)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	UiStyle.button(button)
	button.pressed.connect(action)
	add_child(button)
	return button

func _place_buttons() -> void:
	if _zoom_in == null:
		return
	_zoom_in.position = Vector2(size.x - 31.0, size.y - 71.0)
	_zoom_out.position = Vector2(size.x - 31.0, size.y - 48.0)
	_center.position = Vector2(size.x - 31.0, size.y - 25.0)

func _font() -> Font:
	var face: Font = Locale.font()
	return face if face != null else ThemeDB.fallback_font

func _icon(path: String) -> Texture2D:
	if _icons.has(path):
		return _icons[path]
	var source: Texture2D = load(path) as Texture2D
	if source == null:
		return null
	var icon: Texture2D = UiStyle.fit_picture(source, ICON_SIZE)
	_icons[path] = icon
	return icon
