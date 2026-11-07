# src/scripts/farm/crop_catalog.gd
# Purpose: Holds the data for each crop. A new crop is a new entry, not a new script.

class_name CropCatalog
extends RefCounted

const TURNIP: String = "turnip"
const TOMATO: String = "tomato"
const WHEAT: String = "wheat"
const WATERMELON: String = "watermelon"
const PLANTS: Texture2D = preload("res://assets/farming/crops/turnip.png")
const TOMATO_SHEET: Texture2D = preload("res://assets/farming/crops/tomato.png")
const WHEAT_SHEET: Texture2D = preload("res://assets/farming/crops/wheat.png")
const MELON_SHEET: Texture2D = preload("res://assets/farming/crops/watermelon.png")

const _CROPS: Dictionary = {
	"turnip": {
		"name": "Turnip",
		"seed_name": "Turnip seed",
		"seed_item": "seeds",
		"harvest_item": "turnips",
		"harvest_amount": 1,
		"mature_stage": 3,
		"seed_price": 10,
		"sell_price": 20,
		"seasons": ["Spring", "Summer", "Autumn"],
		"texture": PLANTS,
		"sprites": [
			Rect2(0, 0, 32, 32),
			Rect2(32, 0, 32, 32),
			Rect2(64, 0, 32, 32),
			Rect2(96, 0, 32, 32),
		],
	},
	"tomato": {
		"name": "Tomato",
		"seed_name": "Tomato seed",
		"seed_item": "tomato_seeds",
		"harvest_item": "tomatoes",
		"harvest_amount": 1,
		"mature_stage": 3,
		## After a harvest the plant stays and fruits again from this stage.
		"regrow_to": 1,
		"seed_price": 20,
		"sell_price": 40,
		"seasons": ["Spring", "Summer"],
		"texture": TOMATO_SHEET,
		"sprites": [
			Rect2(0, 0, 32, 32),
			Rect2(32, 0, 32, 32),
			Rect2(64, 0, 32, 32),
			Rect2(96, 0, 32, 32),
		],
	},
	"wheat": {
		"name": "Wheat",
		"seed_name": "Wheat seed",
		"seed_item": "wheat_seeds",
		"harvest_item": "wheat",
		"harvest_amount": 1,
		"mature_stage": 4,
		"seed_price": 15,
		"sell_price": 30,
		"seasons": ["Autumn", "Winter"],
		"texture": WHEAT_SHEET,
		"sprites": [
			Rect2(0, 0, 32, 32),
			Rect2(32, 0, 32, 32),
			Rect2(64, 0, 32, 32),
			Rect2(96, 0, 32, 32),
			Rect2(128, 0, 32, 32),
		],
	},
	"watermelon": {
		"name": "Watermelon",
		"seed_name": "Watermelon seed",
		"seed_item": "watermelon_seeds",
		"harvest_item": "watermelons",
		"harvest_amount": 1,
		"mature_stage": 4,
		"seed_price": 40,
		"sell_price": 90,
		"seasons": ["Summer"],
		"texture": MELON_SHEET,
		"sprites": [
			Rect2(0, 0, 32, 32),
			Rect2(32, 0, 32, 32),
			Rect2(64, 0, 32, 32),
			Rect2(96, 0, 32, 32),
			Rect2(128, 0, 32, 32),
		],
	},
}

static func ids() -> PackedStringArray:
	return PackedStringArray(["turnip", "tomato", "wheat", "watermelon"])

static func has_crop(crop_id: String) -> bool:
	return _CROPS.has(crop_id)

static func get_crop(crop_id: String) -> Dictionary:
	if not _CROPS.has(crop_id):
		return {}
	return _CROPS[crop_id]
