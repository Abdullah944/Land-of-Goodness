# src/scripts/data/fish_catalog.gd
# Purpose: The kinds of fish and where they bite. The home pond always gives the plain fish;
# the forest water and the harbor give Gulf fish, some only in their season.

class_name FishCatalog
extends RefCounted

const PLAIN: String = "fish"
## Chance weights by water. A fish with seasons bites only in those seasons.
const WATERS: Dictionary = {
	"Forest": {"fish": 50, "maid": 30, "sheim": 20},
	"Harbor": {"safi": 35, "zubaidi": 30, "sheim": 15, "hamour": 12, "fish": 8},
}
const SEASONS: Dictionary = {
	"zubaidi": ["Spring", "Summer"],
	"hamour": ["Summer", "Autumn", "Winter"],
}

static func kinds() -> PackedStringArray:
	return PackedStringArray(["maid", "sheim", "safi", "zubaidi", "hamour"])

static func is_fish(item_id: String) -> bool:
	return item_id == PLAIN or item_id in kinds()

## What can bite in a water in a season, with its weight.
static func table(place: String, season: String) -> Dictionary:
	var found: Dictionary = {}
	var water: Dictionary = WATERS.get(place, {})
	for kind: String in water:
		if not SEASONS.has(kind) or season in SEASONS[kind]:
			found[kind] = int(water[kind])
	if found.is_empty():
		found[PLAIN] = 1
	return found

## One catch. The roll is a number from 0 up to 1.
static func pick(place: String, season: String, roll: float) -> String:
	var choices: Dictionary = table(place, season)
	var total: int = 0
	for kind: String in choices:
		total += int(choices[kind])
	var at: float = clampf(roll, 0.0, 0.9999) * total
	for kind: String in choices:
		at -= int(choices[kind])
		if at < 0.0:
			return kind
	return PLAIN
