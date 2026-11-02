# src/scripts/farm/inventory.gd
# Purpose: Keeps seeds, crops, gathered goods, and dinars.

class_name Inventory
extends Node

var seeds: int = 8
var turnips: int = 0
var tomato_seeds: int = 4
var tomatoes: int = 0
var wheat_seeds: int = 4
var wheat: int = 0
var watermelon_seeds: int = 2
var watermelons: int = 0
var selected_seed: String = "turnip"
var fish: int = 0
var stone: int = 0
var dinars: int = 0
var wood: int = 0
var dates: int = 0
var forage: int = 0
var hearts: float = 5.0
var max_hearts: float = 5.0
var extra: Dictionary = {}

const TOOL_TIRE: float = 0.1
const STORED_GOODS: Array[String] = [
	"seeds", "tomato_seeds", "wheat_seeds", "watermelon_seeds",
	"turnips", "tomatoes", "wheat", "watermelons",
	"wood", "stone", "fish", "dates", "forage",
]

func spend_heart() -> bool:
	if hearts < 1.0:
		return false
	hearts -= 1.0
	return true

func refill_hearts() -> void:
	hearts = max_hearts

## Each tool swing tires the boy a little. False means he must rest or eat first.
func tire() -> bool:
	if hearts < TOOL_TIRE * 0.1:
		return false
	hearts = maxf(0.0, hearts - TOOL_TIRE)
	return true

## Eats the cheapest food in the bag for one heart. Returns its id, or "" when nothing was eaten.
func eat_something() -> String:
	if hearts >= max_hearts:
		return ""
	var choice: String = ""
	for item_id: String in Kindness.FOODS:
		if count_of(item_id) < 1:
			continue
		if choice == "" or GoodsCatalog.sell_price(item_id) < GoodsCatalog.sell_price(choice):
			choice = item_id
	if choice == "" or not take_item(choice, 1):
		return ""
	hearts = minf(max_hearts, hearts + 1.0)
	return choice

func try_craft_seeds() -> bool:
	if stone < 2:
		return false
	stone -= 2
	seeds += 3
	return true

static func all_stored_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray(STORED_GOODS)
	for item_id: String in GoodsCatalog.extra_ids():
		ids.append(item_id)
	return ids

func sell_stack(item_id: String) -> int:
	var price: int = GoodsCatalog.sell_price(item_id)
	var have: int = count_of(item_id)
	if price < 1 or have < 1:
		return 0
	if not take_item(item_id, have):
		return 0
	var earned: int = _with_market(price * have)
	dinars += earned
	return earned

func sell_turnips() -> int:
	var price: int = int(CropCatalog.get_crop(CropCatalog.TURNIP).get("sell_price", 20))
	var earned: int = _with_market(turnips * price)
	dinars += earned
	turnips = 0
	return earned

func try_buy_seed(crop_id: String) -> bool:
	var crop: Dictionary = CropCatalog.get_crop(crop_id)
	if crop.is_empty():
		return false
	var price: int = int(crop.get("seed_price", 0))
	if dinars < price:
		return false
	dinars -= price
	add_item(str(crop.get("seed_item", "")), 1)
	return true

func count_of(item_id: String) -> int:
	match item_id:
		"seeds":
			return seeds
		"turnips":
			return turnips
		"tomato_seeds":
			return tomato_seeds
		"tomatoes":
			return tomatoes
		"wheat_seeds":
			return wheat_seeds
		"wheat":
			return wheat
		"watermelon_seeds":
			return watermelon_seeds
		"watermelons":
			return watermelons
		"fish":
			return fish
		"stone":
			return stone
		"wood":
			return wood
		"dates":
			return dates
		"forage":
			return forage
		_:
			return maxi(0, int(extra.get(item_id, 0)))

func add_item(item_id: String, amount: int) -> void:
	_set_item(item_id, count_of(item_id) + amount)

func take_item(item_id: String, amount: int) -> bool:
	if amount < 1 or count_of(item_id) < amount:
		return false
	_set_item(item_id, count_of(item_id) - amount)
	return true

func can_store(item_id: String) -> bool:
	return item_id in all_stored_ids()

func store_in(holder: Dictionary, item_id: String) -> bool:
	if not can_store(item_id):
		return false
	if not take_item(item_id, 1):
		return false
	holder[item_id] = int(holder.get(item_id, 0)) + 1
	return true

func take_from(holder: Dictionary, item_id: String) -> bool:
	if not can_store(item_id):
		return false
	var have: int = int(holder.get(item_id, 0))
	if have < 1:
		return false
	holder[item_id] = have - 1
	add_item(item_id, 1)
	return true

func to_data() -> Dictionary:
	return {
		"seeds": seeds,
		"turnips": turnips,
		"tomato_seeds": tomato_seeds,
		"tomatoes": tomatoes,
		"wheat_seeds": wheat_seeds,
		"wheat": wheat,
		"watermelon_seeds": watermelon_seeds,
		"watermelons": watermelons,
		"selected_seed": selected_seed,
		"fish": fish,
		"stone": stone,
		"dinars": dinars,
		"wood": wood,
		"dates": dates,
		"forage": forage,
		"hearts": hearts,
		"extra": extra.duplicate(),
	}

func from_data(data: Dictionary) -> void:
	seeds = int(data.get("seeds", 8))
	turnips = int(data.get("turnips", 0))
	tomato_seeds = int(data.get("tomato_seeds", 4))
	tomatoes = int(data.get("tomatoes", 0))
	wheat_seeds = int(data.get("wheat_seeds", 4))
	wheat = int(data.get("wheat", 0))
	watermelon_seeds = int(data.get("watermelon_seeds", 2))
	watermelons = int(data.get("watermelons", 0))
	selected_seed = str(data.get("selected_seed", CropCatalog.TURNIP))
	if not CropCatalog.has_crop(selected_seed):
		selected_seed = CropCatalog.TURNIP
	fish = int(data.get("fish", 0))
	stone = int(data.get("stone", 0))
	dinars = int(data.get("dinars", 0))
	wood = int(data.get("wood", 0))
	dates = int(data.get("dates", 0))
	forage = int(data.get("forage", 0))
	hearts = float(data.get("hearts", 5.0))
	extra.clear()
	var stored_extra: Variant = data.get("extra", {})
	if stored_extra is Dictionary:
		for key: Variant in stored_extra:
			if GoodsCatalog.is_extra(str(key)):
				extra[str(key)] = maxi(0, int(stored_extra[key]))
	for item_id: String in all_stored_ids():
		_set_item(item_id, maxi(0, count_of(item_id)))
	dinars = maxi(0, dinars)
	hearts = clampf(hearts, 0.0, 7.0)

## The repaired market brings more buyers, so goods sell for a tenth more.
func _with_market(amount: int) -> int:
	var works: VillageWorks = get_parent().get_node_or_null("VillageWorks") as VillageWorks
	if works != null and works.is_done("market"):
		return int(ceil(amount * 1.1))
	return amount

func _set_item(item_id: String, amount: int) -> void:
	match item_id:
		"seeds":
			seeds = amount
		"turnips":
			turnips = amount
		"tomato_seeds":
			tomato_seeds = amount
		"tomatoes":
			tomatoes = amount
		"wheat_seeds":
			wheat_seeds = amount
		"wheat":
			wheat = amount
		"watermelon_seeds":
			watermelon_seeds = amount
		"watermelons":
			watermelons = amount
		"fish":
			fish = amount
		"stone":
			stone = amount
		"wood":
			wood = amount
		"dates":
			dates = amount
		"forage":
			forage = amount
		_:
			if GoodsCatalog.is_extra(item_id):
				extra[item_id] = maxi(0, amount)
