# src/scripts/data/goods_catalog.gd
# Purpose: Names, icons, and sell prices for goods beyond the crop catalog.

class_name GoodsCatalog
extends RefCounted

const _EXTRAS: Dictionary = {
	"fish": {"sell": 30, "icon": "res://assets/fish/Cozy Gulf Fish Pixel Icon.png"},
	"wood": {"sell": 4, "icon": "res://assets/nature/Pixel art cut wood log.png"},
	"stone": {"sell": 4, "icon": "res://assets/nature/Tiny pixel stone chunk.png"},
	"dates": {"sell": 25, "icon": "res://assets/farming/Date inventory icon.png"},
	"forage": {"sell": 12, "icon": "res://assets/farming/Wild herb inventory icon.png"},
	"eggs": {"sell": 18, "icon": "res://assets/items/Egg.png"},
	"milk": {"sell": 45, "icon": "res://assets/items/Milk.png"},
	"wool": {"sell": 36, "icon": "res://assets/items/Wool.png"},
	"feed": {"sell": 0, "icon": "res://assets/items/Feed.png"},
	"copper": {"sell": 40, "icon": "res://assets/items/Copper.png"},
}

static func extra_ids() -> PackedStringArray:
	return PackedStringArray(["eggs", "milk", "wool", "feed", "copper"])

static func is_extra(item_id: String) -> bool:
	return item_id in extra_ids()

static func sell_price(item_id: String) -> int:
	for crop_id: String in CropCatalog.ids():
		var crop: Dictionary = CropCatalog.get_crop(crop_id)
		if str(crop.get("harvest_item", "")) == item_id:
			return int(crop.get("sell_price", 0))
	return int(_EXTRAS.get(item_id, {}).get("sell", 0))

static func sellable_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for crop_id: String in CropCatalog.ids():
		ids.append(str(CropCatalog.get_crop(crop_id).get("harvest_item", "")))
	for item_id: String in _EXTRAS.keys():
		if int(_EXTRAS[item_id].get("sell", 0)) > 0:
			ids.append(item_id)
	return ids

static func icon_path(item_id: String) -> String:
	return str(_EXTRAS.get(item_id, {}).get("icon", ""))
