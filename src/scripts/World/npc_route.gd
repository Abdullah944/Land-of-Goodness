# src/scripts/World/npc_route.gd
# Purpose: Walks its villager between daily spots by the clock, with a small step bounce.

extends Node

## Spots in the place, in the villager's daily order.
@export var spots: PackedVector2Array = PackedVector2Array()
## The hour each spot begins. Same length as spots.
@export var hours: PackedFloat32Array = PackedFloat32Array()
@export var speed: float = 44.0

var _walked: float = 0.0
var _placed: bool = false

func _process(delta: float) -> void:
	var person: Node2D = get_parent() as Node2D
	if person == null or spots.is_empty():
		return
	var goal: Vector2 = spots[_spot_index()]
	if not _placed:
		person.position = goal
		_placed = true
	if _talking(person):
		_set_bob(person, 0.0)
		person.set("walking", false)
		return
	var gap: Vector2 = goal - person.position
	if gap.length() <= 0.5:
		if bool(person.get("walking")):
			person.set("walking", false)
			person.queue_redraw()
		_set_bob(person, 0.0)
		return
	person.set("walking", true)
	var step: float = minf(speed * delta, gap.length())
	person.position += gap.normalized() * step
	_walked += step
	_set_bob(person, 1.0 if int(_walked / 6.0) % 2 == 0 else 0.0)

func _spot_index() -> int:
	var hour: float = _hour()
	var index: int = spots.size() - 1
	for i: int in mini(spots.size(), hours.size()):
		if hour >= hours[i]:
			index = i
	if hours.size() > 0 and hour < hours[0]:
		index = spots.size() - 1
	return index

func _hour() -> float:
	var scene: Node = get_tree().current_scene
	var clock: Node = scene.get_node_or_null("Systems/Clock") if scene != null else null
	if clock == null:
		return 8.0
	return fmod(float(clock.get("minute")) / 60.0, 24.0)

func _talking(person: Node2D) -> bool:
	var scene: Node = get_tree().current_scene
	var dialogue: Node = scene.get_node_or_null("UI/Dialogue") if scene != null else null
	return dialogue != null and bool(dialogue.get("visible")) and bool(person.get("_show_talk"))

func _set_bob(person: Node2D, value: float) -> void:
	if float(person.get("bob")) == value:
		return
	person.set("bob", value)
	person.queue_redraw()
