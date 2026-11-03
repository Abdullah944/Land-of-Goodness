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
const KHAIR_W: float = 78.0

var _time: Label
var _gold: Label
var _note: Label
var _bag_rows: Array[Dictionary] = []
var _clock_panel: Control
var _toolbar: Control
var _burger: Button
var _menu: Control
var _slots: Array[Button] = []
var _tab: String = "bag"
var _craft: Button
var _bag_money: Label
var _zoom_in: Button
var _language: Button
var _sound: Button
var _journal_tab: Button
var _journal: Label
var _journal2: Label
var _zoom_out: Button
var _list: Control
var _bag_scroll: ScrollContainer
var _bag_row_h: float = 24.0
var _bag_press: Vector2
var _bag_scroll_at_press: int = 0
var _bag_holding: bool = false
var _bag_moved: bool = false
var _bar: Control
var _hearts: Array[TextureRect] = []
var _sleep_dark: ColorRect
var _sale_panel: Control
var _sale_item: Label
var _sale_earned: Label
var _sale_left: Label
var _sale_balance: Label
var _sale_token: int = 0
var _sale_titles: Array[Label] = []
var _music_button: Button
var _help_button: Button
var _eat: Button
var _tab_keys: Dictionary = {}
var _world_map: WorldMap

func _ready() -> void:
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
	_note.add_theme_constant_override("outline_size", 4)
	_note.add_theme_color_override("font_outline_color", Color("3f2d27"))
	_note.add_theme_font_size_override("font_size", 11)
	add_child(_note)
	_sleep_dark = ColorRect.new()
	_sleep_dark.name = "SleepDark"
	_sleep_dark.color = Color(0.05, 0.08, 0.2)
	_sleep_dark.mouse_filter = Control.MOUSE_FILTER_STOP
	_sleep_dark.visible = false
	add_child(_sleep_dark)
	_sleep_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_sale()
	_fit_screen()
	get_viewport().size_changed.connect(_fit_screen)
	refresh()

## Pins each panel to its screen edge, so wide phones fill the screen and the notch stays clear.
func _fit_screen() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var side: float = _side_margin(view)
	_heart_bar.position.x = side
	_toolbar.position.x = side
	_clock_panel.position.x = view.x - side - _clock_panel.size.x
	_burger.position = Vector2(view.x - side - _burger.size.x, view.y - MARGIN - _burger.size.y)
	_menu.position = Vector2((view.x - _menu.size.x) * 0.5, (view.y - _menu.size.y) * 0.5 + 18.0)
	_note.position = Vector2((view.x - _note.size.x) * 0.5, view.y - 40.0)
	_sale_panel.position = (view - _sale_panel.size) * 0.5

func _side_margin(view: Vector2) -> float:
	if not OS.has_feature("mobile"):
		return MARGIN
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window.x <= 0.0 or safe.size.x <= 0:
		return MARGIN
	var inset: float = maxf(float(safe.position.x), window.x - float(safe.end.x))
	return maxf(MARGIN, ceil(inset * view.x / window.x))

func cover_for_sleep() -> void:
	_sleep_dark.visible = true
	_sleep_dark.move_to_front()

func uncover_sleep() -> void:
	_sleep_dark.visible = false

func show_sale(item: String, quantity: int, earned: int, remaining: int, balance: int) -> void:
	_sale_token += 1
	var token: int = _sale_token
	_sale_item.text = "%s  × %d" % [item, quantity]
	_sale_earned.text = Locale.t("dinars") % earned
	_sale_left.text = "%d %s" % [remaining, item]
	_sale_balance.text = Locale.t("dinars") % balance
	for row: int in _sale_titles.size():
		_sale_titles[row].text = Locale.t(["sale_sold", "sale_earned", "sale_left", "sale_balance"][row])
		Locale.apply_control(_sale_titles[row])
	_sale_panel.visible = true
	_sale_panel.move_to_front()
	await get_tree().create_timer(3.0).timeout
	if token != _sale_token:
		return
	_sale_panel.visible = false

func dismiss_sale() -> void:
	_sale_token += 1
	if _sale_panel != null:
		_sale_panel.visible = false

func dismiss_menu() -> void:
	if _menu != null and _menu.visible:
		_menu.visible = false
		var clock: Node = get_tree().current_scene.get_node_or_null("Systems/Clock")
		if clock != null:
			clock.set_process(true)

func set_world_chrome(shown: bool) -> void:
	for box: CanvasItem in [_clock_panel, _heart_bar, _toolbar, _burger, _note]:
		if box != null:
			box.visible = shown

func blocks_point(screen_position: Vector2) -> bool:
	var chest: Node = get_parent().get_node_or_null("ChestPanel")
	if chest != null and chest.has_method("is_open") and bool(chest.call("is_open")):
		return true
	var title: Node = get_parent().get_node_or_null("TitleMenu")
	if title != null and title.has_method("is_open") and bool(title.call("is_open")):
		return true
	if _menu.visible:
		return true
	if _sale_panel != null and _sale_panel.visible and _sale_panel.get_global_rect().has_point(screen_position):
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
	if int(float(Time.get_ticks_msec()) / 500.0) % 2 == 1:
		shown = shown.replace(":", " ")
	_time.text = "%s %d   %s" % [Locale.t(clock.season), clock.day, shown]
	_gold.text = Locale.t("dinars") % inventory.dinars
	if _bag_money != null:
		_bag_money.text = Locale.t("dinars") % inventory.dinars
	var stead: Stead = systems.get_node_or_null("Stead") as Stead
	if activities.display_note() != "":
		_note.text = activities.display_note()
	elif stead != null:
		_note.text = stead.goal_text()
	elif activities.quest_done:
		_note.text = ""
	else:
		_note.text = Locale.t("quest_turnip")
	Locale.apply_control(_note)
	for row: Dictionary in _bag_rows:
		var count_label: Label = row["count"]
		count_label.text = str(inventory.count_of(str(row["item"])))
		if row.has("name"):
			var name_label: Label = row["name"]
			name_label.text = Locale.item(str(row["item"]))
		count_label.visible = _tab == "bag"
		var slot: CanvasItem = row["slot"]
		var chosen: bool = str(row["kind"]) == "seed" and str(row["crop_id"]) == inventory.selected_seed
		slot.modulate = Color("d9a441") if chosen else Color.WHITE
	_list.visible = _tab == "bag"
	_bar.visible = _tab == "bag"
	_craft.visible = _tab == "bag"
	_world_map.visible = _tab == "map"
	_eat.visible = _tab == "bag"
	_eat.size = Vector2(60, 24)
	_eat.text = Locale.t("eat")
	Locale.apply_control(_eat)
	_refresh_settings(stead)
	for tab: Button in _tab_keys:
		tab.text = Locale.t(_tab_keys[tab])
		Locale.apply_control(tab)
	_craft.text = Locale.t("craft_seeds")
	Locale.apply_control(_craft)
	if _journal != null:
		_journal.visible = _tab == "quests"
		_journal2.visible = _tab == "quests"
		if _journal.visible:
			var lines: PackedStringArray = _journal_text(stead).split("\n")
			var half: int = int(ceil(lines.size() / 2.0))
			_journal.text = "\n".join(lines.slice(0, half))
			_journal2.text = "\n".join(lines.slice(half))
			Locale.apply_control(_journal)
			Locale.apply_control(_journal2)
	for i: int in _slots.size():
		_slots[i].modulate = Color("d9a441") if _player().tool == TOOLS[i] else Color.WHITE
	for i: int in _hearts.size():
		_hearts[i].visible = float(i) < inventory.max_hearts
		_hearts[i].modulate.a = clampf(inventory.hearts - float(i), 0.3, 1.0)
	var kindness: Kindness = systems.get_node_or_null("Kindness") as Kindness
	if kindness != null:
		_khair_fill.size.x = (KHAIR_W - 2.0) * float(kindness.points) / float(Kindness.MAX_POINTS)
		_khair_label.text = "%s  %d" % [Locale.t("khair"), kindness.points]
		Locale.apply_control(_khair_label)

func _refresh_settings(stead: Stead) -> void:
	var labels: Dictionary = {_zoom_in: Locale.t("zoom_in"), _zoom_out: Locale.t("zoom_out"), _language: Locale.t("language"), _help_button: Locale.t("help_button")}
	if stead != null:
		labels[_music_button] = Locale.t("music") % Locale.t("level_%d" % stead.music_level)
		labels[_sound] = Locale.t("effects") % Locale.t("level_%d" % stead.sfx_level)
	for button: Button in labels:
		button.visible = _tab == "settings"
		button.text = labels[button]
		Locale.apply_control(button)

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
	_gold = _make_label(Vector2(10, 22), Color("3f2d27"))
	panel.add_child(_time)
	panel.add_child(_gold)

var _heart_bar: Control
var _khair_fill: ColorRect
var _khair_label: Label

func _build_hearts() -> void:
	var bar: Control = Control.new()
	bar.position = Vector2(MARGIN, 8.0)
	bar.size = Vector2(78, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Texture2D = _fit_icon(HEART_ICON, 14)
	for i: int in 7:
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
	_build_khair(bar)

func _build_khair(bar: Control) -> void:
	bar.size.y = 40.0
	var track: ColorRect = ColorRect.new()
	track.color = Color("3f2d27")
	track.position = Vector2(0, 17)
	track.size = Vector2(KHAIR_W, 6)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(track)
	_khair_fill = ColorRect.new()
	_khair_fill.color = Color("d9a441")
	_khair_fill.position = Vector2(1, 1)
	_khair_fill.size = Vector2(0, 4)
	_khair_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_khair_fill)
	_khair_label = _make_label(Vector2(0, 24), Color("fff3dc"))
	_khair_label.size = Vector2(KHAIR_W, 14)
	_khair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_khair_label.add_theme_font_size_override("font_size", 9)
	_khair_label.add_theme_constant_override("outline_size", 3)
	_khair_label.add_theme_color_override("font_outline_color", Color("3f2d27"))
	bar.add_child(_khair_label)

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
	var bag_tab: Button = _tab_button("", Vector2(inner.position.x, inner.position.y))
	var settings_tab: Button = _tab_button("", Vector2(inner.position.x + 84.0, inner.position.y))
	var journal_tab: Button = _tab_button("", Vector2(inner.position.x + 168.0, inner.position.y))
	var map_tab: Button = _tab_button("", Vector2(inner.position.x + 252.0, inner.position.y))
	map_tab.pressed.connect(_show_tab.bind("map"))
	var close_tab: Button = _tab_button("", Vector2(inner.end.x - 78.0, inner.position.y))
	bag_tab.pressed.connect(_show_tab.bind("bag"))
	settings_tab.pressed.connect(_show_tab.bind("settings"))
	journal_tab.pressed.connect(_show_tab.bind("quests"))
	close_tab.pressed.connect(_toggle_menu)
	_tab_keys = {bag_tab: "tab_bag", settings_tab: "tab_settings", journal_tab: "journal", map_tab: "tab_map", close_tab: "tab_close"}
	_world_map = WorldMap.new()
	_world_map.position = Vector2(inner.position.x, 48)
	_world_map.size = Vector2(inner.size.x, 142)
	_world_map.visible = false
	page.add_child(_world_map)
	for tab: Button in _tab_keys:
		tab.size = Vector2(78, 24)
		tab.focus_mode = Control.FOCUS_NONE
		page.add_child(tab)
	_journal_tab = journal_tab
	var column_w: float = (inner.size.x - 30.0) * 0.5
	_journal = _make_label(Vector2(inner.position.x + 10.0, 52), Color("3f2d27"))
	_journal2 = _make_label(Vector2(inner.position.x + 20.0 + column_w, 52), Color("3f2d27"))
	for column: Label in [_journal, _journal2]:
		column.size = Vector2(column_w, 104)
		column.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_theme_font_size_override("font_size", 11)
		column.add_theme_constant_override("line_spacing", -4)
		column.visible = false
		page.add_child(column)
	var list: Panel = _nine("res://assets/ui/menu/Empty tall pixel-art list box.png", Vector2(inner.position.x, 48), Vector2(inner.size.x, 108), 11, 2)
	page.add_child(list)
	_list = list
	_build_bag_rows(list)
	var bar: Panel = _nine("res://assets/ui/menu/Empty Beige Pixel Game Bar.png", Vector2(inner.position.x, 160), Vector2(inner.size.x, 30), 8, 2)
	page.add_child(bar)
	_bar = bar
	var craft: Button = _tab_button("", Vector2(6, 3))
	craft.size = Vector2(96, 24)
	craft.focus_mode = Control.FOCUS_NONE
	craft.pressed.connect(_on_craft)
	bar.add_child(craft)
	_craft = craft
	_bag_money = _make_label(Vector2(180, 0), Color("3f2d27"))
	_bag_money.size = Vector2(bar.size.x - 192, bar.size.y)
	_bag_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bag_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bag_money.add_theme_font_size_override("font_size", 12)
	bar.add_child(_bag_money)
	_zoom_in = _settings_button(0, 0, _zoom.bind(1.15))
	_zoom_out = _settings_button(1, 0, _zoom.bind(0.87))
	_music_button = _settings_button(0, 1, _cycle_music)
	_sound = _settings_button(1, 1, _toggle_sound)
	_language = _settings_button(0, 2, _toggle_language)
	_help_button = _settings_button(1, 2, _show_help)
	_eat = _tab_button(Locale.t("eat"), Vector2(108, 3))
	_eat.size = Vector2(60, 24)
	_eat.focus_mode = Control.FOCUS_NONE
	_eat.pressed.connect(_on_eat)
	bar.add_child(_eat)

func _settings_button(column: int, row: int, action: Callable) -> Button:
	var button: Button = _tab_button("", Vector2(84.0 + column * 156.0, 60.0 + row * 40.0))
	button.size = Vector2(144, 32)
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	_menu.add_child(button)
	return button

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
	var image: Image = _open_image(path)
	var used: Rect2i = _solid_bounds(image)
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

func _solid_bounds(image: Image) -> Rect2i:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var left: int = 0
	while left < width and not _edge_solid(image, left, true):
		left += 1
	var right: int = width - 1
	while right > left and not _edge_solid(image, right, true):
		right -= 1
	var top: int = 0
	while top < height and not _edge_solid(image, top, false):
		top += 1
	var bottom: int = height - 1
	while bottom > top and not _edge_solid(image, bottom, false):
		bottom -= 1
	if right <= left or bottom <= top:
		return image.get_used_rect()
	return Rect2i(left, top, right - left + 1, bottom - top + 1)

func _edge_solid(image: Image, at: int, vertical: bool) -> bool:
	var count: int = 0
	var limit: int = image.get_height() if vertical else image.get_width()
	var i: int = 0
	while i < limit:
		var color: Color = image.get_pixel(at, i) if vertical else image.get_pixel(i, at)
		if color.a > 0.4:
			count += 1
			if count >= 8:
				return true
		i += 4
	return false

func _fit_box(path: String, size: Vector2) -> Texture2D:
	var image: Image = _open_image(path)
	var used: Rect2i = image.get_used_rect()
	if used.size != Vector2i.ZERO:
		image = image.get_region(used)
	image.resize(maxi(1, int(size.x)), maxi(1, int(size.y)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _fit_height(path: String, height_px: int) -> Texture2D:
	var image: Image = _open_image(path)
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
	var clock: Node = get_tree().current_scene.get_node_or_null("Systems/Clock")
	if clock != null:
		clock.set_process(not _menu.visible)
	refresh()

func _show_tab(tab: String) -> void:
	_tab = tab
	refresh()

func _journal_text(stead: Stead) -> String:
	if stead == null:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	var works: VillageWorks = get_tree().current_scene.get_node_or_null("Systems/VillageWorks") as VillageWorks
	if stead.is_established() and works != null:
		lines.append(Locale.t("journal_works"))
		for project: Dictionary in VillageWorks.PROJECTS:
			lines.append("%s %s" % ["[x]" if works.is_done(str(project["id"])) else "[  ]", Locale.t(str(project["id"]))])
	else:
		for step: Dictionary in stead.steps():
			var mark: String = "[x]" if bool(step["done"]) else "[  ]"
			lines.append("%s %s" % [mark, Locale.t(str(step["key"])).trim_prefix("Quest: ").trim_prefix("المهمة: ")])
	if works != null:
		var wish: Dictionary = works.request_today()
		if not bool(wish.get("done", false)):
			var who: String = str(wish.get("person", ""))
			lines.append(Locale.t("journal_request") % [Locale.t(who if who == "jassim" else who + "_name"), int(wish.get("amount", 0)), Locale.item(str(wish.get("item", "")))])
	var kindness: Kindness = get_tree().current_scene.get_node_or_null("Systems/Kindness") as Kindness
	if kindness != null:
		lines.append(Locale.t("khair_line") % [kindness.points, Kindness.MAX_POINTS])
	return "\n".join(lines)

func _toggle_language() -> void:
	var stead: Stead = get_tree().current_scene.get_node_or_null("Systems/Stead") as Stead
	if stead == null:
		return
	stead.language = "en" if stead.language == "ar" else "ar"
	Locale.language = stead.language
	var save: SaveGame = get_tree().current_scene.get_node_or_null("Systems/SaveGame") as SaveGame
	if save != null:
		save.write_now()
	refresh()

func _show_help() -> void:
	_toggle_menu()
	var lines: PackedStringArray = PackedStringArray()
	for key: String in ["help_clear", "help_farm", "help_rest", "help_zones", "help_world", "help_khair"]:
		lines.append(Locale.t(key))
	(get_tree().current_scene.get_node("UI/Dialogue") as DialogueBox).open_lines(lines)

func _on_eat() -> void:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	var inventory: Inventory = systems.get_node("Inventory") as Inventory
	var activities: Activities = systems.get_node("Activities") as Activities
	var eaten: String = inventory.eat_something()
	if eaten == "":
		activities.flash(Locale.t("nothing_to_eat"))
		return
	activities.flash(Locale.t("ate") % Locale.item(eaten))
	(systems.get_node("SoundBank") as SoundBank).play("gather")
	(systems.get_node("SaveGame") as SaveGame).write_now()
	refresh()

func _cycle_music() -> void:
	var stead: Stead = get_tree().current_scene.get_node_or_null("Systems/Stead") as Stead
	if stead == null:
		return
	stead.music_level = (stead.music_level + 2) % 3
	(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).apply_levels()
	(get_tree().current_scene.get_node("Systems/SaveGame") as SaveGame).write_now()
	refresh()

func _toggle_sound() -> void:
	var stead: Stead = get_tree().current_scene.get_node_or_null("Systems/Stead") as Stead
	if stead == null:
		return
	stead.sfx_level = (stead.sfx_level + 2) % 3
	(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).play("ui")
	refresh()
	var save: SaveGame = get_tree().current_scene.get_node_or_null("Systems/SaveGame") as SaveGame
	if save != null:
		save.write_now()

func _zoom(multiplier: float) -> void:
	_player().change_zoom(multiplier)

func _player() -> Player:
	return get_tree().current_scene.find_child("Player", true, false) as Player

func _fit_icon(path: String, pixels: int) -> Texture2D:
	return UiStyle.fit_picture(load(path) as Texture2D, pixels)

func _open_image(path: String) -> Image:
	var texture: Texture2D = load(path) as Texture2D
	return texture.get_image()

func _make_label(at: Vector2, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_sale() -> void:
	var panel: TextureRect = TextureRect.new()
	panel.name = "SaleReceipt"
	var wood: Image = _open_image("res://assets/ui/Blank pixel-art wooden HUD panel.png")
	wood = wood.get_region(_solid_bounds(wood))
	panel.texture = ImageTexture.create_from_image(wood)
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.position = Vector2(120, 78)
	panel.size = Vector2(272, 124)
	panel.visible = false
	add_child(panel)
	_sale_panel = panel
	var hit: Button = Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.size = panel.size
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.add_theme_stylebox_override("focus", empty)
	hit.pressed.connect(dismiss_sale)
	panel.add_child(hit)
	for i: int in 4:
		var title: Label = _make_label(Vector2(18, 22 + i * 22), Color("7a4f32"))
		_sale_titles.append(title)
		title.size = Vector2(70, 16)
		title.add_theme_font_size_override("font_size", 12)
		panel.add_child(title)
	_sale_item = _sale_value(0)
	_sale_earned = _sale_value(1)
	_sale_left = _sale_value(2)
	_sale_balance = _sale_value(3)

func _sale_value(row: int) -> Label:
	var label: Label = _make_label(Vector2(96, 22 + row * 22), Color("3f2d27"))
	label.size = Vector2(156, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 12)
	_sale_panel.add_child(label)
	return label

func _build_bag_rows(list: Panel) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(6, 4)
	scroll.size = Vector2(list.size.x - 12, list.size.y - 8)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	list.add_child(scroll)
	_bag_scroll = scroll
	var specs: Array[Dictionary] = []
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		specs.append({
			"kind": "seed",
			"crop_id": crop_id,
			"item": str(crop["seed_item"]),
			"label": str(crop["seed_name"]),
		})
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		specs.append({
			"kind": "harvest",
			"crop_id": crop_id,
			"item": str(crop["harvest_item"]),
			"label": str(crop["name"]),
		})
	specs.append({"kind": "item", "crop_id": "", "item": "fish", "label": "Fish", "icon": "res://assets/fish/Cozy Gulf Fish Pixel Icon.png"})
	specs.append({"kind": "item", "crop_id": "", "item": "stone", "label": "Stone", "icon": "res://assets/nature/Tiny pixel stone chunk.png"})
	specs.append({"kind": "item", "crop_id": "", "item": "wood", "label": "Wood", "icon": "res://assets/nature/Pixel art cut wood log.png"})
	specs.append({"kind": "item", "crop_id": "", "item": "dates", "label": "Date", "icon": "res://assets/farming/Date inventory icon.png"})
	specs.append({"kind": "item", "crop_id": "", "item": "forage", "label": "Herb", "icon": "res://assets/farming/Wild herb inventory icon.png"})
	for extra_id: String in GoodsCatalog.extra_ids():
		specs.append({
			"kind": "item",
			"crop_id": "",
			"item": extra_id,
			"label": Locale.item(extra_id),
			"icon": GoodsCatalog.icon_path(extra_id),
		})
	var row_h: float = 24.0
	_bag_row_h = row_h
	var qty_w: float = 48.0
	scroll.size.y = floor((list.size.y - 8.0) / row_h) * row_h
	var body: Control = Control.new()
	body.custom_minimum_size = Vector2(scroll.size.x - 4.0, row_h * specs.size())
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.gui_input.connect(_on_bag_drag)
	scroll.add_child(body)
	for i: int in specs.size():
		var spec: Dictionary = specs[i]
		var button: Button = Button.new()
		button.position = Vector2(0, i * row_h)
		button.size = Vector2(body.custom_minimum_size.x, row_h)
		button.focus_mode = Control.FOCUS_NONE
		button.flat = true
		button.clip_contents = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty)
		button.add_theme_stylebox_override("hover", empty)
		button.add_theme_stylebox_override("pressed", empty)
		button.add_theme_stylebox_override("focus", empty)
		if str(spec["kind"]) == "seed":
			button.pressed.connect(_select_seed.bind(str(spec["crop_id"])))
		body.add_child(button)
		var slot: Panel = _nine("res://assets/ui/menu/Empty beige inventory slot tile.png", Vector2(2, 2), Vector2(20, 20), 15, 2)
		button.add_child(slot)
		var icon: TextureRect = TextureRect.new()
		icon.texture = _bag_icon(spec)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(1, 1)
		icon.size = Vector2(18, 18)
		slot.add_child(icon)
		var name: Label = _make_label(Vector2(28, 0), Color("3f2d27"))
		name.text = Locale.item(str(spec["item"]))
		name.size = Vector2(button.size.x - 28.0 - qty_w - 8.0, row_h)
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.add_theme_font_size_override("font_size", 12)
		button.add_child(name)
		var count: Label = _make_label(Vector2(button.size.x - qty_w - 4.0, 0), Color("3f2d27"))
		count.size = Vector2(qty_w, row_h)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 12)
		button.add_child(count)
		_bag_rows.append({
			"slot": slot,
			"count": count,
			"item": str(spec["item"]),
			"name": name,
			"kind": str(spec["kind"]),
			"crop_id": str(spec["crop_id"]),
		})

func _bag_icon(spec: Dictionary) -> Texture2D:
	var item: String = str(spec["item"])
	if GoodsCatalog.icon_path(item) != "":
		return _fit_icon(GoodsCatalog.icon_path(item), 18)
	if item == "seeds":
		return _fit_icon("res://assets/farming/Six Pixel Farm Seeds.png", 16)
	if item == "turnips":
		return _fit_icon("res://assets/farming/Pixel art turnip inventory icon.png", 16)
	if spec.has("icon"):
		return _fit_icon(str(spec["icon"]), 16)
	var crop: Dictionary = CropCatalog.get_crop(str(spec["crop_id"]))
	var sprites: Array = crop.get("sprites", [])
	var index: int = 0 if str(spec["kind"]) == "seed" else maxi(sprites.size() - 1, 0)
	var rect: Rect2 = sprites[index]
	return UiStyle.region_picture(crop["texture"], rect, Vector2(16, 16))

func _on_bag_drag(event: InputEvent) -> void:
	if _bag_scroll == null:
		return
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_bag_press = click.global_position
			_bag_scroll_at_press = _bag_scroll.scroll_vertical
			_bag_holding = true
			_bag_moved = false
		else:
			if _bag_holding and not _bag_moved:
				_tap_bag_row(click.position)
			_bag_holding = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _bag_holding:
		var motion: InputEventMouseMotion = event
		var delta: Vector2 = motion.global_position - _bag_press
		if absf(delta.y) > 8.0 or absf(delta.x) > 8.0:
			_bag_moved = true
		if _bag_moved:
			_bag_scroll.scroll_vertical = _bag_scroll_at_press - int(delta.y)
		get_viewport().set_input_as_handled()

func _tap_bag_row(local_position: Vector2) -> void:
	var index: int = int(local_position.y / _bag_row_h)
	if index < 0 or index >= _bag_rows.size():
		return
	var row: Dictionary = _bag_rows[index]
	if str(row["kind"]) == "seed":
		_select_seed(str(row["crop_id"]))

func _select_seed(crop_id: String) -> void:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	var inventory: Inventory = systems.get_node("Inventory") as Inventory
	if not CropCatalog.has_crop(crop_id):
		return
	inventory.selected_seed = crop_id
	var save: SaveGame = systems.get_node("SaveGame") as SaveGame
	save.write_now()
	refresh()

func _on_craft() -> void:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	var inventory: Inventory = systems.get_node("Inventory") as Inventory
	var activities: Activities = systems.get_node("Activities") as Activities
	if inventory.try_craft_seeds():
		activities.note = Locale.t("seeds_made")
		var save: SaveGame = systems.get_node("SaveGame") as SaveGame
		save.write_now()
	else:
		activities.note = Locale.t("seeds_need")
	refresh()
