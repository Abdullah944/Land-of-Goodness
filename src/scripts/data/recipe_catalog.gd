# src/scripts/data/recipe_catalog.gd
# Purpose: Crafting costs and building costs. A new recipe is a new entry.

class_name RecipeCatalog
extends RefCounted

const RECIPES: Dictionary = {
	"feed": {
		"name_key": "craft_feed",
		"costs": {"wheat": 1, "forage": 1},
		"outputs": {"feed": 3},
	},
	"feed_herbs": {
		"name_key": "craft_feed_herbs",
		"costs": {"forage": 2},
		"outputs": {"feed": 2},
	},
}

const FEED_PRICE: int = 10

const BUILDINGS: Dictionary = {
	"coop": {"name_key": "coop", "costs": {"wood": 12, "stone": 6}, "requires": ""},
	"barn": {"name_key": "barn", "costs": {"wood": 20, "stone": 12}, "requires": "coop"},
	"expand": {"name_key": "expand", "costs": {"wood": 8, "stone": 8, "dinars": 100}, "requires": ""},
	"tools": {"name_key": "tools", "costs": {"copper": 3, "dinars": 120}, "requires": ""},
	"house": {"name_key": "house", "costs": {"wood": 30, "stone": 20, "dinars": 1200}, "requires": ""},
	"coop2": {"name_key": "coop2", "costs": {"wood": 15, "stone": 8, "dinars": 600}, "requires": "coop"},
	"barn2": {"name_key": "barn2", "costs": {"wood": 25, "stone": 15, "dinars": 1200}, "requires": "barn"},
	"expand2": {"name_key": "expand2", "costs": {"wood": 16, "stone": 16, "dinars": 800}, "requires": "expand"},
	"tools2": {"name_key": "tools2", "costs": {"copper": 8, "dinars": 800}, "requires": "tools"},
	"decor_rug": {"name_key": "decor_rug", "costs": {"wool": 2, "dinars": 300}, "requires": "house"},
	"decor_table": {"name_key": "decor_table", "costs": {"wood": 6, "dinars": 250}, "requires": "house"},
	"decor_plant": {"name_key": "decor_plant", "costs": {"forage": 2, "dinars": 150}, "requires": "house"},
	"decor_lantern": {"name_key": "decor_lantern", "costs": {"copper": 1, "dinars": 200}, "requires": "house"},
}

## The order the build menu lists things.
const BUILD_ORDER: Array[String] = [
	"coop", "barn", "expand", "tools", "house", "coop2", "barn2", "expand2", "tools2",
	"decor_rug", "decor_table", "decor_plant", "decor_lantern",
]

## Pictures that a bought decoration adds inside the house.
const DECOR: Dictionary = {
	"decor_rug": {"place": "HouseInside", "name": "DecorRug", "path": "res://assets/props/rug_sadu.png", "at": Vector2(70, 120), "flat": true},
	"decor_table": {"place": "HouseInside", "name": "DecorTable", "path": "res://assets/props/table.png", "at": Vector2(70, 128), "block": Vector2(24, 8)},
	"decor_plant": {"place": "HouseInside", "name": "DecorPlant", "path": "res://assets/props/plant.png", "at": Vector2(150, 118)},
	"decor_lantern": {"place": "HouseInside", "name": "DecorLantern", "path": "res://assets/props/lantern.png", "at": Vector2(150, 96)},
}

const BUNDLE_PRICE: int = 70
const BUNDLE_SIZE: int = 10

const ANIMALS: Dictionary = {
	"chicken": {"name_key": "chicken", "price": 180, "home": "coop", "feed": 1, "product": "eggs", "amount": 1, "cap": 4},
	"goat": {"name_key": "goat", "price": 420, "home": "barn", "feed": 1, "product": "milk", "amount": 1, "cap": 2},
	"sheep": {"name_key": "sheep", "price": 380, "home": "barn", "feed": 1, "product": "wool", "amount": 1, "cap": 2},
	"cow": {"name_key": "cow", "price": 800, "home": "barn", "feed": 2, "product": "milk", "amount": 2, "cap": 1},
}

static func recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {})

static func building(building_id: String) -> Dictionary:
	return BUILDINGS.get(building_id, {})

static func animal(kind: String) -> Dictionary:
	return ANIMALS.get(kind, {})
