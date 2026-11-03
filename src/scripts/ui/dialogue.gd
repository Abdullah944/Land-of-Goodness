# src/scripts/ui/dialogue.gd
# Purpose: Shows spoken lines, Yes or No, and a list of shop choices.

class_name DialogueBox
extends CanvasLayer

signal answered(yes: bool)
signal picked(choice: String)

const _PANEL_AT: Vector2 = Vector2(40, 200)
const _PANEL_SIZE: Vector2 = Vector2(430, 70)
const MAX_ROWS: int = 6
## One choice row: a button with the Arabic font is about thirty-five pixels tall.
const ROW_STEP: float = 38.0
const MORE: String = "__more"

var _offer_all: PackedStringArray = []
var _offer_page: int = 0
var _lines: PackedStringArray = []
var _index: int = 0
var _choosing: bool = false
var _offering: bool = false
var _panel: Panel
var _label: Label
var _next: Button
var _yes: Button
var _no: Button
var _offer_buttons: Array[Button] = []
var _portrait_box: Panel
var _portrait: TextureRect
var _speaker_name: Label
var _speaker: String = ""
var _faces: Dictionary = {}
var _typing: Tween
var _heart_row: HBoxContainer
var _heart_marks: Array[TextureRect] = []

const FACE_W: float = 44.0
const SPEAKERS: Dictionary = {
	"jassim": "res://assets/characters/NPC/Kind Kuwaiti Elder Sprite JASSEM.png",
	"elder": "res://assets/characters/village/Elder.png",
	"merchant": "res://assets/characters/village/Merchant.png",
	"carpenter": "res://assets/characters/village/Carpenter.png",
	"fisherman": "res://assets/characters/village/Fisherman.png",
}

func _ready() -> void:
	visible = false
	_panel = Panel.new()
	_panel.position = Vector2(40, 200)
	_panel.size = Vector2(430, 70)
	UiStyle.panel(_panel)
	add_child(_panel)
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.size = Vector2(414, 32)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color("3f2d27"))
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_constant_override("line_spacing", -4)
	_panel.add_child(_label)
	_next = Button.new()
	_next.text = Locale.t("next")
	Locale.apply_control(_label)
	Locale.apply_control(_next)
	_next.position = Vector2(360, 40)
	UiStyle.button(_next)
	_next.pressed.connect(_advance)
	_panel.add_child(_next)
	_yes = _choice_button(Locale.t("yes"), Vector2(250, 40))
	_no = _choice_button(Locale.t("no"), Vector2(340, 40))
	_yes.pressed.connect(_choose.bind(true))
	_no.pressed.connect(_choose.bind(false))
	_build_portrait()
	_fit_screen()
	get_viewport().size_changed.connect(_fit_screen)

func _build_portrait() -> void:
	_portrait_box = Panel.new()
	_portrait_box.position = Vector2(8, 6)
	_portrait_box.size = Vector2(FACE_W - 6.0, 25)
	_portrait_box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CREAM, UiStyle.WOOD_DARK, 1))
	_portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_portrait_box)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(2, 2)
	_portrait.size = _portrait_box.size - Vector2(4, 4)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_box.add_child(_portrait)
	_speaker_name = Label.new()
	_speaker_name.position = Vector2(4, 29)
	_speaker_name.size = Vector2(FACE_W + 4.0, 11)
	_speaker_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speaker_name.add_theme_font_size_override("font_size", 8)
	_speaker_name.add_theme_color_override("font_color", UiStyle.DARK)
	_speaker_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_speaker_name)
	# Five small hearts: how close the boy is to this neighbor.
	_heart_row = HBoxContainer.new()
	_heart_row.position = Vector2(5, 42)
	_heart_row.size = Vector2(FACE_W, 6)
	_heart_row.add_theme_constant_override("separation", 1)
	_heart_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_heart_row)
	var heart_picture: Texture2D = load("res://assets/ui/Terracotta pixel heart icon.png") as Texture2D
	for i: int in Friendship.MAX_HEARTS:
		var heart: TextureRect = TextureRect.new()
		heart.texture = heart_picture
		heart.custom_minimum_size = Vector2(7, 7)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_heart_row.add_child(heart)
		_heart_marks.append(heart)
	_heart_row.visible = false

## Shows who is talking until set_speaker("") or the talk ends.
func set_speaker(person: String) -> void:
	_speaker = person if SPEAKERS.has(person) else ""
	_heart_row.visible = false
	_place_speaker()

## Fills that many of the five hearts under the speaker's face.
func set_hearts(count: int) -> void:
	for i: int in _heart_marks.size():
		_heart_marks[i].modulate = Color.WHITE if i < count else Color(0.3, 0.22, 0.18, 0.85)
	_heart_row.visible = _speaker != ""

func _place_speaker() -> void:
	var shown: bool = _speaker != ""
	_portrait_box.visible = shown
	_speaker_name.visible = shown
	if not shown:
		_heart_row.visible = false
	_label.position.x = 8.0 + (FACE_W + 4.0 if shown else 0.0)
	_label.size.x = 414.0 - (FACE_W + 4.0 if shown else 0.0)
	if shown:
		_portrait.texture = _face(_speaker)
		_speaker_name.text = Locale.t("name_" + _speaker)
		Locale.apply_control(_speaker_name)

## The head and shoulders of the person's picture.
func _face(person: String) -> Texture2D:
	if _faces.has(person):
		return _faces[person]
	var image: Image = UiStyle.pixels_of(load(str(SPEAKERS[person])) as Texture2D)
	var used: Rect2i = image.get_used_rect()
	var side: int = mini(used.size.x, int(used.size.y * 0.5))
	var left: int = used.position.x + int((used.size.x - side) * 0.5)
	var cut: Image = image.get_region(Rect2i(left, used.position.y, side, side))
	var face: Texture2D = UiStyle.hd_texture(cut, Vector2(64, 64))
	_faces[person] = face
	return face

## Letters appear one after another. A tap on any button never has to wait for it.
func _type_text() -> void:
	if _typing != null:
		_typing.kill()
	_label.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(_label, "visible_ratio", 1.0, minf(1.0, float(_label.text.length()) * 0.02))

## Keeps the box centered and on the bottom edge of any screen shape.
func _fit_screen() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	offset = Vector2((view.x - 512.0) * 0.5, view.y - 288.0)

func open_lines(lines: PackedStringArray) -> void:
	_close_offer()
	_choosing = false
	_lines = lines
	_index = 0
	visible = true
	_panel.size = Vector2(430, 112)
	_panel.position = Vector2(40, 288.0 - 112.0 - 6.0)
	_label.size = Vector2(414, 62)
	_next.position = Vector2(8, 72)
	_next.size = Vector2(414, 32)
	_show_choices(false)
	_show_line()
	_hold_player()

func ask(text: String) -> void:
	_close_offer()
	_heart_row.visible = false
	_choosing = true
	_lines = PackedStringArray([text])
	_index = 0
	visible = true
	_label.text = text
	_yes.text = Locale.t("yes")
	_no.text = Locale.t("no")
	Locale.apply_control(_label)
	_fit_actions(2)
	_yes.position = Vector2(8, 46)
	_yes.size = Vector2(414, 34)
	_no.position = Vector2(8, 82)
	_no.size = Vector2(414, 34)
	_show_choices(true)
	_speaker = ""
	_place_speaker()
	_hold_player()

func offer(text: String, choices: PackedStringArray) -> void:
	_close_offer()
	_offering = true
	_choosing = false
	_show_choices(false)
	_next.visible = false
	visible = true
	_label.text = text
	Locale.apply_control(_label)
	_offer_all = choices
	_offer_page = 0
	_show_offer_page()
	_type_text()
	_hold_player()

## A short list shows whole. A long one shows a page, a More button, and always Cancel.
func _show_offer_page() -> void:
	_clear_offer_buttons()
	var rows: PackedStringArray = _offer_all
	if _offer_all.size() > MAX_ROWS:
		var body: PackedStringArray = _offer_all
		var last: PackedStringArray = PackedStringArray()
		if _choice_parts(_offer_all[_offer_all.size() - 1])[0] == "cancel":
			body = _offer_all.slice(0, _offer_all.size() - 1)
			last.append(_offer_all[_offer_all.size() - 1])
		var per_page: int = MAX_ROWS - 1 - last.size()
		rows = body.slice(_offer_page * per_page, (_offer_page + 1) * per_page)
		rows.append("%s|%s" % [MORE, Locale.t("more")])
		rows.append_array(last)
	_fit_actions(rows.size())
	_place_speaker()
	for i: int in rows.size():
		var parts: PackedStringArray = _choice_parts(rows[i])
		var button: Button = Button.new()
		button.text = parts[1]
		var spot: Rect2 = _offer_spot(i, rows.size())
		button.position = spot.position
		button.size = spot.size
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UiStyle.button(button)
		Locale.apply_control(button)
		if parts[0] == MORE:
			button.pressed.connect(_next_offer_page)
		else:
			button.pressed.connect(_pick.bind(parts[0]))
		_panel.add_child(button)
		_offer_buttons.append(button)

func _next_offer_page() -> void:
	var body: int = _offer_all.size()
	if _choice_parts(_offer_all[body - 1])[0] == "cancel":
		body -= 1
	var per_page: int = MAX_ROWS - 1 - (_offer_all.size() - body)
	_offer_page += 1
	if _offer_page * per_page >= body:
		_offer_page = 0
	_show_offer_page()

func _clear_offer_buttons() -> void:
	for button: Button in _offer_buttons:
		button.queue_free()
	_offer_buttons.clear()

## Buttons start lower when a neighbor's hearts show under the face.
func _first_row() -> float:
	return 54.0 if _heart_row.visible else 46.0

## Short lists stay one wide row each; longer ones sit in two columns, so the panel never covers the screen.
func _offer_spot(index: int, count: int) -> Rect2:
	if count <= 3:
		return Rect2(8, _first_row() + ROW_STEP * index, 414, ROW_STEP - 3.0)
	var width: float = (414.0 - 6.0) * 0.5
	return Rect2(8.0 + (index % 2) * (width + 6.0), _first_row() + ROW_STEP * (index / 2), width, ROW_STEP - 3.0)

func _fit_actions(rows: int) -> void:
	_label.size = Vector2(414, 40)
	var lines: int = rows if rows <= 3 else (rows + 1) / 2
	var height: float = _first_row() + 6.0 + ROW_STEP * lines
	_panel.size = Vector2(430, height)
	_panel.position = Vector2(40, 288.0 - height - 6.0)

func _close_offer() -> void:
	_offering = false
	_clear_offer_buttons()
	_panel.position = _PANEL_AT
	_panel.size = _PANEL_SIZE
	_label.size = Vector2(414, 32)

func _choice_parts(raw: String) -> PackedStringArray:
	var parts: PackedStringArray = raw.split("|", true, 1)
	if parts.size() < 2:
		return PackedStringArray([raw, raw])
	return parts

func _pick(choice: String) -> void:
	if not _offering:
		return
	_close_offer()
	visible = false
	var player: Player = get_tree().current_scene.find_child("Player", true, false) as Player
	player.busy = false
	var bank: Node = get_tree().current_scene.get_node_or_null("Systems/SoundBank")
	if bank != null:
		bank.call("play", "ui")
	picked.emit(choice)

func _choice_button(text: String, at: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = at
	button.visible = false
	UiStyle.button(button)
	_panel.add_child(button)
	return button

func _show_choices(choosing: bool) -> void:
	_next.visible = not choosing
	_yes.visible = choosing
	_no.visible = choosing

func _hold_player() -> void:
	var player: Player = get_tree().current_scene.find_child("Player", true, false) as Player
	player.busy = true
	player.cancel_tap()

func _choose(yes: bool) -> void:
	if not _choosing:
		return
	_choosing = false
	visible = false
	_show_choices(false)
	var player: Player = get_tree().current_scene.find_child("Player", true, false) as Player
	player.busy = false
	answered.emit(yes)

func _advance() -> void:
	if _choosing:
		return
	_index += 1
	if _index >= _lines.size():
		visible = false
		_speaker = ""
		var player: Player = get_tree().current_scene.find_child("Player", true, false) as Player
		player.busy = false
		return
	_show_line()

func _show_line() -> void:
	_next.text = Locale.t("next")
	Locale.apply_control(_label)
	Locale.apply_control(_next)
	_label.text = _lines[_index]
	_place_speaker()
	_type_text()
