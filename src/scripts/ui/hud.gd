# src/scripts/ui/hud.gd
# Purpose: Clock and money at the top, tools on the left, and the menu button.

extends CanvasLayer

const MARGIN: float = 28.0
const TOOLS: Array[String] = ["", "hoe", "water", "axe", "pick", ""]
const NAMES: Array[String] = ["Hand", "Hoe", "Can", "Axe", "Pick", ""]
const ICONS: Array[String] = [
	"",
	"res://assets/tools/16-bit Farm Hoe Icon.png",
	"res://assets/tools/Pixel Art Clay Watering Can.png",
	"res://assets/tools/16-Bit Pixel Art Woodcutting Axe.png",
	"res://assets/tools/Cozy 16-bit pixel pickaxe.png",
	"",
]
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
	for box: Control in [_clock_panel, _toolbar, _burger]:
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
	_craft.visible = _tab == "bag"
	_zoom_in.visible = _tab == "settings"
	_zoom_out.visible = _tab == "settings"
	for i: int in _slots.size():
		_slots[i].modulate = Color("d9a441") if _player().tool == TOOLS[i] else Color.WHITE

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
	for i: int in TOOLS.size():
		var slot: Button = Button.new()
		slot.position = Vector2(8, 8 + i * 29)
		slot.size = Vector2(36, 26)
		slot.add_theme_font_size_override("font_size", 8)
		if ICONS[i] != "":
			slot.icon = _fit_icon(ICONS[i], 18)
			slot.expand_icon = false
		else:
			slot.text = NAMES[i]
		slot.pressed.connect(_pick_tool.bind(i))
		bar.add_child(slot)
		_slots.append(slot)

func _build_burger() -> void:
	_burger = Button.new()
	_burger.text = "Menu"
	_burger.position = Vector2(512.0 - MARGIN - 52.0, 288.0 - MARGIN - 28.0)
	_burger.size = Vector2(52, 28)
	_burger.add_theme_font_size_override("font_size", 10)
	_burger.pressed.connect(_toggle_menu)
	add_child(_burger)

func _build_menu() -> void:
	var page: TextureRect = TextureRect.new()
	page.texture = load("res://assets/ui/Empty parchment inventory with wood frame.png")
	page.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	page.stretch_mode = TextureRect.STRETCH_SCALE
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.position = Vector2(70, 28)
	page.size = Vector2(360, 220)
	page.visible = false
	add_child(page)
	_menu = page
	var bag_tab: Button = _tab_button("Bag", Vector2(16, 12))
	var settings_tab: Button = _tab_button("Settings", Vector2(78, 12))
	var close_tab: Button = _tab_button("Close", Vector2(280, 12))
	bag_tab.pressed.connect(_show_tab.bind("bag"))
	settings_tab.pressed.connect(_show_tab.bind("settings"))
	close_tab.pressed.connect(_toggle_menu)
	page.add_child(bag_tab)
	page.add_child(settings_tab)
	page.add_child(close_tab)
	for i: int in BAG_ICONS.size():
		var icon: TextureRect = TextureRect.new()
		icon.texture = _fit_icon(BAG_ICONS[i], 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(24, 48 + i * 22)
		icon.size = Vector2(16, 16)
		page.add_child(icon)
		_bag_icons.append(icon)
		var count: Label = _make_label(Vector2(46, 48 + i * 22), Color("3f2d27"))
		page.add_child(count)
		_bag_counts.append(count)
	var craft: Button = Button.new()
	craft.text = "Craft seeds"
	craft.position = Vector2(20, 170)
	craft.size = Vector2(90, 22)
	craft.add_theme_font_size_override("font_size", 10)
	craft.pressed.connect(_on_craft)
	page.add_child(craft)
	_craft = craft
	var zoom_in: Button = _tab_button("Zoom in", Vector2(180, 70))
	var zoom_out: Button = _tab_button("Zoom out", Vector2(180, 102))
	zoom_in.pressed.connect(_zoom.bind(1.15))
	zoom_out.pressed.connect(_zoom.bind(0.87))
	page.add_child(zoom_in)
	page.add_child(zoom_out)
	_zoom_in = zoom_in
	_zoom_out = zoom_out

func _tab_button(title: String, at: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.position = at
	button.size = Vector2(70, 22)
	button.add_theme_font_size_override("font_size", 10)
	return button

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
	return get_tree().current_scene.get_node("Player") as Player

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
