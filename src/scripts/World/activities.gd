# src/scripts/World/activities.gd
# Purpose: Neighbor, the seed shop, daily gathering, the cave, and the one quest.

class_name Activities
extends Node

var quest_done: bool = false
var fished_today: bool = false
var fish_day: int = -1
var fish_spots: Dictionary = {}
var rock_mined: bool = false
var gathered: Dictionary = {}
var note: String = ""
var _shop: String = ""
var _gift_to: String = ""
var _flash: String = ""
var _flash_token: int = 0
var _shown_note: String = ""
var _shown_at: int = 0

const PEARL_CHANCE: float = 0.25
## Big things can be tapped this many squares from their middle.
const BIG_SNAP: Dictionary = {"CaveEntrance": 3}
## Distance in world pixels from which a big thing can be used.
const BIG_REACH: Dictionary = {"CaveEntrance": 40.0}
## What the sea may leave in the shore crate each morning.
const SHORE_FINDS: Array[String] = ["wood", "wood", "fish", "dates", "stone", "copper", "pearl"]
const NOTE_MS: int = 7000

## Skips the fishing game. Only the tests turn this on.
var quick_fish: bool = false

func try_use(dirt: TileMapLayer, cell: Vector2i) -> bool:
	var place: Node = _place()
	if place == null:
		return false
	if _clear_debris("debris_weed", dirt, cell, "forage"):
		return true
	if _take_mark("date", dirt, cell, "dates"):
		return true
	if _take_mark("ore", dirt, cell, "copper"):
		return true
	if _take_mark("forage", dirt, cell, "forage"):
		return true
	var role: String = _role_at(place, dirt, cell)
	if role != "":
		talk_role(role)
		return true
	if _matches(place, "Neighbor", dirt, cell):
		_talk()
		return true
	var pond: Node2D = _pond_at(place, dirt, cell)
	if pond != null:
		cast(str(place.name), str(pond.name))
		return true
	if _matches(place, "CaveEntrance", dirt, cell):
		_enter_cave()
		return true
	return false

func snap_cell(dirt: TileMapLayer, cell: Vector2i) -> Vector2i:
	var place: Node = _place()
	if place == null:
		return cell
	var best: Vector2i = cell
	var best_distance: int = 99
	for mark: Node in place.get_children():
		if not mark is Node2D:
			continue
		if not _is_debris(mark) and not mark.is_in_group("tree") and not mark.is_in_group("rock") and not mark.is_in_group("ore") and not mark.is_in_group("date") and not mark.is_in_group("forage") and Activities.role_of(mark) == "" and mark.name != "Neighbor" and mark.name != "FishingSpot" and mark.name != "CaveEntrance" and not _is_pond(mark):
			continue
		var spot: Node2D = mark as Node2D
		var mark_cell: Vector2i = dirt.local_to_map(dirt.to_local(spot.global_position))
		var gap: Vector2i = cell - mark_cell
		var distance: int = maxi(absi(gap.x), absi(gap.y))
		var close: bool = distance <= (BIG_SNAP.get(str(spot.name), 1) as int)
		if _is_pond(spot):
			close = distance <= int(float(spot.get("fit_pixels")) / 32.0)
		if spot.is_in_group("tree") or spot.is_in_group("date"):
			close = absi(gap.x) <= 2 and gap.y <= 0 and gap.y >= -5
			distance = absi(gap.x) + absi(gap.y)
		elif Activities.role_of(spot) != "" or spot.get("person") != null:
			close = absi(gap.x) <= 1 and gap.y <= 0 and gap.y >= -3
			distance = absi(gap.x) + absi(gap.y)
		if close and distance < best_distance:
			best = mark_cell
			best_distance = distance
	return best

func tool_for_cell(dirt: TileMapLayer, cell: Vector2i) -> String:
	var place: Node = _place()
	if place == null:
		return ""
	if _group_has("debris_weed", dirt, cell) or _group_has("date", dirt, cell) or _group_has("forage", dirt, cell) or _role_at(place, dirt, cell) != "":
		return "use"
	if _group_has("debris_wood", dirt, cell) or _group_has("tree", dirt, cell):
		return "axe"
	if _group_has("debris_stone", dirt, cell) or _group_has("rock", dirt, cell) or _group_has("ore", dirt, cell):
		return "pick"
	if _matches(place, "Neighbor", dirt, cell) or _pond_at(place, dirt, cell) != null or _matches(place, "CaveEntrance", dirt, cell):
		return "use"
	var farm: FarmField = get_parent().get_node("FarmField") as FarmField
	return farm.tool_for_plot(cell)

func reach_for(dirt: TileMapLayer, cell: Vector2i) -> float:
	var place: Node = _place()
	if place == null:
		return 0.0
	var pond: Node2D = _pond_at(place, dirt, cell)
	if pond != null:
		return float(pond.get("fit_pixels")) * 0.5 + 10.0
	for mark_name: String in BIG_REACH:
		if _matches(place, mark_name, dirt, cell):
			return float(BIG_REACH[mark_name])
	return 0.0

func chop_at(dirt: TileMapLayer, cell: Vector2i) -> bool:
	return _clear_debris("debris_wood", dirt, cell, "wood") or _take_mark("tree", dirt, cell, "wood")

func mine_at(dirt: TileMapLayer, cell: Vector2i) -> bool:
	return _clear_debris("debris_stone", dirt, cell, "stone") or _take_mark("rock", dirt, cell, "stone") or _take_mark("ore", dirt, cell, "copper")

## Twigs, stones, and weeds leave the farm for good and give one item.
func _clear_debris(group_name: String, dirt: TileMapLayer, cell: Vector2i, item: String) -> bool:
	var place: Node = _place()
	if place == null:
		return false
	for mark: Node in place.get_children():
		if not mark.is_in_group(group_name) or not mark is Node2D:
			continue
		if dirt.local_to_map(dirt.to_local((mark as Node2D).global_position)) != cell:
			continue
		_inventory().add_item(item, 1)
		_stead().flags["cleared_" + str(mark.name)] = true
		mark.remove_from_group(group_name)
		mark.queue_free()
		note = _gather_note(item)
		_chime("gather")
		pop_item(item)
		_save()
		_refresh()
		return true
	return false

func _is_pond(mark: Node) -> bool:
	return mark.name == "FishingSpot" or str(mark.name).begins_with("Pond_")

func _pond_at(place: Node, dirt: TileMapLayer, cell: Vector2i) -> Node2D:
	for mark: Node in place.get_children():
		if mark is Node2D and _is_pond(mark) and dirt.local_to_map(dirt.to_local((mark as Node2D).global_position)) == cell:
			return mark as Node2D
	return null

func _is_debris(mark: Node) -> bool:
	return str(mark.get("group_name")).begins_with("debris")

## A small "+1" rises over the boy's head and fades.
func pop_item(item: String, amount: int = 1) -> void:
	var scene: Node = get_tree().current_scene
	var player: Node2D = scene.find_child("Player", true, false) as Node2D if scene != null else null
	var place: Node = _place()
	if player == null or place == null:
		return
	var label: Label = Label.new()
	label.text = "+%d %s" % [amount, Locale.item(item)]
	label.z_index = 3000
	label.position = player.global_position + Vector2(-30, -48)
	label.size = Vector2(60, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", UiStyle.CREAM)
	label.add_theme_color_override("font_outline_color", UiStyle.DARK)
	label.add_theme_constant_override("outline_size", 3)
	Locale.apply_control(label)
	place.add_child(label)
	var rise: Tween = label.create_tween()
	rise.set_parallel(true)
	rise.tween_property(label, "position:y", label.position.y - 16.0, 0.9)
	rise.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.35)
	rise.chain().tween_callback(label.queue_free)

## A quick puff of dust, water, or chips where a tool lands.
func burst(at: Vector2, color: Color) -> void:
	var place: Node = _place()
	if place == null:
		return
	var puff: CPUParticles2D = CPUParticles2D.new()
	puff.position = at
	puff.z_index = 3000
	puff.amount = 8
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.lifetime = 0.4
	puff.spread = 180.0
	puff.direction = Vector2.UP
	puff.gravity = Vector2(0, 70)
	puff.initial_velocity_min = 14.0
	puff.initial_velocity_max = 34.0
	puff.scale_amount_min = 1.0
	puff.scale_amount_max = 2.0
	puff.color = color
	puff.finished.connect(puff.queue_free)
	place.add_child(puff)
	puff.emitting = true

func on_new_day() -> void:
	fished_today = false
	fish_day = -1
	rock_mined = false
	gathered.clear()
	apply_gathered()

## Opens the fishing game, or fishes at once when tests ask for quick fishing. A rested spot just says so.
func cast(place_name: String, spot_name: String = "FishingSpot") -> void:
	var game: FishGame = get_tree().current_scene.get_node_or_null("UI/FishGame") as FishGame if get_tree().current_scene != null else null
	if quick_fish or game == null or int(fish_spots.get("%s/%s" % [place_name, spot_name], -1)) == _day():
		fish_at(place_name, spot_name)
		return
	if game.is_open():
		return
	if not game.finished.is_connected(_on_fish_game):
		game.finished.connect(_on_fish_game)
	game.start(place_name, spot_name)

func _on_fish_game(caught: bool) -> void:
	var game: FishGame = get_tree().current_scene.get_node_or_null("UI/FishGame") as FishGame
	if caught and game != null:
		fish_at(game.place_name, game.spot_name)
	elif not caught:
		note = Locale.t("fish_lost")
		_refresh()

func fish_at(place_name: String, spot_name: String = "FishingSpot") -> bool:
	var key: String = "%s/%s" % [place_name, spot_name]
	if int(fish_spots.get(key, -1)) == _day():
		note = Locale.t("quiet")
		_refresh()
		return false
	fish_spots[key] = _day()
	if place_name == "Home" and spot_name == "FishingSpot":
		fished_today = true
		fish_day = _day()
	_inventory().add_item("fish", 1)
	note = Locale.t("caught")
	pop_item("fish")
	var works: VillageWorks = _works()
	if place_name == "Harbor" and works != null and works.is_done("dock") and randf() < PEARL_CHANCE:
		_inventory().add_item("pearl", 1)
		note = Locale.t("found_pearl")
	_chime("gather")
	_save()
	_refresh()
	return true

func take_daily(mark_key: String, item: String) -> bool:
	if int(gathered.get(mark_key, -1)) == _day():
		return false
	gathered[mark_key] = _day()
	_inventory().add_item(item, 1)
	note = _gather_note(item)
	pop_item(item)
	_chime("gather")
	_save()
	_refresh()
	apply_gathered()
	return true

func gather_node(spot: Node2D) -> bool:
	var kind: String = str(spot.get("group_name"))
	var item: String = ""
	match kind:
		"date":
			item = "dates"
		"forage":
			item = "forage"
		"tree":
			item = "wood"
		"rock":
			item = "stone"
		"ore":
			item = "copper"
		"shore":
			var finds: RandomNumberGenerator = RandomNumberGenerator.new()
			finds.seed = _day() * 131 + 7
			item = SHORE_FINDS[finds.randi_range(0, SHORE_FINDS.size() - 1)]
		_:
			return false
	var place: Node = spot.get_parent()
	if place == null:
		return false
	return take_daily(_mark_key(place, spot), item)

func give_stone() -> void:
	if rock_mined:
		return
	rock_mined = true
	var inventory: Inventory = _inventory()
	inventory.stone += 1
	note = Locale.t("broke_rock")
	_save()

func to_data() -> Dictionary:
	return {
		"quest_done": quest_done,
		"fished_today": fished_today,
		"fish_day": fish_day,
		"rock_mined": rock_mined,
		"gathered": gathered.duplicate(),
		"fish_spots": fish_spots.duplicate(),
	}

func from_data(data: Dictionary) -> void:
	quest_done = bool(data.get("quest_done", false))
	rock_mined = bool(data.get("rock_mined", false))
	if data.has("fish_day"):
		fish_day = int(data.get("fish_day", -1))
		fished_today = fish_day == _day()
	else:
		fish_day = -1
		fished_today = bool(data.get("fished_today", false))
	gathered.clear()
	var stored: Variant = data.get("gathered", {})
	if typeof(stored) == TYPE_DICTIONARY:
		for key: Variant in stored:
			if int(stored[key]) == _day():
				gathered[str(key)] = _day()
	fish_spots.clear()
	if data.has("fish_spots") and data["fish_spots"] is Dictionary:
		var stored_fish: Dictionary = data["fish_spots"]
		for key: Variant in stored_fish:
			if int(stored_fish[key]) == _day():
				fish_spots[str(key)] = _day()
	elif fish_day == _day():
		fish_spots["Home/FishingSpot"] = _day()
	apply_gathered()

func apply_gathered() -> void:
	var place: Node = _place()
	if place == null:
		return
	var today: int = _day()
	for mark: Node in place.get_children():
		if not mark is Node2D:
			continue
		var kind: String = str(mark.get("group_name"))
		if kind != "tree" and kind != "rock" and kind != "ore" and kind != "date" and kind != "forage" and kind != "shore":
			continue
		var taken: bool = gathered.has(_mark_key(place, mark)) and int(gathered[_mark_key(place, mark)]) == today
		_set_mark(mark as Node2D, not taken)
	for node: Node in get_tree().get_nodes_in_group("daily_spot"):
		if node.has_method("apply_day"):
			node.call("apply_day", gathered, today)

func _talk() -> void:
	var dialogue: DialogueBox = _dialogue()
	if dialogue.visible:
		return
	if not dialogue.picked.is_connected(_on_shop_choice):
		dialogue.picked.connect(_on_shop_choice)
	_shop = "menu"
	_gift_to = "jassim"
	dialogue.set_speaker("jassim")
	var greeting: String = _line("greeting")
	if not quest_done:
		greeting = Locale.t("greeting_quest")
	greeting = _friend_line("jassim", greeting)
	dialogue.offer(_with_request(greeting, "jassim"), _with_help("jassim", _menu_choices()))

func talk_role(role: String) -> void:
	var dialogue: DialogueBox = _dialogue()
	if dialogue.visible:
		return
	_listen(dialogue)
	_gift_to = role
	dialogue.set_speaker(role)
	match role:
		"workbench":
			_shop = "work"
			dialogue.offer(Locale.t("workbench"), _labeled(["craft", "build", "animals", "quests", "cancel"]))
		"carpenter":
			_shop = "work"
			var rows: PackedStringArray = _labeled(["craft", "build", "animals", "supplies", "give_food", "cancel"])
			dialogue.offer(_with_request(_friend_line(role, _line("carpenter")), role), _with_help(role, rows))
		"elder":
			_shop = "menu"
			dialogue.offer(_with_request(_friend_line(role, _elder_line()), role), _with_help(role, _elder_choices()))
		"fisherman":
			_shop = "menu"
			dialogue.offer(_with_request(_friend_line(role, _line("fisherman")), role), _with_help(role, _labeled(["give_food", "cancel"])))
		"merchant":
			_shop = "menu"
			var rows: PackedStringArray = _labeled(["sell_goods", "buy_seeds", "buy_feed", "give_food", "cancel"])
			dialogue.offer(_with_request(_friend_line(role, _line("merchant")), role), _with_help(role, rows))
		_:
			_talk()

func _on_shop_choice(choice: String) -> void:
	if choice == "give_food":
		_offer_gift()
		return
	if choice == "give_fund":
		_give_fund()
		return
	if choice == "help":
		_give_help()
		return
	if choice == "works":
		_fund_work()
		return
	if choice == "festival":
		_join_fair()
		return
	if _shop == "gift":
		_give_gift(choice)
		return
	if _shop == "menu":
		if choice == "sell_turnips" or choice == "Sell Turnips":
			_sell_to_jassim()
		elif choice == "sell_goods" or choice == "Sell Goods":
			_shop = "sell"
			_offer_sell()
		elif choice == "buy_seeds" or choice == "Buy Seeds":
			_shop = "seeds"
			_dialogue().offer(Locale.t("which_seed"), _seed_choices())
		elif choice == "buy_feed":
			_shop = ""
			var stead: Stead = _stead()
			if stead != null and stead.buy_feed():
				note = Locale.t("bought") % Locale.item("feed")
				_chime("coin")
				_save()
			else:
				note = Locale.t("need_dinars") % RecipeCatalog.FEED_PRICE
			_dialogue().open_lines(PackedStringArray([note]))
			_refresh()
		return
	if _shop == "sell":
		if choice == "cancel" or choice == "Cancel":
			_shop = ""
			return
		_sell_good(choice)
		return
	if _shop == "work":
		_work_choice(choice)
		return
	if _shop == "craft" or _shop == "build" or _shop == "animals" or _shop == "supplies":
		_work_action(choice)
		return
	if _shop != "seeds" or choice == "cancel" or choice == "Cancel":
		_shop = ""
		return
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		if choice != crop_id and choice != _seed_label(crop):
			continue
		_buy_seed(crop_id, crop)
		return

func _offer_gift() -> void:
	var kindness: Kindness = _kindness()
	if kindness == null:
		return
	if kindness.gifted_today(_gift_to):
		_say(Locale.t("gift_today"))
		return
	var inventory: Inventory = _inventory()
	var choices: PackedStringArray = []
	for item_id: String in Kindness.FOODS + Kindness.GIFTS:
		var count: int = inventory.count_of(item_id)
		if count > 0:
			choices.append("%s|%s x%d" % [item_id, Locale.item(item_id), count])
	if choices.is_empty():
		_say(Locale.t("no_food"))
		return
	choices.append("cancel|%s" % Locale.t("cancel"))
	_shop = "gift"
	_dialogue().offer(Locale.t("gift_which"), choices)

func _give_gift(choice: String) -> void:
	_shop = ""
	if choice == "cancel":
		return
	if _kindness().give_food(_gift_to, choice):
		note = Locale.t("gift_thanks") % Kindness.GIFT_POINTS
		var friends: Friendship = _friends()
		if friends != null:
			note = "%s %s" % [Locale.t("gift_" + friends.gift(_gift_to, choice)), note]
		_chime("gather")
		_save()
	else:
		note = Locale.t("cannot")
	_dialogue().open_lines(PackedStringArray([note]))
	_refresh()

func _give_fund() -> void:
	_shop = ""
	var kindness: Kindness = _kindness()
	if kindness == null:
		return
	if kindness.fund_done:
		_say(Locale.t("fund_today"))
		return
	if not kindness.give_fund():
		_say(Locale.t("need_dinars") % Kindness.FUND_PRICE)
		return
	note = Locale.t("gift_thanks") % Kindness.FUND_POINTS
	_chime("coin")
	_save()
	_dialogue().open_lines(PackedStringArray([note]))
	_refresh()

func _say(line: String) -> void:
	_shop = ""
	note = line
	_dialogue().open_lines(PackedStringArray([note]))
	_refresh()

func _give_help() -> void:
	var works: VillageWorks = _works()
	if works == null:
		return
	var wish: Dictionary = works.request_today()
	var pay: int = int(wish.get("pay", 0))
	if not works.fulfil_request():
		_say(Locale.t("request_short") % [int(wish.get("amount", 0)), Locale.item(str(wish.get("item", "")))])
		return
	note = Locale.t("request_done") % [pay, VillageWorks.REQUEST_POINTS]
	_chime("coin")
	_save()
	_dialogue().open_lines(PackedStringArray([note]))
	_refresh()

func _fund_work() -> void:
	var works: VillageWorks = _works()
	var stead: Stead = _stead()
	if works == null or stead == null:
		return
	var project: Dictionary = works.next_project()
	if project.is_empty():
		return
	if not works.fund_next():
		_say(Locale.t("need_items") % stead.missing_text(project["costs"]))
		return
	var lines: PackedStringArray = PackedStringArray([Locale.t("done_" + str(project["id"]))])
	note = lines[0]
	_chime("level")
	_save()
	if works.all_done():
		lines.append(Locale.t("works_all_done"))
	_dialogue().open_lines(lines)
	_refresh()

func _elder_choices() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	var works: VillageWorks = _works()
	var stead: Stead = _stead()
	if works != null and stead != null and stead.is_established():
		var project: Dictionary = works.next_project()
		if not project.is_empty():
			rows.append("works|%s: %s" % [Locale.t(str(project["id"])), Stead.cost_text(project["costs"])])
	var fairs: Festivals = _fairs()
	if fairs != null and fairs.can_join():
		rows.insert(0, "festival|%s" % (Locale.t("fair_join") % Locale.t("fair_" + str(fairs.today()["id"]))))
	rows.append_array(_labeled(["give_food", "give_fund", "cancel"]))
	return rows

func _elder_line() -> String:
	var works: VillageWorks = _works()
	var stead: Stead = _stead()
	if works != null and stead != null and stead.is_established():
		var project: Dictionary = works.next_project()
		if not project.is_empty():
			return Locale.t("ask_" + str(project["id"]))
	return _line("elder")

## One of a person's four lines, a different one each day.
func _line(role: String) -> String:
	var turn: int = _day() % 4
	return Locale.t(role if turn == 0 else "%s_%d" % [role, turn])

func _with_request(line: String, person: String) -> String:
	var works: VillageWorks = _works()
	if works == null or not works.can_help(person):
		return line
	var wish: Dictionary = works.request_today()
	return "%s\n%s" % [line, Locale.t("request_line") % [int(wish["amount"]), Locale.item(str(wish["item"]))]]

func _with_help(person: String, rows: PackedStringArray) -> PackedStringArray:
	var works: VillageWorks = _works()
	if works == null or not works.can_help(person):
		return rows
	var wish: Dictionary = works.request_today()
	var help_row: String = "help|%s" % (Locale.t("request_row") % [int(wish["amount"]), Locale.item(str(wish["item"])), int(wish["pay"])])
	var result: PackedStringArray = PackedStringArray([help_row])
	result.append_array(rows)
	return result

## A neighbor's heart talk or birthday line takes the place of today's greeting.
func _friend_line(person: String, line: String) -> String:
	var friends: Friendship = _friends()
	if friends == null:
		return line
	var special: String = friends.talk(person)
	_dialogue().set_hearts(friends.hearts(person))
	return special if special != "" else line

func _join_fair() -> void:
	var fairs: Festivals = _fairs()
	if fairs == null:
		return
	var fair: Dictionary = fairs.today()
	if not fairs.join():
		_say(Locale.t("fair_done"))
		return
	note = Locale.t("fair_gift") % [int(fair["amount"]), Locale.item(str(fair["gift"])), Festivals.KHAIR]
	_chime("level")
	_save()
	_dialogue().open_lines(PackedStringArray([Locale.t("fair_line_" + str(fair["id"])), note]))
	_refresh()

func _friends() -> Friendship:
	return get_parent().get_node_or_null("Friendship") as Friendship

func _fairs() -> Festivals:
	return get_parent().get_node_or_null("Festivals") as Festivals

func _works() -> VillageWorks:
	return get_parent().get_node_or_null("VillageWorks") as VillageWorks

func _kindness() -> Kindness:
	return get_parent().get_node_or_null("Kindness") as Kindness

func _sell_to_jassim() -> void:
	var inventory: Inventory = _inventory()
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if inventory.turnips <= 0:
		note = Locale.t("no_turnips")
		if hud != null and hud.has_method("dismiss_sale"):
			hud.call("dismiss_sale")
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	var sold: int = inventory.turnips
	var earned: int = inventory.sell_turnips()
	quest_done = true
	note = ""
	_chime("coin")
	_save()
	_refresh()
	if hud != null and hud.has_method("show_sale"):
		hud.call("show_sale", Locale.item("turnips"), sold, earned, inventory.turnips, inventory.dinars)

func _buy_seed(crop_id: String, crop: Dictionary) -> void:
	var inventory: Inventory = _inventory()
	var price: int = int(crop.get("seed_price", 0))
	var seed_name: String = Locale.item(str(crop.get("seed_item", "seeds")))
	if not inventory.try_buy_seed(crop_id):
		note = Locale.t("need_dinars") % price
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	note = Locale.t("bought") % seed_name
	_dialogue().open_lines(PackedStringArray([note]))
	_save()
	_refresh()

func _seed_choices() -> PackedStringArray:
	var choices: PackedStringArray = []
	for crop_id: String in CropCatalog.ids():
		choices.append("%s|%s" % [crop_id, _seed_label(CropCatalog.get_crop(crop_id))])
	choices.append("cancel|%s" % Locale.t("cancel"))
	return choices

func _seed_label(crop: Dictionary) -> String:
	return "%s  %d" % [Locale.item(str(crop.get("seed_item", "seeds"))), int(crop.get("seed_price", 0))]

func _menu_choices() -> PackedStringArray:
	return _labeled(["sell_turnips", "sell_goods", "buy_seeds", "give_food", "cancel"])

func _labeled(keys: Array) -> PackedStringArray:
	var choices: PackedStringArray = []
	for key: Variant in keys:
		choices.append("%s|%s" % [str(key), Locale.t(str(key))])
	return choices

func _listen(dialogue: DialogueBox) -> void:
	if not dialogue.picked.is_connected(_on_shop_choice):
		dialogue.picked.connect(_on_shop_choice)

func _offer_sell() -> void:
	var inventory: Inventory = _inventory()
	var choices: PackedStringArray = []
	for item_id: String in GoodsCatalog.sellable_ids():
		var count: int = inventory.count_of(item_id)
		var price: int = GoodsCatalog.sell_price(item_id)
		if count < 1 or price < 1:
			continue
		choices.append("%s|%s x%d  %d" % [item_id, Locale.item(item_id), count, count * price])
	if choices.is_empty():
		_shop = ""
		note = Locale.t("nothing_to_sell")
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	choices.append("cancel|%s" % Locale.t("cancel"))
	_dialogue().offer(Locale.t("sell_goods"), choices)

func _sell_good(item_id: String) -> void:
	var inventory: Inventory = _inventory()
	var sold: int = inventory.count_of(item_id)
	var earned: int = inventory.sell_stack(item_id)
	if earned < 1:
		note = Locale.t("nothing_to_sell")
		_dialogue().open_lines(PackedStringArray([note]))
		_refresh()
		return
	if item_id == "turnips":
		quest_done = true
	note = Locale.t("sold") % Locale.item(item_id)
	_chime("coin")
	_save()
	_refresh()
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if item_id == "turnips" and hud != null and hud.has_method("show_sale"):
		hud.call("show_sale", Locale.item(item_id), sold, earned, inventory.count_of(item_id), inventory.dinars)
	else:
		_dialogue().open_lines(PackedStringArray([note]))

func _work_choice(choice: String) -> void:
	var stead: Stead = _stead()
	if stead == null or choice == "cancel":
		_shop = ""
		return
	if choice == "quests":
		_shop = ""
		_dialogue().open_lines(PackedStringArray([stead.goal_text(), Locale.t("quests_body")]))
		return
	if choice == "craft":
		_shop = "craft"
		_dialogue().offer(Locale.t("craft"), PackedStringArray([
			"craft_feed|%s  (%s)" % [Locale.t("craft_feed"), Stead.cost_text(RecipeCatalog.recipe("feed")["costs"])],
			"craft_feed_herbs|%s" % Locale.t("craft_feed_herbs"),
			"cancel|%s" % Locale.t("cancel"),
		]))
		return
	if choice == "build":
		_shop = "build"
		var rows: PackedStringArray = _build_choices(stead)
		if rows.size() < 2:
			_say(Locale.t("all_built"))
			return
		_dialogue().offer(Locale.t("build"), rows)
		return
	if choice == "supplies":
		_shop = "supplies"
		var price: String = Locale.t("dinars") % RecipeCatalog.BUNDLE_PRICE
		_dialogue().offer(Locale.t("supplies"), PackedStringArray([
			"buy_wood|%d %s  %s" % [RecipeCatalog.BUNDLE_SIZE, Locale.item("wood"), price],
			"buy_stone|%d %s  %s" % [RecipeCatalog.BUNDLE_SIZE, Locale.item("stone"), price],
			"cancel|%s" % Locale.t("cancel"),
		]))
		return
	if choice == "animals":
		_shop = "animals"
		_dialogue().offer(Locale.t("animals"), _animal_choices(stead))
		return
	_shop = ""

func _build_choices(stead: Stead) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for building_id: String in RecipeCatalog.BUILD_ORDER:
		if stead.can_offer(building_id):
			rows.append("%s|%s: %s" % [building_id, Locale.t(building_id), Stead.cost_text(RecipeCatalog.building(building_id)["costs"])])
	rows.append("cancel|%s" % Locale.t("cancel"))
	return rows

func _animal_choices(stead: Stead) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for kind: String in RecipeCatalog.ANIMALS:
		var spec: Dictionary = RecipeCatalog.animal(kind)
		if stead.count_kind(kind) > 0:
			rows.append("feed_%s|%s  x%d" % [kind, Locale.t("feed_" + kind), stead.count_kind(kind)])
		if stead.count_kind(kind) < stead.animal_cap(kind):
			rows.append("buy_%s|%s  %s" % [kind, Locale.t("buy_" + kind), Locale.t("dinars") % int(spec["price"])])
	rows.append("cancel|%s" % Locale.t("cancel"))
	return rows

## Says what is missing, so a refused tap never leaves the player guessing.
func _refusal(stead: Stead, shop: String, choice: String) -> String:
	if shop == "build":
		return Locale.t("need_items") % stead.missing_text(RecipeCatalog.building(choice).get("costs", {}))
	if shop == "supplies":
		return Locale.t("need_dinars") % RecipeCatalog.BUNDLE_PRICE
	if shop == "craft":
		var spec: Dictionary = RecipeCatalog.recipe("feed" if choice == "craft_feed" else "feed_herbs")
		return Locale.t("need_items") % stead.missing_text(spec.get("costs", {}))
	if shop == "animals" and choice.begins_with("buy_"):
		var spec: Dictionary = RecipeCatalog.animal(choice.trim_prefix("buy_"))
		var home: String = str(spec.get("home", ""))
		if not stead.is_built(home):
			return Locale.t("need_home") % Locale.t(home)
		return Locale.t("need_dinars") % int(spec.get("price", 0))
	if shop == "animals" and choice.begins_with("feed_"):
		return Locale.t("need_feed")
	return Locale.t("cannot")

func _work_action(choice: String) -> void:
	var stead: Stead = _stead()
	var shop: String = _shop
	_shop = ""
	if stead == null or choice == "cancel":
		return
	var ok: bool = false
	var line: String = Locale.t("cannot")
	if shop == "craft" and (choice == "craft_feed" or choice == "craft_feed_herbs"):
		ok = stead.craft("feed" if choice == "craft_feed" else "feed_herbs")
		line = Locale.t("made") % Locale.item("feed")
	elif shop == "build":
		ok = stead.build(choice)
		line = Locale.t("built") % Locale.t(choice)
	elif shop == "supplies":
		var item: String = "wood" if choice == "buy_wood" else "stone"
		ok = stead.buy_bundle(item)
		line = Locale.t("bought") % Locale.item(item)
	elif shop == "animals" and choice.begins_with("buy_"):
		var kind: String = choice.trim_prefix("buy_")
		ok = stead.buy_animal(kind)
		line = Locale.t("bought") % Locale.t(kind)
	elif shop == "animals" and choice.begins_with("feed_"):
		var kind: String = choice.trim_prefix("feed_")
		var fed: int = stead.feed_kind(kind)
		ok = fed > 0
		line = Locale.t("fed") % fed
	if not ok:
		note = _refusal(stead, shop, choice)
	else:
		note = line
		_chime("ui")
		_save()
	_dialogue().open_lines(PackedStringArray([note]))
	_refresh()

func _stead() -> Stead:
	return get_parent().get_node_or_null("Stead") as Stead

func _chime(kind: String) -> void:
	var bank: Node = get_parent().get_node_or_null("SoundBank")
	if bank != null and bank.has_method("play"):
		bank.call("play", kind)

func _dialogue() -> DialogueBox:
	return get_tree().current_scene.get_node("UI/Dialogue") as DialogueBox

## A note fades after a few seconds, so the next goal comes back under the day.
func display_note() -> String:
	if _flash != "":
		return _flash
	if note != _shown_note:
		_shown_note = note
		_shown_at = Time.get_ticks_msec()
	elif note != "" and Time.get_ticks_msec() - _shown_at > NOTE_MS:
		note = ""
		_shown_note = ""
	return note

func flash(text: String) -> void:
	_flash_token += 1
	var token: int = _flash_token
	_flash = text
	_refresh()
	await get_tree().create_timer(2.0).timeout
	if token != _flash_token:
		return
	_flash = ""
	_refresh()

func _refresh() -> void:
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud != null and hud.has_method("refresh"):
		hud.refresh()

func _fish() -> void:
	var place: Node = _place()
	fish_at(place.name if place != null else "Home")

func _enter_cave() -> void:
	var loader: LevelLoader = get_parent().get_node("LevelLoader") as LevelLoader
	var cave: PackedScene = load("res://src/scenes/world/cave/Cave.tscn") as PackedScene
	loader.go_to(cave, "PlayerSpawn")

func _group_has(group_name: String, dirt: TileMapLayer, cell: Vector2i) -> bool:
	var place: Node = _place()
	if place == null:
		return false
	for mark: Node in place.get_children():
		if not mark.is_in_group(group_name) or not mark is Node2D:
			continue
		var spot: Node2D = mark as Node2D
		if dirt.local_to_map(dirt.to_local(spot.global_position)) == cell:
			return true
	return false

func _take_mark(group_name: String, dirt: TileMapLayer, cell: Vector2i, item: String) -> bool:
	var place: Node = _place()
	if place == null:
		return false
	for mark: Node in place.get_children():
		if not mark.is_in_group(group_name) or not mark is Node2D:
			continue
		var spot: Node2D = mark as Node2D
		if dirt.local_to_map(dirt.to_local(spot.global_position)) != cell:
			continue
		var key: String = _mark_key(place, spot)
		if gathered.has(key) and int(gathered[key]) == _day():
			return false
		var inventory: Inventory = _inventory()
		inventory.add_item(item, 1)
		note = _gather_note(item)
		pop_item(item)
		gathered[key] = _day()
		_set_mark(spot, false)
		_save()
		_refresh()
		return true
	return false

func _gather_note(item: String) -> String:
	match item:
		"wood":
			return Locale.t("cut_tree")
		"stone":
			return Locale.t("broke_rock")
		"dates":
			return Locale.t("picked_date")
		"forage":
			return Locale.t("picked_herb")
		"copper":
			return Locale.t("found_copper")
		_:
			return Locale.t("made") % Locale.item(item)

## Markers and walls have no role at all, which is not the same as a person's role.
static func role_of(mark: Node) -> String:
	var role: Variant = mark.get("role")
	return "" if role == null else str(role)

func _role_at(place: Node, dirt: TileMapLayer, cell: Vector2i) -> String:
	for mark: Node in place.get_children():
		if Activities.role_of(mark) == "" or not mark is Node2D:
			continue
		var spot: Node2D = mark as Node2D
		if dirt.local_to_map(dirt.to_local(spot.global_position)) == cell:
			return Activities.role_of(mark)
	return ""

func _mark_key(place: Node, spot: Node) -> String:
	return "%s/%s" % [place.name, spot.name]

func _day() -> int:
	var clock: GameClock = get_parent().get_node("Clock") as GameClock
	return clock.day

func _set_mark(spot: Node2D, available: bool) -> void:
	spot.visible = available
	spot.set_process(available)
	var kind: String = str(spot.get("group_name"))
	if available:
		if kind != "" and not spot.is_in_group(kind):
			spot.add_to_group(kind)
	elif kind != "" and spot.is_in_group(kind):
		spot.remove_from_group(kind)
	var block: StaticBody2D = spot.get_node_or_null("Block") as StaticBody2D
	if block != null:
		block.set_collision_layer_value(1, available)

func _matches(place: Node, node_name: String, dirt: TileMapLayer, cell: Vector2i) -> bool:
	var mark: Node2D = place.get_node_or_null(node_name) as Node2D
	if mark == null:
		return false
	return dirt.local_to_map(dirt.to_local(mark.global_position)) == cell

func _place() -> Node:
	var world: Node = get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return null
	for child: Node in world.get_children():
		if child.name == "Player":
			continue
		return child
	return null

func _inventory() -> Inventory:
	return get_parent().get_node("Inventory") as Inventory

func _save() -> void:
	var stead: Stead = _stead()
	if stead != null and stead.check_milestone():
		note = Locale.t("milestone")
		_chime("coin")
	var kindness: Kindness = _kindness()
	if kindness != null and kindness.take_level_up():
		note = Locale.t("khair_rise")
		_chime("level")
	var save: SaveGame = get_parent().get_node("SaveGame") as SaveGame
	save.write_now()
