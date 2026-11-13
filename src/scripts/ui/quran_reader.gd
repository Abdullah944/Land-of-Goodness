# src/scripts/ui/quran_reader.gd
# Purpose: The Quran on the mosque's shelf. A list of the 114 suras; tap one to read it.
# The text is shown exactly as in the Tanzil file (see QuranText), in the Naskh font, right to left.
# The last sura read is remembered, so the list offers "Continue" next time.
# Recitation is not part of this yet: it will be an optional download for each sura, once a reciter is chosen.

class_name QuranReader
extends CanvasLayer

const WINDOW_SIZE: Vector2 = Vector2(472, 264)
const COLUMNS: int = 3
const ROW_H: float = 26.0
const GAP: float = 4.0
## The top row: title, the back button and the X. Everything else starts below it.
const HEAD_H: float = 30.0
const TOP: float = HEAD_H + 10.0
const VERSE_FONT: int = 15
## A press that moves less than this is a tap, not a drag.
const TAP_SLOP: float = 8.0

var _page: Control
var _window: Panel
var _title: Label
var _back: Button
var _close: Button
var _list_scroll: ScrollContainer
var _list_body: Control
var _list_buttons: Array[Button] = []
var _continue: Button
var _credit: Label
var _read_scroll: ScrollContainer
var _read_body: VBoxContainer
var _basmala: Label
var _verses: Label
var _sura: int = 0
var _press_at: Vector2 = Vector2.INF
var _scroll_at_press: int = 0
var _moved: bool = false

func _ready() -> void:
	layer = 4
	visible = false
	_build()
	get_viewport().size_changed.connect(_fit_screen)

func is_open() -> bool:
	return visible

## Opens the list of suras.
func open() -> void:
	visible = true
	_hold(true)
	_show_list()

func close() -> void:
	visible = false
	_hold(false)

## Opens one sura at its start.
func read(index: int) -> void:
	if QuranText.sura(index).is_empty():
		return
	_sura = index
	var stead: Node = _systems().get_node_or_null("Stead") if _systems() != null else null
	if stead != null:
		(stead.get("flags") as Dictionary)["quran_sura"] = index
		var save: Node = _systems().get_node_or_null("SaveGame")
		if save != null:
			save.call("write_now")
	var info: Dictionary = QuranText.sura(index)
	_title.text = "سورة %s" % str(info["name"])
	_title.add_theme_font_override("font", Locale.arabic_face())
	_basmala.visible = QuranText.has_basmala(index)
	var parts: PackedStringArray = PackedStringArray()
	var count: int = QuranText.verses(index).size()
	for number: int in range(1, count + 1):
		parts.append("%s ﴿%s﴾" % [QuranText.shown_verse(index, number), QuranText.arabic_number(number)])
	_verses.text = " ".join(parts)
	_list_scroll.visible = false
	_continue.visible = false
	_credit.visible = false
	_read_scroll.visible = true
	_back.visible = true
	_back.text = "◀ " + Locale.t("quran_suras")
	Locale.apply_control(_back)
	_read_scroll.scroll_vertical = 0

func showing_sura() -> int:
	return _sura if _read_scroll.visible else 0

func _show_list() -> void:
	_sura = 0
	_title.text = Locale.t("quran_title")
	_title.remove_theme_font_override("font")
	Locale.apply_control(_title)
	_back.visible = false
	_read_scroll.visible = false
	_list_scroll.visible = true
	_credit.visible = true
	_credit.text = Locale.t("quran_credit")
	Locale.apply_control(_credit)
	var last: int = _last_read()
	_continue.visible = last > 0
	var top: float = TOP
	if last > 0:
		_continue.text = Locale.t("quran_continue") % ("سورة " + str(QuranText.sura(last)["name"]))
		_continue.add_theme_font_override("font", Locale.arabic_face())
		top += ROW_H + GAP
	_list_scroll.position = Vector2(8, top)
	_list_scroll.size = Vector2(WINDOW_SIZE.x - 16.0, WINDOW_SIZE.y - top - 22.0)
	for i: int in _list_buttons.size():
		var info: Dictionary = QuranText.sura(i + 1)
		var name: String = str(info["name"])
		_list_buttons[i].text = "%d. %s" % [i + 1, name] if Locale.language == "ar" else "%d. %s  %s" % [i + 1, str(info["tname"]), name]

func _last_read() -> int:
	var stead: Node = _systems().get_node_or_null("Stead") if _systems() != null else null
	if stead == null:
		return 0
	return int((stead.get("flags") as Dictionary).get("quran_sura", 0))

func _build() -> void:
	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_page)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.08, 0.2, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.size = Vector2(4096, 4096)
	shade.position = Vector2(-2048, -2048)
	_page.add_child(shade)
	_window = Panel.new()
	_window.size = WINDOW_SIZE
	UiStyle.panel(_window)
	_page.add_child(_window)
	_title = Label.new()
	_title.position = Vector2(84, 4)
	_title.size = Vector2(WINDOW_SIZE.x - 168.0, HEAD_H)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", UiStyle.DARK)
	_window.add_child(_title)
	_back = _button("◀ " + Locale.t("quran_suras"), Vector2(6, 4), Vector2(74, HEAD_H))
	_back.pressed.connect(_show_list)
	_close = _button("X", Vector2(WINDOW_SIZE.x - 36.0, 4), Vector2(30, HEAD_H))
	_close.pressed.connect(close)
	_continue = _button("", Vector2(8, TOP), Vector2(WINDOW_SIZE.x - 16.0, ROW_H))
	_continue.pressed.connect(func() -> void: read(_last_read()))
	_list_scroll = _scroller()
	_window.add_child(_list_scroll)
	_list_body = Control.new()
	var cell_w: float = (WINDOW_SIZE.x - 16.0 - 4.0 - GAP * (COLUMNS - 1)) / float(COLUMNS)
	_list_body.custom_minimum_size = Vector2(WINDOW_SIZE.x - 20.0, ceil(QuranText.SURA_COUNT / float(COLUMNS)) * (ROW_H + GAP))
	_list_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_list_body.gui_input.connect(_on_drag.bind(_list_scroll, true))
	_list_scroll.add_child(_list_body)
	for i: int in QuranText.SURA_COUNT:
		var cell: Button = _button("", Vector2((i % COLUMNS) * (cell_w + GAP), (i / COLUMNS) * (ROW_H + GAP)), Vector2(cell_w, ROW_H))
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_font_override("font", Locale.arabic_face())
		cell.add_theme_font_size_override("font_size", 11)
		cell.clip_text = true
		cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.reparent(_list_body)
		_list_buttons.append(cell)
	_credit = Label.new()
	_credit.position = Vector2(8, WINDOW_SIZE.y - 20.0)
	_credit.size = Vector2(WINDOW_SIZE.x - 16.0, 14)
	_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credit.add_theme_font_size_override("font_size", 8)
	_credit.add_theme_color_override("font_color", UiStyle.BROWN)
	_window.add_child(_credit)
	_read_scroll = _scroller()
	_read_scroll.position = Vector2(8, TOP)
	_read_scroll.size = Vector2(WINDOW_SIZE.x - 16.0, WINDOW_SIZE.y - TOP - 8.0)
	_window.add_child(_read_scroll)
	_read_body = VBoxContainer.new()
	_read_body.custom_minimum_size = Vector2(WINDOW_SIZE.x - 24.0, 0)
	_read_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_read_body.add_theme_constant_override("separation", 4)
	_read_body.gui_input.connect(_on_drag.bind(_read_scroll, false))
	_read_scroll.add_child(_read_body)
	_basmala = _quran_label(VERSE_FONT + 2)
	_basmala.text = QuranText.basmala()
	_basmala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_read_body.add_child(_basmala)
	_verses = _quran_label(VERSE_FONT)
	# Lines are filled by widening the spaces only. Stretching letters (kashida) would change how the words look.
	_verses.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	_verses.justification_flags = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_SKIP_LAST_LINE
	_read_body.add_child(_verses)
	_fit_screen()

func _quran_label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.custom_minimum_size = Vector2(WINDOW_SIZE.x - 24.0, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.add_theme_font_override("font", Locale.arabic_face())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", 6)
	label.add_theme_color_override("font_color", UiStyle.DARK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _scroller() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.visible = false
	return scroll

func _button(title: String, at: Vector2, size: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.position = at
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	UiStyle.button(button)
	_window.add_child(button)
	return button

## Dragging scrolls; a short press on the list opens the sura under the finger.
func _on_drag(event: InputEvent, scroll: ScrollContainer, is_list: bool) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll.scroll_vertical += -24 if click.button_index == MOUSE_BUTTON_WHEEL_UP else 24
			return
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_press_at = click.global_position
			_scroll_at_press = scroll.scroll_vertical
			_moved = false
		else:
			if is_list and not _moved:
				_tap_list(click.position)
			_press_at = Vector2.INF
	elif event is InputEventMouseMotion and _press_at != Vector2.INF:
		var motion: InputEventMouseMotion = event
		var pulled: float = motion.global_position.y - _press_at.y
		if absf(pulled) > TAP_SLOP:
			_moved = true
		if _moved:
			scroll.scroll_vertical = _scroll_at_press - int(pulled)

func _tap_list(local_position: Vector2) -> void:
	for i: int in _list_buttons.size():
		if Rect2(_list_buttons[i].position, _list_buttons[i].size).has_point(local_position):
			Juice.press(_list_buttons[i])
			read(i + 1)
			return

func _fit_screen() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	_window.position = (view - WINDOW_SIZE) * 0.5

func _hold(on: bool) -> void:
	var scene: Node = get_tree().current_scene
	var player: Node = scene.find_child("Player", true, false) if scene != null else null
	if player != null:
		player.set("busy", on)
		if on and player.has_method("cancel_tap"):
			player.call("cancel_tap")
	var hud: Node = scene.get_node_or_null("UI/HUD") if scene != null else null
	if hud != null and hud.has_method("set_world_chrome"):
		hud.call("set_world_chrome", not on)

func _systems() -> Node:
	var scene: Node = get_tree().current_scene
	return scene.get_node_or_null("Systems") if scene != null else null
