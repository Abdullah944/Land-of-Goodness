# src/scripts/World/jamaah.gd
# Purpose: Prayer together. When a real prayer time comes (the phone's clock, worked out for Kuwait in
# PrayerTimes), the neighbors leave their places for the mosque for two minutes, and a talk box asks the boy
# whether he will pray with them. If he goes, he stands in the row facing the mihrab while a calm window shows
# who is praying with him and how long is left. Afterwards the elder says "May Allah accept from us and you",
# and the boy's heart, the village's Khair and every friendship grow a little.
# The reminder switch in Settings turns this off along with the reminder.

class_name Jamaah
extends Node

## How long the neighbors are at the mosque, and how long the boy prays with them, in seconds.
const LENGTH: float = 120.0
## The neighbors who go. The farm's neighbor is the node named "Neighbor" (Jassim).
const ROLES: Array[String] = ["elder", "merchant", "carpenter", "fisherman"]
const PEOPLE: Array[String] = ["jassim", "elder", "merchant", "carpenter", "fisherman"]
const MOSQUE: String = "res://src/scenes/world/mosque/Mosque_inside.tscn"
## Where the boy stands in the row: the second rug row, in front of the mihrab.
const ROW_SPOT: Vector2 = Vector2(16, 62)
const FRIEND_POINTS: int = 5

signal finished(prayed: bool)

var active: bool = false
var prayer: String = ""
var left: float = 0.0
var praying: bool = false
var _asked: bool = false
var _card: PrayerCard

func _ready() -> void:
	_card = PrayerCard.new()
	_card.visible = false
	add_child(_card)

## Starts the two minutes for this prayer: the neighbors go, and the boy is asked when he is free.
func begin(name: String) -> void:
	if active:
		return
	active = true
	prayer = name
	left = LENGTH
	praying = false
	_asked = false
	_keep_neighbors_away()

func _process(delta: float) -> void:
	if not active:
		return
	left -= delta
	_keep_neighbors_away()
	if praying:
		_card.show_left(left, LENGTH)
	elif not _asked and _boy_is_free():
		_ask()
	if left <= 0.0:
		_finish()

## The boy is asked only when nothing else is on the screen.
func _boy_is_free() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	var player: Player = scene.find_child("Player", true, false) as Player
	if player == null or player.busy:
		return false
	for name: String in ["UI/Dialogue", "UI/TitleMenu", "UI/FishGame", "UI/Ending"]:
		var layer: Node = scene.get_node_or_null(name)
		if layer is CanvasLayer and (layer as CanvasLayer).visible and not (name == "UI/FishGame" and not bool(layer.call("is_open"))):
			return false
	var hud: Node = scene.get_node_or_null("UI/HUD")
	var menu: Variant = hud.get("_menu") if hud != null else null
	return not (menu is Control and (menu as Control).visible)

func _ask() -> void:
	_asked = true
	var dialogue: DialogueBox = get_tree().current_scene.get_node("UI/Dialogue") as DialogueBox
	var activities: Node = get_parent().get_node_or_null("Activities")
	if activities != null:
		activities.set("_shop", "")
	dialogue.set_speaker("elder")
	dialogue.offer(Locale.t("jamaah_call") % Locale.t(prayer), PackedStringArray([
		"jamaah_go|" + Locale.t("jamaah_go"), "jamaah_later|" + Locale.t("jamaah_later")]))
	if not dialogue.picked.is_connected(_on_pick):
		dialogue.picked.connect(_on_pick, CONNECT_ONE_SHOT)

func _on_pick(choice: String) -> void:
	if choice == "jamaah_go":
		join()

## Goes to the mosque (if he is not there already) and prays in the row until the two minutes end.
func join() -> void:
	if not active or praying:
		return
	praying = true
	left = LENGTH
	var activities: Activities = get_parent().get_node_or_null("Activities") as Activities
	var place: Node = activities.place_node() if activities != null else null
	if place == null or place.name != "MosqueInside":
		(get_parent().get_node("LevelLoader") as LevelLoader).go_to(load(MOSQUE) as PackedScene, "PlayerSpawn")
		for i: int in 4:
			await get_tree().process_frame
	var player: Player = get_tree().current_scene.find_child("Player", true, false) as Player
	if player != null:
		player.cancel_tap()
		player.busy = true
		player.global_position = ROW_SPOT
		player.facing = "Up"
		var sprite: AnimatedSprite2D = player.get_node_or_null("CharacterSprite") as AnimatedSprite2D
		if sprite != null and sprite.sprite_frames.has_animation("idle_Up"):
			sprite.play("idle_Up")
	for light: Node in get_tree().get_nodes_in_group("night_light"):
		light.set("enabled", true)
	var hud: Node = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud != null and hud.has_method("set_world_chrome"):
		hud.call("set_world_chrome", false)
	_card.open(Locale.t("jamaah_title") % Locale.t(prayer), PEOPLE)

## The two minutes are over: the neighbors come back, and if the boy prayed, the thanks and the small rewards.
func _finish() -> void:
	var prayed: bool = praying
	active = false
	praying = false
	left = 0.0
	_bring_neighbors_back()
	_card.close()
	var scene: Node = get_tree().current_scene
	if prayed and scene != null:
		var player: Player = scene.find_child("Player", true, false) as Player
		if player != null:
			player.busy = false
		var hud: Node = scene.get_node_or_null("UI/HUD")
		if hud != null and hud.has_method("set_world_chrome"):
			hud.call("set_world_chrome", true)
		var bag: Inventory = get_parent().get_node_or_null("Inventory") as Inventory
		if bag != null:
			bag.hearts = minf(bag.max_hearts, bag.hearts + 1.0)
		var kindness: Kindness = get_parent().get_node_or_null("Kindness") as Kindness
		if kindness != null:
			kindness.reward(1)
		var friends: Node = get_parent().get_node_or_null("Friendship")
		if friends != null:
			var points: Dictionary = friends.get("points")
			for person: String in PEOPLE:
				points[person] = int(points.get(person, 0)) + FRIEND_POINTS
		var dialogue: DialogueBox = scene.get_node("UI/Dialogue") as DialogueBox
		dialogue.set_speaker("elder")
		dialogue.open_lines(PackedStringArray([Locale.t("jamaah_after")]))
		var save: Node = get_parent().get_node_or_null("SaveGame")
		if save != null:
			save.call("write_now")
		var hud_refresh: Node = scene.get_node_or_null("UI/HUD")
		if hud_refresh != null:
			hud_refresh.call("refresh")
	finished.emit(prayed)

## While the neighbors are at the mosque, their places stand empty: they fade out and cannot be talked to.
func _keep_neighbors_away() -> void:
	for mark: Node2D in _neighbors_here():
		if mark.has_meta("at_prayer"):
			continue
		mark.set_meta("at_prayer", true)
		var bodies: Dictionary = {}
		for child: Node in mark.get_children():
			if child is CollisionObject2D:
				bodies[child.name] = (child as CollisionObject2D).collision_layer
				(child as CollisionObject2D).set_deferred("collision_layer", 0)
		mark.set_meta("prayer_bodies", bodies)
		var fade: Tween = mark.create_tween()
		fade.tween_property(mark, "modulate:a", 0.0, 1.2)
		fade.tween_callback(func() -> void:
			if mark.has_meta("at_prayer"):
				mark.visible = false)

func _bring_neighbors_back() -> void:
	for mark: Node2D in _neighbors_here():
		if not mark.has_meta("at_prayer"):
			continue
		mark.remove_meta("at_prayer")
		var bodies: Dictionary = mark.get_meta("prayer_bodies", {})
		for child: Node in mark.get_children():
			if child is CollisionObject2D and bodies.has(child.name):
				(child as CollisionObject2D).set_deferred("collision_layer", int(bodies[child.name]))
		mark.visible = true
		var fade: Tween = mark.create_tween()
		fade.tween_property(mark, "modulate:a", 1.0, 1.2)

func _neighbors_here() -> Array[Node2D]:
	var found: Array[Node2D] = []
	var activities: Activities = get_parent().get_node_or_null("Activities") as Activities
	var place: Node = activities.place_node() if activities != null else null
	if place == null:
		return found
	for mark: Node in place.get_children():
		if not mark is Node2D:
			continue
		var role: Variant = mark.get("role")
		if mark.name == "Neighbor" or (role != null and str(role) in ROLES):
			found.append(mark as Node2D)
	return found

## The calm window while praying: a soft golden light from the mihrab, slow motes of light rising,
## the faces of the neighbors praying in the row, and the time left.
class PrayerCard extends CanvasLayer:
	const CARD: Vector2 = Vector2(300, 96)
	const FACE: float = 36.0
	var _glow: Glow
	var _panel: Panel
	var _title: Label
	var _with: Label
	var _time: Label
	var _bar: ColorRect
	var _fill: ColorRect
	var _faces: HBoxContainer

	func _ready() -> void:
		layer = 3
		_glow = Glow.new()
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_glow)
		_panel = Panel.new()
		_panel.size = CARD
		UiStyle.panel(_panel)
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_panel)
		_title = _label(Vector2(8, 4), Vector2(CARD.x - 16.0, 18), 13, UiStyle.DARK)
		_faces = HBoxContainer.new()
		_faces.position = Vector2(0, 24)
		_faces.size = Vector2(CARD.x, FACE)
		_faces.alignment = BoxContainer.ALIGNMENT_CENTER
		_faces.add_theme_constant_override("separation", 6)
		_faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(_faces)
		_with = _label(Vector2(8, 62), Vector2(CARD.x - 70.0, 14), 9, UiStyle.BROWN)
		_time = _label(Vector2(CARD.x - 62.0, 62), Vector2(54, 14), 11, UiStyle.DARK)
		_bar = ColorRect.new()
		_bar.color = UiStyle.BEIGE
		_bar.position = Vector2(12, 82)
		_bar.size = Vector2(CARD.x - 24.0, 5)
		_panel.add_child(_bar)
		_fill = ColorRect.new()
		_fill.color = Color("d9a441")
		_fill.size = Vector2(0, 5)
		_bar.add_child(_fill)
		get_viewport().size_changed.connect(_fit)
		_fit()

	func _label(at: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
		var label: Label = Label.new()
		label.position = at
		label.size = size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(label)
		return label

	func open(title: String, people: Array[String]) -> void:
		_title.text = title
		Locale.apply_control(_title)
		_with.text = Locale.t("jamaah_with")
		Locale.apply_control(_with)
		_with.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if Locale.language == "ar" else HORIZONTAL_ALIGNMENT_LEFT
		for old: Node in _faces.get_children():
			old.queue_free()
		for person: String in people:
			var path: String = str(DialogueBox.PORTRAITS.get(person, ""))
			if path == "" or not ResourceLoader.exists(path):
				continue
			var frame: Panel = Panel.new()
			frame.custom_minimum_size = Vector2(FACE, FACE)
			frame.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BEIGE, UiStyle.BROWN, 1))
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var face: TextureRect = TextureRect.new()
			face.texture = load(path) as Texture2D
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			face.position = Vector2(2, 2)
			face.size = Vector2(FACE - 4.0, FACE - 4.0)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(face)
			_faces.add_child(frame)
		visible = true
		_glow.modulate.a = 0.0
		_panel.modulate.a = 0.0
		var show: Tween = create_tween().set_parallel(true)
		show.tween_property(_glow, "modulate:a", 1.0, 2.0)
		show.tween_property(_panel, "modulate:a", 1.0, 1.0)

	func show_left(seconds: float, total: float) -> void:
		var whole: int = maxi(0, ceili(seconds))
		_time.text = "%d:%02d" % [whole / 60, whole % 60]
		_fill.size.x = _bar.size.x * clampf(1.0 - seconds / total, 0.0, 1.0)

	func close() -> void:
		if not visible:
			return
		var hide: Tween = create_tween().set_parallel(true)
		hide.tween_property(_glow, "modulate:a", 0.0, 1.0)
		hide.tween_property(_panel, "modulate:a", 0.0, 0.6)
		hide.chain().tween_callback(func() -> void: visible = false)

	func _fit() -> void:
		var view: Vector2 = get_viewport().get_visible_rect().size
		_glow.size = view
		_panel.position = Vector2((view.x - CARD.x) * 0.5, view.y - CARD.y - 12.0)

## A warm light falling from the top middle of the screen, and small motes of light drifting up through it.
class Glow extends Control:
	var _motes: Array[Vector3] = []
	var _clock: float = 0.0

	func _ready() -> void:
		for i: int in 26:
			_motes.append(Vector3(randf(), randf(), randf() * TAU))

	func _process(delta: float) -> void:
		_clock += delta
		for i: int in _motes.size():
			var mote: Vector3 = _motes[i]
			mote.y -= delta * (0.02 + 0.01 * sin(mote.z))
			if mote.y < -0.05:
				mote = Vector3(randf(), 1.05, randf() * TAU)
			_motes[i] = mote
		queue_redraw()

	func _draw() -> void:
		var middle: float = size.x * 0.5
		# Soft warm wash over everything, stronger near the top where the mihrab is.
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.82, 0.45, 0.08))
		for i: int in 6:
			var spread: float = size.x * (0.12 + 0.08 * i)
			var light: Color = Color(1.0, 0.86, 0.5, 0.035)
			draw_colored_polygon(PackedVector2Array([
				Vector2(middle - 30.0, 0), Vector2(middle + 30.0, 0),
				Vector2(middle + spread, size.y), Vector2(middle - spread, size.y)]), light)
		for mote: Vector3 in _motes:
			var shine: float = 0.5 + 0.5 * sin(_clock * 1.6 + mote.z)
			var at: Vector2 = Vector2(mote.x * size.x + sin(_clock * 0.7 + mote.z) * 6.0, mote.y * size.y)
			draw_circle(at, 3.0, Color(1.0, 0.92, 0.6, 0.10 * shine))
			draw_circle(at, 1.3, Color(1.0, 0.96, 0.75, 0.6 * shine))
