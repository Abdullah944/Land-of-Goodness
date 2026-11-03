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
	if role == "fisherman" and _picture != null:
		_picture = ImageTexture.create_from_image(UiStyle.crisp_sprite(_picture.get_image()))
	_phase = fmod(absf(global_position.x * 0.37 + global_position.y * 0.11), TAU)
	var is_person: bool = name == "Neighbor" or role != ""
	_sways = group_name in ["tree", "date", "forage"] or str(name).begins_with("Palm") or str(name).begins_with("Grove")
	var is_pond: bool = name == "FishingSpot" or str(name).begins_with("Pond_")
	_breathes = is_person and not IDLE_SHEETS.has(str(name))
	if IDLE_SHEETS.has(str(name)):
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
	var path: String = WorldShapes.seasonal_picture(person.resource_path, str(clock.get("season")))
	if path != person.resource_path:
		person = load(path) as Texture2D

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

## Lanterns and torches glow after dark. The clock turns them on.
func _add_night_light() -> void:
	var path: String = person.resource_path.to_lower()
	if name != "HouseLamp" and not (path.contains("lantern") or path.contains("torch")):
		return
	var light: PointLight2D = PointLight2D.new()
	light.texture = UiStyle.glow_texture()
	light.color = Color("ffc56b")
	light.energy = 0.95
	light.texture_scale = 0.8
	light.position = Vector2(0, -_picture.get_size().y * 0.6) if stand_on_feet else Vector2.ZERO
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
	body.add_child(shape_node)
	add_child(body)

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

func _process(_delta: float) -> void:
	if _picture == null:
		return
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
	if group_name != "tree":
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
		if walking:
			var turn: float = sin(_clock() * 10.0) * 0.06
			draw_set_transform(Vector2(-sin(turn) * ground_y, ground_y - cos(turn) * ground_y), turn)
		elif _sways:
			var lean: float = sin(_clock() * 1.1) * 0.03
			draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(lean, 1), Vector2(-lean * ground_y, 0)))
		elif _breathes:
			var grow: float = 1.0 + sin(_clock() * 1.8) * 0.018
			draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(0, grow), Vector2(0, ground_y * (1.0 - grow))))
		draw_texture_rect(shown, Rect2(origin + Vector2(0, -bob), size), false)
		draw_set_transform(Vector2.ZERO)
		_draw_talk_mark()
		return
	draw_rect(Rect2(-8, -8, 16, 16), mark_color)
	if title != "":
		draw_string(ThemeDB.fallback_font, Vector2(-16, -12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("3f2d27"))

func _fit(texture: Texture2D, pixels: int) -> Texture2D:
	var image: Image = texture.get_image()
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	var longest: int = maxi(image.get_width(), image.get_height())
	var width: int = maxi(1, int(round(float(image.get_width()) * pixels / float(longest))))
	var height: int = maxi(1, int(round(float(image.get_height()) * pixels / float(longest))))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
