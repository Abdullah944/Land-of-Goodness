# src/scripts/ui/hud.gd
# Purpose: Clock and money at the top, tools on the left, and the menu button.

extends CanvasLayer

const MARGIN: float = 28.0
const TOOLS: Array[String] = ["", "hoe", "water", "axe", "pick", ""]
const NAMES: Array[String] = ["Hand", "Hoe", "Can", "Axe", "Pick", ""]
const ICONS: Array[String] = [
	"res://assets/ui/Five-finger pixel hand cursor.png",
	"res://assets/tools/16-bit Farm Hoe Icon.png",
	"res://assets/tools/Pixel Art Clay Watering Can.png",
	"res://assets/tools/16-Bit Pixel Art Woodcutting Axe.png",
	"res://assets/tools/Cozy 16-bit pixel pickaxe.png",
	"",
]
const HEART_ICON: String = "res://assets/ui/Terracotta pixel heart icon.png"
const BAG_ICONS: Array[String] = [
	"res://assets/farming/Six Pixel Farm Seeds.png",
	"res://assets/farming/Pixel art turnip inventory icon.png",
	"res://assets/fish/Cozy Gulf Fish Pixel Icon.png",
	"res://assets/nature/Tiny pixel stone chunk.png",
	"res://assets/nature/Pixel art cut wood log.png",
]

var _time: Label
var _gold: Label
var _note: Label
var _bag_icons: Array[TextureRect] = []
var _bag_counts: Array[Label] = []
var _clock_panel: Control
var _toolbar: Control
var _burger: Button
var _menu: Control
var _slots: Array[Button] = []
var _tab: String = "bag"
var _craft: Button
var _zoom_in: Button
var _zoom_out: Button
var _list: Control
var _bar: Control
var _hearts: Array[TextureRect] = []

func _ready() -> void:
	var night: ColorRect = ColorRect.new()
	night.name = "Night"
	night.color = Color(0.05, 0.08, 0.2)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night.visible = false
	add_child(night)
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rain: ColorRect = ColorRect.new()
	rain.name = "Rain"
	rain.color = Color("55afc4")
	rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain.modulate.a = 0.18
	rain.visible = false
	add_child(rain)
	rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_clock()
	_build_hearts()
	_build_tools()
	_build_burger()
	_build_menu()
	_note = _make_label(Vector2(90, 248), Color("fff3dc"))
	_note.size = Vector2(300, 16)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_note)
	refresh()

func blocks_point(screen_position: Vector2) -> bool:
	if _menu.visible:
		return true
	for box: Control in [_clock_panel, _heart_bar, _toolbar, _burger]:
		if box.get_global_rect().has_point(screen_position):
			return true
	return false

func refresh() -> void:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	var clock: GameClock = systems.get_node("Clock") as GameClock
	var inventory: Inventory = systems.get_node("Inventory") as Inventory
	var activities: Activities = systems.get_node("Activities") as Activities
	var shown: String = clock.hour_text()
	if int(Time.get_ticks_msec() / 500) % 2 == 1:
		shown = shown.replace(":", " ")
	_time.text = "%s %d   %s" % [clock.season, clock.day, shown]
	_gold.text = "%d dinars" % inventory.dinars
	if activities.note != "":
		_note.text = activities.note
	elif activities.quest_done:
		_note.text = ""
	else:
		_note.text = "Quest: sell a turnip to Jassim"
	var amounts: Array[int] = [
		inventory.seeds, inventory.turnips, inventory.fish, inventory.stone, inventory.wood,
	]
	for i: int in _bag_counts.size():
		_bag_counts[i].text = str(amounts[i])
		_bag_counts[i].visible = _tab == "bag"
		_bag_icons[i].visible = _tab == "bag"
	_list.visible = _tab == "bag"
	_bar.visible = _tab == "bag"
	_craft.visible = _tab == "bag"
	_zoom_in.visible = _tab == "settings"
	_zoom_out.visible = _tab == "settings"
	for i: int in _slots.size():
		_slots[i].modulate = Color("d9a441") if _player().tool == TOOLS[i] else Color.WHITE
	for i: int in _hearts.size():
		_hearts[i].modulate.a = 1.0 if float(i) < inventory.hearts else 0.35

func _build_clock() -> void:
	var panel: TextureRect = TextureRect.new()
	panel.texture = load("res://assets/ui/Blank pixel-art wooden HUD panel.png")
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.position = Vector2(512.0 - MARGIN - 156.0, 8.0)
	panel.size = Vector2(156, 46)
	add_child(panel)
	_clock_panel = panel
	_time = _make_label(Vector2(10, 4), Color("3f2d27"))
	_gold = _make_label(Vector2(10, 22), Color("7a4f32"))
	panel.add_child(_time)
	panel.add_child(_gold)

var _heart_bar: Control

func _build_hearts() -> void:
	var bar: Control = Control.new()
	bar.position = Vector2(MARGIN, 8.0)
	bar.size = Vector2(78, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Texture2D = _fit_icon(HEART_ICON, 14)
	for i: int in 5:
		var heart: TextureRect = TextureRect.new()
		heart.texture = icon
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_SCALE
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart.position = Vector2(i * 16, 0)
		heart.size = Vector2(14, 14)
		bar.add_child(heart)
		_hearts.append(heart)
	add_child(bar)
	_heart_bar = bar

func _build_tools() -> void:
	var bar: TextureRect = TextureRect.new()
	bar.texture = load("res://assets/ui/Empty six-slot pixel wooden toolbar.png")
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.position = Vector2(MARGIN, 58.0)
	bar.size = Vector2(52, 186)
	add_child(bar)
	_toolbar = bar
	var squares: Array[Rect2] = [
		Rect2(16, 10, 20, 23),
		Rect2(16, 37, 20, 24),
		Rect2(16, 65, 20, 24),
		Rect2(16, 92, 20, 24),
		Rect2(16, 120, 20, 24),
		Rect2(16, 148, 20, 24),
	]
	var normal: StyleBoxFlat = _slot_box(Color(0.1, 0.1, 0.12, 0.55))
	var hover: StyleBoxFlat = _slot_box(Color(0.16, 0.16, 0.18, 0.7))
	var pressed: StyleBoxFlat = _slot_box(Color(0.08, 0.08, 0.1, 0.8))
	for i: int in TOOLS.size():
		var slot: Button = Button.new()
		slot.position = squares[i].position
		slot.size = squares[i].size
		slot.custom_minimum_size = squares[i].size
		slot.clip_text = true
		slot.add_theme_stylebox_override("normal", normal)
		slot.add_theme_stylebox_override("hover", hover)
		slot.add_theme_stylebox_override("pressed", pressed)
		slot.add_theme_stylebox_override("focus", normal)
		slot.add_theme_font_size_override("font_size", 8)
		if ICONS[i] != "":
			slot.icon = _fit_icon(ICONS[i], 18)
			slot.expand_icon = false
		else:
			slot.text = NAMES[i]
		slot.pressed.connect(_pick_tool.bind(i))
		bar.add_child(slot)
		_slots.append(slot)

func _slot_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.shadow_size = 0
	box.set_content_margin_all(0)
	return box

func _build_burger() -> void:
	_burger = Button.new()
	_burger.position = Vector2(512.0 - MARGIN - 32.0, 288.0 - MARGIN - 32.0)
	_burger.size = Vector2(32, 32)
	_burger.custom_minimum_size = Vector2(32, 32)
	_burger.icon = _fit_icon("res://assets/ui/16-bit wooden hamburger menu button.png", 32)
	_burger.expand_icon = true
	_burger.flat = true
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	_burger.add_theme_stylebox_override("normal", empty)
	_burger.add_theme_stylebox_override("hover", empty)
	_burger.add_theme_stylebox_override("pressed", empty)
	_burger.add_theme_stylebox_override("focus", empty)
	_burger.pressed.connect(_toggle_menu)
	add_child(_burger)

func _build_menu() -> void:
	var page: Control = Control.new()
	page.position = Vector2(22, 56)
	page.size = Vector2(468, 212)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.visible = false
	add_child(page)
	_menu = page
	var window: TextureRect = TextureRect.new()
	window.texture = _fit_box("res://assets/ui/menu/Empty wooden inventory window.png", page.size)
	window.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	window.stretch_mode = TextureRect.STRETCH_SCALE
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.size = page.size
	page.add_child(window)
	var inner: Rect2 = Rect2(20, 22, 429, 170)
	var bag_tab: Button = _picture_button("res://assets/ui/tabs/Cozy wooden Bag inventory tab.png", 18)
	var settings_tab: Button = _picture_button("res://assets/ui/tabs/Cozy pixel-game settings tab.png", 18)
	var close_tab: Button = _picture_button("res://assets/ui/tabs/Cozy pixel-art beige Close tab.png", 18)
	bag_tab.position = Vector2(inner.position.x, inner.position.y)
	settings_tab.position = Vector2(bag_tab.position.x + bag_tab.size.x + 6.0, inner.position.y)
	close_tab.position = Vector2(inner.end.x - close_tab.size.x, inner.position.y)
	bag_tab.pressed.connect(_show_tab.bind("bag"))
	settings_tab.pressed.connect(_show_tab.bind("settings"))
	close_tab.pressed.connect(_toggle_menu)
	page.add_child(bag_tab)
	page.add_child(settings_tab)
	page.add_child(close_tab)
	var list: Panel = _nine("res://assets/ui/menu/Empty tall pixel-art list box.png", Vector2(inner.position.x, 48), Vector2(inner.size.x, 108), 11, 2)
	page.add_child(list)
	_list = list
	var row_h: float = 20.0
	var top: float = (list.size.y - row_h * BAG_ICONS.size()) * 0.5
	for i: int in BAG_ICONS.size():
		var slot: Panel = _nine("res://assets/ui/menu/Empty beige inventory slot tile.png", Vector2(10, top + i * row_h), Vector2(18, 18), 15, 2)
		list.add_child(slot)
		var icon: TextureRect = TextureRect.new()
		icon.texture = _fit_icon(BAG_ICONS[i], 14)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(2, 2)
		icon.size = Vector2(14, 14)
		slot.add_child(icon)
		_bag_icons.append(icon)
		var count: Label = _make_label(Vector2(34, top + i * row_h + 1.0), Color("3f2d27"))
		count.size = Vector2(48, 16)
		list.add_child(count)
		_bag_counts.append(count)
	var bar: Panel = _nine("res://assets/ui/menu/Empty Beige Pixel Game Bar.png", Vector2(inner.position.x, 160), Vector2(inner.size.x, 30), 8, 2)
	page.add_child(bar)
	_bar = bar
	var craft: Button = _picture_button("res://assets/ui/tabs/Wooden craft seeds button.png", 22)
	craft.position = Vector2(8, (bar.size.y - craft.size.y) * 0.5)
	craft.pressed.connect(_on_craft)
	bar.add_child(craft)
	_craft = craft
	var zoom_in: Button = _tab_button("Zoom in", Vector2(180, 78))
	var zoom_out: Button = _tab_button("Zoom out", Vector2(180, 110))
	zoom_in.pressed.connect(_zoom.bind(1.15))
	zoom_out.pressed.connect(_zoom.bind(0.87))
	page.add_child(zoom_in)
	page.add_child(zoom_out)
	_zoom_in = zoom_in
	_zoom_out = zoom_out

func _picture_button(path: String, height_px: int) -> Button:
	var button: Button = Button.new()
	var picture: Texture2D = _fit_height(path, height_px)
	button.icon = picture
	button.expand_icon = true
	button.flat = true
	button.custom_minimum_size = picture.get_size()
	button.size = picture.get_size()
	button.focus_mode = Control.FOCUS_NONE
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	return button

func _tab_button(title: String, at: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.position = at
	button.size = Vector2(70, 22)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("3f2d27"))
	button.add_theme_color_override("font_hover_color", Color("3f2d27"))
	button.add_theme_color_override("font_pressed_color", Color("fff3dc"))
	var box: StyleBoxFlat = _slot_box(Color("e7c99a"))
	box.border_color = Color("7a4f32")
	box.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", _slot_box(Color("7a4f32")))
	button.add_theme_stylebox_override("focus", box)
	return button

func _nine(path: String, at: Vector2, size: Vector2, source_border: int, screen_border: int) -> Panel:
	var image: Image = Image.new()
	image.load(path)
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	var factor: float = float(screen_border) / float(source_border)
	image.resize(maxi(screen_border * 2 + 2, int(round(image.get_width() * factor))), maxi(screen_border * 2 + 2, int(round(image.get_height() * factor))), Image.INTERPOLATE_LANCZOS)
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(image)
	box.texture_margin_left = screen_border
	box.texture_margin_top = screen_border
	box.texture_margin_right = screen_border
	box.texture_margin_bottom = screen_border
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override("panel", box)
	panel.position = at
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _fit_box(path: String, size: Vector2) -> Texture2D:
	var image: Image = Image.new()
	image.load(path)
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	image.resize(maxi(1, int(size.x)), maxi(1, int(size.y)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _fit_height(path: String, height_px: int) -> Texture2D:
	var image: Image = Image.new()
	image.load(path)
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	var width: int = maxi(1, int(round(float(image.get_width()) * float(height_px) / float(image.get_height()))))
	image.resize(width, height_px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _pick_tool(index: int) -> void:
	var boy: Player = _player()
	boy.tool = TOOLS[index]
	boy.tool_locked = true
	refresh()

func _toggle_menu() -> void:
	_menu.visible = not _menu.visible
	var boy: Player = _player()
	boy.busy = _menu.visible
	if _menu.visible:
		boy.cancel_tap()
	refresh()

func _show_tab(tab: String) -> void:
	_tab = tab
	refresh()

func _zoom(multiplier: float) -> void:
	_player().change_zoom(multiplier)

func _player() -> Player:
	return get_tree().current_scene.find_child("Player", true, false) as Player

func _fit_icon(path: String, pixels: int) -> Texture2D:
	var image: Image = Image.new()
	image.load(path)
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	var longest: int = maxi(image.get_width(), image.get_height())
	var width: int = maxi(1, int(round(float(image.get_width()) * pixels / float(longest))))
	var height: int = maxi(1, int(round(float(image.get_height()) * pixels / float(longest))))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _make_label(at: Vector2, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _on_craft() -> void:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	var inventory: Inventory = systems.get_node("Inventory") as Inventory
	var activities: Activities = systems.get_node("Activities") as Activities
	if inventory.try_craft_seeds():
		activities.note = "Two stones became three seeds."
		var save: SaveGame = systems.get_node("SaveGame") as SaveGame
		save.write_now()
	else:
		activities.note = "Crafting needs two stones."
	refresh()
