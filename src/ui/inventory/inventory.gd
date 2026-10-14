# File: src/ui/inventory/inventory.gd
# Purpose: open the bag, stack items, and put one into a tool square.

extends Control

const BLOCK := preload("res://assets/UI/inventory/general/normal_block.png")
const CHOSEN := preload("res://assets/UI/inventory/general/choosen_block.png")

@onready var _window: TextureRect = $CanvasLayer/Window
@onready var _slots_row: Control = $CanvasLayer/Window/Slots

var _slots: Array[BagSlot] = []
var _equipped: GameItem

func _ready() -> void:
	_window.visible = false
	$CanvasLayer/BagButton.pressed.connect(_toggle)
	$CanvasLayer/Window/CloseButton.pressed.connect(_close)

func _toggle() -> void:
	_window.visible = not _window.visible
	if not _window.visible:
		_cancel_tool_wait()

func open_bag() -> void:
	_window.visible = true

func _close() -> void:
	_window.visible = false
	_cancel_tool_wait()

func add_item(item: GameItem) -> void:
	for slot in _slots:
		if slot.item.id == item.id:
			slot.count += 1
			_redraw()
			return
	var slot := BagSlot.new()
	slot.item = item
	slot.count = 1
	_slots.append(slot)
	_redraw()

func has_seed_equipped() -> bool:
	return _equipped != null

func equipped_icon() -> Texture2D:
	if _equipped == null:
		return null
	return _equipped.icon

func equipped_item() -> GameItem:
	return _equipped

func equip_item(item: GameItem) -> void:
	_equipped = item
	_redraw.call_deferred()

func clear_equipped() -> void:
	_equipped = null
	_redraw.call_deferred()

func _equip(item: GameItem) -> void:
	var tools := get_tree().get_first_node_in_group("tool_bar")
	if tools != null and tools.is_waiting():
		tools.give_item(item)
		_equipped = item
		_close()
		_redraw.call_deferred()
		return
	if _equipped == item:
		_equipped = null
		if tools != null:
			tools.clear_last_if(item)
	else:
		_equipped = item
		if tools != null:
			tools.put_in_last(item)
		_close()
	_redraw.call_deferred()

func _cancel_tool_wait() -> void:
	var tools := get_tree().get_first_node_in_group("tool_bar")
	if tools != null:
		tools.cancel_wait()

func _redraw() -> void:
	for child in _slots_row.get_children():
		child.free()
	var index := 0
	for slot in _slots:
		var button := TextureButton.new()
		button.texture_normal = CHOSEN if slot.item == _equipped else BLOCK
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.position = Vector2(index * 136, 0)
		button.size = Vector2(120, 120)
		button.pressed.connect(_equip.bind(slot.item))
		var icon := TextureRect.new()
		icon.texture = slot.item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(18, 18)
		icon.size = Vector2(84, 84)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var count := Label.new()
		count.text = str(slot.count)
		count.position = Vector2(78, 82)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_color_override("font_color", Color("7A4F32"))
		button.add_child(count)
		_slots_row.add_child(button)
		index += 1

class BagSlot:
	var item: GameItem
	var count: int