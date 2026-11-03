# src/scripts/ui/fish_game.gd
# Purpose: A short fishing game. The fish darts along the line; tap Pull while it is inside the green net to catch it.

class_name FishGame
extends CanvasLayer

signal finished(caught: bool)

const BAR_SIZE: Vector2 = Vector2(260, 18)
## Net width and fish speed for each place. The sea is the hardest.
const WATERS: Dictionary = {
	"Home": {"net": 70.0, "speed": 120.0},
	"Forest": {"net": 56.0, "speed": 150.0},
	"Harbor": {"net": 46.0, "speed": 185.0},
}
const RESULT_SECONDS: float = 0.9

var place_name: String = ""
var spot_name: String = ""
var _panel: Panel
var _bar: ColorRect
var _net: ColorRect
var _fish: TextureRect
var _label: Label
var _pull: Button
var _x: float = 0.0
var _direction: float = 1.0
var _speed: float = 120.0
var _turn_in: float = 0.0
var _playing: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	layer = 20
	visible = false
	_panel = Panel.new()
	_panel.size = Vector2(300, 96)
	_panel.position = Vector2((512.0 - 300.0) * 0.5, 288.0 - 96.0 - 8.0)
	UiStyle.panel(_panel)
	add_child(_panel)
	_label = Label.new()
	_label.position = Vector2(8, 4)
	_label.size = Vector2(284, 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", UiStyle.DARK)
	_panel.add_child(_label)
	_bar = ColorRect.new()
	_bar.color = Color("2f6f8f")
	_bar.position = Vector2((300.0 - BAR_SIZE.x) * 0.5, 26)
	_bar.size = BAR_SIZE
	_panel.add_child(_bar)
	_net = ColorRect.new()
	_net.color = Color(0.45, 0.8, 0.4, 0.75)
	_net.size = Vector2(60, BAR_SIZE.y)
	_bar.add_child(_net)
	_fish = TextureRect.new()
	_fish.texture = load("res://assets/items/goods/fish.png") as Texture2D
	_fish.size = Vector2(16, 16)
	_fish.position.y = 1
	_fish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bar.add_child(_fish)
	_pull = Button.new()
	_pull.position = Vector2(8, 52)
	_pull.size = Vector2(284, 36)
	_pull.focus_mode = Control.FOCUS_NONE
	UiStyle.button(_pull)
	_pull.pressed.connect(pull)
	_panel.add_child(_pull)
	_fit_screen()
	get_viewport().size_changed.connect(_fit_screen)

func is_open() -> bool:
	return visible

## Begins a cast at one spot. The net lands somewhere new each time.
func start(place: String, spot: String) -> void:
	place_name = place
	spot_name = spot
	var water: Dictionary = WATERS.get(place, WATERS["Home"])
	_rng.randomize()
	_net.size.x = float(water["net"])
	_net.position.x = _rng.randf_range(0.0, BAR_SIZE.x - _net.size.x)
	_speed = float(water["speed"])
	_x = 0.0 if _net.position.x > BAR_SIZE.x * 0.5 else BAR_SIZE.x - _fish.size.x
	_direction = 1.0 if _x == 0.0 else -1.0
	_turn_in = _rng.randf_range(0.4, 1.2)
	_label.text = Locale.t("fish_tap")
	_pull.text = Locale.t("fish_pull")
	_pull.disabled = false
	Locale.apply_control(_label)
	Locale.apply_control(_pull)
	_place_fish()
	_playing = true
	visible = true
	_hold_player(true)

func _process(delta: float) -> void:
	if not _playing:
		return
	_x += _direction * _speed * delta
	_turn_in -= delta
	var right_end: float = BAR_SIZE.x - _fish.size.x
	if _x <= 0.0 or _x >= right_end or _turn_in <= 0.0:
		_x = clampf(_x, 0.0, right_end)
		_direction = 1.0 if _x <= 0.0 else -1.0 if _x >= right_end else -_direction
		_turn_in = _rng.randf_range(0.35, 1.1)
	_place_fish()

## True while the fish's middle is inside the net.
func in_net() -> bool:
	var middle: float = _x + _fish.size.x * 0.5
	return middle >= _net.position.x and middle <= _net.position.x + _net.size.x

func pull() -> void:
	if not _playing:
		return
	_playing = false
	_pull.disabled = true
	var caught: bool = in_net()
	_label.text = Locale.t("fish_got") if caught else Locale.t("fish_lost")
	Locale.apply_control(_label)
	finished.emit(caught)
	await get_tree().create_timer(RESULT_SECONDS).timeout
	visible = false
	_hold_player(false)

## Moves the fish into the net and pulls. Used by tests and by nobody else.
func land() -> void:
	_x = _net.position.x + (_net.size.x - _fish.size.x) * 0.5
	pull()

func _place_fish() -> void:
	_fish.position.x = _x
	_fish.flip_h = _direction < 0.0

func _hold_player(hold: bool) -> void:
	var scene: Node = get_tree().current_scene
	var player: Player = scene.find_child("Player", true, false) as Player if scene != null else null
	if player == null:
		return
	player.busy = hold
	if hold:
		player.cancel_tap()

func _fit_screen() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	offset = Vector2((view.x - 512.0) * 0.5, view.y - 288.0)
