# src/scripts/World/cave_work.gd
# Purpose: The effort of mining in the cave. Deeper levels tire the boy more for each rock or vein
# (CaveFloor.mine_cost), so long trips down need food. Outside the cave mining costs nothing extra.

class_name CaveWork
extends RefCounted

## Hearts this spot costs to mine, or 0 outside the cave.
static func cost(spot: Node) -> float:
	var floor: CaveFloor = spot.get_parent() as CaveFloor
	return CaveFloor.mine_cost(floor.level) if floor != null else 0.0

## True when the boy has the strength; otherwise he is told he is tired and nothing is mined.
static func can_mine(spot: Node, activities: Activities) -> bool:
	var need: float = cost(spot)
	if need <= 0.0:
		return true
	var bag: Inventory = activities.get_parent().get_node_or_null("Inventory") as Inventory
	if bag == null or bag.hearts >= need:
		return true
	activities.note = Locale.t("tired")
	var bank: Node = activities.get_parent().get_node_or_null("SoundBank")
	if bank != null:
		bank.call("play", "no")
	return false

static func pay(spot: Node) -> void:
	var need: float = cost(spot)
	var scene: Node = spot.get_tree().current_scene
	var bag: Inventory = scene.get_node_or_null("Systems/Inventory") as Inventory if scene != null else null
	if bag != null and need > 0.0:
		bag.hearts = maxf(0.0, bag.hearts - need)
