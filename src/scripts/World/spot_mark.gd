# src/scripts/World/spot_mark.gd
# Purpose: Draws a picture, or a small colored mark, on one farm spot.

extends Node2D

@export var mark_color: Color = Color("fff3dc")
@export var title: String = ""
@export var group_name: String = ""
@export var person: Texture2D
@export var person_scale: float = 1.0
@export var stand_on_feet: bool = false
@export var fit_pixels: int = 0
@export var role: String = ""
## Solid footprint at the feet. Zero means the boy walks through.
@export var block_size: Vector2 = Vector2.ZERO
## A name board hung on a building, so the mosque, the shop and the people's houses can be told apart.
@export var sign_key: String = ""
## Where the boy stands to talk, measured from this spot's feet. Behind a counter it is in front of the counter.
@export var talk_from: Vector2 = Vector2(0, 18)

const IDLE_SHEETS: Dictionary = {
	"Neighbor": "res://assets/characters/village/idle/Jassim.png",
	"Elder": "res://assets/characters/village/idle/Elder.png",
	"Merchant": "res://assets/characters/village/idle/Merchant.png",
	"Carpenter": "res://assets/characters/village/idle/Carpenter.png",
}
const IDLE_FPS: float = 6.0
const WATER_SHADER: String = "res://src/shaders/water_shimmer.gdshader"

var bob: float = 0.0
var walking: bool = false
var _picture: Texture2D
var _frames: Array[Texture2D] = []
var _frame: int = 0
var _phase: float = 0.0
var _sways: bool = false
var _breathes: bool = false
var _player: Player
var _show_talk: bool = false
## A small bubble over a villager's head: "wish" (a request today), "gift" (birthday), "heart", "sad" or "note".
var emote: String = ""
var _emote_left: float = 0.0
var _emote_pop: float = 1.0
var _standing_emote: String = ""
var _emote_check: float = 0.0
## A little jump when the boy starts to talk.
var hop: float = 0.0
## Bushes and trees rustle when the boy brushes past them; this fades from 1 to 0.
var _rustle: float = 0.0
var _last_hero: Vector2 = Vector2.INF
const PEOPLE_ROLES: Array[String] = ["elder", "merchant", "carpenter", "fisherman"]
## How much of a building's height, from the ground up, is solid wall.
const BUILDING_SOLID: float = 0.5
const SIGN_WOOD: Color = Color("8a5a2b")
const SIGN_EDGE: Color = Color("4a2c17")
const SIGN_GREEN: Color = Color("2f6b4a")
const SIGN_FONT: int = 10

func _ready() -> void:
	if group_name != "":
		add_to_group(group_name)
	if person == null:
		return
	_use_season_picture()
	if fit_pixels > 0:
		_picture = _fit(person, fit_pixels)
	else:
		_picture = person
	if role == "fisherman" and _picture != null and not UiStyle.is_hd(person):
		_picture = ImageTexture.create_from_image(UiStyle.crisp_sprite(_picture.get_image()))
	_phase = fmod(absf(global_position.x * 0.37 + global_position.y * 0.11), TAU)
	var is_person: bool = name == "Neighbor" or (role != "" and role != "mosque")
	_sways = group_name in ["tree", "date", "forage"] or str(name).begins_with("Palm") or str(name).begins_with("Grove")
	var is_pond: bool = name == "FishingSpot" or str(name).begins_with("Pond_")
	# Painted HD people breathe; only the old pixel people have idle sheets drawn for them.
	var idles: bool = IDLE_SHEETS.has(str(name)) and not UiStyle.is_hd(person)
	_breathes = is_person and not idles
	if idles:
		_load_idle(str(IDLE_SHEETS[str(name)]))
	if is_pond:
		var shimmer: ShaderMaterial = ShaderMaterial.new()
		shimmer.shader = load(WATER_SHADER) as Shader
		material = shimmer
	_block_tree()
	_block_footprint()
	_add_night_light()
	queue_redraw()
	if str(name).begins_with("Forest"):
		# Dozens of these stand far from the path, so they stay still and cost nothing each frame.
		z_index = 2000 + int(global_position.y)
		modulate = Color(0.78, 0.86, 0.8)
		set_process(false)

func _use_season_picture() -> void:
	var scene: Node = get_tree().current_scene
	var clock: Node = scene.get_node_or_null("Systems/Clock") if scene != null else null
	if clock == null or person.resource_path == "":
		return
	var season: String = str(clock.get("season"))
	var path: String = WorldShapes.seasonal_picture(person.resource_path, season)
	if path != person.resource_path:
		person = load(path) as Texture2D
	# Only the picture is tinted, not its shadow.
	self_modulate = WorldShapes.season_leaves(person.resource_path, season)

## Cuts a sheet of eight idle frames, with one crop for all so the feet never jump.
func _load_idle(path: String) -> void:
	var sheet: Texture2D = load(path) as Texture2D
	if sheet == null or _picture == null:
		return
	var image: Image = sheet.get_image()
	var cell: int = image.get_height()
	var count: int = int(float(image.get_width()) / float(cell))
	var crop: Rect2i = Rect2i()
	var cells: Array[Image] = []
	for i: int in count:
		var part: Image = image.get_region(Rect2i(i * cell, 0, cell, cell))
		cells.append(part)
		var used: Rect2i = part.get_used_rect()
		crop = used if crop.size == Vector2i.ZERO else crop.merge(used)
	if crop.size == Vector2i.ZERO:
		return
	var tall: float = _picture.get_size().y * (1.0 if fit_pixels > 0 else person_scale)
	var factor: float = tall / float(crop.size.y)
	for part: Image in cells:
		var cut: Image = part.get_region(crop)
		cut.resize(maxi(1, int(round(crop.size.x * factor))), maxi(1, int(round(crop.size.y * factor))), Image.INTERPOLATE_LANCZOS)
		_frames.append(ImageTexture.create_from_image(UiStyle.crisp_sprite(cut)))
	_picture = _frames[0]

## Lanterns, lamp posts and torches glow after dark. The clock turns them on.
func _add_night_light() -> void:
	var path: String = person.resource_path.to_lower()
	var post: bool = path.contains("lamp_post")
	if name != "HouseLamp" and not (path.contains("lantern") or path.contains("torch") or post):
		return
	var light: PointLight2D = PointLight2D.new()
	light.texture = UiStyle.glow_texture()
	light.color = Color("ffc56b")
	light.energy = 0.95
	light.texture_scale = 0.8
	# A lamp post's light sits up in the lamp at the top of the post.
	light.position = Vector2(4 if post else 0, -_picture.get_size().y * (0.72 if post else 0.6)) if stand_on_feet else Vector2.ZERO
	light.enabled = false
	light.add_to_group("night_light")
	add_child(light)

func _block_footprint() -> void:
	if block_size == Vector2.ZERO:
		return
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Block"
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = block_size
	shape_node.shape = shape
	shape_node.position = Vector2(0, -block_size.y * 0.5) if stand_on_feet else Vector2.ZERO
	var walls: Rect2 = _building_walls()
	if walls.size != Vector2.ZERO:
		shape.size = walls.size
		shape_node.position = walls.get_center()
	body.add_child(shape_node)
	add_child(body)

## A building is solid across its painted walls, not just a strip at its base, so the boy cannot walk
## into a house and vanish. The roof's upper part stays open: he can pass behind it and it fades.
func _building_walls() -> Rect2:
	if not is_building() or _picture == null:
		return Rect2()
	var image: Image = _picture.get_image()
	if image == null:
		return Rect2()
	var used: Rect2i = image.get_used_rect()
	var scale_by: Vector2 = _sprite_rect().size / Vector2(image.get_size())
	var left: float = -_sprite_rect().size.x * 0.5 + used.position.x * scale_by.x
	var width: float = used.size.x * scale_by.x
	var bottom: float = -_sprite_rect().size.y + used.end.y * scale_by.y
	var tall: float = maxf(block_size.y, used.size.y * scale_by.y * BUILDING_SOLID)
	return Rect2(left + width * 0.04, bottom - tall, width * 0.92, tall - 2.0)

func _block_tree() -> void:
	if group_name != "tree" or _picture == null:
		return
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Block"
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	var trunk: Vector2 = Vector2(10, 6)
	shape.size = trunk
	shape_node.shape = shape
	shape_node.position = Vector2(0, -13)
	body.add_child(shape_node)
	add_child(body)

func _process(delta: float) -> void:
	if _picture == null:
		return
	if is_villager():
		_tick_emote(delta)
	if _sways:
		_check_rustle(delta)
	z_index = 1 if name == "FishingSpot" or str(name).begins_with("Pond_") else 2000 + int(global_position.y)
	if not _frames.is_empty():
		var now: int = int(_clock() * IDLE_FPS) % _frames.size()
		if now != _frame:
			_frame = now
			queue_redraw()
	if _sways or _breathes or walking:
		queue_redraw()
	if name == "Neighbor" or role != "":
		var show_talk: bool = _near_player()
		if show_talk != _show_talk or show_talk:
			_show_talk = show_talk
			queue_redraw()
	if group_name != "tree" and not is_building():
		return
	if _player == null or not is_instance_valid(_player):
		var scene: Node = get_tree().current_scene
		_player = scene.find_child("Player", true, false) as Player if scene != null else null
	if _player == null:
		return
	var feet_y: float = _player.global_position.y + 20.0
	var behind: bool = feet_y < global_position.y + 4.0
	var covered: bool = _sprite_rect().intersects(_player_rect())
	modulate.a = 0.45 if behind and covered else 1.0

func _unhandled_input(event: InputEvent) -> void:
	if not _show_talk:
		return
	if name != "Neighbor" and role == "":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		var activities: Activities = get_tree().current_scene.get_node("Systems/Activities") as Activities
		if role != "":
			activities.talk_role(role)
		else:
			activities.call("_talk")
		get_viewport().set_input_as_handled()

func _check_rustle(delta: float) -> void:
	_rustle = maxf(0.0, _rustle - delta * 1.6)
	var hero: Player = _hero()
	if hero == null:
		return
	var feet: Vector2 = hero.global_position + Vector2(0, 20)
	var moved: bool = _last_hero != Vector2.INF and _last_hero.distance_to(feet) > 0.2
	_last_hero = feet
	if moved and absf(feet.x - global_position.x) < 14.0 and absf(feet.y - global_position.y) < 10.0:
		_rustle = 1.0

func is_villager() -> bool:
	return name == "Neighbor" or role in PEOPLE_ROLES

## The name the friendship and request books use for this villager.
func person_id() -> String:
	return "jassim" if name == "Neighbor" else role

## Shows a bubble for a while. A villager with a request or a birthday keeps theirs between bubbles.
func show_emote(kind: String, seconds: float = 2.2) -> void:
	emote = kind
	_emote_left = seconds
	_emote_pop = 0.0
	queue_redraw()

func greet() -> void:
	var jump: Tween = create_tween()
	jump.tween_property(self, "hop", 5.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump.tween_property(self, "hop", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	jump.tween_callback(queue_redraw)

func _tick_emote(delta: float) -> void:
	_emote_check -= delta
	if _emote_check <= 0.0:
		_emote_check = 1.0
		_standing_emote = _standing()
	if _emote_left > 0.0:
		_emote_left -= delta
		if _emote_left <= 0.0:
			emote = ""
	var wanted: String = emote if _emote_left > 0.0 else _standing_emote
	if wanted != emote:
		emote = wanted
		_emote_pop = 0.0
	if emote != "" and _emote_pop < 1.0:
		_emote_pop = minf(1.0, _emote_pop + delta * 6.0)
	if emote != "" or hop > 0.0:
		queue_redraw()

func _standing() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return ""
	var friends: Node = scene.get_node_or_null("Systems/Friendship")
	if friends != null and bool(friends.call("is_birthday", person_id())):
		return "gift"
	var works: Node = scene.get_node_or_null("Systems/VillageWorks")
	if works != null and bool(works.call("can_help", person_id())):
		return "wish"
	return ""

## The bubble pops up a little bigger, then settles.
func _draw_emote(head: Vector2) -> void:
	if emote == "":
		return
	var grow: float = 1.0 + sin(_emote_pop * PI) * 0.35 if _emote_pop < 1.0 else 1.0
	var size: float = _emote_pop * grow
	var bounce: float = sin(_clock() * 3.0) * 1.2
	draw_set_transform(head + Vector2(0, -12.0 + bounce), 0.0, Vector2(size, size))
	draw_circle(Vector2.ZERO, 7.5, UiStyle.CREAM)
	draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 20, UiStyle.BROWN, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 6), Vector2(3, 6), Vector2(0, 11)]), UiStyle.CREAM)
	match emote:
		"wish":
			draw_rect(Rect2(-1.2, -5.0, 2.4, 6.0), UiStyle.GOLD)
			draw_circle(Vector2(0, 3.2), 1.3, UiStyle.GOLD)
		"heart":
			var red: Color = Color("d2453c")
			draw_circle(Vector2(-2.0, -1.5), 2.4, red)
			draw_circle(Vector2(2.0, -1.5), 2.4, red)
			draw_colored_polygon(PackedVector2Array([Vector2(-4.3, -0.6), Vector2(4.3, -0.6), Vector2(0, 4.2)]), red)
		"gift":
			draw_rect(Rect2(-4.0, -2.5, 8.0, 6.0), Color("c4553f"))
			draw_rect(Rect2(-0.8, -2.5, 1.6, 6.0), UiStyle.GOLD)
			draw_rect(Rect2(-4.5, -4.0, 9.0, 2.0), Color("d76a52"))
			draw_circle(Vector2(-1.6, -4.6), 1.2, UiStyle.GOLD)
			draw_circle(Vector2(1.6, -4.6), 1.2, UiStyle.GOLD)
		"sad":
			for x: float in [-2.5, 2.5]:
				draw_circle(Vector2(x, -1.5), 0.9, UiStyle.DARK)
			draw_arc(Vector2(0, 3.5), 2.5, PI * 1.15, PI * 1.85, 8, UiStyle.DARK, 1.0)
		_:
			for x: float in [-3.0, 0.0, 3.0]:
				draw_circle(Vector2(x, 0.0), 1.0, UiStyle.DARK)
	draw_set_transform(Vector2.ZERO)

## A loose copy of this picture with its feet at the copy's origin, so it can tip over or break away.
func picture_copy() -> Sprite2D:
	if _picture == null:
		return null
	var copy: Sprite2D = Sprite2D.new()
	copy.texture = _frames[_frame] if not _frames.is_empty() else _picture
	var box: Rect2 = _sprite_rect()
	copy.scale = box.size / copy.texture.get_size()
	copy.offset = Vector2(0, -copy.texture.get_size().y * 0.5) if stand_on_feet else Vector2.ZERO
	copy.position = position
	copy.z_index = z_index
	copy.modulate = Color(modulate.r * self_modulate.r, modulate.g * self_modulate.g, modulate.b * self_modulate.b, 1.0)
	return copy

## Houses, shops and the mosque: big solid pictures that stand on the ground.
func is_building() -> bool:
	return stand_on_feet and block_size.x >= 60.0 and (role == "" or role == "mosque") and name != "Neighbor"

func _near_player() -> bool:
	var player: Player = _hero()
	if player == null or player.busy:
		return false
	var feet: Vector2 = player.global_position + Vector2(0, 20)
	return feet.distance_to(global_position) <= 40.0

func _hero() -> Player:
	if _player != null and is_instance_valid(_player):
		return _player
	var scene: Node = get_tree().current_scene
	_player = scene.find_child("Player", true, false) as Player if scene != null else null
	return _player

func _draw_talk_mark() -> void:
	if not _show_talk:
		return
	var player: Player = _hero()
	if player == null:
		return
	UiStyle.draw_bubble(self, to_local(player.global_position + Vector2(0, -28)))

## True when a tap at this point lands on the picture itself: the middle of its width, top to feet.
## A tap on a tree's leaves then chops that tree, not only a tap at its foot.
const MIN_TAP: float = 32.0

func covers_tap(point: Vector2) -> bool:
	if _picture == null or not is_visible_in_tree():
		return false
	var box: Rect2 = _sprite_rect()
	var inner: Rect2 = Rect2(box.position + Vector2(box.size.x * 0.15, box.size.y * 0.05), Vector2(box.size.x * 0.7, box.size.y * 0.95 + 6.0))
	# Small things (a stone, a herb) get a tap area of at least MIN_TAP around them, about 44 points on a phone.
	if inner.size.x < MIN_TAP or inner.size.y < MIN_TAP:
		var middle: Vector2 = inner.get_center()
		var size: Vector2 = Vector2(maxf(inner.size.x, MIN_TAP), maxf(inner.size.y, MIN_TAP))
		inner = Rect2(middle - size * 0.5, size)
	return inner.has_point(point)

func _sprite_rect() -> Rect2:
	var size: Vector2 = _picture.get_size()
	if fit_pixels == 0:
		size *= person_scale
	var origin: Vector2 = Vector2(-size.x * 0.5, -size.y) if stand_on_feet else -size * 0.5
	return Rect2(to_global(origin), size)

func _player_rect() -> Rect2:
	return Rect2(_player.global_position - Vector2(10, 22), Vector2(20, 40))

func _clock() -> float:
	return float(Time.get_ticks_msec()) / 1000.0 + _phase

func _draw() -> void:
	if _picture != null:
		var shown: Texture2D = _frames[_frame] if not _frames.is_empty() else _picture
		var size: Vector2 = shown.get_size()
		if fit_pixels == 0 and _frames.is_empty():
			size *= person_scale
		var origin: Vector2 = Vector2(-size.x * 0.5, -size.y) if stand_on_feet else -size * 0.5
		var ground_y: float = origin.y + size.y
		if not _frames.is_empty() or _breathes or _sways:
			UiStyle.draw_shadow(self, Vector2(0, ground_y - 1.0), size.x * (0.3 if _sways else 0.42))
		origin.y -= hop
		if walking:
			_draw_steps(shown, Rect2(origin, size))
			_draw_talk_mark()
			_draw_emote(Vector2(0, origin.y))
			return
		if _sways:
			var lean: float = sin(_clock() * 1.1) * 0.03 + sin(_clock() * 24.0) * 0.07 * _rustle
			draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(lean, 1), Vector2(-lean * ground_y, 0)))
		elif _breathes:
			var grow: float = 1.0 + sin(_clock() * 1.8) * 0.018
			draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(0, grow), Vector2(0, ground_y * (1.0 - grow))))
		draw_texture_rect(shown, Rect2(origin + Vector2(0, -bob), size), false)
		draw_set_transform(Vector2.ZERO)
		_draw_name_board(origin, size)
		_draw_talk_mark()
		_draw_emote(Vector2(0, origin.y - bob))
		return
	draw_rect(Rect2(-8, -8, 16, 16), mark_color)
	if title != "":
		draw_string(ThemeDB.fallback_font, Vector2(-16, -12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("3f2d27"))

## The board hangs over the door, at the top of the solid wall; a small piece hangs over its top.
func _draw_name_board(origin: Vector2, size: Vector2) -> void:
	if sign_key == "":
		return
	var title: String = Locale.t(sign_key)
	var font: Font = Locale.font() if Locale.font() != null else ThemeDB.fallback_font
	var text: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT)
	var walls: Rect2 = _building_walls()
	var top: float = walls.position.y + 2.0 if walls.size != Vector2.ZERO else origin.y - 4.0
	var box: Rect2 = Rect2(Vector2(-text.x * 0.5 - 6.0, top - text.y - 2.0), Vector2(text.x + 12.0, text.y + 4.0))
	var holy: bool = role == "mosque"
	draw_rect(Rect2(box.position + Vector2(1, 2), box.size), Color(0, 0, 0, 0.25))
	draw_rect(box, SIGN_GREEN if holy else SIGN_WOOD)
	draw_rect(box, SIGN_EDGE, false, 1.0)
	var at: Vector2 = Vector2(-text.x * 0.5, box.get_center().y + font.get_ascent(SIGN_FONT) * 0.35)
	draw_string_outline(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT, 2, SIGN_EDGE)
	draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT, UiStyle.CREAM)

## A walking step: the body bobs twice a stride while the left and right feet lift in turn under the robe.
func _draw_steps(shown: Texture2D, box: Rect2) -> void:
	const FEET: float = 0.16
	const LIFT: float = 1.6
	var stride: float = sin(_clock() * 9.0)
	var pixels: Vector2 = shown.get_size()
	var scale_by: Vector2 = box.size / pixels
	var feet_top: float = floorf(pixels.y * (1.0 - FEET))
	var half: float = floorf(pixels.x * 0.5)
	var feet_h: float = pixels.y - feet_top
	for side: int in 2:
		var lift: float = maxf(0.0, stride if side == 0 else -stride) * LIFT
		var source: Rect2 = Rect2(half * side, feet_top, half if side == 0 else pixels.x - half, feet_h)
		var at: Vector2 = box.position + Vector2(source.position.x * scale_by.x, feet_top * scale_by.y - lift - bob)
		draw_texture_rect_region(shown, Rect2(at, source.size * scale_by), source)
	# The robe is drawn last and reaches a little lower, so a lifted foot tucks under it with no gap.
	var robe_h: float = minf(pixels.y, feet_top + 2.0)
	var body_bob: float = absf(stride) * LIFT * 0.6 + bob
	draw_texture_rect_region(shown, Rect2(box.position - Vector2(0, body_bob), Vector2(box.size.x, robe_h * scale_by.y)), Rect2(0, 0, pixels.x, robe_h))

func _fit(texture: Texture2D, pixels: int) -> Texture2D:
	return UiStyle.fit_picture(texture, pixels)
