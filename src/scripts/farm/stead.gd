# src/scripts/farm/stead.gd
# Purpose: Buildings, animals, tool upgrades, and the main quest steps.

class_name Stead
extends Node

var coop: bool = false
var barn: bool = false
var expanded: bool = false
var tool_level: int = 0
var animals: Array = []
var flags: Dictionary = {}
var visited: Dictionary = {}
var place_name: String = "Home"
var language: String = "ar"
## 0 is off, 1 is soft, 2 is full.
var music_level: int = 2
var sfx_level: int = 2
## Shows the next real prayer time in the menu and a gentle note when one comes.
var prayer_reminder: bool = true
## One gentle phone notification a day while the game is closed, such as ripe crops.
var phone_notices: bool = true

const SCENES: Dictionary = {
	"Home": "res://src/scenes/world/home/Home.tscn",
	"Village": "res://src/scenes/world/village/Village.tscn",
	"Harbor": "res://src/scenes/world/harbor/Harbor.tscn",
	"Orchard": "res://src/scenes/world/orchard/Orchard.tscn",
	"Cave": "res://src/scenes/world/cave/Cave.tscn",
	"Road": "res://src/scenes/world/road/Road.tscn",
	"Forest": "res://src/scenes/world/forest/Forest.tscn",
	"HouseInside": "res://src/scenes/world/house/House_inside.tscn",
	"MosqueInside": "res://src/scenes/world/mosque/Mosque_inside.tscn",
	"WorkshopInside": "res://src/scenes/world/workshop/Workshop_inside.tscn",
}

func scene_for(place: String) -> String:
	return str(SCENES.get(place, ""))

func note_place(place: String) -> void:
	place_name = place
	visited[place] = true

func craft(recipe_id: String) -> bool:
	var spec: Dictionary = RecipeCatalog.recipe(recipe_id)
	if spec.is_empty() or not _pay(spec.get("costs", {})):
		return false
	_grant(spec.get("outputs", {}))
	if spec.get("outputs", {}).has("feed"):
		flags["crafted_feed"] = true
	return true

func buy_feed() -> bool:
	var bag: Inventory = _bag()
	if bag == null or bag.dinars < RecipeCatalog.FEED_PRICE:
		return false
	bag.dinars -= RecipeCatalog.FEED_PRICE
	bag.add_item("feed", 1)
	return true

func build(building_id: String) -> bool:
	if not can_offer(building_id):
		return false
	var spec: Dictionary = RecipeCatalog.building(building_id)
	if not _pay(spec.get("costs", {})):
		return false
	if building_id == "coop":
		coop = true
	elif building_id == "barn":
		barn = true
	elif building_id == "expand":
		expanded = true
	elif building_id == "tools":
		tool_level = 1
	elif building_id == "tools2":
		tool_level = 2
	else:
		flags["built_" + building_id] = true
	apply_buildings()
	return true

func is_built(building_id: String) -> bool:
	match building_id:
		"coop":
			return coop
		"barn":
			return barn
		"expand":
			return expanded
		"tools":
			return tool_level >= 1
		"tools2":
			return tool_level >= 2
	return bool(flags.get("built_" + building_id, false))

## True when the thing is not built yet and what it depends on is standing.
func can_offer(building_id: String) -> bool:
	var spec: Dictionary = RecipeCatalog.building(building_id)
	if spec.is_empty() or is_built(building_id):
		return false
	var requires: String = str(spec.get("requires", ""))
	return requires == "" or is_built(requires)

func pay_costs(costs: Variant) -> bool:
	return _pay(costs)

## Spends dinars on a bundle of wood or stone from the carpenter.
func buy_bundle(item_id: String) -> bool:
	var bag: Inventory = _bag()
	if bag == null or bag.dinars < RecipeCatalog.BUNDLE_PRICE:
		return false
	bag.dinars -= RecipeCatalog.BUNDLE_PRICE
	bag.add_item(item_id, RecipeCatalog.BUNDLE_SIZE)
	return true

static func cost_text(costs: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key: Variant in costs:
		if str(key) == "dinars":
			parts.append(Locale.t("dinars") % int(costs[key]))
		else:
			parts.append("%d %s" % [int(costs[key]), Locale.item(str(key))])
	return Locale.t("list_join").join(parts)

## Only what is still missing, for the line that says why something cannot be paid yet.
func missing_text(costs: Dictionary) -> String:
	var bag: Inventory = _bag()
	var short: Dictionary = {}
	for key: Variant in costs:
		var have: int = bag.dinars if str(key) == "dinars" else bag.count_of(str(key))
		if have < int(costs[key]):
			short[key] = int(costs[key]) - have
	return Stead.cost_text(short)

func animal_cap(kind: String) -> int:
	var spec: Dictionary = RecipeCatalog.animal(kind)
	var bigger: bool = is_built("coop2") if str(spec.get("home", "")) == "coop" else is_built("barn2")
	return int(spec.get("cap", 0)) * (2 if bigger else 1)

func buy_animal(kind: String) -> bool:
	var spec: Dictionary = RecipeCatalog.animal(kind)
	if spec.is_empty():
		return false
	if str(spec.get("home", "")) == "coop" and not coop:
		return false
	if str(spec.get("home", "")) == "barn" and not barn:
		return false
	if count_kind(kind) >= animal_cap(kind):
		return false
	var bag: Inventory = _bag()
	var price: int = int(spec.get("price", 0))
	if bag == null or bag.dinars < price:
		return false
	bag.dinars -= price
	animals.append({"kind": kind, "fed": false})
	apply_buildings()
	return true

func feed_kind(kind: String) -> int:
	var spec: Dictionary = RecipeCatalog.animal(kind)
	var bag: Inventory = _bag()
	if spec.is_empty() or bag == null:
		return 0
	var fed_count: int = 0
	var need: int = int(spec.get("feed", 1))
	for index: int in animals.size():
		var animal: Dictionary = animals[index]
		if str(animal.get("kind", "")) != kind or bool(animal.get("fed", false)):
			continue
		if bag.count_of("feed") < need:
			break
		if not bag.take_item("feed", need):
			break
		animal["fed"] = true
		animals[index] = animal
		fed_count += 1
	if fed_count > 0:
		apply_buildings()
		var kindness: Kindness = get_parent().get_node_or_null("Kindness") as Kindness
		if kindness != null:
			kindness.note_feeding()
	return fed_count

func on_new_day() -> String:
	var bag: Inventory = _bag()
	if bag == null:
		return ""
	var produced: bool = false
	var hungry: int = 0
	for index: int in animals.size():
		var animal: Dictionary = animals[index]
		var spec: Dictionary = RecipeCatalog.animal(str(animal.get("kind", "")))
		if spec.is_empty():
			continue
		if not bool(animal.get("fed", false)):
			hungry += 1
			continue
		var product: String = str(spec.get("product", ""))
		bag.add_item(product, int(spec.get("amount", 1)))
		animal["fed"] = false
		animals[index] = animal
		produced = true
		if product == "eggs":
			flags["got_egg"] = true
		else:
			flags["got_barn_product"] = true
	apply_buildings()
	if produced:
		return Locale.t("produced")
	if hungry > 0:
		return Locale.t("hungry")
	return ""

func count_kind(kind: String) -> int:
	var total: int = 0
	for animal: Variant in animals:
		if animal is Dictionary and str(animal.get("kind", "")) == kind:
			total += 1
	return total

func goal_text() -> String:
	var activities: Node = get_parent().get_node_or_null("Activities")
	var quest_done: bool = activities != null and bool(activities.get("quest_done"))
	if not quest_done:
		return first_step()
	if not bool(flags.get("crafted_feed", false)):
		return _with_missing("quest_feed", _step_costs("quest_feed"))
	if not coop:
		return _with_missing("quest_coop", _step_costs("quest_coop"))
	if count_kind("chicken") < 1:
		return _with_missing("quest_chicken", _step_costs("quest_chicken"))
	if not bool(flags.get("got_egg", false)):
		return Locale.t("quest_egg")
	if not bool(visited.get("Harbor", false)):
		return Locale.t("quest_harbor")
	if not bool(visited.get("Orchard", false)):
		return Locale.t("quest_orchard")
	if not barn:
		return _with_missing("quest_barn", _step_costs("quest_barn"))
	if count_kind("goat") + count_kind("sheep") + count_kind("cow") < 1 and not bool(flags.get("got_barn_product", false)):
		return _with_missing("quest_barn_animal", _step_costs("quest_barn_animal"))
	if not bool(flags.get("got_barn_product", false)):
		return Locale.t("quest_barn_product")
	var works: VillageWorks = get_parent().get_node_or_null("VillageWorks") as VillageWorks
	if works == null:
		return Locale.t("quest_established")
	if works.finished:
		return Locale.t("quest_free")
	if works.festival_ready():
		return Locale.t("quest_festival")
	var project: Dictionary = works.next_project()
	if not project.is_empty():
		return Locale.t("quest_work") % Locale.t(str(project["id"]))
	var kindness: Kindness = get_parent().get_node_or_null("Kindness") as Kindness
	return Locale.t("quest_khair") % (kindness.points if kindness != null else 0)

## What a quest step costs, so its line can say what is still missing. Empty for steps that cost nothing.
func _step_costs(step_key: String) -> Dictionary:
	match step_key:
		"quest_feed":
			return RecipeCatalog.recipe("feed_herbs").get("costs", {})
		"quest_coop":
			return RecipeCatalog.building("coop").get("costs", {})
		"quest_barn":
			return RecipeCatalog.building("barn").get("costs", {})
		"quest_chicken":
			return {"dinars": int(RecipeCatalog.animal("chicken").get("price", 0))}
		"quest_barn_animal":
			return {"dinars": int(RecipeCatalog.animal("sheep").get("price", 0))}
	return {}

## The quest line, with what the boy still lacks for it added when he lacks something.
func _with_missing(step_key: String, costs: Dictionary) -> String:
	var missing: String = missing_text(costs)
	if missing == "":
		return Locale.t(step_key)
	return "%s. %s" % [Locale.t(step_key), Locale.t("need_items") % missing]

## One short line on where to find the first thing the current quest step still lacks, or "".
func where_hint() -> String:
	var activities: Node = get_parent().get_node_or_null("Activities")
	if activities == null or not bool(activities.get("quest_done")):
		return ""
	for step: Dictionary in steps():
		if bool(step["done"]):
			continue
		return where_text(_step_costs(str(step["key"])))
	return ""

## Where to find the first missing thing in these costs, or "" when nothing is missing or it has no hint.
func where_text(costs: Dictionary) -> String:
	var bag: Inventory = _bag()
	if bag == null:
		return ""
	for key: Variant in costs:
		var item_id: String = str(key)
		var have: int = bag.dinars if item_id == "dinars" else bag.count_of(item_id)
		if have >= int(costs[key]):
			continue
		var hint: String = Locale.t("where_" + item_id)
		if hint != "where_" + item_id:
			return hint
	return ""

## Pays the one-time village thanks when the farm goal is first reached.
func check_milestone() -> bool:
	if bool(flags.get("celebrated", false)) or not is_established():
		return false
	flags["celebrated"] = true
	var bag: Inventory = _bag()
	if bag != null:
		bag.dinars += 300
	return true

## Before the first sale, the line under the day walks a new player through one small step at a time.
func first_step() -> String:
	if not bool(flags.get("met_jassim", false)):
		return Locale.t("step_hello")
	var bag: Inventory = _bag()
	if bag != null and bag.turnips > 0:
		return Locale.t("quest_turnip")
	var farm: FarmField = get_parent().get_node_or_null("FarmField") as FarmField
	if farm == null:
		return Locale.t("quest_turnip")
	if farm.has_ripe():
		return Locale.t("step_harvest")
	var dug: bool = false
	var growing: bool = false
	var dry: bool = false
	for key: String in farm.plots.keys():
		var plot: Dictionary = farm.plots[key]
		if not bool(plot.get("tilled", false)) or bool(plot.get("sprinkler", false)):
			continue
		dug = true
		if int(plot.get("stage", -1)) >= 0:
			growing = true
			if not bool(plot.get("watered", false)):
				dry = true
	if growing and dry:
		return Locale.t("step_water")
	if growing:
		# From the second morning, the wait for the first turnips is a good time to meet the village.
		var friends: Friendship = get_parent().get_node_or_null("Friendship") as Friendship
		var clock: GameClock = get_parent().get_node_or_null("Clock") as GameClock
		if friends != null and clock != null and clock.day >= 2 and friends.met_count() < Friendship.PEOPLE.size():
			return Locale.t("step_meet") % [friends.met_count(), Friendship.PEOPLE.size()]
		# Then the woods, where the wood, stone and herbs for the first buildings are.
		if clock != null and clock.day >= 2 and not bool(visited.get("Forest", false)):
			return Locale.t("step_woods")
		return Locale.t("step_sleep")
	return Locale.t("step_plant") if dug else Locale.t("step_dig")

func steps() -> Array[Dictionary]:
	var activities: Node = get_parent().get_node_or_null("Activities")
	var quest_done: bool = activities != null and bool(activities.get("quest_done"))
	return [
		{"key": "quest_turnip", "done": quest_done},
		{"key": "quest_feed", "done": bool(flags.get("crafted_feed", false))},
		{"key": "quest_coop", "done": coop},
		{"key": "quest_chicken", "done": count_kind("chicken") > 0 or bool(flags.get("got_egg", false))},
		{"key": "quest_egg", "done": bool(flags.get("got_egg", false))},
		{"key": "quest_harbor", "done": bool(visited.get("Harbor", false))},
		{"key": "quest_orchard", "done": bool(visited.get("Orchard", false))},
		{"key": "quest_barn", "done": barn},
		{"key": "quest_barn_animal", "done": bool(flags.get("got_barn_product", false)) or count_kind("goat") + count_kind("sheep") + count_kind("cow") > 0},
	]

func is_established() -> bool:
	return bool(flags.get("got_egg", false)) \
		and bool(flags.get("got_barn_product", false)) \
		and bool(visited.get("Harbor", false)) \
		and bool(visited.get("Orchard", false)) \
		and coop and barn

func apply_buildings() -> void:
	var farm: FarmField = get_parent().get_node_or_null("FarmField") as FarmField
	if farm != null and expanded:
		farm.farm_size = FarmField.LARGEST_SIZE if is_built("expand2") else FarmField.LARGER_SIZE
	var bag: Inventory = _bag()
	if bag != null:
		bag.max_hearts = 7.0 if is_built("house") else 5.0
	var place: Node = _place()
	if place == null:
		return
	PlaceDecor.dress(place, flags)
	var gatherers: Activities = get_parent().get_node_or_null("Activities") as Activities
	if gatherers != null:
		gatherers.apply_gathered()
	for decor_id: String in RecipeCatalog.DECOR:
		var piece: Dictionary = RecipeCatalog.DECOR[decor_id]
		if is_built(decor_id) and str(piece["place"]) == str(place.name) and place.get_node_or_null(str(piece["name"])) == null:
			PropPiece.add_to(place, piece)
	var works: VillageWorks = get_parent().get_node_or_null("VillageWorks") as VillageWorks
	if works != null:
		works.apply_place()
	var fairs: Festivals = get_parent().get_node_or_null("Festivals") as Festivals
	if fairs != null:
		fairs.apply_place()
	var coop_node: CanvasItem = place.get_node_or_null("Coop") as CanvasItem
	if coop_node != null:
		coop_node.visible = coop
	var barn_node: CanvasItem = place.get_node_or_null("Barn") as CanvasItem
	if barn_node != null:
		barn_node.visible = barn
	for building: CanvasItem in [coop_node, barn_node]:
		if building == null:
			continue
		var block: StaticBody2D = building.get_node_or_null("Block") as StaticBody2D
		if block != null:
			block.set_collision_layer_value(1, building.visible)
	var pen: Node = place.get_node_or_null("Pen")
	if pen != null and pen.has_method("sync"):
		pen.call("sync", animals)

func to_data() -> Dictionary:
	return {
		"coop": coop,
		"barn": barn,
		"expanded": expanded,
		"tool_level": tool_level,
		"animals": animals.duplicate(true),
		"flags": flags.duplicate(true),
		"visited": visited.duplicate(true),
		"place_name": place_name,
		"language": language,
		"music_level": music_level,
		"sfx_level": sfx_level,
		"prayer_reminder": prayer_reminder,
		"phone_notices": phone_notices,
	}

func from_data(data: Dictionary) -> void:
	coop = bool(data.get("coop", false))
	barn = bool(data.get("barn", false))
	expanded = bool(data.get("expanded", false))
	tool_level = int(data.get("tool_level", 0))
	animals = []
	var stored_animals: Variant = data.get("animals", [])
	if stored_animals is Array:
		for row: Variant in stored_animals:
			if row is Dictionary and RecipeCatalog.animal(str(row.get("kind", ""))) != {}:
				animals.append({
					"kind": str(row.get("kind", "")),
					"fed": bool(row.get("fed", false)),
				})
	flags = {}
	var stored_flags: Variant = data.get("flags", {})
	if stored_flags is Dictionary:
		for key: Variant in stored_flags:
			flags[str(key)] = bool(stored_flags[key])
	visited = {}
	var stored_visits: Variant = data.get("visited", {})
	if stored_visits is Dictionary:
		for key: Variant in stored_visits:
			visited[str(key)] = bool(stored_visits[key])
	place_name = str(data.get("place_name", "Home"))
	if not SCENES.has(place_name):
		place_name = "Home"
	language = str(data.get("language", "ar"))
	if language != "ar" and language != "en":
		language = "ar"
	music_level = clampi(int(data.get("music_level", 2)), 0, 2)
	sfx_level = clampi(int(data.get("sfx_level", 2 if bool(data.get("sfx", true)) else 0)), 0, 2)
	prayer_reminder = bool(data.get("prayer_reminder", true))
	phone_notices = bool(data.get("phone_notices", true))
	Locale.language = language
	apply_buildings()

func _pay(costs: Variant) -> bool:
	if not costs is Dictionary or not _can_pay(costs):
		return false
	var bag: Inventory = _bag()
	for key: Variant in costs:
		var amount: int = int(costs[key])
		if str(key) == "dinars":
			bag.dinars -= amount
		elif not bag.take_item(str(key), amount):
			return false
	return true

func _can_pay(costs: Dictionary) -> bool:
	var bag: Inventory = _bag()
	if bag == null:
		return false
	for key: Variant in costs:
		var amount: int = int(costs[key])
		if amount < 1:
			continue
		if str(key) == "dinars":
			if bag.dinars < amount:
				return false
		elif bag.count_of(str(key)) < amount:
			return false
	return true

func _grant(outputs: Variant) -> void:
	if not outputs is Dictionary:
		return
	var bag: Inventory = _bag()
	for key: Variant in outputs:
		bag.add_item(str(key), int(outputs[key]))

func _bag() -> Inventory:
	return get_parent().get_node_or_null("Inventory") as Inventory

func _place() -> Node:
	var world: Node = get_tree().current_scene.get_node_or_null("World") if get_tree().current_scene != null else null
	if world == null:
		return null
	for child: Node in world.get_children():
		if child.name != "Player":
			return child
	return null
