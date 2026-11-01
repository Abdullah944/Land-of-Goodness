# src/scripts/farm/chest_store.gd
# Purpose: Holds the goods stored in the house chest.

class_name ChestStore
extends Node

var counts: Dictionary = {}

func count_of(item_id: String) -> int:
	return maxi(0, int(counts.get(item_id, 0)))

func store_one(bag: Inventory, item_id: String) -> bool:
	return bag.store_in(counts, item_id)

func take_one(bag: Inventory, item_id: String) -> bool:
	return bag.take_from(counts, item_id)

func to_data() -> Dictionary:
	var data: Dictionary = {}
	for item_id: String in Inventory.all_stored_ids():
		data[item_id] = count_of(item_id)
	return data

func from_data(data: Dictionary) -> void:
	counts.clear()
	for item_id: String in Inventory.all_stored_ids():
		counts[item_id] = maxi(0, int(data.get(item_id, 0)))
