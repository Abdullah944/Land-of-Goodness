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
## The toolbar square that shows and changes the seed in hand.
const SEED_SLOT: int = 5
const HEART_ICON: String = "res://assets/ui/Terracotta pixel heart icon.png"
const KHAIR_W: float = 78.0

var _time: Label
var _gold: Label
var _note: Label
var _bag_rows: Array[Dictionary] = []
## The bag rows on screen now, top to bottom.
var _bag_shown: Array[Dictionary] = []
var _bag_body: Control
var _bag_empty: Label
var _clock_panel: Control
var _toolbar: Control
var _burger: Button
var _menu: Control
var _slots: Array[Button] = []
var _tab: String = "bag"
var _seed_icons: Dictionary = {}
var _craft: Button
var _bag_money: Label
var _zoom_in: Button
var _language: Button
var _sound: Button
var _journal_tab: Button
var _journal: Label
var _journal2: Label
var _pages_button: Button
var _book_button: Button
## The collections book: one page at a time, its pictures, and the line about the picture tapped.
var _book: Control
var _book_title: Label
var _book_cells: Array[Button] = []
var _book_marks: Array[Label] = []
var _book_names: Array[Label] = []
var _book_about: Label
var _book_deepest: Label
var _book_page: int = 0
var _book_item: String = ""
var _notice_button: Button
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
var _prayer_button: Button
var _prayer_next: Label
var _prayer_banner: PanelContainer
var _prayer_text: Label
## The last prayer the banner told about, so each one is told once.
var _prayer_told: String = ""
## Small notes at the side for each item picked up: {item, amount, panel, label, left}.
var _pickups: Array[Dictionary] = []
const PICKUP_SECONDS: float = 2.6
const PICKUP_MAX: int = 4
var _picked_tool: String = "<none>"
## What the top bar last showed, so a change can be played out and not just jump.
var _live_after: int = 0
var _dinars_seen: int = -1
var _dinars_shown: float = 0.0
var _count_tween: Tween
var _khair_seen: int = -1
var _hearts_seen: float = -1.0
var _heart_pulse: Tween
var _goal_id: String = ""
var _progress_seen: int = -1
var _seed_count: Label

func _ready() -> void:
	# The saved farm loads right after this, and its numbers should just be there, not count up.
	_live_after = Time.get_ticks_msec() + 1200
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
	_build_prayer_banner()
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

## "+1 Wood" with its picture slides in at the side, and a second pick of the same item adds to it.
func show_pickup(item: String, amount: int) -> void:
	for row: Dictionary in _pickups:
		if str(row["item"]) == item:
			row["amount"] = int(row["amount"]) + amount
			row["left"] = PICKUP_SECONDS
			_pickup_text(row)
			Juice.press(row["panel"])
			return
	var panel: PanelContainer = PanelContainer.new()
	UiStyle.panel(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	var icon: TextureRect = TextureRect.new()
	icon.texture = Juice.item_icon(item)
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var label: Label = _make_label(Vector2.ZERO, UiStyle.DARK)
	label.add_theme_font_size_override("font_size", 10)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(label)
	add_child(panel)
	var row: Dictionary = {"item": item, "amount": amount, "panel": panel, "label": label, "left": PICKUP_SECONDS}
	_pickup_text(row)
	_pickups.push_front(row)
	while _pickups.size() > PICKUP_MAX:
		(_pickups.pop_back()["panel"] as Node).queue_free()
	panel.modulate.a = 0.0
	_place_pickups()
	panel.position.x -= 30.0
	var slide: Tween = panel.create_tween()
	slide.set_parallel(true)
	slide.tween_property(panel, "position:x", panel.position.x + 30.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide.tween_property(panel, "modulate:a", 1.0, 0.15)

func _pickup_text(row: Dictionary) -> void:
	var label: Label = row["label"]
	var systems: Node = get_tree().current_scene.get_node("Systems")
	var total: int = (systems.get_node("Inventory") as Inventory).count_of(str(row["item"]))
	label.text = "+%d %s  (%d)" % [int(row["amount"]), Locale.item(str(row["item"])), total]
	Locale.apply_control(label)
	(row["panel"] as Control).reset_size()

func _place_pickups() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var y: float = view.y - 62.0
	for row: Dictionary in _pickups:
		var panel: Control = row["panel"]
		panel.reset_size()
		y -= panel.size.y + 3.0
		panel.position = Vector2(_side_margin(view) + _toolbar.size.x + 6.0, y)

func _process(delta: float) -> void:
	var gone: Array[Dictionary] = []
	for row: Dictionary in _pickups:
		row["left"] = float(row["left"]) - delta
		var panel: Control = row["panel"]
		if float(row["left"]) < 0.4:
			panel.modulate.a = maxf(0.0, float(row["left"]) / 0.4)
		if float(row["left"]) <= 0.0:
			gone.append(row)
	for row: Dictionary in gone:
		_pickups.erase(row)
		(row["panel"] as Node).queue_free()
	if not gone.is_empty():
		_place_pickups()

func _side_margin(view: Vector2) -> float:
	if not OS.has_feature("mobile"):
		return MARGIN
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window.x <= 0.0 or safe.size.x <= 0:
		return MARGIN
	var inset: float = maxf(float(safe.position.x), window.x - float(safe.end.x))
	return maxf(MARGIN, ceil(inset * view.x / window.x))

## Darkens the screen for sleep and shows one line about tomorrow.
func cover_for_sleep(tomorrow: String = "") -> void:
	_sleep_dark.visible = true
	_sleep_dark.move_to_front()
	var line: Label = _sleep_dark.get_node_or_null("Tomorrow") as Label
	if line == null:
		line = _make_label(Vector2.ZERO, Color("fff3dc"))
		line.name = "Tomorrow"
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 16)
		_sleep_dark.add_child(line)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 40.0
		line.offset_right = -40.0
	line.text = tomorrow
	Locale.apply_control(line)
	line.modulate.a = 0.0
	if tomorrow != "":
		create_tween().tween_property(line, "modulate:a", 1.0, 0.6).set_delay(0.5)

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
	# The receipt pops in, and the sum earned counts up.
	_sale_panel.pivot_offset = _sale_panel.size * 0.5
	_sale_panel.scale = Vector2(0.8, 0.8)
	_sale_panel.modulate.a = 0.0
	var pop: Tween = _sale_panel.create_tween()
	pop.tween_property(_sale_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(_sale_panel, "modulate:a", 1.0, 0.12)
	var count_up: Callable = func(value: float) -> void:
		_sale_earned.text = Locale.t("dinars") % int(round(value))
	pop.parallel().tween_method(count_up, 0.0, float(earned), 0.5).set_delay(0.1)
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
	_show_dinars(inventory.dinars)
	var stead: Stead = systems.get_node_or_null("Stead") as Stead
	if activities.display_note() != "":
		_note.text = activities.display_note()
	elif stead != null:
		_note.text = stead.goal_text()
		_mark_goal(_note.text, stead)
	elif activities.quest_done:
		_note.text = ""
	else:
		_note.text = Locale.t("quest_turnip")
	Locale.apply_control(_note)
	# Only goods the boy has are listed; a row leaves the bag when its last one is used, sold, or stored.
	_bag_shown.clear()
	for row: Dictionary in _bag_rows:
		var count_label: Label = row["count"]
		var have: int = inventory.count_of(str(row["item"]))
		count_label.text = str(have)
		var line: Control = row["button"]
		line.visible = have > 0
		if have > 0:
			line.position.y = _bag_shown.size() * _bag_row_h
			_bag_shown.append(row)
		if row.has("name"):
			var name_label: Label = row["name"]
			name_label.text = Locale.item(str(row["item"]))
		count_label.visible = _tab == "bag"
		var slot: CanvasItem = row["slot"]
		var chosen: bool = str(row["kind"]) == "seed" and str(row["crop_id"]) == inventory.selected_seed
		slot.modulate = Color("d9a441") if chosen else Color.WHITE
	_bag_body.custom_minimum_size.y = _bag_row_h * maxi(1, _bag_shown.size())
	_bag_empty.visible = _bag_shown.is_empty()
	_bag_empty.text = Locale.t("bag_empty")
	Locale.apply_control(_bag_empty)
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
		_pages_button.visible = _tab == "quests"
		_book_button.visible = _tab == "quests"
		_book.visible = _tab == "book"
		var bag_now: Inventory = systems.get_node("Inventory") as Inventory
		_book_button.text = Locale.t("book") % [CollectionBook.found_total(bag_now.found), CollectionBook.total()]
		Locale.apply_control(_book_button)
		if _book.visible:
			_refresh_book(bag_now, stead)
		var page_systems: Node = get_tree().current_scene.get_node_or_null("Systems")
		if page_systems != null:
			_pages_button.text = Locale.t("pages") % [Journal.found(page_systems), Journal.PAGE_COUNT]
			Locale.apply_control(_pages_button)
		if _journal.visible:
			var lines: PackedStringArray = _journal_text(stead).split("\n")
			var half: int = int(ceil(lines.size() / 2.0))
			_journal.text = "\n".join(lines.slice(0, half))
			_journal2.text = "\n".join(lines.slice(half))
			Locale.apply_control(_journal)
			Locale.apply_control(_journal2)
	var tool_now: String = _player().tool
	for i: int in _slots.size():
		_slots[i].modulate = Color("d9a441") if tool_now == TOOLS[i] and i != SEED_SLOT else Color.WHITE
	if tool_now != _picked_tool:
		# The square of a newly chosen tool pops, also when the boy picks the tool himself.
		if _picked_tool != "<none>" and TOOLS.find(tool_now) >= 0:
			Juice.press(_slots[TOOLS.find(tool_now)])
		_picked_tool = tool_now
	_refresh_seed_slot(inventory)
	for i: int in _hearts.size():
		_hearts[i].visible = float(i) < inventory.max_hearts
		_hearts[i].modulate.a = clampf(inventory.hearts - float(i), 0.3, 1.0)
	_show_hearts(inventory)
	var kindness: Kindness = systems.get_node_or_null("Kindness") as Kindness
	if kindness != null:
		_show_khair(kindness.points)
		_khair_label.text = "%s  %d" % [Locale.t("khair"), kindness.points]
		Locale.apply_control(_khair_label)

func _is_live() -> bool:
	return Time.get_ticks_msec() > _live_after

## Dinars count up or down to the new sum, and the change floats up beside them.
func _show_dinars(now: int) -> void:
	if now != _dinars_seen:
		var change: int = now - _dinars_seen
		var live: bool = _dinars_seen >= 0 and _is_live()
		_dinars_seen = now
		if _count_tween != null:
			_count_tween.kill()
		if live:
			_count_tween = create_tween()
			_count_tween.tween_method(_set_dinars, _dinars_shown, float(now), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			Juice.press(_gold)
			var at: Vector2 = _clock_panel.position + Vector2(12.0, _clock_panel.size.y + 4.0)
			Juice.float_text(self, at, "%+d" % change, Color("ffe08a") if change > 0 else Color("f2a48f"))
		else:
			_dinars_shown = float(now)
	_set_dinars(_dinars_shown)

func _set_dinars(value: float) -> void:
	_dinars_shown = value
	_gold.text = Locale.t("dinars") % int(round(value))
	if _bag_money != null:
		_bag_money.text = _gold.text

## The Khair bar fills smoothly, and its number pops when Khair is earned.
func _show_khair(points: int) -> void:
	var width: float = (KHAIR_W - 2.0) * float(points) / float(Kindness.MAX_POINTS)
	if points == _khair_seen:
		return
	var live: bool = _khair_seen >= 0 and _is_live()
	var gained: bool = points > _khair_seen
	_khair_seen = points
	if not live:
		_khair_fill.size.x = width
		return
	var fill: Tween = _khair_fill.create_tween()
	fill.tween_property(_khair_fill, "size:x", width, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if gained:
		_khair_fill.color = Color("fff3dc")
		fill.parallel().tween_property(_khair_fill, "color", Color("d9a441"), 0.6)
		Juice.press(_khair_label)

## A heart pops when it is used up, and the last one beats slowly as a reminder to eat or sleep.
func _show_hearts(inventory: Inventory) -> void:
	var now: float = inventory.hearts
	if _hearts_seen >= 0.0 and _is_live() and floorf(now + 0.001) < floorf(_hearts_seen + 0.001):
		Juice.press(_hearts[clampi(int(floorf(now + 0.001)), 0, _hearts.size() - 1)])
	_hearts_seen = now
	var low: bool = now <= 1.0 and inventory.max_hearts >= 1.0
	if low and _heart_pulse == null:
		_hearts[0].pivot_offset = _hearts[0].size * 0.5
		_heart_pulse = _hearts[0].create_tween().set_loops()
		_heart_pulse.tween_property(_hearts[0], "scale", Vector2(1.25, 1.25), 0.3)
		_heart_pulse.tween_property(_hearts[0], "scale", Vector2.ONE, 0.3)
		_heart_pulse.tween_interval(0.5)
	elif not low and _heart_pulse != null:
		_heart_pulse.kill()
		_heart_pulse = null
		_hearts[0].scale = Vector2.ONE

## The hearts shake their heads when the boy is too tired for another swing.
func nudge_hearts() -> void:
	for heart: TextureRect in _hearts:
		if heart.visible:
			Juice.wobble(heart)
	Juice.tap(get_tree(), Juice.TAP_FIRM)

## The line under the day pops when it changes, and a finished quest step gets a chime and a gold glow.
func _mark_goal(goal: String, stead: Stead) -> void:
	var id: String = goal.get_slice(". ", 0)
	for digit: String in "0123456789":
		id = id.replace(digit, "")
	var progress: int = stead.progress()
	var live: bool = _goal_id != "" and _is_live()
	if live and progress > _progress_seen:
		Juice.press(_note)
		_note.modulate = Color(1.0, 0.82, 0.3)
		_note.create_tween().tween_property(_note, "modulate", Color.WHITE, 1.4).set_delay(0.4)
		(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).play("level")
		Juice.tap(get_tree(), Juice.TAP_STRONG)
	elif live and id != _goal_id:
		Juice.press(_note)
	_goal_id = id
	_progress_seen = progress

func _refresh_settings(stead: Stead) -> void:
	var labels: Dictionary = {_zoom_in: Locale.t("zoom_in"), _zoom_out: Locale.t("zoom_out"), _language: Locale.t("language"), _help_button: Locale.t("help_button")}
	if stead != null:
		labels[_music_button] = Locale.t("music") % Locale.t("level_%d" % stead.music_level)
		labels[_sound] = Locale.t("effects") % Locale.t("level_%d" % stead.sfx_level)
		labels[_prayer_button] = Locale.t("prayer_reminder") % Locale.t("switch_on" if stead.prayer_reminder else "switch_off")
		labels[_notice_button] = Locale.t("phone_notices") % Locale.t("switch_on" if stead.phone_notices else "switch_off")
		_prayer_next.visible = _tab == "settings" and stead.prayer_reminder
		if _prayer_next.visible:
			var next: Array = PrayerTimes.next_prayer(PrayerTimes.today(), PrayerTimes.now_minutes())
			_prayer_next.text = Locale.t("prayer_next") % [Locale.t(str(next[0])), PrayerTimes.clock_text(int(next[1]))]
			Locale.apply_control(_prayer_next)
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
		if i == SEED_SLOT:
			# The last square holds the seed that planting uses; a tap picks the next seed in the bag.
			slot.pressed.connect(_next_seed)
			_seed_count = _make_label(Vector2(0, squares[i].size.y - 11.0), UiStyle.CREAM)
			_seed_count.size = Vector2(squares[i].size.x, 10)
			_seed_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_seed_count.add_theme_font_size_override("font_size", 8)
			_seed_count.add_theme_constant_override("outline_size", 3)
			_seed_count.add_theme_color_override("font_outline_color", UiStyle.DARK)
			slot.add_child(_seed_count)
		else:
			slot.pressed.connect(_pick_tool.bind(i))
		slot.button_down.connect(Juice.press.bind(slot))
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
	_burger.button_down.connect(Juice.press.bind(_burger))
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
	_world_map.place_chosen.connect(_travel_to)
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
	_pages_button = _tab_button("", Vector2(inner.position.x + 10.0, 160))
	var half_w: float = (inner.size.x - 26.0) * 0.5
	_pages_button.size = Vector2(half_w, 26)
	_pages_button.focus_mode = Control.FOCUS_NONE
	_pages_button.add_theme_font_size_override("font_size", 12)
	_pages_button.visible = false
	_pages_button.pressed.connect(_read_pages)
	page.add_child(_pages_button)
	_book_button = _tab_button("", Vector2(inner.position.x + 16.0 + half_w, 160))
	_book_button.size = Vector2(half_w, 26)
	_book_button.focus_mode = Control.FOCUS_NONE
	_book_button.add_theme_font_size_override("font_size", 12)
	_book_button.visible = false
	_book_button.pressed.connect(_open_book)
	page.add_child(_book_button)
	_build_book(page, Rect2(inner.position.x, 48, inner.size.x, 142))
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
	_music_button = _settings_button(2, 0, _cycle_music)
	_sound = _settings_button(0, 1, _toggle_sound)
	_language = _settings_button(1, 1, _toggle_language)
	_help_button = _settings_button(2, 1, _show_help)
	_prayer_button = _settings_button(0, 2, _toggle_prayer)
	_notice_button = _settings_button(2, 2, _toggle_notices)
	_prayer_next = _make_label(Vector2(20.0 + 146.0, 54.0 + 2 * 39.0), UiStyle.DARK)
	_prayer_next.size = Vector2(136, 36)
	_prayer_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prayer_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prayer_next.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prayer_next.add_theme_font_size_override("font_size", 12)
	_menu.add_child(_prayer_next)
	_eat = _tab_button(Locale.t("eat"), Vector2(108, 3))
	_eat.size = Vector2(60, 24)
	_eat.focus_mode = Control.FOCUS_NONE
	_eat.pressed.connect(_on_eat)
	bar.add_child(_eat)

func _settings_button(column: int, row: int, action: Callable) -> Button:
	# Three across, so seven settings fit inside the wooden window.
	var button: Button = _tab_button("", Vector2(20.0 + column * 146.0, 54.0 + row * 39.0))
	button.size = Vector2(136, 34)
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
	(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).play("ui")
	Juice.tap(get_tree())
	refresh()

var _shown_seed: String = ""

func _refresh_seed_slot(inventory: Inventory) -> void:
	var slot: Button = _slots[SEED_SLOT]
	var seed_item: String = _seed_item_of(inventory.selected_seed)
	if _shown_seed != inventory.selected_seed:
		_shown_seed = inventory.selected_seed
		slot.icon = Juice.item_icon(seed_item)
		slot.text = ""
	_seed_count.text = str(inventory.count_of(seed_item))
	slot.modulate = Color.WHITE if inventory.count_of(seed_item) > 0 else Color(1, 1, 1, 0.55)

## The bag item that the seed button uses: a seed, or a sprinkler.
func _seed_item_of(choice: String) -> String:
	if choice == FarmField.SPRINKLER:
		return FarmField.SPRINKLER
	return str(CropCatalog.get_crop(choice).get("seed_item", "seeds"))

## Picks the next kind of seed, the ones in the bag first. Sprinklers join the turn when the bag has one.
func _next_seed() -> void:
	var inventory: Inventory = get_tree().current_scene.get_node("Systems/Inventory") as Inventory
	var ids: PackedStringArray = CropCatalog.ids()
	ids.append(FarmField.SPRINKLER)
	var at: int = ids.find(inventory.selected_seed)
	for step: int in range(1, ids.size() + 1):
		var crop_id: String = ids[(at + step) % ids.size()]
		if inventory.count_of(_seed_item_of(crop_id)) > 0 or step == ids.size():
			inventory.selected_seed = crop_id
			break
	(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).play("ui")
	Juice.tap(get_tree())
	(get_tree().current_scene.get_node("Systems/SaveGame") as SaveGame).write_now()
	activities_flash(Locale.item(_seed_item_of(inventory.selected_seed)))
	refresh()

func activities_flash(text: String) -> void:
	(get_tree().current_scene.get_node("Systems/Activities") as Activities).flash(text)

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

## Fast travel from the map: closes the menu and takes the boy to that place's arrival spot.
func _travel_to(key: String) -> void:
	var main: Node = get_tree().current_scene
	var stead: Stead = main.get_node_or_null("Systems/Stead") as Stead
	if _menu.visible:
		_toggle_menu()
	if stead == null or stead.place_name == key:
		return
	var destination: PackedScene = load(stead.scene_for(key)) as PackedScene
	(main.get_node("Systems/LevelLoader") as LevelLoader).go_to(destination, "PlayerSpawn")

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
		# Finished steps are ticked; only the current step and the one after it are shown ahead.
		var ahead: int = 0
		for step: Dictionary in stead.steps():
			var done: bool = bool(step["done"])
			if not done:
				ahead += 1
				if ahead > 2:
					break
			var mark: String = "[x]" if done else ("  >" if ahead == 1 else "[  ]")
			lines.append("%s %s" % [mark, Locale.t(str(step["key"])).trim_prefix("Quest: ").trim_prefix("المهمة: ")])
			if not done and ahead == 1 and stead.where_hint() != "":
				lines.append(stead.where_hint())
	if works != null and works.requests_open():
		var wish: Dictionary = works.request_today()
		if not bool(wish.get("done", false)):
			var who: String = str(wish.get("person", ""))
			lines.append(Locale.t("journal_request") % [Locale.t(who if who == "jassim" else who + "_name"), int(wish.get("amount", 0)), Locale.item(str(wish.get("item", "")))])
	var kindness: Kindness = get_tree().current_scene.get_node_or_null("Systems/Kindness") as Kindness
	if kindness != null:
		lines.append(Locale.t("khair_line") % [kindness.points, Kindness.MAX_POINTS])
	var clock: GameClock = get_tree().current_scene.get_node_or_null("Systems/Clock") as GameClock
	if clock != null:
		lines.append(clock.forecast_text())
	return "\n".join(lines)

## The book sits where the quest list is, with arrows to turn its four pages.
func _build_book(page: Control, area: Rect2) -> void:
	_book = _nine("res://assets/ui/menu/Empty tall pixel-art list box.png", area.position, area.size, 11, 2)
	_book.visible = false
	page.add_child(_book)
	_book_title = _make_label(Vector2(40, 6), UiStyle.DARK)
	_book_title.size = Vector2(area.size.x - 80.0, 18)
	_book_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_book_title.add_theme_font_size_override("font_size", 13)
	_book.add_child(_book_title)
	var back: Button = _tab_button("◀", Vector2(8, 5))
	back.size = Vector2(30, 20)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_turn_book.bind(-1))
	_book.add_child(back)
	var on: Button = _tab_button("▶", Vector2(area.size.x - 38.0, 5))
	on.size = Vector2(30, 20)
	on.focus_mode = Control.FOCUS_NONE
	on.pressed.connect(_turn_book.bind(1))
	_book.add_child(on)
	var most: int = 0
	for book_page: Dictionary in CollectionBook.PAGES:
		most = maxi(most, (book_page["items"] as Array).size())
	var cell_w: float = (area.size.x - 16.0) / float(most)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for i: int in most:
		var cell: Button = Button.new()
		cell.position = Vector2(8.0 + i * cell_w, 38)
		cell.size = Vector2(cell_w, 36)
		cell.flat = true
		cell.expand_icon = false
		cell.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "focus"]:
			cell.add_theme_stylebox_override(state, empty)
		cell.pressed.connect(_pick_book_item.bind(i))
		cell.button_down.connect(Juice.press.bind(cell))
		_book.add_child(cell)
		_book_cells.append(cell)
		var mark: Label = _make_label(Vector2.ZERO, UiStyle.CREAM)
		mark.size = cell.size
		mark.text = "?"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 14)
		mark.add_theme_constant_override("outline_size", 3)
		mark.add_theme_color_override("font_outline_color", UiStyle.DARK)
		cell.add_child(mark)
		_book_marks.append(mark)
		var name_label: Label = _make_label(Vector2(8.0 + i * cell_w, 74), UiStyle.DARK)
		name_label.size = Vector2(cell_w, 14)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.clip_text = true
		_book.add_child(name_label)
		_book_names.append(name_label)
	_book_deepest = _make_label(Vector2(10, 90), UiStyle.DARK)
	_book_deepest.size = Vector2(area.size.x - 20.0, 14)
	_book_deepest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_book_deepest.add_theme_font_size_override("font_size", 10)
	_book.add_child(_book_deepest)
	_book_about = _make_label(Vector2(12, 104), UiStyle.DARK)
	_book_about.size = Vector2(area.size.x - 24.0, 34)
	_book_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_book_about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_book_about.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_book_about.add_theme_font_size_override("font_size", 11)
	_book.add_child(_book_about)

static var _book_icons: Dictionary = {}

func _book_icon(item_id: String) -> Texture2D:
	if not _book_icons.has(item_id):
		var path: String = GoodsCatalog.icon_path(item_id)
		_book_icons[item_id] = UiStyle.fit_picture(load(path) as Texture2D, 26) if path != "" and ResourceLoader.exists(path) else null
	return _book_icons[item_id]

func _refresh_book(bag: Inventory, stead: Stead) -> void:
	var book_page: Dictionary = CollectionBook.PAGES[_book_page]
	var items: Array = book_page["items"]
	_book_title.text = Locale.t("book_page") % [Locale.t(str(book_page["key"])), CollectionBook.found_on(book_page, bag.found), items.size()]
	Locale.apply_control(_book_title)
	for i: int in _book_cells.size():
		var cell: Button = _book_cells[i]
		var shown: bool = i < items.size()
		cell.visible = shown
		_book_names[i].visible = shown
		if not shown:
			continue
		var item_id: String = str(items[i])
		var have: bool = bag.found.has(item_id)
		cell.icon = _book_icon(item_id)
		# Things not found yet show as a dark shape with a question mark.
		cell.self_modulate = Color.WHITE if have else Color(0.12, 0.08, 0.06, 0.55)
		_book_marks[i].visible = not have
		_book_names[i].text = Locale.item(item_id) if have else "?"
		_book_names[i].modulate = Color.WHITE if item_id != _book_item else Color("b5651d")
		Locale.apply_control(_book_names[i])
	_book_deepest.visible = str(book_page["key"]) == "book_cave"
	if _book_deepest.visible:
		var deepest: int = int(stead.flags.get("cave_deepest", 0)) if stead != null else 0
		_book_deepest.text = Locale.t("book_deepest") % [deepest, CaveFloor.DEEPEST]
		Locale.apply_control(_book_deepest)
	if _book_item == "" or not items.has(_book_item):
		_book_about.text = Locale.t("book_tap")
	elif bag.found.has(_book_item):
		_book_about.text = "%s: %s" % [Locale.item(_book_item), Locale.t("about_" + _book_item)]
	else:
		# Some things give a hint about where to look.
		var hint: String = Locale.t("hint_" + _book_item)
		_book_about.text = Locale.t("book_unknown") if hint == "hint_" + _book_item else hint
	Locale.apply_control(_book_about)

func _open_book() -> void:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	var bag: Inventory = systems.get_node("Inventory") as Inventory
	bag.note_held(systems.get_node_or_null("ChestStore") as ChestStore)
	bag.pay_book_pages()
	_book_item = ""
	(systems.get_node("SoundBank") as SoundBank).play("page")
	_show_tab("book")

func _turn_book(step: int) -> void:
	_book_page = posmod(_book_page + step, CollectionBook.PAGES.size())
	_book_item = ""
	(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).play("page")
	refresh()

func _pick_book_item(index: int) -> void:
	var items: Array = CollectionBook.PAGES[_book_page]["items"]
	if index < items.size():
		_book_item = str(items[index])
		(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).play("ui")
		refresh()

## Closes the menu and reads grandfather's pages found so far, then says who has the next one.
func _read_pages() -> void:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	dismiss_menu()
	(get_tree().current_scene.get_node("UI/Dialogue") as DialogueBox).open_lines(Journal.read_lines(systems))

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

func _toggle_notices() -> void:
	var stead: Stead = get_tree().current_scene.get_node_or_null("Systems/Stead") as Stead
	if stead == null:
		return
	stead.phone_notices = not stead.phone_notices
	(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).play("ui")
	(get_tree().current_scene.get_node("Systems/SaveGame") as SaveGame).write_now()
	refresh()

func _toggle_prayer() -> void:
	var stead: Stead = get_tree().current_scene.get_node_or_null("Systems/Stead") as Stead
	if stead == null:
		return
	stead.prayer_reminder = not stead.prayer_reminder
	_prayer_told = ""
	(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).play("ui")
	(get_tree().current_scene.get_node("Systems/SaveGame") as SaveGame).write_now()
	refresh()

## A small wooden note at the top of the screen when a real prayer time comes, checked by the phone's clock.
func _build_prayer_banner() -> void:
	_prayer_banner = PanelContainer.new()
	UiStyle.panel(_prayer_banner)
	_prayer_banner.visible = false
	_prayer_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_prayer_banner.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_prayer_banner.visible = false)
	_prayer_text = _make_label(Vector2.ZERO, UiStyle.DARK)
	_prayer_text.add_theme_font_size_override("font_size", 12)
	_prayer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prayer_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prayer_text.custom_minimum_size = Vector2(210, 24)
	_prayer_banner.add_child(_prayer_text)
	add_child(_prayer_banner)
	var check: Timer = Timer.new()
	check.wait_time = 15.0
	check.autostart = true
	check.timeout.connect(_check_prayer)
	add_child(check)
	_check_prayer.call_deferred()

## Within fifteen minutes after a prayer time, the banner shows once for that prayer.
func _check_prayer() -> void:
	var stead: Stead = get_tree().current_scene.get_node_or_null("Systems/Stead") as Stead
	if stead == null or not stead.prayer_reminder:
		return
	var times: Dictionary = PrayerTimes.today()
	var now: int = PrayerTimes.now_minutes()
	var date: Dictionary = Time.get_date_dict_from_system()
	for name: String in PrayerTimes.NAMES:
		var at: int = int(times[name])
		var key: String = "%d-%d-%d %s" % [date["year"], date["month"], date["day"], name]
		if now >= at and now < at + 15 and key != _prayer_told:
			_prayer_told = key
			_show_prayer_banner(Locale.t("prayer_now") % Locale.t(name))

func _show_prayer_banner(text: String) -> void:
	_prayer_text.text = text
	Locale.apply_control(_prayer_text)
	_prayer_banner.reset_size()
	var view: Vector2 = get_viewport().get_visible_rect().size
	_prayer_banner.position = Vector2((view.x - _prayer_banner.size.x) * 0.5, 10.0)
	_prayer_banner.visible = true
	(get_tree().current_scene.get_node("Systems/SoundBank") as SoundBank).play("level")
	var token: String = _prayer_told
	await get_tree().create_timer(12.0).timeout
	if _prayer_told == token:
		_prayer_banner.visible = false

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

## A seed bag with a small picture of what it grows, so each seed row is easy to tell apart.
func _seed_icon(crop_id: String) -> Texture2D:
	if _seed_icons.has(crop_id):
		return _seed_icons[crop_id]
	var bag: Image = _trimmed_image("res://assets/farming/Six Pixel Farm Seeds.png")
	var crop: Dictionary = CropCatalog.get_crop(crop_id)
	var path: String = GoodsCatalog.icon_path(str(crop.get("harvest_item", "")))
	if path != "":
		var fruit: Image = _trimmed_image(path)
		var side: float = float(bag.get_width()) * 0.6
		var shrink: float = side / float(maxi(fruit.get_width(), fruit.get_height()))
		fruit.resize(maxi(1, int(fruit.get_width() * shrink)), maxi(1, int(fruit.get_height() * shrink)), Image.INTERPOLATE_NEAREST)
		var at: Vector2i = bag.get_size() - fruit.get_size()
		bag.blend_rect(fruit, Rect2i(Vector2i.ZERO, fruit.get_size()), at)
	var longest: float = float(maxi(bag.get_width(), bag.get_height()))
	var picture: Texture2D = UiStyle.hd_texture(bag, Vector2(bag.get_size()) * 16.0 / longest)
	_seed_icons[crop_id] = picture
	return picture

func _trimmed_image(path: String) -> Image:
	var image: Image = UiStyle.pixels_of(load(path) as Texture2D).duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var used: Rect2i = image.get_used_rect()
	return image.get_region(used) if used.size != Vector2i.ZERO else image

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
		# A sprinkler is chosen like a seed and set down on a tilled square.
		var placeable: bool = extra_id == FarmField.SPRINKLER
		specs.append({
			"kind": "seed" if placeable else "item",
			"crop_id": extra_id if placeable else "",
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
	_bag_body = body
	_bag_empty = _make_label(Vector2.ZERO, Color("3f2d27"))
	_bag_empty.size = Vector2(body.custom_minimum_size.x, row_h * 2.0)
	_bag_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bag_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bag_empty.add_theme_font_size_override("font_size", 12)
	body.add_child(_bag_empty)
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
			"button": button,
			"slot": slot,
			"count": count,
			"item": str(spec["item"]),
			"name": name,
			"kind": str(spec["kind"]),
			"crop_id": str(spec["crop_id"]),
		})

func _bag_icon(spec: Dictionary) -> Texture2D:
	var item: String = str(spec["item"])
	if str(spec["kind"]) == "seed" and CropCatalog.ids().has(str(spec.get("crop_id", ""))):
		return _seed_icon(str(spec["crop_id"]))
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
	if index < 0 or index >= _bag_shown.size():
		return
	var row: Dictionary = _bag_shown[index]
	if str(row["kind"]) == "seed":
		_select_seed(str(row["crop_id"]))

func _select_seed(crop_id: String) -> void:
	var systems: Node = get_tree().current_scene.get_node("Systems")
	var inventory: Inventory = systems.get_node("Inventory") as Inventory
	if not CropCatalog.has_crop(crop_id) and crop_id != FarmField.SPRINKLER:
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
