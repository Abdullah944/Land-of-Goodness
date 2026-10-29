# src/scripts/ui/dialogue.gd
# Purpose: Shows Jassim's lines and waits for a tap to continue.

class_name DialogueBox
extends CanvasLayer

var _lines: PackedStringArray = []
var _index: int = 0
var _panel: Panel
var _label: Label
var _next: Button

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

func open_lines(lines: PackedStringArray) -> void:
	_lines = lines
	_index = 0
	visible = true
	_show_line()
	var player: Player = get_tree().current_scene.find_child("Player", true, false) as Player
	player.busy = true
	player.cancel_tap()

func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		visible = false
		var player: Player = get_tree().current_scene.find_child("Player", true, false) as Player
		player.busy = false
		return
	_show_line()

func _show_line() -> void:
	_label.text = _lines[_index]
