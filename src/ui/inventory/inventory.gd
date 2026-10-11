# File: src/ui/Inventory/inventory.gd
# Purpose: open the bag, and stack whatever the boy picks up.

extends Control

const BLOCK := preload("res://assets/UI/inventory/general/normal_block.png")

@onready var _window: TextureRect = $CanvasLayer/Window
@onready var _slots: Control = $CanvasLayer/Window/Slots

var _order: Array[StringName] = []
var _counts := {}
var _icons := {}

func _ready() -> void:
	_window.visible = false
	$CanvasLayer/BagButton.pressed.connect(_toggle)
	$CanvasLayer/Window/CloseButton.pressed.connect(_close)

func _toggle() -> void:
	_window.visible = not _window.visible

func _close() -> void:
	_window.visible = false

func add_item(item: GameItem) -> void:
	if _counts.has(item.id):
		_counts[item.id] += 1
	else:
		_counts[item.id] = 1
		_order.append(item.id)
		_icons[item.id] = item.icon
	_redraw()

func _redraw() -> void:
	for child in _slots.get_children():
		child.free()
	var index := 0
	for id in _order:
		var slot := TextureRect.new()
		slot.texture = BLOCK
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.position = Vector2(index * 136, 0)
		slot.size = Vector2(120, 120)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = _icons[id]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(18, 18)
		icon.size = Vector2(84, 84)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var count := Label.new()
		count.text = str(_counts[id])
		count.position = Vector2(78, 82)
		count.add_theme_color_override("font_color", Color("7A4F32"))
		slot.add_child(count)
		_slots.add_child(slot)
		index += 1
