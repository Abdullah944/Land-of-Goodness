# src/scripts/ui/title_menu.gd
# Purpose: The opening screen: continue the saved farm, start a new one, or switch language.

class_name TitleMenu
extends CanvasLayer

static var dismissed: bool = false
static var show_intro: bool = false

var _page: Control
var _window: Control
var _hero: TextureRect
var _confirm: bool = false

func _ready() -> void:
	if dismissed or (OS.is_debug_build() and OS.get_environment("KHAIR_SKIP_TITLE") == "1"):
		visible = false
		return
	_build()
	_hold(true)

func is_open() -> bool:
	return visible and _page != null

func _build() -> void:
	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_page)
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.08, 0.2, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var window: TextureRect = TextureRect.new()
	var image: Image = (load("res://assets/ui/menu/Empty wooden inventory window.png") as Texture2D).get_image()
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	window.texture = ImageTexture.create_from_image(image)
	window.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	window.stretch_mode = TextureRect.STRETCH_SCALE
	window.size = Vector2(300, 200)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(window)
	_window = window
	_hero = TextureRect.new()
	_hero.texture = load("res://assets/appIcon/Kuwaiti Farm Boy and Date Palm.png") as Texture2D
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_hero)
	_redraw_buttons()
	get_viewport().size_changed.connect(_redraw_buttons)

func _redraw_buttons() -> void:
	for child: Node in _page.get_children():
		if child.has_meta("title_item"):
			child.queue_free()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var rows: Array = []
	if _confirm:
		rows = [["yes", _start_new], ["no", _cancel_confirm]]
	else:
		var save: SaveGame = _save()
		if save != null and FileAccess.file_exists(save.path):
			rows.append(["continue", _continue])
		rows.append(["new_game", _ask_new])
		rows.append(["language", _toggle_language])
	# The window grows with its rows, so a third button (Continue) stays on the paper.
	_window.size.y = 136.0 + 32.0 * rows.size()
	var side: float = (view.x - _window.size.x) * 0.5
	var show_hero: bool = side >= 90.0
	_hero.visible = show_hero
	_window.position = Vector2(side + (side * 0.5 if show_hero else 0.0), (view.y - _window.size.y) * 0.5)
	_hero.size = Vector2(_window.position.x - 16.0, minf(view.y - 24.0, _window.position.x - 16.0))
	_hero.position = Vector2(8.0, (view.y - _hero.size.y) * 0.5)
	var top: float = _window.position.y
	var title: Label = Label.new()
	# Wrapping is switched on before the words go in; otherwise a long line stretches the label past the window.
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text = Locale.t("new_confirm") if _confirm else Locale.t("title")
	title.position = Vector2(_window.position.x + 30.0, top + 30.0)
	title.size = Vector2(240, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("3f2d27"))
	title.add_theme_font_size_override("font_size", 12 if _confirm else 22)
	Locale.apply_control(title)
	title.set_meta("title_item", true)
	_page.add_child(title)
	var version: Label = Label.new()
	version.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	version.position = Vector2(_window.position.x + 30.0, top + 74.0 + 32.0 * rows.size())
	version.size = Vector2(240, 12)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 8)
	version.add_theme_color_override("font_color", Color("7a5a44"))
	version.set_meta("title_item", true)
	_page.add_child(version)
	for i: int in rows.size():
		var button: Button = Button.new()
		button.text = Locale.t(str(rows[i][0]))
		button.position = Vector2(_window.position.x + 50.0, top + 72.0 + 32.0 * i)
		button.size = Vector2(200, 28)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		UiStyle.button(button)
		Locale.apply_control(button)
		button.pressed.connect(rows[i][1])
		button.set_meta("title_item", true)
		_page.add_child(button)

func _continue() -> void:
	_close()

func _ask_new() -> void:
	var save: SaveGame = _save()
	if save != null and not FileAccess.file_exists(save.path):
		_start_new()
		return
	_confirm = true
	_redraw_buttons()

func _cancel_confirm() -> void:
	_confirm = false
	_redraw_buttons()

func _start_new() -> void:
	var save: SaveGame = _save()
	if save == null:
		return
	var stead: Stead = get_tree().current_scene.get_node_or_null("Systems/Stead") as Stead
	var language: String = stead.language if stead != null else Locale.language
	save.start_new({"stead": {"language": language}})
	dismissed = true
	show_intro = true
	get_tree().reload_current_scene()

func _toggle_language() -> void:
	Locale.language = "en" if Locale.language == "ar" else "ar"
	var stead: Stead = get_tree().current_scene.get_node_or_null("Systems/Stead") as Stead
	if stead != null:
		stead.language = Locale.language
	_redraw_buttons()

func _close() -> void:
	dismissed = true
	visible = false
	_hold(false)
	var save: SaveGame = _save()
	if save != null:
		save.write_now()
	var hud: Node = get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("refresh"):
		hud.call("refresh")

func _hold(on: bool) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var clock: Node = scene.get_node_or_null("Systems/Clock")
	if clock != null:
		clock.set_process(not on)
	var player: Node = scene.find_child("Player", true, false)
	if player != null:
		player.set("busy", on)
	# The game's own hearts, clock and quest line stay hidden behind the start screen.
	var hud: CanvasLayer = scene.get_node_or_null("UI/HUD") as CanvasLayer
	if hud != null:
		hud.visible = not on

func _save() -> SaveGame:
	var scene: Node = get_tree().current_scene
	return scene.get_node_or_null("Systems/SaveGame") as SaveGame if scene != null else null
