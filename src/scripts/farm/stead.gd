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
var sfx: bool = true

const SCENES: Dictionary = {
	"Home": "res://src/scenes/world/home/Home.tscn",
	"Village": "res://src/scenes/world/village/Village.tscn",
	"Harbor": "res://src/scenes/world/harbor/Harbor.tscn",
	"Orchard": "res://src/scenes/world/orchard/Orchard.tscn",
	"Cave": "res://src/scenes/world/cave/Cave.tscn",
	"HouseInside": "res://src/scenes/world/house/House_inside.tscn",
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
	if recipe_id == "feed":
		flags["crafted_feed"] = true
	return true

func build(building_id: String) -> bool:
	var spec: Dictionary = RecipeCatalog.building(building_id)
	if spec.is_empty():
		return false
	if building_id == "coop" and coop:
		return false
	if building_id == "barn" and (barn or not coop):
		return false
	if building_id == "expand" and expanded:
		return false
	if building_id == "tools" and tool_level >= 1:
		return false
	var requires: String = str(spec.get("requires", ""))
	if requires == "coop" and not coop:
		return false
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
	apply_buildings()
	return true

func buy_animal(kind: String) -> bool:
	var spec: Dictionary = RecipeCatalog.animal(kind)
	if spec.is_empty():
		return false
	if str(spec.get("home", "")) == "coop" and not coop:
		return false
	if str(spec.get("home", "")) == "barn" and not barn:
		return false
	if count_kind(kind) >= int(spec.get("cap", 0)):
		return false
	var bag: Inventory = _bag()
	var price: int = int(spec.get("price", 0))
	if bag == null or bag.dinars < price:
		return false
	bag.dinars -= price
	animals.append({"kind": kind, "fed": false})
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
		return Locale.t("quest_turnip")
	if not bool(flags.get("crafted_feed", false)):
		return Locale.t("quest_feed")
	if not coop:
		return Locale.t("quest_coop")
	if count_kind("chicken") < 1:
		return Locale.t("quest_chicken")
	if not bool(flags.get("got_egg", false)):
		return Locale.t("quest_egg")
	if not bool(visited.get("Harbor", false)):
		return Locale.t("quest_harbor")
	if not bool(visited.get("Orchard", false)):
		return Locale.t("quest_orchard")
	if not barn:
		return Locale.t("quest_barn")
	if count_kind("goat") + count_kind("sheep") + count_kind("cow") < 1:
		return Locale.t("quest_barn_animal")
	return Locale.t("quest_established")

func is_established() -> bool:
	return bool(flags.get("got_egg", false)) \
		and bool(flags.get("got_barn_product", false)) \
		and bool(visited.get("Harbor", false)) \
		and bool(visited.get("Orchard", false)) \
		and coop and barn

func apply_buildings() -> void:
	var farm: FarmField = get_parent().get_node_or_null("FarmField") as FarmField
	if farm != null and expanded:
		farm.farm_size = Vector2i(4, 4)
	var place: Node = _place()
	if place == null:
		return
	var coop_node: CanvasItem = place.get_node_or_null("Coop") as CanvasItem
	if coop_node != null:
		coop_node.visible = coop
	var barn_node: CanvasItem = place.get_node_or_null("Barn") as CanvasItem
	if barn_node != null:
		barn_node.visible = barn

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
		"sfx": sfx,
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
	sfx = bool(data.get("sfx", true))
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
