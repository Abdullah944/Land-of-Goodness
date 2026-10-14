# File: src/ui/touch_controls/tool_bar.gd
# Purpose: five squares in the middle. An empty square opens the bag.

extends Control

const BLOCK := preload("res://assets/UI/inventory/general/normal_block.png")
const CHOSEN := preload("res://assets/UI/inventory/general/choosen_block.png")
const HOE := preload("res://assets/tools/hoe.png")

var _tools: Array[StringName] = [&"hoe", &"", &"", &"", &""]
var _icons: Array[Texture2D] = [HOE, null, null, null, null]
var _items: Array[GameItem] = [null, null, null, null, null]
var _selected := 0
var _waiting := -1
var _buttons: Array[TextureButton] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -176.0
	offset_top = -104.0
	offset_right = 176.0
	offset_bottom = -40.0
	for index in 5:
		var button := TextureButton.new()
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.position = Vector2(index * 72, 0)
		button.size = Vector2(64, 64)
		button.pressed.connect(_select.bind(index))
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(8, 8)
		icon.size = Vector2(48, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		add_child(button)
		_buttons.append(button)
	_refresh()

func tool_id() -> StringName:
	return _tools[_selected]

func is_waiting() -> bool:
	return _waiting >= 0

func cancel_wait() -> void:
	_waiting = -1

func give_item(item: GameItem) -> void:
	if _waiting < 0:
		return
	_items[_waiting] = item
	_icons[_waiting] = item.icon
	_tools[_waiting] = &"seed" if item.sprout != null else &"item"
	_selected = _waiting
	_waiting = -1
	_refresh()

func _select(index: int) -> void:
	if _tools[index] == &"":
		_waiting = index
		var inventory := get_tree().get_first_node_in_group("inventory")
		if inventory != null:
			inventory.open_bag()
		return
	_waiting = -1
	_selected = index
	var inventory := get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		_refresh()
		return
	if index == 0:
		inventory.clear_equipped()
	else:
		inventory.equip_item(_items[index])
	_refresh()

func _refresh() -> void:
	for index in _buttons.size():
		var button := _buttons[index]
		button.texture_normal = CHOSEN if index == _selected else BLOCK
		var icon := button.get_node("Icon") as TextureRect
		icon.texture = _icons[index]
		icon.visible = _icons[index] != null