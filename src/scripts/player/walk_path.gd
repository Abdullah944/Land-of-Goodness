# src/scripts/player/walk_path.gd
# Purpose: Finds a way around bushes, trees, stalls and walls to where the player tapped.
# When the straight line is clear the boy walks straight. Otherwise a small grid is laid over the ground
# between him and the goal, every square his feet would bump into is marked, and A* finds the way round.

class_name WalkPath
extends RefCounted

## Size of one grid square, in pixels. A big area uses bigger squares, so a far tap never costs a long freeze.
const STEP: float = 8.0
const MOST_SQUARES: int = 200
## How far the grid reaches past the boy and the goal. When no way is found close by, a wider search follows,
## so the way can bend around a long belt of bushes or a pond.
const MARGINS: Array[float] = [120.0, 360.0, 720.0]
## The boy's feet box sits this far below his middle (see player.tscn).
const FEET: Vector2 = Vector2(0, 17)

## Points to walk through, ending at the goal (feet positions). Empty when no way was found.
static func find(player: CharacterBody2D, goal: Vector2) -> PackedVector2Array:
	var feet: Vector2 = player.global_position + FEET
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = _query(player)
	if _clear_line(space, query, feet, goal):
		return PackedVector2Array([goal])
	for margin: float in MARGINS:
		var way: PackedVector2Array = _search(space, query, feet, goal, margin)
		if not way.is_empty():
			return way
	return PackedVector2Array()

static func _search(space: PhysicsDirectSpaceState2D, query: PhysicsShapeQueryParameters2D, feet: Vector2, goal: Vector2, margin: float) -> PackedVector2Array:
	var area: Rect2 = Rect2(feet, Vector2.ZERO).expand(goal).grow(margin)
	var step: float = maxf(STEP, ceil(maxf(area.size.x, area.size.y) / float(MOST_SQUARES)))
	var columns: int = int(ceil(area.size.x / step))
	var rows: int = int(ceil(area.size.y / step))
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, columns, rows)
	grid.cell_size = Vector2(step, step)
	grid.offset = area.position + Vector2(step, step) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x: int in columns:
		for y: int in rows:
			query.transform = Transform2D(0.0, grid.offset + Vector2(x, y) * step)
			if not space.intersect_shape(query, 1).is_empty():
				grid.set_point_solid(Vector2i(x, y))
	var start: Vector2i = _square(grid, feet)
	grid.set_point_solid(start, false)
	var end: Vector2i = _nearest_open(grid, _square(grid, goal))
	if end.x < 0:
		return PackedVector2Array()
	var path: PackedVector2Array = grid.get_point_path(start, end)
	if path.is_empty():
		return path
	return _shorten(space, query, feet, path, goal, end == _square(grid, goal))

static func _query(player: CharacterBody2D) -> PhysicsShapeQueryParameters2D:
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(12, 6)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	return query

## True when the feet box can slide from one point to the other without touching anything.
static func _clear_line(space: PhysicsDirectSpaceState2D, query: PhysicsShapeQueryParameters2D, from: Vector2, to: Vector2) -> bool:
	query.transform = Transform2D(0.0, from)
	query.motion = to - from
	var travel: PackedFloat32Array = space.cast_motion(query)
	query.motion = Vector2.ZERO
	return travel.size() == 0 or travel[0] >= 1.0

static func _square(grid: AStarGrid2D, point: Vector2) -> Vector2i:
	var at: Vector2 = (point - grid.offset) / grid.cell_size.x
	return Vector2i(clampi(roundi(at.x), 0, grid.region.size.x - 1), clampi(roundi(at.y), 0, grid.region.size.y - 1))

## The goal is often a tree or rock, which is solid itself; the boy walks to the closest open square instead.
static func _nearest_open(grid: AStarGrid2D, square: Vector2i) -> Vector2i:
	if not grid.is_point_solid(square):
		return square
	for ring: int in range(1, 8):
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var near: Vector2i = square + Vector2i(dx, dy)
				if grid.is_in_boundsv(near) and not grid.is_point_solid(near):
					return near
	return Vector2i(-1, -1)

## Skips grid corners the boy can walk past in a straight line, so he does not zig-zag.
static func _shorten(space: PhysicsDirectSpaceState2D, query: PhysicsShapeQueryParameters2D, feet: Vector2, path: PackedVector2Array, goal: Vector2, goal_open: bool) -> PackedVector2Array:
	var points: PackedVector2Array = path.duplicate()
	if goal_open:
		points[points.size() - 1] = goal
	var out: PackedVector2Array = PackedVector2Array()
	var from: Vector2 = feet
	var i: int = 0
	while i < points.size():
		var far: int = i
		for j: int in range(points.size() - 1, i, -1):
			if _clear_line(space, query, from, points[j]):
				far = j
				break
		out.append(points[far])
		from = points[far]
		i = far + 1
	return out
