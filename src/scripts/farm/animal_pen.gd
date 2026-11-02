# src/scripts/farm/animal_pen.gd
# Purpose: Shows the owned animals wandering near their coop or barn.

extends Node2D

const SHEETS: Dictionary = {
	"chicken": "res://assets/characters/animals/Chicken.png",
	"goat": "res://assets/characters/animals/Goat.png",
	"sheep": "res://assets/characters/animals/Sheep.png",
	"cow": "res://assets/characters/animals/Cow.png",
}

@export var coop_area: Rect2 = Rect2(8, 120, 28, 22)
@export var barn_area: Rect2 = Rect2(106, 104, 36, 36)

var _walkers: Array[Dictionary] = []

func sync(animals: Array) -> void:
	for walker: Dictionary in _walkers:
		(walker["sprite"] as Node).queue_free()
	_walkers.clear()
	for i: int in animals.size():
		var row: Variant = animals[i]
		if not row is Dictionary:
			continue
		var kind: String = str(row.get("kind", ""))
		if not SHEETS.has(kind):
			continue
		var area: Rect2 = coop_area if kind == "chicken" else barn_area
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(SHEETS[kind]) as Texture2D
		sprite.hframes = 2
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = area.position + Vector2(fmod(17.0 * i, area.size.x), fmod(7.0 * i, area.size.y))
		sprite.modulate = Color.WHITE if bool(row.get("fed", false)) else Color(0.92, 0.88, 0.85)
		add_child(sprite)
		var cell: Vector2 = sprite.texture.get_size() / Vector2(2.0, 1.0)
		sprite.add_child(UiStyle.shadow_node(Vector2(0, cell.y * 0.5 - 2.0), cell.x * 0.8))
		sprite.z_index = 2000 + int(global_position.y + sprite.position.y)
		_walkers.append({"sprite": sprite, "area": area, "goal": sprite.position, "wait": 0.5 + 0.3 * i, "clock": 0.0})

func _process(delta: float) -> void:
	for walker: Dictionary in _walkers:
		var sprite: Sprite2D = walker["sprite"]
		var area: Rect2 = walker["area"]
		walker["clock"] = float(walker["clock"]) + delta
		if float(walker["wait"]) > 0.0:
			walker["wait"] = float(walker["wait"]) - delta
			sprite.frame = 0
			continue
		var goal: Vector2 = walker["goal"]
		var gap: Vector2 = goal - sprite.position
		if gap.length() < 1.0:
			walker["goal"] = area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
			walker["wait"] = 1.0 + randf() * 2.5
			continue
		sprite.position += gap.normalized() * minf(12.0 * delta, gap.length())
		sprite.flip_h = gap.x < 0.0
		sprite.frame = int(float(walker["clock"]) * 4.0) % 2
		sprite.z_index = 2000 + int(global_position.y + sprite.position.y)
