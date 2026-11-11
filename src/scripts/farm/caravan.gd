# src/scripts/farm/caravan.gd
# Purpose: The caravan that stops at the market on the last day of every season, for that day only.
# It brings seeds for the season that starts tomorrow, one rare thing, and a mystery sack.

class_name Caravan
extends RefCounted

## Day of the season, from 0 to 6, as GameClock counts them. The fair is on day 4.
const DAY: int = 6
## Six seeds for the price of four.
const SEED_COUNT: int = 6
const SEED_PAID: int = 4
## item, amount, price. Never cheaper than the merchant pays for it.
const RARE: Dictionary = {
	"Spring": ["copper", 2, 90],
	"Summer": ["iron", 2, 130],
	"Autumn": ["pearl", 1, 140],
	"Winter": ["sprinkler", 1, 150],
}
const SACK: String = "caravan_sack"
const SACK_PRICE: int = 80
## What the sack's goods would sell for, at most. Less than its price.
const SACK_WORTH: int = 72
## The sack holds the first of these the boy has not found for his book yet.
const SACK_FINDS: Array[String] = ["dates", "forage", "fish", "copper", "eggs", "milk", "wool", "iron"]
## Its goods are set down on the grass at the rim of the market square, never on the stones people walk on.
const PROPS: Array[Dictionary] = [
	{"name": "CaravanSack", "path": "res://assets/props/sack.png", "at": Vector2(-66, -190)},
	{"name": "CaravanCrate", "path": "res://assets/props/crate.png", "at": Vector2(-86, -184)},
	{"name": "CaravanBasket", "path": "res://assets/props/basket.png", "at": Vector2(86, -190)},
]

static func is_day(day: int) -> bool:
	return day >= DAY and Friendship.day_of_season(day) == DAY

## What the caravan carries on the given day: rows of id, item, amount and price. Empty on other days.
static func offers(day: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not is_day(day):
		return rows
	var season: String = _season(day)
	var crop_id: String = _coming_crop(season, _season(day + 1))
	var crop: Dictionary = CropCatalog.get_crop(crop_id)
	rows.append({"id": crop_id, "item": str(crop["seed_item"]), "amount": SEED_COUNT, "price": int(crop["seed_price"]) * SEED_PAID})
	var rare: Array = RARE[season]
	rows.append({"id": str(rare[0]), "item": str(rare[0]), "amount": int(rare[1]), "price": int(rare[2])})
	rows.append({"id": SACK, "item": "", "amount": 1, "price": SACK_PRICE})
	return rows

## What is inside the sack: something new for the book when there is one, or else one of the usual finds.
## There is always enough of it to feel like a fair buy, and never enough to sell on for a profit.
static func sack_find(found: Dictionary, day: int) -> Dictionary:
	var item: String = SACK_FINDS[day % SACK_FINDS.size()]
	for item_id: String in SACK_FINDS:
		if not found.has(item_id):
			item = item_id
			break
	return {"item": item, "amount": clampi(int(SACK_WORTH / float(maxi(1, GoodsCatalog.sell_price(item)))), 1, 5)}

static func label(offer: Dictionary) -> String:
	if str(offer["id"]) == SACK:
		return "%s  %d" % [Locale.t(SACK), int(offer["price"])]
	return "%s x%d  %d" % [Locale.item(str(offer["item"])), int(offer["amount"]), int(offer["price"])]

## The dearest crop that grows tomorrow but not today, so the boy can be ready for the new season.
static func _coming_crop(now: String, next: String) -> String:
	var best: String = ""
	var best_new: bool = false
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		var seasons: Array = crop.get("seasons", [])
		if not seasons.has(next):
			continue
		var is_new: bool = not seasons.has(now)
		if best == "" or (is_new and not best_new) or (is_new == best_new and int(crop["seed_price"]) > int(CropCatalog.get_crop(best)["seed_price"])):
			best = crop_id
			best_new = is_new
	return best

static func _season(day: int) -> String:
	return GameClock.SEASONS[int(float(day) / 7.0) % GameClock.SEASONS.size()]
