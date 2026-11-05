# src/scripts/ui/juice.gd
# Purpose: Small answers to every touch: things shake, fall and break, items fly to the boy, and the phone taps back.

class_name Juice
extends RefCounted

const LEAF_GREEN: Color = Color("6f9a3c")
const LEAF_AUTUMN: Color = Color("d08a3a")
const STONE_GREY: Color = Color("a8a39a")
const WATER_BLUE: Color = Color("8fd3e8")
const DUST_BROWN: Color = Color("8a6238")
const WOOD_CHIP: Color = Color("c79a5e")
## How long the phone taps, in milliseconds, and how hard (0 to 1).
const TAP_LIGHT: Vector2 = Vector2(12, 0.35)
const TAP_FIRM: Vector2 = Vector2(28, 0.65)
const TAP_STRONG: Vector2 = Vector2(55, 1.0)

static var _icons: Dictionary = {}

## The bag picture for an item, shared and cached.
static func item_icon(item: String) -> Texture2D:
	if _icons.has(item):
		return _icons[item]
	var path: String = GoodsCatalog.icon_path(item)
	var icon: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		icon = UiStyle.fit_picture(load(path) as Texture2D, 14)
	elif item == "seeds":
		icon = UiStyle.fit_picture(load("res://assets/farming/Six Pixel Farm Seeds.png") as Texture2D, 14)
	else:
		for crop_id: String in CropCatalog.ids():
			var crop: Dictionary = CropCatalog.get_crop(crop_id)
			if str(crop.get("seed_item", "")) != item and str(crop.get("harvest_item", "")) != item:
				continue
			var sprites: Array = crop.get("sprites", [])
			if not sprites.is_empty():
				var index: int = 0 if str(crop.get("seed_item", "")) == item else sprites.size() - 1
				icon = UiStyle.region_picture(crop["texture"], sprites[index], Vector2(14, 14))
			break
	_icons[item] = icon
	return icon

## A short tap from the phone. It follows the sound effects setting, so Off means no taps either.
static func tap(tree: SceneTree, strength: Vector2 = TAP_LIGHT) -> void:
	if not OS.has_feature("mobile") or tree == null or tree.current_scene == null:
		return
	var stead: Node = tree.current_scene.get_node_or_null("Systems/Stead")
	if stead != null and int(stead.get("sfx_level")) < 1:
		return
	Input.vibrate_handheld(int(strength.x), strength.y)

## The item jumps out of where it was found, bounces once, then flies into the boy.
static func fly_item(place: Node, player: Node2D, item: String, from: Vector2) -> void:
	var icon: Texture2D = item_icon(item)
	if icon == null or place == null or player == null:
		return
	var piece: Sprite2D = Sprite2D.new()
	piece.texture = icon
	piece.z_index = 3500
	piece.position = from
	piece.scale = Vector2(0.2, 0.2)
	place.add_child(piece)
	var side: float = randf_range(-10.0, 10.0)
	var jump: Tween = piece.create_tween()
	jump.set_parallel(true)
	jump.tween_property(piece, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	jump.tween_property(piece, "position:x", from.x + side, 0.36)
	jump.tween_property(piece, "position:y", from.y - 18.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump.tween_property(piece, "position:y", from.y - 4.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.18)
	jump.chain().tween_interval(0.12)
	# The flight follows the boy, so it still lands on him if he walks on.
	var start: Vector2 = from + Vector2(side, -4.0)
	var follow: Callable = func(t: float) -> void:
		if not is_instance_valid(player):
			return
		var goal: Vector2 = player.global_position + Vector2(0, -8)
		var arc: float = sin(t * PI) * 14.0
		piece.global_position = start.lerp(goal, t * t) - Vector2(0, arc)
		piece.scale = Vector2.ONE * lerpf(1.0, 0.45, t)
	jump.chain().tween_method(follow, 0.0, 1.0, 0.32)
	jump.chain().tween_callback(piece.queue_free)

## A quick side to side shake, for a tree hit with the axe or a rock hit with the pick.
static func shake(node: CanvasItem, strength: float = 2.0) -> void:
	if node == null or not is_instance_valid(node) or not node is Node2D:
		return
	var body: Node2D = node as Node2D
	var home: Vector2 = body.position
	var wobble: Tween = body.create_tween()
	for i: int in 4:
		var side: float = strength * (1.0 - float(i) / 4.0) * (1.0 if i % 2 == 0 else -1.0)
		wobble.tween_property(body, "position", home + Vector2(side, 0), 0.04)
	wobble.tween_property(body, "position", home, 0.04)

## A copy of a spot's picture that falls, breaks or pops away, while the spot itself is already gone.
## kind: "tree" tips over, "rock" cracks apart, anything else pops and shrinks.
static func break_away(spot: Node2D, kind: String) -> void:
	if spot == null or not spot.has_method("picture_copy"):
		return
	var place: Node = spot.get_parent()
	var copy: Sprite2D = spot.call("picture_copy") as Sprite2D
	if place == null or copy == null:
		return
	place.add_child(copy)
	var feet: Vector2 = spot.global_position
	var middle: Vector2 = copy.global_position + Vector2(0, copy.offset.y * copy.scale.y)
	var tree: SceneTree = spot.get_tree()
	# A stump or a log is too short to tip over; it breaks apart in chips instead.
	if kind == "tree" and copy.texture.get_size().y * copy.scale.y < 40.0:
		burst(place, middle, WOOD_CHIP, 14, 60.0, 0.5, 2.4)
		tap(tree, TAP_FIRM)
		kind = ""
	match kind:
		"tree":
			var away: float = -1.0 if randf() < 0.5 else 1.0
			var leaves: Color = LEAF_AUTUMN if _season(tree) == "Autumn" else LEAF_GREEN
			var land: Callable = func() -> void:
				burst(place, feet + Vector2(away * 26.0, -6.0), leaves, 22, 60.0, 0.8)
				burst(place, feet + Vector2(away * 14.0, 0.0), DUST_BROWN, 10, 30.0, 0.5)
				tap(tree, TAP_FIRM)
			var fall: Tween = copy.create_tween()
			fall.tween_property(copy, "rotation", -away * 0.06, 0.07)
			fall.tween_property(copy, "rotation", away * 1.45, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fall.tween_callback(land)
			fall.tween_property(copy, "modulate:a", 0.0, 0.35)
			fall.tween_callback(copy.queue_free)
			burst(place, middle, leaves, 10, 40.0, 0.7)
		"rock":
			var crack: Tween = copy.create_tween()
			crack.tween_property(copy, "scale", copy.scale * Vector2(1.12, 0.88), 0.06)
			crack.tween_property(copy, "scale", copy.scale * Vector2(0.7, 0.7), 0.12)
			crack.parallel().tween_property(copy, "modulate:a", 0.0, 0.12)
			crack.tween_callback(copy.queue_free)
			burst(place, middle, STONE_GREY, 16, 70.0, 0.55, 2.5)
			tap(tree, TAP_FIRM)
		_:
			var pop: Tween = copy.create_tween()
			pop.tween_property(copy, "scale", copy.scale * 1.15, 0.07)
			pop.tween_property(copy, "scale", copy.scale * 0.1, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			pop.parallel().tween_property(copy, "modulate:a", 0.0, 0.16)
			pop.tween_callback(copy.queue_free)
			burst(place, middle, LEAF_GREEN, 8, 35.0, 0.45)

## Bits that jump up and fall back: dust, chips, leaves or drops.
static func burst(place: Node, at: Vector2, color: Color, amount: int = 8, speed: float = 34.0, lifetime: float = 0.4, size: float = 2.0) -> void:
	if place == null:
		return
	var puff: CPUParticles2D = CPUParticles2D.new()
	puff.position = at
	puff.z_index = 3000
	puff.amount = amount
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.lifetime = lifetime
	puff.spread = 70.0
	puff.direction = Vector2.UP
	puff.gravity = Vector2(0, 160)
	puff.initial_velocity_min = speed * 0.4
	puff.initial_velocity_max = speed
	puff.scale_amount_min = size * 0.5
	puff.scale_amount_max = size
	puff.color = color
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	puff.color_ramp = fade
	puff.finished.connect(puff.queue_free)
	place.add_child(puff)
	puff.emitting = true

## Water from the can: drops fall in a small ring and splash out.
static func splash(place: Node, at: Vector2) -> void:
	burst(place, at + Vector2(0, -3), WATER_BLUE, 14, 40.0, 0.45, 1.6)
	burst(place, at, Color(1, 1, 1, 0.8), 5, 20.0, 0.3, 1.2)

## A plant that is touched gives a little bounce.
static func boing(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var home: Vector2 = node.scale
	var spring: Tween = node.create_tween()
	spring.tween_property(node, "scale", home * Vector2(1.2, 0.8), 0.06)
	spring.tween_property(node, "scale", home * Vector2(0.9, 1.15), 0.08)
	spring.tween_property(node, "scale", home, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A UI button that pops when it is picked.
static func press(control: Control) -> void:
	if control == null:
		return
	control.pivot_offset = control.size * 0.5
	var pop: Tween = control.create_tween()
	pop.tween_property(control, "scale", Vector2(0.85, 0.85), 0.05)
	pop.tween_property(control, "scale", Vector2(1.18, 1.18), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(control, "scale", Vector2.ONE, 0.1)

static func _season(tree: SceneTree) -> String:
	var clock: Node = tree.current_scene.get_node_or_null("Systems/Clock") if tree != null and tree.current_scene != null else null
	return str(clock.get("season")) if clock != null else "Spring"
