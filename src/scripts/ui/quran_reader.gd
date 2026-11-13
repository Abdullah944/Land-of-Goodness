# src/scripts/ui/quran_reader.gd
# Purpose: The Quran on the mosque's shelf, to listen to. A list of the 114 suras; tap one to hear it recited
# by Mishary Alafasy. No Quran text is shown. Each sura is downloaded only when the player asks, once, and
# then plays without internet (see QuranAudio). The last sura is remembered, so the list offers it next time.

class_name QuranReader
extends CanvasLayer

const WINDOW_SIZE: Vector2 = Vector2(472, 264)
const COLUMNS: int = 3
const ROW_H: float = 26.0
const GAP: float = 4.0
## The top row: title, the back button and the X. Everything else starts below it.
const HEAD_H: float = 30.0
const TOP: float = HEAD_H + 10.0
const NAME_FONT: int = 24
const BAR_W: float = 300.0
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
var _listen: Control
var _name: Label
var _about: Label
var _status: Label
var _play: Button
var _bar_fill: ColorRect
var _http: HTTPRequest
var _player: AudioStreamPlayer
var _sura: int = 0
var _downloading: int = 0
## Tests turn this off, so they never download anything.
static var allow_network: bool = true
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
	_stop()
	visible = false
	_hold(false)

## Opens one sura's page. It plays at once when it is on the phone; otherwise the player chooses to download it.
func listen(index: int) -> void:
	if QuranText.sura(index).is_empty():
		return
	_stop()
	_sura = index
	var stead: Node = _systems().get_node_or_null("Stead") if _systems() != null else null
	if stead != null:
		(stead.get("flags") as Dictionary)["quran_sura"] = index
		var save: Node = _systems().get_node_or_null("SaveGame")
		if save != null:
			save.call("write_now")
	var info: Dictionary = QuranText.sura(index)
	_title.text = Locale.t("quran_title")
	Locale.apply_control(_title)
	_name.text = "سورة %s" % str(info["name"])
	_about.text = "%s   ·   %s" % [Locale.t("quran_verses") % int(info["ayas"]), Locale.t("quran_reciter")]
	Locale.apply_control(_about)
	_list_scroll.visible = false
	_continue.visible = false
	_listen.visible = true
	_back.visible = true
	_back.text = "◀ " + Locale.t("quran_suras")
	Locale.apply_control(_back)
	_bar_fill.size.x = 0.0
	if QuranAudio.has(index):
		_start_playing()
	else:
		_set_status(Locale.t("quran_once"))
		_set_play(Locale.t("quran_get"))

func showing_sura() -> int:
	return _sura if _listen.visible else 0

func is_playing() -> bool:
	return _player.playing and not _player.stream_paused

func is_downloading() -> bool:
	return _downloading != 0

func _show_list() -> void:
	_stop()
	_sura = 0
	_title.text = Locale.t("quran_title")
	_title.remove_theme_font_override("font")
	Locale.apply_control(_title)
	_back.visible = false
	_listen.visible = false
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
	_continue.pressed.connect(func() -> void: listen(_last_read()))
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
	_listen = Control.new()
	_listen.position = Vector2(8, TOP)
	_listen.size = Vector2(WINDOW_SIZE.x - 16.0, WINDOW_SIZE.y - TOP - 26.0)
	_listen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_listen.visible = false
	_window.add_child(_listen)
	var wide: float = _listen.size.x
	_name = _line(Vector2(0, 8), Vector2(wide, 40), NAME_FONT)
	_name.add_theme_font_override("font", Locale.arabic_face())
	_about = _line(Vector2(0, 52), Vector2(wide, 18), 11)
	_about.add_theme_color_override("font_color", UiStyle.BROWN)
	var bar: ColorRect = ColorRect.new()
	bar.color = UiStyle.BEIGE
	bar.position = Vector2((wide - BAR_W) * 0.5, 84)
	bar.size = Vector2(BAR_W, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_listen.add_child(bar)
	_bar_fill = ColorRect.new()
	_bar_fill.color = UiStyle.BROWN
	_bar_fill.size = Vector2(0, 6)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_bar_fill)
	_status = _line(Vector2(0, 96), Vector2(wide, 18), 10)
	_status.add_theme_color_override("font_color", UiStyle.BROWN)
	_play = _button("", Vector2(0, 0), Vector2(180, 34))
	_play.reparent(_listen)
	_play.position = Vector2((wide - 180.0) * 0.5, 126)
	_play.add_theme_font_size_override("font_size", 13)
	_play.pressed.connect(_on_play)
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 60.0
	_http.request_completed.connect(_on_downloaded)
	add_child(_http)
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.finished.connect(_on_finished)
	add_child(_player)
	_fit_screen()

func _line(at: Vector2, size: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.position = at
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiStyle.DARK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_listen.add_child(label)
	return label

## The one big button: download, play, pause, or play again.
func _on_play() -> void:
	if _sura == 0 or is_downloading():
		return
	if not QuranAudio.has(_sura):
		_download()
	elif _player.stream == null or not _player.playing:
		_start_playing()
	else:
		_player.stream_paused = not _player.stream_paused
		_set_play(Locale.t("quran_play") if _player.stream_paused else Locale.t("quran_pause"))

func _download() -> void:
	if not allow_network:
		_set_status(Locale.t("quran_failed"))
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QuranAudio.FOLDER))
	_http.download_file = QuranAudio.part_path(_sura)
	if _http.request(QuranAudio.url(_sura)) != OK:
		_set_status(Locale.t("quran_failed"))
		return
	_downloading = _sura
	_set_status(Locale.t("quran_loading") % 0)
	_set_play("...")

func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var index: int = _downloading
	_downloading = 0
	var kept: bool = result == HTTPRequest.RESULT_SUCCESS and code == 200 and QuranAudio.keep(index)
	if not kept:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QuranAudio.part_path(index)))
	if index != _sura or not visible:
		return
	if kept:
		_start_playing()
	else:
		_bar_fill.size.x = 0.0
		_set_status(Locale.t("quran_failed"))
		_set_play(Locale.t("quran_get"))

func _start_playing() -> void:
	var sound: AudioStreamMP3 = QuranAudio.stream(_sura)
	if sound == null:
		return
	_player.stream = sound
	_player.stream_paused = false
	_player.play()
	_set_status(Locale.t("quran_saved"))
	_set_play(Locale.t("quran_pause"))

func _on_finished() -> void:
	_bar_fill.size.x = BAR_W
	_set_play(Locale.t("quran_again"))

## Stops the recitation and any download, so nothing plays or loads after the page is left.
func _stop() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null
	if is_downloading():
		_http.cancel_request()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QuranAudio.part_path(_downloading)))
		_downloading = 0

func _process(_delta: float) -> void:
	if not visible or _sura == 0:
		return
	if is_downloading():
		var total: int = _http.get_body_size()
		var share: float = float(_http.get_downloaded_bytes()) / float(total) if total > 0 else 0.0
		_bar_fill.size.x = BAR_W * clampf(share, 0.0, 1.0)
		_set_status(Locale.t("quran_loading") % int(share * 100.0))
	elif _player.playing and _player.stream != null:
		var length: float = _player.stream.get_length()
		_bar_fill.size.x = BAR_W * clampf(_player.get_playback_position() / length, 0.0, 1.0) if length > 0.0 else 0.0

func _set_status(text: String) -> void:
	_status.text = text
	Locale.apply_control(_status)

func _set_play(text: String) -> void:
	_play.text = text
	Locale.apply_control(_play)

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
			listen(i + 1)
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
