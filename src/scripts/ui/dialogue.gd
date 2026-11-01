# src/scripts/ui/dialogue.gd
# Purpose: Shows spoken lines, Yes or No, and a list of shop choices.

class_name DialogueBox
extends CanvasLayer

signal answered(yes: bool)
signal picked(choice: String)

const _PANEL_AT: Vector2 = Vector2(40, 200)
const _PANEL_SIZE: Vector2 = Vector2(430, 70)

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

func _ready() -> void:
	visible = false
	_panel = Panel.new()
	_panel.position = Vector2(40, 200)
	_panel.size = Vector2(430, 70)
	add_child(_panel)
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.size = Vector2(414, 32)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color("3f2d27"))
	_panel.add_child(_label)
	_next = Button.new()
	_next.text = "Next"
	_next.position = Vector2(360, 40)
	_next.pressed.connect(_advance)
	_panel.add_child(_next)
	_yes = _choice_button("Yes", Vector2(250, 40))
	_no = _choice_button("No", Vector2(340, 40))
	_yes.pressed.connect(_choose.bind(true))
	_no.pressed.connect(_choose.bind(false))

func open_lines(lines: PackedStringArray) -> void:
	_close_offer()
	_choosing = false
	_lines = lines
	_index = 0
	visible = true
	_fit_actions(1)
	_next.position = Vector2(8, 46)
	_next.size = Vector2(414, 34)
	_show_choices(false)
	_show_line()
	_hold_player()

func ask(text: String) -> void:
	_close_offer()
	_choosing = true
	_lines = PackedStringArray([text])
	_index = 0
	visible = true
	_label.text = text
	_fit_actions(2)
	_yes.position = Vector2(8, 46)
	_yes.size = Vector2(414, 34)
	_no.position = Vector2(8, 82)
	_no.size = Vector2(414, 34)
	_show_choices(true)
	_hold_player()

func offer(text: String, choices: PackedStringArray) -> void:
	_close_offer()
	_offering = true
	_choosing = false
	_show_choices(false)
	_next.visible = false
	visible = true
	_label.text = text
	_fit_actions(choices.size())
	for i: int in choices.size():
		var button: Button = Button.new()
		button.text = choices[i]
		button.position = Vector2(8, 46.0 + 36.0 * i)
		button.size = Vector2(414, 34)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_pick.bind(choices[i]))
		_panel.add_child(button)
		_offer_buttons.append(button)
	_hold_player()

func _fit_actions(rows: int) -> void:
	_label.size = Vector2(414, 40)
	var height: float = 52.0 + 36.0 * rows
	_panel.size = Vector2(430, height)
	_panel.position = Vector2(40, 288.0 - height - 6.0)

func _close_offer() -> void:
	_offering = false
	for button: Button in _offer_buttons:
		button.queue_free()
	_offer_buttons.clear()
	_panel.position = _PANEL_AT
	_panel.size = _PANEL_SIZE
	_label.size = Vector2(414, 32)

func _pick(choice: String) -> void:
	if not _offering:
		return
	_close_offer()
	visible = false
	var player: Player = get_tree().current_scene.find_child("Player", true, false) as Player
	player.busy = false
	picked.emit(choice)

func _choice_button(text: String, at: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = at
	button.visible = false
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
		var player: Player = get_tree().current_scene.find_child("Player", true, false) as Player
		player.busy = false
		return
	_show_line()

func _show_line() -> void:
	_label.text = _lines[_index]
