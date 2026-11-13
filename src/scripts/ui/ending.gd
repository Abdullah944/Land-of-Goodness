# src/scripts/ui/ending.gd
# Purpose: The village festival that closes the story. The farm stays open afterward.

class_name EndingScreen
extends CanvasLayer

## The festival opens with the square, then each neighbor has a moment, then grandfather's last page and the boy's own story.
const OPENING: Array[String] = ["ending_1", "ending_2", "ending_3"]
const CLOSING: Array[String] = ["ending_4", "ending_saad"]

var _pages: PackedStringArray = PackedStringArray()

var _page: Control
var _panel: Panel
var _label: Label
var _next: Button
var _index: int = 0
var _playing: bool = false

func _ready() -> void:
	layer = 3
	visible = false

func is_playing() -> bool:
	return _playing

func play() -> void:
	if _playing:
		return
	_playing = true
	var scene: Node = get_tree().current_scene
	var loader: LevelLoader = scene.get_node("Systems/LevelLoader") as LevelLoader
	loader.go_to(load("res://src/scenes/world/village/Village.tscn") as PackedScene, "PlayerSpawn")
	var player: Player = scene.find_child("Player", true, false) as Player
	if player != null:
		player.busy = true
		player.cancel_tap()
	_set_clock(false)
	var hud: Node = scene.get_node_or_null("UI/HUD")
	if hud != null:
		hud.call("set_world_chrome", false)
	_pages = _write_pages(scene.get_node("Systems"))
	_build()
	visible = true
	_index = 0
	_show_page()
	var bank: Node = scene.get_node_or_null("Systems/SoundBank")
	if bank != null:
		bank.call("play", "level")

func advance() -> void:
	if not _playing:
		return
	_index += 1
	if _index > _pages.size():
		_close()
		return
	_show_page()

func _show_page() -> void:
	if _index < _pages.size():
		_label.text = _pages[_index]
		_next.text = Locale.t("next")
	else:
		var clock: GameClock = get_tree().current_scene.get_node("Systems/Clock") as GameClock
		_label.text = Locale.t("ending_thanks") % clock.day
		_next.text = Locale.t("keep_playing")
	Locale.apply_control(_label)
	Locale.apply_control(_next)
	_fit_screen()

func page_count() -> int:
	return _pages.size()

## A neighbor whose story the boy finished speaks about it. The others are there too, with a plainer line.
func _write_pages(systems: Node) -> PackedStringArray:
	var pages: PackedStringArray = PackedStringArray()
	for key: String in OPENING:
		pages.append(Locale.t(key))
	var friends: Friendship = systems.get_node_or_null("Friendship") as Friendship
	for person: String in Friendship.STORIES.keys():
		var told: bool = friends != null and friends.story_done(person)
		pages.append(Locale.t("end_%s_story" % person if told else "end_%s" % person))
	for key: String in CLOSING:
		pages.append(Locale.t(key))
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var bag: Inventory = systems.get_node_or_null("Inventory") as Inventory
	var kindness: Kindness = systems.get_node_or_null("Kindness") as Kindness
	pages.append(Locale.t("ending_summary") % [
		clock.day,
		friends.stories_done() if friends != null else 0,
		CollectionBook.found_total(bag.found) if bag != null else 0,
		CollectionBook.total(),
		kindness.points if kindness != null else 0,
	])
	return pages

func _close() -> void:
	var scene: Node = get_tree().current_scene
	var works: VillageWorks = scene.get_node("Systems/VillageWorks") as VillageWorks
	works.finish_story()
	_playing = false
	visible = false
	var player: Player = scene.find_child("Player", true, false) as Player
	if player != null:
		player.busy = false
	_set_clock(true)
	var hud: Node = scene.get_node_or_null("UI/HUD")
	if hud != null:
		hud.call("set_world_chrome", true)
		hud.call("refresh")
	(scene.get_node("Systems/SaveGame") as SaveGame).write_now()

func _set_clock(running: bool) -> void:
	var clock: Node = get_tree().current_scene.get_node_or_null("Systems/Clock")
	if clock != null:
		clock.set_process(running)

func _build() -> void:
	if _page != null:
		return
	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_page)
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(0.85, 0.55, 0.2, 0.28)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lights: CPUParticles2D = CPUParticles2D.new()
	lights.name = "Lanterns"
	lights.amount = 40
	lights.lifetime = 6.0
	lights.preprocess = 6.0
	lights.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	lights.emission_rect_extents = Vector2(320, 10)
	lights.direction = Vector2(0, -1)
	lights.spread = 12.0
	lights.gravity = Vector2.ZERO
	lights.initial_velocity_min = 16.0
	lights.initial_velocity_max = 34.0
	lights.scale_amount_min = 2.0
	lights.scale_amount_max = 4.0
	lights.color = UiStyle.GOLD
	_page.add_child(lights)
	_panel = Panel.new()
	_panel.size = Vector2(400, 142)
	UiStyle.panel(_panel)
	_page.add_child(_panel)
	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.size = Vector2(372, 90)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Centered, so a page reads the same in English and Arabic.
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", UiStyle.DARK)
	_label.add_theme_font_size_override("font_size", 14)
	_panel.add_child(_label)
	_next = Button.new()
	_next.position = Vector2(14, 104)
	_next.size = Vector2(372, 30)
	_next.focus_mode = Control.FOCUS_NONE
	UiStyle.button(_next)
	_next.pressed.connect(advance)
	_panel.add_child(_next)
	get_viewport().size_changed.connect(_fit_screen)

func _fit_screen() -> void:
	if _panel == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2((view.x - _panel.size.x) * 0.5, view.y - _panel.size.y - 12.0)
	(_page.get_node("Lanterns") as Node2D).position = Vector2(view.x * 0.5, view.y)
