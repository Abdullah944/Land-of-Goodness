# src/scripts/farm/inventory.gd
# Purpose: Keeps seeds, crops, fish, stone, and dinars.

class_name Inventory
extends Node

var seeds: int = 8
var turnips: int = 0
var fish: int = 0
var stone: int = 0
var dinars: int = 0
var wood: int = 0
var hearts: float = 5.0

func spend_heart() -> bool:
	if hearts < 1.0:
		return false
	hearts -= 1.0
	return true

func refill_hearts() -> void:
	hearts = 5.0

func try_craft_seeds() -> bool:
	if stone < 2:
		return false
	stone -= 2
	seeds += 3
	return true

func sell_turnips() -> int:
	var earned: int = turnips * 20
	dinars += earned
	turnips = 0
	return earned

func to_data() -> Dictionary:
	return {
		"seeds": seeds,
		"turnips": turnips,
		"fish": fish,
		"stone": stone,
		"dinars": dinars,
		"wood": wood,
		"hearts": hearts,
	}

func from_data(data: Dictionary) -> void:
	seeds = int(data.get("seeds", 8))
	turnips = int(data.get("turnips", 0))
	fish = int(data.get("fish", 0))
	stone = int(data.get("stone", 0))
	dinars = int(data.get("dinars", 0))
	wood = int(data.get("wood", 0))
	hearts = float(data.get("hearts", 5.0))
