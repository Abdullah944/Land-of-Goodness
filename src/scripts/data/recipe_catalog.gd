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
}

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
