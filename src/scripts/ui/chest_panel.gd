# src/scripts/ui/chest_panel.gd
# Purpose: Shows bag and chest counts and moves one item at a time.

class_name ChestPanel
extends CanvasLayer

const WINDOW_SIZE: Vector2 = Vector2(468, 260)
const ROW_H: float = 34.0
const ICON_X: float = 4.0
const NAME_X: float = 30.0
const NAME_W: float = 128.0
const BAG_X: float = 166.0
const BAG_W: float = 44.0
const CHEST_X: float = 216.0
const CHEST_W: float = 48.0
const STORE_X: float = 272.0
const TAKE_X: float = 346.0
const BUTTON_SIZE: Vector2 = Vector2(68, 26)

var _page: Control
var _scroll: ScrollContainer
var _rows: Array[Dictionary] = []
var _press: Vector2 = Vector2.ZERO
var _scroll_at_press: int = 0
var _holding: bool = false
var _moved: bool = false
var _open: bool = false

func _ready() -> void:
	_page = Control.new()
	_page.visible = false
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_page)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.08, 0.2, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.add_child(shade)
	var window: TextureRect = TextureRect.new()
	window.name = "Window"
	window.texture = _cropped_window()
	window.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	window.stretch_mode = TextureRect.STRETCH_SCALE
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.size = WINDOW_SIZE
	_page.add_child(window)
	var content: Control = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = WINDOW_SIZE - Vector2(56, 78)
	_page.add_child(content)
	var title: Label = _label("Chest", Vector2(0, 0), Vector2(160, 22))
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 14)
	content.add_child(title)
	var close: Button = _close_button()
	close.name = "Close"
	close.position = Vector2(content.size.x - close.size.x, 0)
	close.pressed.connect(close_panel)
	content.add_child(close)
	var bag_header: Label = _label("Bag", Vector2(BAG_X, 24), Vector2(BAG_W, 16))
	bag_header.name = "BagHeader"
	bag_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(bag_header)
	var chest_header: Label = _label("Chest", Vector2(CHEST_X, 24), Vector2(CHEST_W, 16))
	chest_header.name = "ChestHeader"
	chest_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(chest_header)
	_scroll = ScrollContainer.new()
	_scroll.name = "List"
	_scroll.position = Vector2(0, 42)
	_scroll.size = Vector2(content.size.x, floor((content.size.y - 46.0) / ROW_H) * ROW_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(_scroll)
	var body: Control = Control.new()
	body.custom_minimum_size = Vector2(content.size.x, ROW_H * Inventory.all_stored_ids().size())
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.gui_input.connect(_on_drag)
	_scroll.add_child(body)
	var stored_ids: PackedStringArray = Inventory.all_stored_ids()
	for i: int in stored_ids.size():
		_add_row(body, stored_ids[i], i)
	_fit_screen()
	get_viewport().size_changed.connect(_fit_screen)

func _fit_screen() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var at: Vector2 = Vector2((view.x - WINDOW_SIZE.x) * 0.5, (view.y - WINDOW_SIZE.y) * 0.5)
	(_page.get_node("Window") as Control).position = at
	(_page.get_node("Content") as Control).position = at + Vector2(28, 32)

## The language may have changed since the panel was built.
func _name_labels() -> void:
	var content: Node = _page.get_node("Content")
	var title_keys: Dictionary = {"Title": "chest", "BagHeader": "bag", "ChestHeader": "chest"}
	for label_name: String in title_keys:
		var label: Label = content.get_node(label_name) as Label
		label.text = Locale.t(title_keys[label_name])
		Locale.apply_control(label)
	var close: Button = content.get_node("Close") as Button
	close.text = Locale.t("tab_close")
	Locale.apply_control(close)
	for row: Dictionary in _rows:
		if row.has("name"):
			(row["name"] as Label).text = Locale.item(str(row["item"]))
		for action: String in ["store", "take"]:
			var title: Label = (row[action] as Node).get_child(0) as Label
			title.text = Locale.t(action + "_one")
			Locale.apply_control(title)

func is_open() -> bool:
	return _open

func open_panel() -> void:
	if _open:
		return
	var hud: Node = get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("dismiss_menu"):
		hud.call("dismiss_menu")
	if hud != null and hud.has_method("set_world_chrome"):
		hud.call("set_world_chrome", false)
	var player: Player = _player()
	if player != null:
		player.busy = true
		player.cancel_tap()
	_open = true
	_page.visible = true
	_name_labels()
	_refresh()

func close_panel() -> void:
	if not _open:
		return
	_open = false
	_holding = false
	_page.visible = false
	var hud: Node = get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("set_world_chrome"):
		hud.call("set_world_chrome", true)
	var player: Player = _player()
	if player != null:
		player.busy = false

func _add_row(body: Control, item_id: String, index: int) -> void:
	var y: float = index * ROW_H
	var slot: TextureRect = TextureRect.new()
	slot.texture = _icon(item_id)
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = Vector2(ICON_X, y + (ROW_H - 20.0) * 0.5)
	slot.size = Vector2(20, 20)
	body.add_child(slot)
	var name: Label = _label(_item_name(item_id), Vector2(NAME_X, y), Vector2(NAME_W, ROW_H))
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.clip_text = true
	body.add_child(name)
	var bag_count: Label = _label("0", Vector2(BAG_X, y), Vector2(BAG_W, ROW_H))
	bag_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bag_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(bag_count)
	var chest_count: Label = _label("0", Vector2(CHEST_X, y), Vector2(CHEST_W, ROW_H))
	chest_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chest_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(chest_count)
	var store: Control = _action_button("Store 1", Vector2(STORE_X, y + (ROW_H - BUTTON_SIZE.y) * 0.5))
	body.add_child(store)
	var take: Control = _action_button("Take 1", Vector2(TAKE_X, y + (ROW_H - BUTTON_SIZE.y) * 0.5))
	body.add_child(take)
	_rows.append({
		"item": item_id,
		"bag": bag_count,
		"chest": chest_count,
		"store": store,
		"take": take,
	})

func _on_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_press = click.global_position
			_scroll_at_press = _scroll.scroll_vertical
			_holding = true
			_moved = false
		else:
			if _holding and not _moved:
				_tap_row(click.position)
			_holding = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _holding:
		var motion: InputEventMouseMotion = event
		var delta: Vector2 = motion.global_position - _press
		if absf(delta.y) > 8.0 or absf(delta.x) > 8.0:
			_moved = true
		if _moved:
			_scroll.scroll_vertical = _scroll_at_press - int(delta.y)
		get_viewport().set_input_as_handled()

func _tap_row(local_position: Vector2) -> void:
	var index: int = int(local_position.y / ROW_H)
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	var store: Control = row["store"]
	var take: Control = row["take"]
	if Rect2(store.position, store.size).has_point(local_position):
		_move(str(row["item"]), true)
	elif Rect2(take.position, take.size).has_point(local_position):
		_move(str(row["item"]), false)

func _move(item_id: String, into_chest: bool) -> void:
	var bag: Inventory = _bag()
	var chest: ChestStore = _chest()
	if bag == null or chest == null:
		return
	var moved: bool = chest.store_one(bag, item_id) if into_chest else chest.take_one(bag, item_id)
	if not moved:
		_refresh()
		return
	var save: SaveGame = get_tree().current_scene.get_node("Systems/SaveGame") as SaveGame
	save.write_now()
	var hud: Node = get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("refresh"):
		hud.call("refresh")
	_refresh()

func _refresh() -> void:
	var bag: Inventory = _bag()
	var chest: ChestStore = _chest()
	if bag == null or chest == null:
		return
	for row: Dictionary in _rows:
		var item_id: String = str(row["item"])
		var bag_count: int = bag.count_of(item_id)
		var chest_count: int = chest.count_of(item_id)
		var bag_label: Label = row["bag"]
		var chest_label: Label = row["chest"]
		bag_label.text = str(bag_count)
		chest_label.text = str(chest_count)
		var store: CanvasItem = row["store"]
		var take: CanvasItem = row["take"]
		store.modulate.a = 1.0 if bag_count > 0 else 0.35
		take.modulate.a = 1.0 if chest_count > 0 else 0.35

func _action_button(title: String, at: Vector2) -> Control:
	var button: Panel = Panel.new()
	button.position = at
	button.size = BUTTON_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("e7c99a")
	box.border_color = Color("7a4f32")
	box.set_border_width_all(1)
	button.add_theme_stylebox_override("panel", box)
	var label: Label = _label(title, Vector2.ZERO, BUTTON_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	button.add_child(label)
	return button

func _cropped_window() -> Texture2D:
	var image: Image = (load("res://assets/ui/menu/Empty wooden inventory window.png") as Texture2D).get_image()
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	return ImageTexture.create_from_image(image)

func _close_button() -> Button:
	var button: Button = Button.new()
	button.size = Vector2(70, 22)
	button.custom_minimum_size = Vector2(70, 22)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	UiStyle.button(button)
	return button

func _label(text: String, at: Vector2, size: Vector2) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("3f2d27"))
	return label

func _item_name(item_id: String) -> String:
	return Locale.item(item_id)

func _icon(item_id: String) -> Texture2D:
	var extra_icon: String = GoodsCatalog.icon_path(item_id)
	if extra_icon != "":
		return _fit_icon(extra_icon)
	match item_id:
		"seeds":
			return _fit_icon("res://assets/farming/Six Pixel Farm Seeds.png")
		"turnips":
			return _fit_icon("res://assets/farming/Pixel art turnip inventory icon.png")
		"fish":
			return _fit_icon("res://assets/fish/Cozy Gulf Fish Pixel Icon.png")
		"stone":
			return _fit_icon("res://assets/nature/Tiny pixel stone chunk.png")
		"wood":
			return _fit_icon("res://assets/nature/Pixel art cut wood log.png")
		"dates":
			return _fit_icon("res://assets/farming/Date inventory icon.png")
		"forage":
			return _fit_icon("res://assets/farming/Wild herb inventory icon.png")
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		var sprites: Array = crop.get("sprites", [])
		if sprites.is_empty():
			continue
		var seed: bool = str(crop.get("seed_item", "")) == item_id
		var harvest: bool = str(crop.get("harvest_item", "")) == item_id
		if not seed and not harvest:
			continue
		var rect: Rect2 = sprites[0] if seed else sprites[sprites.size() - 1]
		var texture: Texture2D = crop["texture"]
		var image: Image = texture.get_image().get_region(Rect2i(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)))
		image.resize(16, 16, Image.INTERPOLATE_NEAREST)
		return ImageTexture.create_from_image(image)
	return _fit_icon("res://assets/farming/Six Pixel Farm Seeds.png")

func _fit_icon(path: String) -> Texture2D:
	var image: Image = (load(path) as Texture2D).get_image()
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	var longest: int = maxi(image.get_width(), image.get_height())
	var width: int = maxi(1, int(round(float(image.get_width()) * 16.0 / float(longest))))
	var height: int = maxi(1, int(round(float(image.get_height()) * 16.0 / float(longest))))
	image.resize(width, height, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

func _bag() -> Inventory:
	return get_tree().current_scene.get_node("Systems/Inventory") as Inventory

func _chest() -> ChestStore:
	return get_tree().current_scene.get_node("Systems/ChestStore") as ChestStore

func _player() -> Player:
	return get_tree().current_scene.find_child("Player", true, false) as Player
